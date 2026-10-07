# Research: Tablet Mode On-Screen Keyboard & Long-Press Right-Click on Lenovo D330-10IGL

## 1. Context
When detaching the keyboard dock, the user relies exclusively on touch interaction:
- **Virtual Keyboard**: On non-GNOME Wayland/X11 desktops (such as Linux Mint Cinnamon, XFCE, or MATE), detaching the dock fails to activate an on-screen keyboard, leaving the user unable to enter passwords, URLs, or text without reattaching the physical dock.
- **Context Menus**: Touch screens lack a physical right button; users expect long-pressing (holding a finger steady for 750ms) to trigger a context menu.

## 2. Solution
1. **Multi-Desktop OSK Integration in `tools/d330-tablet-daemon.py`**:
   - Supports GNOME Shell / Phosh via `org.gnome.desktop.a11y.applications`.
   - Supports Cinnamon via `org.cinnamon.desktop.a11y.applications`.
   - Supports KDE Plasma via `org.kde.kwin.VirtualKeyboard` D-Bus.
   - Automatically summons `onboard` for generic X11 sessions when in tablet mode, and shuts it down upon dock reconnection.
2. **Touchscreen EmulateThirdButton**:
   - Configured in `50-touchscreen-d330.conf` with `EmulateThirdButton=1`, `EmulateThirdButtonTimeout=750ms`, providing reliable tap-and-hold right clicking across all X11 and XWayland windows.
