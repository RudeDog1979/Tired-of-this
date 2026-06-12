//
//  StudioTimerProgressTrack.swift
//  BuxMuseTimerWidget
//

import SwiftUI

struct StudioTimerProgressTrack: View {
    let progress: Double
    let isOvertime: Bool
    var height: CGFloat = 8
    var travelerSize: CGFloat = 22

    private var clampedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1.15))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackH = height
            let x = width * clampedProgress

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.78, blue: 0.42),
                                Color(red: 0.98, green: 0.82, blue: 0.18),
                                Color(red: 0.92, green: 0.28, blue: 0.24)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: trackH)

                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: max(0, width - x), height: trackH)
                    .offset(x: x)

                HStack(spacing: 2) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: travelerSize * 0.45, weight: .bold))
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: travelerSize * 0.32, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(5)
                .background {
                    Circle()
                        .fill(isOvertime ? Color.red.opacity(0.92) : Color.black.opacity(0.78))
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                }
                .offset(x: min(max(x - travelerSize / 2, 0), width - travelerSize))
            }
        }
        .frame(height: max(height, travelerSize))
    }
}
