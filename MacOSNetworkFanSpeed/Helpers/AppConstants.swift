//
//  AppConstants.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 03/02/26.
//

import Foundation

struct AppStrings {
    // General
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "FluxBar"
    }
    static let systemMonitor = "System Monitor"

    // Metrics
    static let download = "Download"
    static let upload = "Upload"
    static let fan = "Fan"
    static let systemTemp = "System Temp"
    static let cpuTemp = "CPU Temp"

    // Status
    static let hardwareConnected = "Hardware Connected"
    static let hardwareDisconnected = "Hardware Disconnected"
    static let unknownConnectionError = "Unknown connection error"
    static let smcInterfaceActive = "✅ SMC Interface Active"
    static let noData = "No data"

    // Actions
    static let retryConnection = "Retry Connection"
    static let quitApplication = "Quit Application"
    static let viewThermalDetails = "View Thermal Details"
    static let openSystemHub = "Open System Hub"

    // Settings
    static let menuBarMetrics = "Menu Bar Metrics"
    static let refreshRate = "Refresh Rate"
    static let fanControlPreset = "Fan Control Preset"
    static let hardwareConnection = "Hardware Connection"

    // Modes & Presets
    static let modeMini = "Mini"
    static let modeStandard = "Standard"
    static let modePro = "Pro"

    static let presetAutomatic = "Automatic"
    static let presetManual = "Manual"
    static let presetFullBlast = "Full Blast"

    // Thermal View
    static let thermalSensors = "Thermal Sensors"
    static let sensorsDetected = "sensors detected"
    static let thermalSensorsUpperCase = "THERMAL SENSORS"
    static let pCores = "P-Cores"
    static let eCores = "E-Cores"
    static let system = "System"
    static let pCoreFilter = "P-Core"
    static let eCoreFilter = "E-Core"

    // Formatting
    static let temperatureFormat = "%.1f°C"
    static let rpmUnit = "RPM"
}

struct AppImages {
    // Metric Icons
    static let download = "arrow.down.circle.fill"
    static let upload = "arrow.up.circle.fill"
    static let fan = "fanblades.fill"
    static let temperature = "thermometer.medium"

    // UI Icons
    static let modeMini = "rectangle.portrait"
    static let modeStandard = "rectangle"
    static let modeExpanded = "rectangle.split.3x1"

    static let info = "info.circle.fill"
    static let close = "xmark.circle.fill"
    static let checklist = "checklist"
    static let refresh = "arrow.clockwise.circle"
    static let fanSettings = "fan.fill"
    static let cpu = "cpu"
    static let power = "power.circle.fill"
    static let window = "macwindow"
    static let gauge = "gauge.with.dots.needle.bottom.50percent"
    static let rocket = "rocket.fill"
}
