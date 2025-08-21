//
//  MainView.swift
//  TAKOYAKKI
//
//  Created by 임채성 on 8/20/25.
//

import SwiftUI
import SceneKit
import CoreMotion
import Combine

// 메인 화면: pitch, roll 시각 자료, 초기 자세 설정
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
                        // 시각적 헤드 트래커
                        VStack(spacing: 8) {
                            // 헤드 시각화와 자세 퍼센트를 중앙 정렬된 수평 스택으로 배치
                            HStack(alignment: .center, spacing: 60) {
                                // 헤드 시각화
                                HeadVisualization(
                                    pitch: headphoneMotionManager.pitch,
                                    roll: headphoneMotionManager.roll,
                                    yaw: headphoneMotionManager.yaw,
                                    postureState: headphoneMotionManager.postureState,
                                    referencePitch: headphoneMotionManager.referencePitch
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
                                        let color: Color = headphoneMotionManager.isPoorPostureNow ? .red : (headphoneMotionManager.poorPosturePercentage >= 40 ? .red : .green)

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

                                }
                                .frame(width: 154)
                                .padding(.leading, 10)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 90)
                            .padding(.bottom, 90)

                            // 롤 시각화 (그림이 Roll 값에 따라 회전)
                            RollTiltVisualization(
                                roll: headphoneMotionManager.roll,
                                threshold: headphoneMotionManager.rollThreshold,
                                referenceRoll: headphoneMotionManager.referenceRoll
                            )
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            // 자세 재설정 버튼
                            VStack {
                                Button(action: {
                                    Task {
                                        await headphoneMotionManager.calibrateBaselinePosture()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("바른 자세 재설정")
                                            .fontWeight(.semibold)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.black.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                }
                            }
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)

                            // 머리 방향 정보
                            VStack(alignment: .leading, spacing: 15) {
                                Text("머리 방향 / Attitude（姿勢）")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Divider()
                                    .padding(.vertical, 4)

                                OrientationRow(label: "피치 / Pitch（上下）", value: headphoneMotionManager.pitch, description: "위/아래 / 上下")
                                OrientationRow(label: "롤 / Roll（傾き）", value: headphoneMotionManager.roll, description: "좌/우 기울기 / 左右の傾き")
                                OrientationRow(label: "요 / Yaw（回転）", value: headphoneMotionManager.yaw, description: "좌/우 회전 / 左右回転")
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.bottom, 20)

                            Spacer(minLength: 100)
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
            .blur(radius: headphoneMotionManager.isCalibrating ? 10 : 0)
            
            // 보정 중 오버레이
            if headphoneMotionManager.isCalibrating {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 20) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                    
                    Text("바른 자세를 3초간 유지하세요...")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: headphoneMotionManager.isCalibrating)
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

// 기존 컴포넌트들을 재사용하기 위한 구조체들
struct HeadVisualization: View {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let postureState: PostureState
    let referencePitch: Double

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
                .rotationEffect(.degrees(pitch - referencePitch))
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

struct RollTiltVisualization: View {
    let roll: Double
    let threshold: Double
    let referenceRoll: Double

    private var relativeRoll: Double { roll - referenceRoll }
    private var ringColor: Color { abs(relativeRoll) > threshold ? .red : .green }

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
                    .rotationEffect(.degrees(relativeRoll))
                    .animation(.easeInOut(duration: 0.2), value: relativeRoll)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                Text(String(format: "현재 롤: %.1f° (기준 대비 %.1f°)", roll, relativeRoll))
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
