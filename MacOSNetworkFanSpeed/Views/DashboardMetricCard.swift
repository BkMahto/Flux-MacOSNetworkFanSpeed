//
//  DashboardMetricCard.swift
//  MacOSNetworkFanSpeed
//
//  Created by Bandan.K on 03/02/26.
//

import SwiftUI

struct DashboardMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var showInfoButton: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }

            HStack(alignment: .bottom) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer()

                if showInfoButton {
                    Button {
                        action?()
                    } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(color.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("View Thermal Details")
                }
            }
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
