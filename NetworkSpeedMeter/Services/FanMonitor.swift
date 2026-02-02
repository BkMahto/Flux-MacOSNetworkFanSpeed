//
//  FanMonitor.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import Combine
import Foundation

class FanMonitor: ObservableObject {
  private let smc = SMCService.shared

  struct FanData {
    let rpm: Int
    let minRPM: Int
    let maxRPM: Int
  }

  struct SensorData {
    let name: String
    let key: String
    let temperature: Double
  }

  func getFans() -> [FanInfo] {
    var fans: [FanInfo] = []

    // Check key "Num " or "#pn " for count
    let countKey = smc.readKey("Num ") ?? smc.readKey("#pn ")
    let count = countKey.map { Int($0.bytes[0]) } ?? 2  // Default to 2 if count fails

    for i in 0..<count {
      if let rpm = smc.getFanRPM(i) {
        // Try to get min/max
        let minVal = smc.readKey("F\(i)Mn")
        let maxVal = smc.readKey("F\(i)Mx")

        let minRPM = minVal.map { Int(smc.bytesToFloat($0)) } ?? 0
        let maxRPM = maxVal.map { Int(smc.bytesToFloat($0)) } ?? 6000

        fans.append(
          FanInfo(
            id: i,
            name: i == 0 ? "Exhaust" : "Fan \(i)",
            currentRPM: rpm,
            minRPM: minRPM,
            maxRPM: maxRPM,
            mode: .auto
          )
        )
      }
    }

    // If still empty and in simulator, add mock
    #if targetEnvironment(simulator)
      if fans.isEmpty {
        fans = [
          FanInfo(id: 0, name: "Exhaust", currentRPM: 1250, minRPM: 1200, maxRPM: 6000, mode: .auto)
        ]
      }
    #endif

    return fans
  }

  func getSensors() -> [SensorInfo] {
    // Unified list for M-series and Intel fallback
    let keys = [
      ("CPU Performance 1", "Tp09"),
      ("CPU Performance 2", "Tp0b"),
      ("CPU Performance 3", "Tp0d"),
      ("CPU Performance 4", "Tp0f"),
      ("CPU Efficiency 1", "Tp01"),
      ("CPU Efficiency 2", "Tp05"),
      ("GPU Cluster 1", "Tg05"),
      ("GPU Cluster 2", "Tg0b"),
      ("Battery Die", "Tb0R"),
      ("Ambient", "TA0p"),
      ("Power Manager Die", "Tp0C"),
      ("Airport Proximity", "TW0P"),
    ]

    print("🌡️ FanMonitor: Starting sensor enumeration...")
    var sensors: [SensorInfo] = []
    for (name, key) in keys {
      if let temp = smc.getTemperature(key) {
        if temp > 0 && temp < 150 {
          print("  ✅ Sensor found: \(name) (\(key)) = \(String(format: "%.1f", temp))°C")
          sensors.append(SensorInfo(id: key, name: name, temperature: temp, isEnabled: true))
        } else {
          print("  ⚠️ Sensor filtered (out of range): \(name) (\(key)) = \(temp)°C")
        }
      }
    }

    // Fallback: If no M-series specific keys found, try common Intel ones
    if sensors.isEmpty {
      let intelKeys = [("CPU Core 1", "TC0P"), ("CPU Core 2", "TC0H"), ("GPU PECI", "TG0E")]
      for (name, key) in intelKeys {
        if let temp = smc.getTemperature(key) {
          sensors.append(SensorInfo(id: key, name: name, temperature: temp, isEnabled: true))
        }
      }
    }

    // Filter out duplicates (if keys were shared)
    var uniqueSensors: [SensorInfo] = []
    var seenKeys = Set<String>()
    for sensor in sensors {
      if !seenKeys.contains(sensor.id) {
        uniqueSensors.append(sensor)
        seenKeys.insert(sensor.id)
      }
    }

    uniqueSensors.sort { $0.name < $1.name }

    #if targetEnvironment(simulator)
      if uniqueSensors.isEmpty {
        uniqueSensors = [
          SensorInfo(id: "TW0P", name: "Airport Proximity", temperature: 39.7, isEnabled: true),
          SensorInfo(id: "TC0P", name: "CPU Core Average", temperature: 45.6, isEnabled: true),
          SensorInfo(
            id: "Tp09", name: "CPU Performance Core 1", temperature: 47.4, isEnabled: true),
          SensorInfo(id: "TG0P", name: "GPU Cluster Area", temperature: 43.9, isEnabled: true),
          SensorInfo(id: "Ts0P", name: "APPLE SSD", temperature: 37.0, isEnabled: true),
        ]
      }
    #endif

    return uniqueSensors
  }

}
