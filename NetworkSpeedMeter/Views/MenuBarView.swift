//
//  MenuBarView.swift
//  NetworkSpeedMeter
//
//  Created by Bandan.K on 29/01/26.
//

import SwiftUI

/// `MenuBarView` determines which speed values to display in the system menu bar based on the user's selected `DisplayMode`.
struct MenuBarView: View {
    @ObservedObject var networkViewModel: NetworkViewModel
    @ObservedObject var fanViewModel: FanViewModel

    var body: some View {
        switch networkViewModel.displayMode {
        case .download:
            speedLabel(networkViewModel.downloadSpeed, systemImage: "arrowtriangle.down.fill")
        case .upload:
            speedLabel(networkViewModel.uploadSpeed, systemImage: "arrowtriangle.up.fill")
        case .both:
            speedLabel(networkViewModel.combinedSpeed, systemImage: "arrow.up.and.down")
        case .combined:
            Text("\(networkViewModel.downloadSpeed) | \(networkViewModel.uploadSpeed)")
                .font(.system(size: 9, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.secondary)
        case .fan:
            speedLabel(fanViewModel.primaryFanRPM, systemImage: "fanblades.fill")
        case .temperature:
            speedLabel(fanViewModel.primaryTemp, systemImage: "thermometer.medium")
        case .fanAndTemp:
            Text("\(fanViewModel.primaryFanRPM) | \(fanViewModel.primaryTemp)")
                .font(.system(size: 9, weight: .bold))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func speedLabel(_ speed: String, systemImage: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .symbolVariant(.fill)
                .imageScale(.small)
            Text(speed)
        }
    }
}
