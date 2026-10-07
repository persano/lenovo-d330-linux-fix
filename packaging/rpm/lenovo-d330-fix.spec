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

cp %{_builddir}/tools/d330-* %{buildroot}/usr/local/bin/ || true
cp %{_builddir}/patches/*/etc/modprobe.d/*.conf %{buildroot}/etc/modprobe.d/ || true
cp %{_builddir}/patches/*/etc/udev/rules.d/*.rules %{buildroot}/etc/udev/rules.d/ || true
cp %{_builddir}/patches/*/etc/udev/hwdb.d/*.hwdb %{buildroot}/etc/udev/hwdb.d/ || true
cp %{_builddir}/patches/*/etc/systemd/system/*.service %{buildroot}/etc/systemd/system/ || true

%post
systemd-hwdb update || true
udevadm trigger || true
systemctl daemon-reload || true
systemctl enable lenovo-d330-resume.service 2>/dev/null || true
systemctl enable d330-tablet-daemon.service 2>/dev/null || true
systemctl enable lenovo-d330-power.service 2>/dev/null || true

%files
/usr/local/bin/*
/etc/modprobe.d/*
/etc/udev/rules.d/*
/etc/udev/hwdb.d/*
/etc/systemd/system/*

%changelog
* Wed Oct 07 2026 Antigravity Community <community@example.com> - 5.0.0-1
- Initial RPM package for Lenovo D330-10IGL parity
