Name:           lenovo-d330-fix
Version:        5.0.0
Release:        1%{?dist}
Summary:        Complete hardware integration and screen freeze fix for Lenovo IdeaPad D330

License:        GPL-2.0-only
URL:            https://github.com/lucasgabmoreno/linuxmint_lenovod330
BuildArch:      noarch

Requires:       dkms
Requires:       tlp
Requires:       pipewire
Requires:       python3
Requires:       libinput

%description
Complete hardware integration package for Lenovo IdeaPad D330-10IGL
(Type 82H0, 81MD, 81H3). Includes i915 TCON power sequence delay,
Goodix touch calibration, ALSA UCM2 audio profiles, tablet dock daemon,
low-battery hibernation daemon, and sensor hysteresis.

%prep
# No prep required for binary packaging

%install
mkdir -p %{buildroot}/usr/local/bin
mkdir -p %{buildroot}/etc/modprobe.d
mkdir -p %{buildroot}/etc/udev/rules.d
mkdir -p %{buildroot}/etc/udev/hwdb.d
mkdir -p %{buildroot}/etc/systemd/system
mkdir -p %{buildroot}/usr/lib/systemd/user

cp %{_builddir}/tools/d330-* %{buildroot}/usr/local/bin/ || true
# d330-auto-hibernate.service ExecStart= points at the suffix-free name, so
# install the daemon as /usr/local/bin/d330-auto-hibernate, mode 755.
mv %{buildroot}/usr/local/bin/d330-auto-hibernate.py %{buildroot}/usr/local/bin/d330-auto-hibernate
chmod 755 %{buildroot}/usr/local/bin/d330-auto-hibernate
cp %{_builddir}/patches/*/etc/modprobe.d/*.conf %{buildroot}/etc/modprobe.d/ || true
cp %{_builddir}/patches/*/etc/udev/rules.d/*.rules %{buildroot}/etc/udev/rules.d/ || true
cp %{_builddir}/patches/*/etc/udev/hwdb.d/*.hwdb %{buildroot}/etc/udev/hwdb.d/ || true
cp %{_builddir}/patches/*/etc/systemd/system/*.service %{buildroot}/etc/systemd/system/ || true
# systemd USER unit: %post enables it with `systemctl --global enable`, which
# requires the unit under /usr/lib/systemd/user.
cp %{_builddir}/patches/*/usr/lib/systemd/user/*.service %{buildroot}/usr/lib/systemd/user/ || true

%post
systemd-hwdb update || true
udevadm trigger || true
systemctl daemon-reload || true
# SC2: enable all 8 shipped units (parity with install_dkms.sh and deb postinst;
# Phase 37 retired the no-op PWM boot unit).
# M6: the tablet daemon is a systemd USER unit -> enable it globally.
systemctl --global enable d330-tablet-daemon.service 2>/dev/null || true
systemctl enable lenovo-d330-power.service 2>/dev/null || true
systemctl enable lenovo-d330-camera-loopback.service 2>/dev/null || true
systemctl enable d330-hardware-state.service 2>/dev/null || true
systemctl enable d330-sensor-filter.service 2>/dev/null || true
systemctl enable d330-thermal.service 2>/dev/null || true
systemctl enable d330-auto-hibernate.service 2>/dev/null || true
systemctl enable d330-swapfile.service 2>/dev/null || true

%files
/usr/local/bin/*
/etc/modprobe.d/*
/etc/udev/rules.d/*
/etc/udev/hwdb.d/*
/etc/systemd/system/*
/usr/lib/systemd/user/*

%changelog
* Wed Oct 07 2026 Antigravity Community <community@example.com> - 5.0.0-1
- Initial RPM package for Lenovo D330-10IGL parity
