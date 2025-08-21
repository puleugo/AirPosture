//
//  ContentView.swift
//  TAKOYAKKI
//
//  Created by 임채성 on 8/20/25.
//

import SwiftUI
import SceneKit
import CoreMotion
import Combine

// 메인 화면: 피치/롤 시각 자료 + 기준 자세 설정
struct MainView: View {
    @EnvironmentObject var headphoneMotionManager: HeadphoneMotionManager
    @State private var connectionAttempts = 0
    @State private var showDebugInfo = false

    var body: some View {
        ZStack {
            Color.primary.opacity(0.05)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if headphoneMotionManager.isDeviceConnected {
                        VStack(spacing: 16) {
                            // 현재 자세 시각화 (피치)
                            HeadVisualization(
                                pitch: headphoneMotionManager.pitch,
                                roll: headphoneMotionManager.roll,
                                yaw: headphoneMotionManager.yaw,
                                postureState: headphoneMotionManager.postureState
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 36)

                            // 좌우 기울기 시각화 (롤)
                            RollTiltVisualization(
                                roll: headphoneMotionManager.roll,
                                threshold: headphoneMotionManager.rollThreshold
                            )
                            .padding(.horizontal)

                            // 기준 자세 설정 버튼
                            VStack {
                                Button(action: {
                                    Task { await headphoneMotionManager.calibrateBaselinePosture() }
                                }) {
                                    HStack {
                                        Image(systemName: "scope")
                                        Text("기준 자세 설정")
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.85))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                Text("현재 자세를 기준으로 저장합니다.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 24)
                        }
                    } else {
                        Spacer()

                        VStack(spacing: 20) {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("AirPods Pro 연결 대기 중")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            Button(action: {
                                connectionAttempts += 1
                                Task { try? await headphoneMotionManager.restart() }
                            }) {
                                Text("연결 재시도")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            if showDebugInfo {
                                VStack(spacing: 4) {
                                    Text("연결 상태: \(headphoneMotionManager.connectionStatus)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    if headphoneMotionManager.isSimulationMode {
                                        Text("시뮬레이션 모드")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    if let error = headphoneMotionManager.lastError {
                                        Text("오류: \(error)")
                                            .font(.caption2)
                                            .foregroundColor(.red)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding(.top, 6)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                        .padding(.horizontal)

                        Spacer()
                    }

                    // 디버그 토글
                    HStack {
                        Spacer()
                        Button(action: { showDebugInfo.toggle() }) {
                            Image(systemName: showDebugInfo ? "info.circle.fill" : "info.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
                .padding(.horizontal, 5)
            }
            .blur(radius: headphoneMotionManager.isCalibrating ? 10 : 0)

            // 보정 중 오버레이 (메인에서 안내)
            if headphoneMotionManager.isCalibrating {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)

                    Text("바른 자세를 3초간 유지하세요")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: headphoneMotionManager.isCalibrating)
    }
}

struct HeadVisualization: View {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let postureState: PostureState

    private var isAlertActive: Bool {
        if case .alert = postureState {
            return true
        }
        return false
    }
    
    private var stateColor: Color {
        colorForState(postureState)
    }

    var body: some View {
        ZStack {
            // 알림 표시기가 있는 배경 원
            Circle()
                .fill(Color.clear)
                .frame(width: 340, height: 240)
                .overlay(
                    Circle()
                        .stroke(
                            stateColor,
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .opacity(0.7)
                        .animation(.easeInOut(duration: 0.3), value: postureState)
                )
                .shadow(
                    color: stateColor.opacity(0.5),
                    radius: isAlertActive ? 10 : 5,
                    x: 0,
                    y: 0
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: postureState)

            // 사람 아이콘 (macOS에서는 시스템 아이콘 사용)
            Image("side")
                .resizable()
                .scaledToFit()
                .frame(width: 196, height: 196)
                .foregroundColor(stateColor)
                .modifier(PulseEffect(isActive: isAlertActive))
                .rotationEffect(.degrees(pitch))
        }
        .padding(20)
    }

    private func colorForState(_ state: PostureState) -> Color {
        switch state {
        case .good:
            return .green
        case .alert:
            return .red
        case .warning:
            return .orange
        }
    }
}

private struct PulseEffect: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isActive ? 1.43 : 1.0)
            .animation(isActive ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: isActive)
    }
}

struct OrientationRow: View {
    let label: String
    let value: Double
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.1f°", value))
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            // 진행률 바 시각화
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 배경
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // 값 표시기
                    let normalizedValue = ((value + 180) / 360).clamped(to: 0...1)
                    let width = normalizedValue * geometry.size.width

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: max(0, width), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct VectorRow: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Spacer()
            Text(String(format: "%.3f %@", value, unit))
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
}

struct RollTiltVisualization: View {
    let roll: Double
    let threshold: Double

    private var ringColor: Color {
        abs(roll) > threshold ? .red : .green
    }

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("롤 시각화 / Roll 可視化")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.3), lineWidth: 10)
                    .frame(width: 160, height: 160)

                Image("front")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(roll))
                    .animation(.easeInOut(duration: 0.2), value: roll)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                Text(String(format: "현재 롤: %.1f°", roll))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "허용 범위: ±%.0f°", threshold))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

public struct PitchGraphView: View {
    public let dataPoints: [Double]
    public let threshold: Double
    public let warningThreshold: Double
    public let referencePitch: Double
    public let currentPitch: Double
    public let poorPostureDuration: TimeInterval
    public let poorPosturePercentage: Int

    // 화면에 표시될 실제 임계값
    private var poorDisplayThreshold: Double {
        referencePitch + threshold
    }
    private var warningDisplayThreshold: Double {
        referencePitch + warningThreshold
    }

    // 선 색상을 결정하는 계산된 속성
    private var lineColor: Color {
        if currentPitch < poorDisplayThreshold {
            return .red
        } else if currentPitch > warningDisplayThreshold {
            return .orange
        } else {
            return .green
        }
    }

    // 공개 이니셜라이저
    public init(dataPoints: [Double], threshold: Double, warningThreshold: Double, referencePitch: Double, currentPitch: Double, poorPostureDuration: TimeInterval, poorPosturePercentage: Int) {
        self.dataPoints = dataPoints
        self.threshold = threshold
        self.warningThreshold = warningThreshold
        self.referencePitch = referencePitch
        self.currentPitch = currentPitch
        self.poorPostureDuration = poorPostureDuration
        self.poorPosturePercentage = poorPosturePercentage
    }

    private var graphHeight: CGFloat = 120
    private var graphWidth: CGFloat = 600

    private var yRange: (min: Double, max: Double) {
        let dataMin = dataPoints.min() ?? poorDisplayThreshold
        let dataMax = dataPoints.max() ?? referencePitch
        
        let lowerBound = min(dataMin, poorDisplayThreshold) - 10
        let upperBound = max(dataMax, referencePitch, warningDisplayThreshold) + 10
        return (lowerBound, upperBound)
    }

    private func normalize(_ value: Double) -> CGFloat {
        let range = yRange.max - yRange.min
        guard range > 0 else { return 0.5 * graphHeight } // 범위가 0일 경우 중앙에 표시
        let normalized = (value - yRange.min) / range
        return (1 - normalized) * graphHeight
    }

    private var normalizedData: [CGPoint] {
        guard !dataPoints.isEmpty else { return [] }
        let step = graphWidth / CGFloat(dataPoints.count - 1)
        return dataPoints.enumerated().map {
            CGPoint(x: step * CGFloat($0.offset), y: normalize($0.element))
        }
    }

    private var poorThresholdY: CGFloat {
        normalize(poorDisplayThreshold)
    }
    
    private var warningThresholdY: CGFloat {
        normalize(warningDisplayThreshold)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("목 각도")
                    .font(.headline)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(String(format: "나쁜 자세: %02d:%02d",
                               Int(poorPostureDuration) / 60,
                               Int(poorPostureDuration) % 60))
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("(세션의 \(poorPosturePercentage)%%)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            ZStack {
                // 그래프 배경
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                
                // 기준선
                Path { path in
                    let y = normalize(referencePitch)
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: graphWidth, y: y))
                }
                .stroke(Color.gray.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

                // 나쁜 자세 임계값 선
                Path { path in
                    path.move(to: CGPoint(x: 0, y: poorThresholdY))
                    path.addLine(to: CGPoint(x: graphWidth, y: poorThresholdY))
                }
                .stroke(Color.red.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5]))
                
                // 경고 임계값 선
                Path { path in
                    path.move(to: CGPoint(x: 0, y: warningThresholdY))
                    path.addLine(to: CGPoint(x: graphWidth, y: warningThresholdY))
                }
                .stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5]))

