//
//  ContentView.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel
    @ObservedObject var systemViewModel: SystemStatsViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left Column: Metrics Dashboard (Always Visible)
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.appName)
                            .font(.title2)
                            .fontWeight(.black)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
                                .frame(width: 6, height: 6)
                            Text(
                                SMCService.shared.isConnected
                                    ? AppStrings.hardwareConnected : AppStrings.hardwareDisconnected
                            )
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 30)

                // Metrics Stack
                VStack(spacing: 20) {
                    DashboardMetricCard(
                        title: AppStrings.download,
                        value: networkViewModel.downloadSpeed,
                        icon: AppImages.download,
                        color: .blue
                    )
                    DashboardMetricCard(
                        title: AppStrings.upload,
                        value: networkViewModel.uploadSpeed,
                        icon: AppImages.upload,
                        color: .green
                    )
                    DashboardMetricCard(
                        title: AppStrings.fan,
                        value: fanViewModel.primaryFanRPM,
                        icon: AppImages.fan,
                        color: .indigo
                    )
                    DashboardMetricCard(
                        title: AppStrings.systemTemp,
                        value: fanViewModel.primaryTemp,
                        icon: AppImages.temperature,
                        color: .orange,
                        showInfoButton: true,
                        action: {
                            fanViewModel.isShowingThermalDetails = true
                        }
                    )
                }
                .padding(.horizontal, 30)

                Spacer()
            }
            .padding(.vertical, 30)
            .frame(width: 350)

            // Middle Column: Thermal Details
            Divider()
            VStack(spacing: 0) {
                ThermalDetailView(fanViewModel: fanViewModel, isEmbedded: true)
            }
            .padding(.horizontal, 10)
            .frame(width: 600)

            // Right Column: Settings Panel
            Divider()
            VStack(spacing: 0) {
                ScrollView {
                    SettingsView(
                        networkViewModel: networkViewModel,
                        fanViewModel: fanViewModel,
                        systemViewModel: systemViewModel,
                        showWindowButton: false
                    )
                }
            }
            .frame(width: 280)
        }
        .frame(width: 1230, height: 650)  // Fixed size (full layout)
        .onAppear {
            // Mark dashboard as visible so view models can start polling.
            networkViewModel.isDashboardVisible = true
            fanViewModel.isDashboardVisible = true
            fanViewModel.updateMonitoring(menuBarEnabledMetrics: networkViewModel.enabledMetrics)
            systemViewModel.isDashboardVisible = true

            // Ensure app is activated and window is brought to front
            NSApp.setActivationPolicy(.regular)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            // Explicitly set title and bring to front with small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                    window.title = AppStrings.appName
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    NSApp.activate(ignoringOtherApps: true)

                    setupWindow(window)
                }
            }
        }
        .onDisappear {
            // Hide Dock icon when window closes
            networkViewModel.isDashboardVisible = false
            fanViewModel.isDashboardVisible = false
            fanViewModel.updateMonitoring(menuBarEnabledMetrics: networkViewModel.enabledMetrics)
            systemViewModel.isDashboardVisible = false
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        .sheet(isPresented: $fanViewModel.isShowingThermalDetails) {
            ThermalDetailView(fanViewModel: fanViewModel)
        }
    }

    private func setupWindow(_ window: NSWindow) {
        // Disable manual resizing by making min/max size the same
        let newSize = CGSize(width: 1230, height: 650)
        var frame = window.frame
        frame.origin.y += (frame.size.height - newSize.height)  // Keep top alignment? (macOS coords start bottom-left)
        // Actually, keeping the top-left corner stable is usually better, but handling origin.y is tricky without screen info
        // Simple resize from bottom-left or simply setting proper frame:

        window.setFrame(NSRect(origin: frame.origin, size: newSize), display: true, animate: true)

        // Lock the size
        window.minSize = newSize
        window.maxSize = newSize

        // Optional: Remove resizable style mask to completely prevent drag cursor
        window.styleMask.remove(.resizable)
        // Note: Removing .resizable might make the zoom button disabled, which is fine.
        window.standardWindowButton(.zoomButton)?.isEnabled = false
    }
}

#Preview {
    ContentView(
        networkViewModel: NetworkViewModel(),
        fanViewModel: FanViewModel(),
        systemViewModel: SystemStatsViewModel()
    )
}
