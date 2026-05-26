import SwiftUI

struct AuroraDashboardConcept: View {
    @State private var now = Date()
    @State private var avatarTapped = false
    @State private var bellTapped = false
    
    var body: some View {
        let gradient = auroraGradient(for: now)
        let heroTint = auroraHeroTint(for: now)
        
        ZStack {
            // Background (static)
            LinearGradient(colors: gradient,
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                
                VStack(spacing: 32) {
                    
                    // Header INSIDE scroll (Option A)
                    headerView
                        .padding(.top, 60)
                        .padding(.horizontal, 24)
                    
                    // Hero card
                    heroCard(tint: heroTint)
                        .padding(.horizontal, 24)
                    
                    // Quick actions
                    HStack(spacing: 18) {
                        quickAction(icon: "plus.circle.fill", title: "Add Expense")
                        quickAction(icon: "arrow.down.circle.fill", title: "Add Income")
                        quickAction(icon: "camera.fill", title: "Scan Receipt")
                    }
                    .padding(.horizontal, 24)
                    
                    // Insight cards
                    VStack(spacing: 20) {
                        stackedCard(
                            title: "You spent 12% less than last week",
                            subtitle: "Great progress — keep it up!",
                            icon: "chart.line.uptrend.xyaxis"
                        )
                        
                        stackedCard(
                            title: "Top category: Food & Dining",
                            subtitle: "£182.40 so far this month",
                            icon: "fork.knife"
                        )
                        
                        stackedCard(
                            title: "3 subscriptions renew soon",
                            subtitle: "Tap to review upcoming charges",
                            icon: "repeat.circle"
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Recent activity
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Recent Activity")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        ForEach(0..<3) { _ in
                            recentActivityRow()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                }
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                now = Date()
            }
        }
    }
}

// MARK: - Aurora Engine

extension AuroraDashboardConcept {
    func dynamicGreeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Hello"
        }
    }
    
    func auroraGradient(for date: Date) -> [Color] {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return [.blue.opacity(0.7), .pink.opacity(0.4)]
        case 12..<17: return [.orange.opacity(0.7), .red.opacity(0.4)]
        case 17..<22: return [.purple.opacity(0.7), .indigo.opacity(0.5)]
        default: return [.black.opacity(0.9), .indigo.opacity(0.7)]
        }
    }
    
    func auroraHeroTint(for date: Date) -> Color {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<12: return .blue
        case 12..<17: return .orange
        case 17..<22: return .purple
        default: return .indigo
        }
    }
}

// MARK: - Header View

extension AuroraDashboardConcept {
    var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                // Avatar
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.white)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .scaleEffect(avatarTapped ? 0.85 : 1)
                    .onTapGesture { bounceAvatar() }
                
                Spacer()
                
                // Bell
                Image(systemName: "bell.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    .scaleEffect(bellTapped ? 0.85 : 1)
                    .onTapGesture { bounceBell() }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dynamicGreeting(for: now))
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                
                Text(now.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Bounce Animations

extension AuroraDashboardConcept {
    func bounceAvatar() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            avatarTapped = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring()) {
                avatarTapped = false
            }
        }
    }
    
    func bounceBell() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            bellTapped = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring()) {
                bellTapped = false
            }
        }
    }
}

// MARK: - Hero Card

extension AuroraDashboardConcept {
    func heroCard(tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(tint.opacity(0.25))
                        .blur(radius: 40)
                )
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: tint.opacity(0.4), radius: 30, y: 20)
            
            VStack(spacing: 16) {
                SampleRingsView()
                    .frame(width: 140, height: 140)
                
                Text("£4,920.18")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                
                Text("You're on track this month")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(28)
        }
        .frame(height: 280)
    }
}

// MARK: - Quick Action

extension AuroraDashboardConcept {
    func quickAction(icon: String, title: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 6)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cards

extension AuroraDashboardConcept {
    func stackedCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
    }
    
    func recentActivityRow() -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.2))
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Starbucks")
                    .foregroundColor(.white)
                Text("Yesterday")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            Text("-£6.20")
                .foregroundColor(.white)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Fitness Rings Component

struct SampleRingsView: View {
    var body: some View {
        ZStack {
            ring(color: .pink, progress: 0.75, thickness: 22)
            ring(color: .orange, progress: 0.55, thickness: 16)
            ring(color: .green, progress: 0.35, thickness: 10)
        }
    }
    
    func ring(color: Color, progress: CGFloat, thickness: CGFloat) -> some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.9),
                        color.opacity(0.6),
                        color.opacity(0.9)
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: thickness, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}

#Preview {
    AuroraDashboardConcept()
}

