//
//  FanViewModel.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import SwiftUI

final class FanViewModel: ObservableObject {
    @Published var fans: [FanInfo] = []
    @Published var sensors: [SensorInfo] = []
    @Published var isShowingThermalDetails: Bool = false

    @Published var activePreset: String = "Automatic" {
        didSet {
            UserDefaults.standard.set(activePreset, forKey: "FanPreset")
            Task { @MainActor in
                applyPreset()
            }
        }
    }

    // These are set by views when the dashboard/settings are visible.
    @Published var isDashboardVisible: Bool = false {
        didSet { updateMonitoring(menuBarEnabledMetrics: lastMenuBarEnabledMetrics) }
    }
    @Published var isSettingsVisible: Bool = false {
        didSet { updateMonitoring(menuBarEnabledMetrics: lastMenuBarEnabledMetrics) }
    }

    private var lastMenuBarEnabledMetrics: Set<MetricType> = []

    @Published var isMonitoring: Bool = false {
        didSet {
            if isMonitoring {
                startMonitoring()
            } else {
                timer?.cancel()
                timer = nil
            }

        }
    }

    private let monitor = FanMonitor()
    private let smc = SMCService.shared
    private let fanControl: FanControlProviding = FanControlClient.shared
    private var timer: AnyCancellable?
    private var refreshInterval: Double = 2.0

    init() {
        let savedPreset = UserDefaults.standard.string(forKey: "FanPreset") ?? "Automatic"
        self._activePreset = Published(wrappedValue: savedPreset)
        self._isMonitoring = Published(wrappedValue: false)

        // Start monitoring only if the menu bar (or visible UI) needs it.
        let enabledMetrics = FanViewModel.loadEnabledMetricsFromDefaults()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastMenuBarEnabledMetrics = enabledMetrics
            self.updateMonitoring(menuBarEnabledMetrics: enabledMetrics)
        }
    }

    private static func loadEnabledMetricsFromDefaults() -> Set<MetricType> {
        guard let savedMetrics = UserDefaults.standard.stringArray(forKey: "EnabledMetrics") else {
            return []
        }
        return Set(savedMetrics.compactMap { MetricType(rawValue: $0) })
    }

    private func applyPreset() {
        let isFullBlast = activePreset == "Full Blast"
        let currentFans = fans

        guard !currentFans.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            for fan in currentFans {
                self.fanControl.setFanMode(index: fan.id, manual: isFullBlast)
                if isFullBlast {
                    self.fanControl.setFanTargetRPM(index: fan.id, rpm: fan.maxRPM)
                }
            }
        }
    }

    func setManualRPM(fanID: Int, rpm: Int) {
        // Change preset to "Manual" if it's not already
        if activePreset != "Manual" {
            activePreset = "Manual"
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            self.fanControl.setFanMode(index: fanID, manual: true)
            self.fanControl.setFanTargetRPM(index: fanID, rpm: rpm)
        }
    }

    func startMonitoring() {
        timer?.cancel()
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
        updateStats()  // Initial update
    }

    /// Updates whether fan/sensor polling should be running.
    /// - Parameter menuBarEnabledMetrics: Metrics enabled in the menu bar popover.
    func updateMonitoring(menuBarEnabledMetrics: Set<MetricType>) {
        lastMenuBarEnabledMetrics = menuBarEnabledMetrics

        let menuBarNeedsFanOrTemp =
            menuBarEnabledMetrics.contains(.fan) || menuBarEnabledMetrics.contains(.temperature)

        let shouldMonitor =
            isDashboardVisible || isSettingsVisible || menuBarNeedsFanOrTemp

        // Prevent re-creating timers if the value didn't change.
        if shouldMonitor != isMonitoring {
            isMonitoring = shouldMonitor
        }
    }

    func updateStats() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let newFans = self.monitor.getFans()
            let newSensors = self.monitor.getSensors()

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let fansChanged = self.fans.isEmpty && !newFans.isEmpty
                self.fans = newFans
                self.sensors = newSensors

                if fansChanged {
                    self.applyPreset()
                }
            }
        }
    }

    var primaryFanRPM: String {
        guard let firstFan = fans.first else { return "0 rpm" }
        return "\(firstFan.currentRPM) rpm"
    }

    var primaryTemp: String {
        // Calculate average of all CPU-related sensors
        let cpuSensors = sensors.filter { sensor in
            sensor.name.contains("P-Core") || sensor.name.contains("E-Core")
                || sensor.name.contains("CPU Core") || sensor.name.contains("CPU Package")
        }

        guard !cpuSensors.isEmpty else { return "0°C" }

        let avgTemp = cpuSensors.reduce(0.0) { $0 + $1.temperature } / Double(cpuSensors.count)
        return String(format: "%.0f°C", avgTemp)
    }

}
