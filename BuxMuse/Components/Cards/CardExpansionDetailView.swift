//
//  CardExpansionDetailView.swift
//  BuxMuse
//  Components/Cards/
//
//  Frosted glass detail sheet that slides in when a crypto holding card is expanded.
//  Follows the Master Motion system and Dynamic Theme Engine.
//

import SwiftUI

struct CardExpansionDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    let cardType: String
    @Binding var isPresented: String?
    
    @State private var animateDetails = false
    
    var body: some View {
        ZStack {
            // Dismiss backdrop with glassmorphism blur feel
            Color.black.opacity(colorScheme == .dark ? 0.6 : 0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        isPresented = nil
                    }
                }
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Bar layout with Close button
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                isPresented = nil
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                        }
                        .buttonStyle(BuxMicroShrinkStyle())
                        
                        Spacer()
                        
                        Text("\(cardType) Portfolio")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                        
                        Spacer()
                        
                        Image(systemName: "xmark.circle.fill").opacity(0)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .padding(.top, 60)
                    
                    // Themed card layout
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(colorScheme == .dark ? Color(red: 24/255, green: 26/255, blue: 32/255) : Color.white)
                            .shadow(color: themeManager.current.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.12), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 16) {
                            Text("Current Holdings")
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : Color.black.opacity(0.5))
                            
                            Text(cardType == "BTC" ? "1.1272 BTC" : "0.6948 ETH")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                            
                            Text(cardType == "BTC" ? "$67,203.95" : "$1,801.73")
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Color.black.opacity(0.7))
                        }
                        .padding(28)
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    
                    // Interactive Performance Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Performance Chart")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : Color.black.opacity(0.7))
                        
                        GeometryReader { geometry in
                            Path { path in
                                let width = geometry.size.width
                                let height = geometry.size.height
                                path.move(to: CGPoint(x: 0, y: height * 0.75))
                                path.addQuadCurve(to: CGPoint(x: width * 0.33, y: height * 0.25), control: CGPoint(x: width * 0.16, y: height * 0.9))
                                path.addQuadCurve(to: CGPoint(x: width * 0.66, y: height * 0.6), control: CGPoint(x: width * 0.5, y: height * -0.1))
                                path.addQuadCurve(to: CGPoint(x: width, y: height * 0.15), control: CGPoint(x: width * 0.83, y: height * 1.1))
                            }
                            .stroke(
                                LinearGradient(
                                    colors: [themeManager.current.accentColor, Color(red: 46/255, green: 204/255, blue: 113/255)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                        }
                        .frame(height: 120)
                        .padding(.vertical, 16)
                    }
                    .padding(24)
                    .background(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.03), lineWidth: 1)
                    )
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .offset(y: animateDetails ? 0 : 40)
                    .opacity(animateDetails ? 1.0 : 0.0)
                    
                    // Transfers / Transactions List
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent Transfers")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : Color(red: 26/255, green: 28/255, blue: 32/255))
                            .padding(.horizontal, 8)
                        
                        VStack(spacing: 0) {
                            TransactionRowCard(item: TransactionItem(title: "Received", date: "Today, 14:24", amount: "+0.02 \(cardType)", icon: "arrow.down.left", isPositive: true))
                            Divider().opacity(colorScheme == .dark ? 0.08 : 0.05)
                            TransactionRowCard(item: TransactionItem(title: "Sent", date: "Yesterday, 09:12", amount: "-0.005 \(cardType)", icon: "arrow.up.right", isPositive: false))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(.horizontal, BuxLayout.marginHorizontal)
                    .offset(y: animateDetails ? 0 : 40)
                    .opacity(animateDetails ? 1.0 : 0.0)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.1)) {
                animateDetails = true
            }
        }
    }
}
