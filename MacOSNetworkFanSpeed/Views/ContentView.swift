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

    // View Modes
    enum ViewMode: String, CaseIterable {
        case mini = "Mini"
        case standard = "Standard"
        case expanded = "Pro"

        var width: CGFloat {
            switch self {
            case .mini: return 350
            case .standard: return 630  // 350 + 280
            case .expanded: return 1230  // 350 + 600 + 280
            }
        }

        var icon: String {
            switch self {
            case .mini: return "rectangle.portrait"
            case .standard: return "rectangle"
            case .expanded: return "rectangle.split.3x1"
            }
        }
    }

    @AppStorage("viewMode") private var viewMode: ViewMode = .expanded

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left Column: Metrics Dashboard (Always Visible)
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("System Hub")
                            .font(.title2)
                            .fontWeight(.black)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
                                .frame(width: 6, height: 6)
                            Text(SMCService.shared.isConnected ? "Hardware Connected" : "Hardware Disconnected")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // View Mode Switcher
                    HStack(spacing: 0) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Button {
                                setWindowMode(mode)
                            } label: {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 12, weight: .bold))  // Larger Icon
                                    .foregroundColor(viewMode == mode ? .white : .secondary)
                                    .frame(width: 36, height: 26)  // Larger Touch Target
                                    .background(viewMode == mode ? Color.blue : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.trailing, 4)
                }
                .padding(.horizontal, 30)

                // Metrics Stack
                VStack(spacing: 20) {
                    DashboardMetricCard(
                        title: "Download",
                        value: networkViewModel.downloadSpeed,
                        icon: "arrow.down.circle.fill",
                        color: .blue
                    )
                    DashboardMetricCard(
                        title: "Upload",
                        value: networkViewModel.uploadSpeed,
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                    DashboardMetricCard(
                        title: "Fan",
                        value: fanViewModel.primaryFanRPM,
                        icon: "fanblades.fill",
                        color: .indigo
                    )
                    DashboardMetricCard(
                        title: "System Temp",
                        value: fanViewModel.primaryTemp,
                        icon: "thermometer.medium",
                        color: .orange,
                        showInfoButton: viewMode != .expanded,
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

            // Middle Column: Thermal Details (Only in Expanded mode)
            if viewMode == .expanded {
                Divider()
                VStack(spacing: 0) {
                    ThermalDetailView(fanViewModel: fanViewModel, isEmbedded: true)
                }
                .padding(.horizontal, 10)
                .frame(width: 600)
            }

            // Right Column: Settings Panel (Hidden in Mini mode)
            if viewMode != .mini {
                Divider()
                VStack(spacing: 0) {
                    ScrollView {
                        SettingsView(
                            networkViewModel: networkViewModel,
                            fanViewModel: fanViewModel,
                            showWindowButton: false
                        )
                    }
                }
                .frame(width: 280)
            }
        }
        .frame(width: viewMode.width, height: 650)  // Fixed size
        .onAppear {
            // Ensure app is activated and window is brought to front
            NSApp.setActivationPolicy(.regular)
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            // Explicitly set title and bring to front with small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let window = NSApp.windows.first(where: { $0.canBecomeKey }) {
                    window.title = "System Hub"
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    NSApp.activate(ignoringOtherApps: true)

                    // Enforce fixed size logic
                    setupWindow(window, mode: .standard)
                }
            }
        }
        .onDisappear {
            // Hide Dock icon when window closes
            NSApplication.shared.setActivationPolicy(.accessory)
        }
        .sheet(isPresented: $fanViewModel.isShowingThermalDetails) {
            ThermalDetailView(fanViewModel: fanViewModel)
        }
    }

    // Helper to resize window programmatically
    private func setWindowMode(_ mode: ViewMode) {
        withAnimation {
            viewMode = mode
        }

        if let window = NSApp.windows.first(where: {
            $0.isVisible && ($0.title == "System Hub" || $0.canBecomeKey)
        }) {
            setupWindow(window, mode: mode)
        }
    }

    private func setupWindow(_ window: NSWindow, mode: ViewMode) {
        // Disable manual resizing by making min/max size the same
        let newSize = CGSize(width: mode.width, height: 650)
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
    ContentView(networkViewModel: NetworkViewModel(), fanViewModel: FanViewModel())
}
