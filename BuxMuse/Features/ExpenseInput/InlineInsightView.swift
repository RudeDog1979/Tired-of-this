//
//  InlineInsightView.swift
//  BuxMuse
//

import SwiftUI

struct InlineInsightView: View {
    let text: String
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .textCase(nil)
        }
        .foregroundColor(.purple)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.purple.opacity(0.15), in: Capsule())
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 5)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.1)) {
                isVisible = true
            }
        }
    }
}
