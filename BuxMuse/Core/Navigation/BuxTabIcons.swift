//
//  BuxTabIcons.swift
//  BuxMuse
//
//  Code-drawn, tintable tab icons with selection-driven animations.
//

import SwiftUI

// MARK: - Shared animation

enum BuxTabIconAnimation {
    static let selection = Animation.spring(response: 0.38, dampingFraction: 0.72)
    static let gearSpin = Animation.spring(response: 0.42, dampingFraction: 0.68)
    static let wallet = Animation.spring(response: 0.44, dampingFraction: 0.78)
    static let macBook = Animation.spring(response: 0.48, dampingFraction: 0.76)
}

// MARK: - Dashboard (house)

struct DashboardTabIcon: View {
    var isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .stroke(lineWidth: 1.75)
                .frame(width: 14, height: 10)
                .offset(y: 3)

            RoundedRectangle(cornerRadius: 0.5, style: .continuous)
                .fill(.primary)
                .frame(width: 4, height: 5)
                .offset(y: 1)
                .opacity(isSelected ? 0 : 1)

            HouseRoofShape()
                .stroke(style: StrokeStyle(lineWidth: 1.75, lineJoin: .round))
                .frame(width: 18, height: 9)
                .offset(y: isSelected ? -10 : -6)
        }
        .frame(width: 26, height: 26)
        .animation(BuxTabIconAnimation.selection, value: isSelected)
    }
}

private struct HouseRoofShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

// MARK: - Expenses (wallet)

struct ExpensesTabIcon: View {
    var isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .stroke(lineWidth: 1.6)
                .frame(width: 21, height: 15)

            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .fill(.primary)
                .frame(width: 15, height: 9)
                .offset(y: isSelected ? -4.5 : 1.5)
                .opacity(isSelected ? 1 : 0.85)

            WalletFlapShape()
                .stroke(style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
                .frame(width: 21, height: 9)
                .offset(y: 5)
                .rotation3DEffect(
                    .degrees(isSelected ? -58 : 0),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    perspective: 0.35
                )
        }
        .frame(width: 26, height: 26)
        .animation(BuxTabIconAnimation.wallet, value: isSelected)
    }
}

private struct WalletFlapShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

// MARK: - Studio (MacBook)

struct StudioTabIcon: View {
    var isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .stroke(lineWidth: 1.6)
                .frame(width: 21, height: 3.5)
                .offset(y: -1)

            RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                .stroke(lineWidth: 1.6)
                .frame(width: 18, height: 11)
                .offset(y: -6)
                .rotation3DEffect(
                    .degrees(isSelected ? -22 : -88),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: 0.5
                )
        }
        .frame(width: 26, height: 26)
        .animation(BuxTabIconAnimation.macBook, value: isSelected)
    }
}

// MARK: - Settings (gear)

struct SettingsTabIcon: View {
    var isSelected: Bool

    var body: some View {
        GearShape(teeth: 8, toothDepth: 0.18)
            .stroke(style: StrokeStyle(lineWidth: 1.65, lineJoin: .round))
            .frame(width: 22, height: 22)
            .rotationEffect(.degrees(isSelected ? 180 : 0))
            .animation(BuxTabIconAnimation.gearSpin, value: isSelected)
    }
}

private struct GearShape: Shape {
    let teeth: Int
    let toothDepth: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * (1 - toothDepth)
        let holeRadius = outerRadius * 0.28
        let angleStep = (2 * CGFloat.pi) / CGFloat(teeth * 2)

        var path = Path()
        for index in 0..<(teeth * 2) {
            let angle = CGFloat(index) * angleStep - CGFloat.pi / 2
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        path.addEllipse(in: CGRect(
            x: center.x - holeRadius,
            y: center.y - holeRadius,
            width: holeRadius * 2,
            height: holeRadius * 2
        ))
        return path
    }
}

// MARK: - Icon router

struct BuxTabIcon: View {
    let tab: AppTab
    var isSelected: Bool

    var body: some View {
        Group {
            switch tab {
            case .home:
                DashboardTabIcon(isSelected: isSelected)
            case .expense:
                ExpensesTabIcon(isSelected: isSelected)
            case .studio:
                StudioTabIcon(isSelected: isSelected)
            case .settings:
                SettingsTabIcon(isSelected: isSelected)
            }
        }
        .accessibilityHidden(true)
    }
}
