//
//  ContentView.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

struct ContentView: View {
  @ObservedObject var networkViewModel: NetworkViewModel
  @ObservedObject var fanViewModel: FanViewModel

  var body: some View {
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
        if fanViewModel.isMonitoring {
          HStack(spacing: 6) {
            Circle()
              .fill(Color.green)
              .frame(width: 8, height: 8)
            Text("MONITORING")
              .font(.system(size: 10, weight: .bold))
              .foregroundColor(.green)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Color.green.opacity(0.1))
          .clipShape(Capsule())
        }
      }
      .padding(.horizontal, 30)

      // Single line metric dashboard
      HStack(spacing: 20) {
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
          title: "Fan Speed",
          value: fanViewModel.primaryFanRPM,
          icon: "fanblades.fill",
          color: .indigo
        )
        Button {
          fanViewModel.isShowingThermalDetails = true
        } label: {
          DashboardMetricCard(
            title: "System Temp",
            value: fanViewModel.primaryTemp,
            icon: "thermometer.medium",
            color: .orange
          )
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(.horizontal, 30)

      Divider().opacity(0.3).padding(.horizontal, 30)

      // Settings Section
      SettingsView(networkViewModel: networkViewModel, fanViewModel: fanViewModel)
    }
    .padding(.vertical, 30)
    .frame(minWidth: 900, minHeight: 500)
    .sheet(isPresented: $fanViewModel.isShowingThermalDetails) {
      ThermalDetailView(fanViewModel: fanViewModel)
    }
  }
}

struct ThermalDetailView: View {
  @ObservedObject var fanViewModel: FanViewModel
  @Environment(\.dismiss) var dismiss

  var body: some View {
    VStack(spacing: 0) {
      // Title Header
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

      // Sensor List
      ScrollView {
        VStack(spacing: 1) {
          // Header for list
          HStack {
            Text("Sensor")
              .font(.system(size: 11, weight: .bold))
              .frame(maxWidth: .infinity, alignment: .leading)
            Text("Value")
              .font(.system(size: 11, weight: .bold))
              .frame(width: 80, alignment: .trailing)
          }
          .padding(.horizontal)
          .padding(.vertical, 8)
          .background(Color.secondary.opacity(0.05))

          if fanViewModel.sensors.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: "thermometer.sun.fill")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
              Text("No sensors detected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 60)
          } else {
            ForEach(fanViewModel.sensors) { sensor in
              HStack {
                Label {
                  Text(sensor.name)
                    .font(.system(size: 12))
                } icon: {
                  Image(systemName: iconForSensor(sensor.name))
                    .foregroundColor(colorForSensor(sensor.name))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(String(format: "%.1f°C", sensor.temperature))
                  .font(.system(size: 12, design: .monospaced))
                  .frame(width: 80, alignment: .trailing)
              }
              .padding(.horizontal)
              .padding(.vertical, 10)
              .background(Color.primary.opacity(0.02))
            }
          }
        }
      }
    }
    .frame(width: 400, height: 600)
  }

  private func iconForSensor(_ name: String) -> String {
    if name.contains("CPU") { return "cpu" }
    if name.contains("GPU") { return "memorychip" }
    if name.contains("Airport") { return "wifi" }
    if name.contains("SSD") { return "internaldrive" }
    if name.contains("Battery") { return "battery.100" }
    if name.contains("Ambient") { return "sun.max" }
    return "thermometer"
  }

  private func colorForSensor(_ name: String) -> Color {
    if name.contains("Performance") { return .orange }
    if name.contains("Efficiency") { return .green }
    if name.contains("GPU") { return .purple }
    if name.contains("Airport") { return .blue }
    return .secondary
  }
}

struct DashboardMetricCard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(color)
          .font(.title3)
        Spacer()
        Text(title)
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)
          .tracking(1)
      }

      Text(value)
        .font(.system(size: 24, weight: .bold, design: .monospaced))
        .minimumScaleFactor(0.5)
        .lineLimit(1)
    }
    .padding(20)
    .frame(maxWidth: .infinity)
    .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
    .background(.ultraThinMaterial)
    .cornerRadius(20)
    .shadow(color: Color.black.opacity(0.1), radius: 15, x: 0, y: 8)
    .overlay(
      RoundedRectangle(cornerRadius: 20)
        .stroke(
          LinearGradient(
            colors: [color.opacity(0.2), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
  }
}

#Preview {
  ContentView(networkViewModel: NetworkViewModel(), fanViewModel: FanViewModel())
}