                // 그래프 선
                if normalizedData.count > 1 {
                    Path { path in
                        path.move(to: normalizedData[0])
                        for point in normalizedData.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(lineColor, lineWidth: 2)
                }
                
                // 축 레이블
                Text("뒤로 누움")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: warningThresholdY - 12)
                
                Text("바른 자세")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: normalize(referencePitch))
                
                Text("나쁜 자세")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: poorThresholdY + 12)

            }
            .frame(height: graphHeight)
            .padding(.vertical, 8)
            .padding(.trailing, 70) // 레이블 공간 확보

            HStack {
                Text(String(format: "나쁜 자세 허용 범위: %.1f°", poorDisplayThreshold))
                    .font(.caption2)
                    .foregroundColor(.red)
                Spacer()
                Text(String(format: "기준: %.1f°", referencePitch))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "뒤로 눕기 허용 범위: %.1f°", warningDisplayThreshold))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

public struct RollGraphView: View {
    public let dataPoints: [Double]
    public let rollThreshold: Double
    public let referenceRoll: Double // 기준점
    public let currentRoll: Double
    
    public init(dataPoints: [Double], rollThreshold: Double, referenceRoll: Double, currentRoll: Double) {
        self.dataPoints = dataPoints
        self.rollThreshold = rollThreshold
        self.referenceRoll = referenceRoll
        self.currentRoll = currentRoll
    }
    
