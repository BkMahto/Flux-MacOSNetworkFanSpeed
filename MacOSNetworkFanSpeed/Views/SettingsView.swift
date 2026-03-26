//
//  SettingsView.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

/// `SettingsView` provides a unified UI for configuring the app, used in both the menu bar and the main window.
struct SettingsView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject var systemViewModel: SystemStatsViewModel
    var showWindowButton: Bool = true
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(AppStrings.systemMonitor)
                    .font(.headline)
                Spacer()

                // Open main app window
                if showWindowButton {
                    Button {
                        openOrFocusDashboard()
                    } label: {
                        Image(systemName: AppImages.window)
                            .foregroundColor(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .help(AppStrings.openSystemHub)
                }

                Image(systemName: AppImages.gauge)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Real-time stats display (Network & Fan)
            VStack(spacing: 0) {
                StatRow(
                    icon: AppImages.download,
                    label: AppStrings.download,
                    value: networkViewModel.downloadSpeed,
                    color: .blue
                )
                .padding(.vertical, 4)

                StatRow(
                    icon: AppImages.upload,
                    label: AppStrings.upload,
                    value: networkViewModel.uploadSpeed,
                    color: .green
                )
                .padding(.vertical, 4)

                Divider().opacity(0.3)

                StatRow(
                    icon: AppImages.temperature,
                    label: AppStrings.cpuTemp,
                    value: fanViewModel.primaryTemp,
                    color: .orange
                )
                .padding(.vertical, 4)

                StatRow(
                    icon: AppImages.fan,
                    label: fanViewModel.fans.first?.name ?? AppStrings.fan,
                    value: fanViewModel.primaryFanRPM,
                    color: .blue
                )
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // System stats (CPU, Memory, Disk, Battery, GPU)
            VStack(alignment: .leading, spacing: 10) {
                Label("System Metrics", systemImage: AppImages.cpu)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                let gridColumns = [GridItem(.flexible()), GridItem(.flexible())]
                LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                    SystemMetricTile(
                        icon: AppImages.cpu,
                        title: "CPU",
                        value: systemViewModel.cpuUsageText,
                        accent: .purple
                    )
                    SystemMetricTile(
                        icon: "memorychip",
                        title: "Memory",
                        value: systemViewModel.memoryUsageText,
                        accent: .indigo
                    )
                    SystemMetricTile(
                        icon: "arrow.2.circlepath.circle",
                        title: "Swap",
                        value: systemViewModel.swapUsageText,
                        accent: .gray
                    )
                    SystemMetricTile(
                        icon: "internaldrive",
                        title: "Disk Free",
                        value: systemViewModel.diskFreeText,
                        accent: .blue
                    )
                    SystemMetricTile(
                        icon: "internaldrive",
                        title: "Disk IO",
                        value: systemViewModel.diskIOText,
                        accent: .blue
                    )
                    SystemMetricTile(
                        icon: AppImages.power,
                        title: "Battery",
                        value: systemViewModel.batteryStatusText,
                        accent: .green
                    )
                    SystemMetricTile(
                        icon: AppImages.temperature,
                        title: "GPU Temp",
                        value: fanViewModel.primaryGPUTemp,
                        accent: .orange
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.primary.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Menu Bar Metrics Selection
            VStack(alignment: .leading, spacing: 8) {
                Label(AppStrings.menuBarMetrics, systemImage: AppImages.checklist)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    ForEach(MetricType.allCases) { metric in
                        Toggle(
                            isOn: Binding(
                                get: { networkViewModel.enabledMetrics.contains(metric) },
                                set: { isEnabled in
                                    if isEnabled {
                                        networkViewModel.enabledMetrics.insert(metric)
                                    } else {
                                        networkViewModel.enabledMetrics.remove(metric)
                                    }
                                }
                            )
                        ) {
                            HStack {
                                Text("\(metric.icon)")
                                Text(metric.rawValue)
                                    .font(.system(size: 12))
                            }
                        }
                        .toggleStyle(.checkbox)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.02))
                .cornerRadius(8)
            }

            HStack {
                Label(AppStrings.refreshRate, systemImage: AppImages.refresh)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("", selection: $networkViewModel.refreshInterval) {
                    Text("0.5s").tag(0.5)
                    Text("1.0s").tag(1.0)
                    Text("2.0s").tag(2.0)
                    Text("5.0s").tag(5.0)
                }
                .pickerStyle(.menu)
                .frame(width: 70)
            }

            Divider().opacity(0.3)

            /*
             Fan Control Presets are currently disabled because the UI flow is not working reliably.
             Keeping this block commented so it’s easy to re-enable later without losing the wiring.

             VStack(alignment: .leading, spacing: 8) {
                 Label(AppStrings.fanControlPreset, systemImage: AppImages.fanSettings)
                     .font(.system(size: 10, weight: .bold))
                     .foregroundColor(.secondary)

                 Picker("", selection: $fanViewModel.activePreset) {
                     Text(AppStrings.presetAutomatic).tag("Automatic")
                     Text(AppStrings.presetManual).tag("Manual")
                     Text(AppStrings.presetFullBlast).tag("Full Blast")
                 }
                 .pickerStyle(.segmented)
                 .labelsHidden()

                 if fanViewModel.activePreset == "Manual" {
                     ForEach(fanViewModel.fans) { fan in
                         VStack(alignment: .leading, spacing: 4) {
                             HStack {
                                 Text("\(fan.name)")
                                     .font(.system(size: 10))
                                     .foregroundColor(.secondary)
                                 Spacer()
                                 Text("\(Int(fan.targetRPM ?? fan.currentRPM)) \(AppStrings.rpmUnit)")
                                     .font(.system(size: 10, design: .monospaced))
                             }

                             Slider(
                                 value: Binding(
                                     get: { Double(fan.targetRPM ?? fan.currentRPM) },
                                     set: { newValue in
                                         fanViewModel.setManualRPM(fanID: fan.id, rpm: Int(newValue))
                                     }
                                 ),
                                 in: Double(fan.minRPM)...Double(fan.maxRPM),
                                 step: 100
                             )
                             .controlSize(.small)
                         }
                         .padding(.top, 4)
                     }
                 }
             }
             */

            // Hardware Diagnostics
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(AppStrings.hardwareConnection, systemImage: AppImages.cpu)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Circle()
                        .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
                        .frame(width: 8, height: 8)
                }

                if !SMCService.shared.isConnected {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(SMCService.shared.lastError ?? AppStrings.unknownConnectionError)
                            .font(.system(size: 9))
                            .foregroundColor(.red.opacity(0.8))

                        Button {
                            SMCService.shared.reconnect()
                        } label: {
                            Text(AppStrings.retryConnection)
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(6)
                } else {
                    Text(AppStrings.smcInterfaceActive)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            Divider().opacity(0.3)

            Button(
                role: .destructive,
                action: {
                    NSApplication.shared.terminate(nil)
                }
            ) {
                HStack {
                    Image(systemName: AppImages.power)
                    Text(AppStrings.quitApplication)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(.red.opacity(0.8))
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            networkViewModel.isSettingsVisible = true
            fanViewModel.isSettingsVisible = true
            systemViewModel.isSettingsVisible = true
            systemViewModel.refreshInterval = networkViewModel.refreshInterval
            fanViewModel.updateMonitoring(menuBarEnabledMetrics: networkViewModel.enabledMetrics)
        }
        .onDisappear {
            networkViewModel.isSettingsVisible = false
            fanViewModel.isSettingsVisible = false
            systemViewModel.isSettingsVisible = false
            fanViewModel.updateMonitoring(menuBarEnabledMetrics: networkViewModel.enabledMetrics)
        }
        .onChange(of: networkViewModel.refreshInterval) { _, newValue in
            systemViewModel.refreshInterval = newValue
        }
    }

    private func openOrFocusDashboard() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Close menu bar popover if it's the key window
        NSApp.keyWindow?.close()

        if let window = NSApp.windows.first(where: {
            $0.title == AppStrings.appName
        }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            NSApp.sendAction(
                #selector(NSApplication.newWindowForTab(_:)),
                to: nil,
                from: nil
            )
        }
    }
}

private struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SystemMetricTile: View {
    let icon: String
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(accent)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(6)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(8)
    }
}
