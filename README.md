# MacOSNetworkFanSpeed

A macOS menu bar application that monitors network speed, fan RPM, and system temperatures with real-time SMC (System Management Controller) integration.

## Features

- **Network Speed Monitoring**: Real-time download/upload tracking (with configurable refresh rate).
- **Thermal Sensors**: Detailed temperature readings (CPU-related sensors in your current UI; GPU temp derived from your existing sensor list).
- **Menu Bar Integration**: Runs as an accessory app (no dock icon) and provides a menu bar popover.
- **System Metrics (Developer Panel)**: A “System Metrics” section in the app/settings panel showing:
  - **CPU usage %**
  - **Memory usage + swap**
  - **Disk free + disk IO (MB/s)**
  - **Battery status** (on supported hardware)
  - **GPU temperature** (from the same sensor plumbing as your thermal UI)

### Visibility-based polling (performance)

System metrics are **only polled while the Settings view is visible** (your “System Metrics” tiles live inside `SettingsView`). When the settings UI closes, the associated timers/processes are stopped to reduce background CPU usage.

Note: these system metrics are **not shown in the menu bar icon**.

## Fan Control

- The app includes the wiring for fan mode/preset selection.
- The “Fan Control Presets” UI block in `SettingsView` is currently **disabled/commented out** because it isn’t working reliably yet.

## Installation

- Build and run with Xcode 15+.
- Ensure entitlements allow SMC access (for fan + thermal sensor reading).

## License

MIT License.