    private var graphHeight: CGFloat = 100
    private var graphWidth: CGFloat = 600
    
    private func yFor(value: Double) -> CGFloat {
        let maxAbs = max(15.0, (dataPoints.map { abs($0 - referenceRoll) }.max() ?? 15.0), rollThreshold) + 5
        let range = maxAbs * 2
        let normalized = (value - (referenceRoll - maxAbs)) / range
        guard range > 0 else { return 0.5 * graphHeight }
        return (1 - normalized) * graphHeight
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("롤 기울기 / Roll（傾き）")
                    .font(.headline)
                Spacer()
                Text(String(format: "현재: %.1f°", currentRoll))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                
                // 기준선
                let y0 = yFor(value: referenceRoll)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y0))
                    path.addLine(to: CGPoint(x: graphWidth, y: y0))
                }
                .stroke(Color.gray.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                
                // +임계값 / -임계값 선 (대시)
                let yp = yFor(value: referenceRoll + rollThreshold)
                let yn = yFor(value: referenceRoll - rollThreshold)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: yp))
                    path.addLine(to: CGPoint(x: graphWidth, y: yp))
                }
                .stroke(Color.orange.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [6]))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: yn))
                    path.addLine(to: CGPoint(x: graphWidth, y: yn))
                }
                .stroke(Color.orange.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [6]))
                
                // 데이터 선
                if dataPoints.count > 1 {
                    Path { path in
                        let step = graphWidth / CGFloat(dataPoints.count - 1)
                        let points = dataPoints.enumerated().map { CGPoint(x: step * CGFloat($0.offset), y: yFor(value: $0.element)) }
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.blue, lineWidth: 2)
                }
                
                // 축 레이블
                Text("바른 자세")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: y0)

                Text("나쁜 자세")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: yp - 12)
                
                Text("나쁜 자세")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: yn + 12)

            }
            .frame(height: graphHeight)
            .padding(.vertical, 6)
            
            HStack {
                Text(String(format: "-%.0f°", rollThreshold))
                    .font(.caption2)
                    .foregroundColor(.orange)
                Spacer()
                Text(String(format: "기준: %.1f°", referenceRoll))
                    .font(.caption2)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "+%.0f°", rollThreshold))
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
    
    // PostureState는 HeadphoneMotionManager.swift에 정의됨
}

