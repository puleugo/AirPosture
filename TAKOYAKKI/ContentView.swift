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

// macOS용 AirPods 자세 교정 서비스 메인 뷰
struct ContentView: View {
    @StateObject private var headphoneMotionManager = HeadphoneMotionManager()
    @State private var connectionAttempts = 0
    @State private var showDebugInfo = false

    var body: some View {
        ZStack {
            Color.primary.opacity(0.05)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    if headphoneMotionManager.isDeviceConnected {
                        // 시각적 헤드 트래커
                        VStack(spacing: 8) {
                            // 헤드 시각화와 자세 퍼센트를 중앙 정렬된 수평 스택으로 배치
                            HStack(alignment: .center, spacing: 60) {
                                // 헤드 시각화
                                HeadVisualization(
                                    pitch: headphoneMotionManager.pitch,
                                    roll: headphoneMotionManager.roll,
                                    yaw: headphoneMotionManager.yaw,
                                    postureState: headphoneMotionManager.postureState
                                )
                                .frame(width: 176, height: 176)
                                .padding(.trailing, 10)

                                // 나쁜 자세 퍼센트 원형 표시
                                VStack {
                                    ZStack {
                                        // 배경 원
                                        Circle()
                                            .stroke(
                                                Color.gray.opacity(0.2),
                                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                            )
                                            .frame(width: 154, height: 154)

                                        // 진행률 원
                                        let percentage = Double(headphoneMotionManager.poorPosturePercentage) / 100.0
                                        let color: Color = headphoneMotionManager.poorPosturePercentage >= 40 ? .red : .green

                                        Circle()
                                            .trim(from: 0, to: percentage)
                                            .stroke(
                                                color,
                                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                            )
                                            .frame(width: 154, height: 154)
                                            .rotationEffect(.degrees(-90))
                                            .animation(.easeInOut(duration: 0.3), value: headphoneMotionManager.poorPosturePercentage)

                                        // 퍼센트 텍스트
                                        VStack(spacing: 2) {
                                            Text("\(Int(headphoneMotionManager.poorPosturePercentage))%")
                                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                                .foregroundColor(color)

                                            Text("나쁜 자세")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Text("나쁜 자세 유지 시간")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                }
                                .frame(width: 154)
                                .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 90)
                            .padding(.bottom, 90)

                            PitchGraphView(
                                dataPoints: headphoneMotionManager.pitchHistory,
                                currentPitch: headphoneMotionManager.pitch,
                                poorPostureDuration: headphoneMotionManager.poorPostureDuration,
                                poorPosturePercentage: headphoneMotionManager.poorPosturePercentage
                            )
                            .padding(.horizontal)
                            .padding(.vertical, 20)

                            VStack(alignment: .leading, spacing: 15) {
                                Text("머리 방향")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Divider()
                                    .padding(.vertical, 4)

                                OrientationRow(label: "피치", value: headphoneMotionManager.pitch, description: "위/아래")
                                OrientationRow(label: "롤", value: headphoneMotionManager.roll, description: "좌/우 기울기")
                                OrientationRow(label: "요", value: headphoneMotionManager.yaw, description: "좌/우 회전")
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 20)

                            Spacer(minLength: 100) // macOS에서는 고정 높이 사용
                        }

                    } else {
                        Spacer()

                        VStack(spacing: 25) {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("AirPods Pro 연결 대기 중...")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            Button(action: {
                                connectionAttempts += 1
                                Task {
                                    do {
                                        try await headphoneMotionManager.restart()
                                    } catch {
                                        print("재시작 오류: \(error.localizedDescription)")
                                    }
                                }
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
                                        Text("시뮬레이션 모드 - AirPods Pro 연결을 기다리는 중")
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
                                .padding(.top, 10)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                        .padding(.horizontal)

                        Spacer()
                    }

                    Spacer()

                    // 디버그 정보 푸터
                    HStack {
                        if showDebugInfo {
                            Text("시도 횟수: \(connectionAttempts)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            showDebugInfo.toggle()
                        }) {
                            Image(systemName: showDebugInfo ? "info.circle.fill" : "info.circle")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 5)
                }
                .padding(.horizontal, 5)
            }
        }
        .onAppear {
            // 앱이 나타날 때 안전한 초기화
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                headphoneMotionManager.resetSession()
                Task {
                    do {
                        try await headphoneMotionManager.start()
                    } catch {
                        print("앱 시작 오류: \(error.localizedDescription)")
                    }
                }
            }
        }
        .onDisappear {
            // 앱이 사라질 때 모션 매니저 중지
            Task {
                do {
                    try await headphoneMotionManager.stop()
                } catch {
                    print("앱 중지 오류: \(error.localizedDescription)")
                }
            }
        }
        .task {
            // 태스크 시작 시 기본 초기화
            headphoneMotionManager.resetSession()
        }
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

    var body: some View {
        ZStack {
            // 알림 표시기가 있는 배경 원
            Circle()
                .fill(Color.clear)
                .frame(width: 340, height: 240)
                .overlay(
                    Circle()
                        .stroke(
                            pitch < -22 ? Color.red : Color.green,
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .opacity(0.7)
                        .animation(.easeInOut(duration: 0.3), value: pitch)
                )
                .shadow(
                    color: (pitch < -22 ? Color.red : Color.green).opacity(0.5),
                    radius: pitch < -22 ? 10 : 5,
                    x: 0,
                    y: 0
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: pitch)

            // 사람 아이콘 (macOS에서는 시스템 아이콘 사용)
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 196, height: 196)
                .foregroundColor(colorForState(postureState))
                .modifier(PulseEffect(isActive: isAlertActive))
                .rotationEffect(.degrees(pitch))
        }
        .padding(20)
    }

    private func colorForState(_ state: PostureState) -> Color {
        switch state {
        case .alert:
            return .red
        case .warning:
            return .orange
        default:
            return .blue
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

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

public struct PitchGraphView: View {
    public let dataPoints: [Double]
    public let threshold: Double = -22.0
    public let currentPitch: Double
    public let poorPostureDuration: TimeInterval
    public let poorPosturePercentage: Int

    // 선 색상을 결정하는 계산된 속성
    private var lineColor: Color {
        currentPitch < threshold ? .red : .green
    }

    // 공개 이니셜라이저
    public init(dataPoints: [Double], currentPitch: Double, poorPostureDuration: TimeInterval, poorPosturePercentage: Int) {
        self.dataPoints = dataPoints
        self.currentPitch = currentPitch
        self.poorPostureDuration = poorPostureDuration
        self.poorPosturePercentage = poorPosturePercentage
    }

    private var graphHeight: CGFloat = 120
    // macOS에서는 고정 너비 사용
    private var graphWidth: CGFloat = 600

    private var normalizedData: [CGFloat] {
        guard !dataPoints.isEmpty else { return [] }
        let minValue = min(threshold - 10, dataPoints.min() ?? threshold - 10)
        let maxValue = max(10, dataPoints.max() ?? 10)
        let range = maxValue - minValue

        return dataPoints.map { point in
            let normalized = (point - minValue) / range
            return (1 - normalized) * graphHeight
        }
    }

    private var thresholdY: CGFloat {
        let minValue = min(threshold - 10, dataPoints.min() ?? threshold - 10)
        let maxValue = max(10, dataPoints.max() ?? 10)
        let range = maxValue - minValue
        let normalizedThreshold = (threshold - minValue) / range
        return (1 - normalizedThreshold) * graphHeight
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("나쁜 자세 타이머")
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

                // 임계값 선
                Path { path in
                    path.move(to: CGPoint(x: 0, y: thresholdY))
                    path.addLine(to: CGPoint(x: graphWidth, y: thresholdY))
                }
                .stroke(Color.red.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5]))

                // 그래프 선
                if normalizedData.count > 1 {
                    Path { path in
                        let step = graphWidth / CGFloat(normalizedData.count - 1)
                        path.move(to: CGPoint(x: 0, y: normalizedData[0]))

                        for i in 1..<normalizedData.count {
                            path.addLine(to: CGPoint(x: step * CGFloat(i), y: normalizedData[i]))
                        }
                    }
                    .stroke(lineColor, lineWidth: 6) // 선 두께를 300% 증가

                    // 임계값 아래 영역 채우기
                    Path { path in
                        let step = graphWidth / CGFloat(normalizedData.count - 1)
                        path.move(to: CGPoint(x: 0, y: thresholdY))

                        for i in 0..<normalizedData.count {
                            let y = min(normalizedData[i], thresholdY)
                            path.addLine(to: CGPoint(x: step * CGFloat(i), y: y))
                        }

                        path.addLine(to: CGPoint(x: graphWidth, y: thresholdY))
                        path.closeSubpath()
                    }
                    .fill(Color.green.opacity(0.2))
                }

                // 현재 피치 표시기
                if !normalizedData.isEmpty {
                    let lastX = graphWidth - 10
                    let lastY = normalizedData.last ?? 0

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .position(x: lastX, y: lastY)
                }
            }
            .frame(height: graphHeight)
            .padding(.vertical, 8)

            HStack {
                Text("좋음")
                    .font(.caption2)
                    .foregroundColor(.green)
                Spacer()
                Text("나쁨")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(12)
    }
}

// PostureState는 HeadphoneMotionManager.swift에 정의됨
