//
//  FanViewModel.swift
//  NetworkSpeedMeter
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
      applyPreset()
    }
  }

  @Published var isMonitoring: Bool = false {
    didSet {
      if isMonitoring {
        print("🕒 FanViewModel: Starting monitoring timer...")
        startMonitoring()
      } else {
        print("🕒 FanViewModel: Stopping monitoring timer...")
        timer?.cancel()
      }

    }
  }

  private let monitor = FanMonitor()
  private let smc = SMCService.shared
  private var timer: AnyCancellable?
  private var refreshInterval: Double = 2.0

  init() {
    if let savedPreset = UserDefaults.standard.string(forKey: "FanPreset") {
      self.activePreset = savedPreset
    }
    self.isMonitoring = true
    applyPreset()
  }

  private func applyPreset() {
    let isFullBlast = activePreset == "Full Blast"
    let currentFans = fans
    DispatchQueue.global(qos: .userInitiated).async { [smc] in
      for fan in currentFans {
        smc.setFanMode(fan.id, manual: isFullBlast)
        if isFullBlast {
          smc.setFanTargetRPM(fan.id, rpm: fan.maxRPM)
        }
      }
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

  func updateStats() {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      let newFans = self.monitor.getFans()
      let newSensors = self.monitor.getSensors()

      DispatchQueue.main.async {
        self.fans = newFans
        self.sensors = newSensors
      }
    }
  }

  var primaryFanRPM: String {
    guard let firstFan = fans.first else { return "0 rpm" }
    return "\(firstFan.currentRPM) rpm"
  }

  var primaryTemp: String {
    // Try to find a Performance or Core sensor first
    let bestSensor =
      sensors.first { $0.name.contains("Performance") }
      ?? sensors.first { $0.name.contains("Core") }
      ?? sensors.first

    guard let sensor = bestSensor else { return "0°C" }
    return String(format: "%.0f°C", sensor.temperature)
  }

}