// 루트 탭 뷰
struct RootView: View {
    @EnvironmentObject var headphoneMotionManager: HeadphoneMotionManager

    var body: some View {
        TabView {
            MainView()
                .tabItem {
                    Label("메인", systemImage: "house.fill")
                }
            SettingsView()
                .tabItem {
                    Label("설정", systemImage: "slider.horizontal.3")
                }
        }
        .onAppear {
            // 안전한 초기화
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                headphoneMotionManager.resetSession()
                Task { try? await headphoneMotionManager.start() }
            }
        }
        .onDisappear {
            Task { try? await headphoneMotionManager.stop() }
        }
    }
}
// 상세 설정 페이지: 허용 범위 + 그래프
struct SettingsView: View {
    @EnvironmentObject var headphoneMotionManager: HeadphoneMotionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 허용 범위 설정
                VStack(alignment: .leading, spacing: 14) {
                    Text("허용 범위 설정")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Text("위로 젖힘 (피치): \(Int(headphoneMotionManager.warningThreshold))°")
                            .frame(width: 220, alignment: .leading)
                        Slider(value: Binding(
                            get: { headphoneMotionManager.warningThreshold },
                            set: { headphoneMotionManager.warningThreshold = $0 }
                        ), in: 0...45, step: 1)
                    }
                    HStack(spacing: 12) {
                        Text("좌우 기울기 (롤): ±\(Int(headphoneMotionManager.rollThreshold))°")
                            .frame(width: 220, alignment: .leading)
                        Slider(value: Binding(
                            get: { headphoneMotionManager.rollThreshold },
                            set: { headphoneMotionManager.rollThreshold = $0 }
                        ), in: 0...45, step: 1)
                    }
                    HStack(spacing: 12) {
                        Text("아래로 숙임 (피치): \(Int(headphoneMotionManager.poorPostureThreshold))°")
                            .frame(width: 220, alignment: .leading)
                        Slider(value: Binding(
                            get: { headphoneMotionManager.poorPostureThreshold },
                            set: { headphoneMotionManager.poorPostureThreshold = $0 }
                        ), in: -45...0, step: 1)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)

                // 그래프: 피치
                PitchGraphView(
                    dataPoints: headphoneMotionManager.pitchHistory,
                    threshold: headphoneMotionManager.poorPostureThreshold,
                    warningThreshold: headphoneMotionManager.warningThreshold,
                    referencePitch: headphoneMotionManager.referencePitch,
                    currentPitch: headphoneMotionManager.pitch,
                    poorPostureDuration: headphoneMotionManager.poorPostureDuration,
                    poorPosturePercentage: headphoneMotionManager.poorPosturePercentage
                )
                .padding(.horizontal)

                // 그래프: 롤
                RollGraphView(
                    dataPoints: headphoneMotionManager.rollHistory,
                    rollThreshold: headphoneMotionManager.rollThreshold,
                    referenceRoll: headphoneMotionManager.referenceRoll,
                    currentRoll: headphoneMotionManager.roll
                )
                .padding(.horizontal)
            }
            .padding(.vertical, 16)
        }
        .background(Color.primary.opacity(0.05).ignoresSafeArea())
    }
}
