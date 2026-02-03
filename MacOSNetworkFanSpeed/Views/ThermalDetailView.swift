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

    var performanceCores: [SensorInfo] {
        fanViewModel.sensors.filter { $0.name.contains("P-Core") }
    }

    var efficiencyCores: [SensorInfo] {
        fanViewModel.sensors.filter { $0.name.contains("E-Core") }
    }

    var otherSensors: [SensorInfo] {
        fanViewModel.sensors.filter {
            !$0.name.contains("P-Core") && !$0.name.contains("E-Core")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isEmbedded {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Thermal Sensors")
                            .font(.headline)
                        Text("\(fanViewModel.sensors.count) sensors detected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))

                Divider()
            } else {
                Text("THERMAL SENSORS")
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
                    SensorCategoryColumn(title: "P-Cores", sensors: performanceCores, color: .orange)
                    Divider()
                    SensorCategoryColumn(title: "E-Cores", sensors: efficiencyCores, color: .green)
                    Divider()
                    SensorCategoryColumn(title: "System", sensors: otherSensors, color: .purple)
                }
            }
        }
        .frame(width: isEmbedded ? nil : 700, height: isEmbedded ? nil : 500)
    }
}

struct SensorCategoryColumn: View {
    let title: String
    let sensors: [SensorInfo]
    let color: Color
    
    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
            
            if sensors.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(sensors) { sensor in
                    HStack {
                        Text(sensor.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .layoutPriority(1)
                        Spacer(minLength: 6)
                        Text(String(format: "%.1f°C", sensor.temperature))
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
