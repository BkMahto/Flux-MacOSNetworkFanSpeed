//
//  ThermalDetailView.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 03/02/26.
//

import SwiftUI

struct ThermalDetailView: View {
    @ObservedObject var fanViewModel: FanViewModel
    @Environment(\.dismiss) var dismiss
    var isEmbedded: Bool = false
    @StateObject private var cpuUsageViewModel = CPUCoreUsageViewModel()

    var performanceCores: [SensorInfo] {
        fanViewModel.sensors.filter { $0.name.contains(AppStrings.pCoreFilter) }
    }

    var efficiencyCores: [SensorInfo] {
        fanViewModel.sensors.filter { $0.name.contains(AppStrings.eCoreFilter) }
    }

    var otherSensors: [SensorInfo] {
        fanViewModel.sensors.filter {
            !$0.name.contains(AppStrings.pCoreFilter) && !$0.name.contains(AppStrings.eCoreFilter)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isEmbedded {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.thermalSensors)
                            .font(.headline)
                        Text("\(fanViewModel.sensors.count) \(AppStrings.sensorsDetected)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: AppImages.close)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                Divider()
            } else {
                Text(AppStrings.thermalSensorsUpperCase)
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.secondary)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                    .padding(.bottom, 15)
            }

            ScrollView {
                HStack(alignment: .top, spacing: 1) {
                    SensorCategoryColumn(
                        title: AppStrings.pCores,
                        sensors: performanceCores,
                        color: .orange,
                        cpuUsageViewModel: cpuUsageViewModel,
                        cpuBaseIndex: 0
                    )
                    Divider()
                    SensorCategoryColumn(
                        title: AppStrings.eCores,
                        sensors: efficiencyCores,
                        color: .green,
                        cpuUsageViewModel: cpuUsageViewModel,
                        cpuBaseIndex: performanceCores.count
                    )
                    Divider()
                    SensorCategoryColumn(
                        title: AppStrings.system,
                        sensors: otherSensors,
                        color: .purple,
                        cpuUsageViewModel: nil,
                        cpuBaseIndex: nil
                    )
                }
            }
        }
        .frame(width: isEmbedded ? nil : 700, height: isEmbedded ? nil : 500)
        .onAppear {
            cpuUsageViewModel.refreshInterval = 1.0
            cpuUsageViewModel.start()
        }
        .onDisappear {
            cpuUsageViewModel.stop()
        }
    }
}

struct SensorCategoryColumn: View {
    let title: String
    let sensors: [SensorInfo]
    let color: Color
    let cpuUsageViewModel: CPUCoreUsageViewModel?
    let cpuBaseIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))

            if sensors.isEmpty {
                Text(AppStrings.noData)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(sensors.enumerated()), id: \.element.id) { index, sensor in
                    HStack {
                        Text(sensor.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .layoutPriority(1)
                        Spacer(minLength: 6)
                        if let cpuUsageViewModel, let cpuBaseIndex, let usage = cpuUsageViewModel.usagePercentText(coreIndex: cpuBaseIndex + index) {
                            Text(usage)
                                .foregroundColor(.secondary)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .frame(minWidth: 40, alignment: .trailing)
                        }
                        Text(String(format: AppStrings.temperatureFormat, sensor.temperature))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
