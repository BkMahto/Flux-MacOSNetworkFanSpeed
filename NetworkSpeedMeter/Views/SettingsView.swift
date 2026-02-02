//
//  SettingsView.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

/// `SettingsView` provides a unified UI for configuring the app, used in both the menu bar and the main window.
struct SettingsView: View {
  @ObservedObject var networkViewModel: NetworkViewModel
  @ObservedObject var fanViewModel: FanViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      HStack {
        Text("System Monitor")
          .font(.headline)
        Spacer()
        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
          .foregroundColor(.secondary)
      }

      Divider()

      // Real-time stats display (Network & Fan)
      VStack(spacing: 0) {
        StatRow(
          icon: "arrow.down.circle.fill",
          label: "Download",
          value: networkViewModel.downloadSpeed,
          color: .blue
        )
        .padding(.vertical, 4)

        StatRow(
          icon: "arrow.up.circle.fill",
          label: "Upload",
          value: networkViewModel.uploadSpeed,
          color: .green
        )
        .padding(.vertical, 4)

        Divider().opacity(0.3)

        StatRow(
          icon: "fanblades.fill",
          label: fanViewModel.fans.first?.name ?? "Fan",
          value: fanViewModel.primaryFanRPM,
          color: .blue
        )
        .padding(.vertical, 4)

        StatRow(
          icon: "thermometer.medium",
          label: "CPU Temp",
          value: fanViewModel.primaryTemp,
          color: .orange
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

      // Network Configuration
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Label("Menu Bar Display", systemImage: "macwindow.badge.plus")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)

          Picker("", selection: $networkViewModel.displayMode) {
            Group {
              Text("Down").tag(DisplayMode.download)
              Text("Up").tag(DisplayMode.upload)
              Text("Total").tag(DisplayMode.both)
              Text("Dual").tag(DisplayMode.combined)
            }
            Divider()
            Group {
              Text("Fan").tag(DisplayMode.fan)
              Text("Temp").tag(DisplayMode.temperature)
              Text("F+T").tag(DisplayMode.fanAndTemp)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
        }

        HStack {
          Label("Refresh Rate", systemImage: "arrow.clockwise.circle")
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
      }

      Divider().opacity(0.3)

      // Fan Control Presets
      VStack(alignment: .leading, spacing: 8) {
        Label("Fan Control Preset", systemImage: "fan.fill")
          .font(.system(size: 10, weight: .bold))
          .foregroundColor(.secondary)

        Picker("", selection: $fanViewModel.activePreset) {
          Text("Automatic").tag("Automatic")
          Text("Full Blast").tag("Full Blast")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }

      Divider().opacity(0.3)

      // Hardware Diagnostics
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label("Hardware Connection", systemImage: "cpu")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)
          Spacer()
          Circle()
            .fill(SMCService.shared.isConnected ? Color.blue : Color.red)
            .frame(width: 8, height: 8)
        }

        if !SMCService.shared.isConnected {
          VStack(alignment: .leading, spacing: 4) {
            Text(SMCService.shared.lastError ?? "Unknown connection error")
              .font(.system(size: 9))
              .foregroundColor(.red.opacity(0.8))

            Button {
              SMCService.shared.reconnect()
            } label: {
              Text("Retry Connection")
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
          Text("✅ SMC Interface Active")
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
          Image(systemName: "power.circle.fill")
          Text("Quit Application")
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
    }
  }
}
