//
//  SettingsView.swift
//  TAKOYAKKI
//
//  Created by 임채성 on 8/20/25.
//

import SwiftUI
import SceneKit
import CoreMotion
import Combine

// 상세 설정 페이지: 허용범위, 그래프
struct SettingsView: View {
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
                        // 피치 그래프
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
                        .padding(.vertical, 20)

                        // 롤 기울기 그래프
                        RollGraphView(
                            dataPoints: headphoneMotionManager.rollHistory,
                            rollThreshold: headphoneMotionManager.rollThreshold,
                            referenceRoll: headphoneMotionManager.referenceRoll,
                            currentRoll: headphoneMotionManager.roll
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 20)

                        // 임계값 설정
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Set Allowable Posture Deviation Rang")
                                .font(.headline)
                                .padding(.bottom, 8)
                            
                            VStack(spacing: 16) {
                                HStack(spacing: 12) {
                                    Text("Leaning Back (Up): \(Int(headphoneMotionManager.warningThreshold))°")
                                        .frame(width: 220, alignment: .leading)
                                    Slider(value: Binding(
                                        get: { headphoneMotionManager.warningThreshold },
                                        set: { headphoneMotionManager.warningThreshold = $0 }
                                    ), in: 0...45, step: 1)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                                
                                HStack(spacing: 12) {
                                    Text("Tilt(Left/Right): \(Int(headphoneMotionManager.rollThreshold))°")
                                        .frame(width: 220, alignment: .leading)
                                    Slider(value: Binding(
                                        get: { headphoneMotionManager.rollThreshold },
                                        set: { headphoneMotionManager.rollThreshold = $0 }
                                    ), in: 0...45, step: 1)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                                
                                HStack(spacing: 12) {
                                    Text("Tilt(Up/Down): \(Int(headphoneMotionManager.poorPostureThreshold))°")
                                        .frame(width: 220, alignment: .leading)
                                    Slider(value: Binding(
                                        get: { headphoneMotionManager.poorPostureThreshold },
                                        set: { headphoneMotionManager.poorPostureThreshold = $0 }
                                    ), in: -45...0, step: 1)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // 회전 속도 정보
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Rotation Rate")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Divider().padding(.vertical, 4)

                            VectorRow(label: "X", value: headphoneMotionManager.rotationRate.x, unit: "rad/s")
                            VectorRow(label: "Y", value: headphoneMotionManager.rotationRate.y, unit: "rad/s")
                            VectorRow(label: "Z", value: headphoneMotionManager.rotationRate.z, unit: "rad/s")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // 사용자 가속도
                        VStack(alignment: .leading, spacing: 12) {
                            Text("User Acceleration")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Divider().padding(.vertical, 4)

                            VectorRow(label: "X", value: headphoneMotionManager.userAcceleration.x, unit: "g")
                            VectorRow(label: "Y", value: headphoneMotionManager.userAcceleration.y, unit: "g")
                            VectorRow(label: "Z", value: headphoneMotionManager.userAcceleration.z, unit: "g")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // 중력
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Gravity")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Divider().padding(.vertical, 4)

                            VectorRow(label: "X", value: headphoneMotionManager.gravity.x, unit: "g")
                            VectorRow(label: "Y", value: headphoneMotionManager.gravity.y, unit: "g")
                            VectorRow(label: "Z", value: headphoneMotionManager.gravity.z, unit: "g")
                        }
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Spacer(minLength: 100)
                    } else {
                        Spacer()

                        VStack(spacing: 25) {
                            Image(systemName: "airpodspro")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)

                            Text("Waiting for AirPods Pro Connecting...")
                                .font(.title3)
                                .foregroundColor(.secondary)

                            Button(action: {
                                connectionAttempts += 1
                                Task {
                                    do {
                                        try await headphoneMotionManager.restart()
                                    } catch {
                                        print("Restart Error: \(error.localizedDescription)")
                                    }
                                }
                            }) {
                                Text("Retry Connection")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            if showDebugInfo {
                                VStack(spacing: 4) {
                                    Text("Connection Status: \(headphoneMotionManager.connectionStatus)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if headphoneMotionManager.isSimulationMode {
                                        Text("Simulation Mode - Waiting for AirPods Pro Connection")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    if let error = headphoneMotionManager.lastError {
                                        Text("Error: \(error)")
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
                            Text("Attempts: \(connectionAttempts)")
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
                        print("App Start Error: \(error.localizedDescription)")
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
                    print("App Stop Error: \(error.localizedDescription)")
                }
            }
        }
        .task {
            // 태스크 시작 시 기본 초기화
            headphoneMotionManager.resetSession()
        }
    }
}

// 기존 컴포넌트들을 재사용하기 위한 구조체들
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
        guard range > 0 else { return 0.5 * graphHeight }
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
                Text("")
                    .font(.headline)
                Spacer()
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
                Text("Are you sleep?")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: warningThresholdY - 12)
                
                Text("Good Posture")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: normalize(referencePitch))
                
                Text("Bad Posture")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(2)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    .position(x: graphWidth - 35, y: poorThresholdY + 12)

            }
            .frame(height: graphHeight)
            .padding(.vertical, 8)
            .padding(.trailing, 70)

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
    public let referenceRoll: Double
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
}
