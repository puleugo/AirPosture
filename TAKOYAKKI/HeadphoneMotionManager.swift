//
//  HeadphoneMotionManager.swift
//  TAKOYAKKI
//
//  Created by 임채성 on 8/20/25.
//

import Foundation
import Combine
import CoreMotion
import AVFoundation

// macOS용 AirPods 모션 데이터 관리자 (안전한 버전)

// MARK: - 커스텀 에러 타입
enum HeadphoneMotionError: Error, LocalizedError {
    case motionManagerUnavailable
    case deviceMotionUnavailable
    case connectionFailed
    case simulationError
    case initializationError
    
    
    
    var errorDescription: String? {
        switch self {
        case .motionManagerUnavailable:
            return "모션 매니저를 사용할 수 없습니다"
        case .deviceMotionUnavailable:
            return "디바이스 모션을 사용할 수 없습니다"
        case .connectionFailed:
            return "AirPods Pro 연결에 실패했습니다"
        case .simulationError:
            return "시뮬레이션 모드 초기화에 실패했습니다"
        case .initializationError:
            return "초기화 중 오류가 발생했습니다"
        }
    }
}

@MainActor
final class HeadphoneMotionManager: ObservableObject {
    // MARK: - Published 속성들
    @Published private(set) var pitch: Double = 0.0                    // 피치 (위아래 각도)
    @Published private(set) var roll: Double = 0.0                     // 롤 (좌우 기울기 각도)
    @Published private(set) var yaw: Double = 0.0                      // 요 (좌우 회전 각도)
    @Published private(set) var isDeviceConnected: Bool = false        // 디바이스 연결 상태
    @Published private(set) var connectionStatus: String = "시작되지 않음"
    @Published private(set) var postureState: PostureState = .good(postureDuration: 0)  // 자세 상태
    @Published private(set) var pitchHistory: [Double] = []            // 피치 히스토리
    @Published private(set) var rollHistory: [Double] = []             // 롤 히스토리
    @Published private(set) var poorPostureDuration: TimeInterval = 0  // 나쁜 자세 지속 시간
    @Published private(set) var poorPosturePercentage: Int = 0         // 나쁜 자세 퍼센트
    @Published private(set) var isSimulationMode: Bool = false         // 시뮬레이션 모드 여부
    @Published private(set) var lastError: String? = nil               // 마지막 에러 메시지
    
    // MARK: - 사용자 설정 임계값 (저장 가능)
    @Published var poorPostureThreshold: Double = UserDefaults.standard.object(forKey: "poorPostureThresholdDeg") as? Double ?? -15.0 {
        didSet { UserDefaults.standard.set(poorPostureThreshold, forKey: "poorPostureThresholdDeg") }
    }
    @Published var warningThreshold: Double = UserDefaults.standard.object(forKey: "warningThresholdDeg") as? Double ?? 1.0 {
        didSet { UserDefaults.standard.set(warningThreshold, forKey: "warningThresholdDeg") }
    }
    @Published var rollThreshold: Double = UserDefaults.standard.object(forKey: "rollThresholdDeg") as? Double ?? 1.0 {
        didSet { UserDefaults.standard.set(rollThreshold, forKey: "rollThresholdDeg") }
    }
    @Published private(set) var rotationRate: (x: Double, y: Double, z: Double) = (0, 0, 0) // 회전 속도(rad/s)
    @Published private(set) var userAcceleration: (x: Double, y: Double, z: Double) = (0, 0, 0) // 사용자 가속도(g)
    @Published private(set) var gravity: (x: Double, y: Double, z: Double) = (0, 0, 0) // 중력 가속도(g)
    @Published private(set) var isPoorPostureNow: Bool = false         // 현재 시점 나쁜 자세 여부
    @Published private(set) var isCalibrating: Bool = false            // 자세 교정 중인지 여부

    // MARK: - Private 속성들
    private var motionManager: CMHeadphoneMotionManager?               // 헤드폰 모션 매니저 (옵셔널)
    private var cancellables = Set<AnyCancellable>()                   // 구독 취소 가능한 객체들
    private var poorPostureStartTime: Date?                            // 나쁜 자세 시작 시간
    private var sessionStartTime: Date = Date()                        // 세션 시작 시간
    @Published var referencePitch: Double = (UserDefaults.standard.object(forKey: "referencePitchDeg") as? Double) ?? 0.0 { // 기준 피치
        didSet { UserDefaults.standard.set(referencePitch, forKey: "referencePitchDeg") }
    }
    @Published var referenceRoll: Double = (UserDefaults.standard.object(forKey: "referenceRollDeg") as? Double) ?? 0.0 { // 기준 롤
        didSet { UserDefaults.standard.set(referenceRoll, forKey: "referenceRollDeg") }
    }
    @Published private var totalSessionTime: TimeInterval = 0          // 총 세션 시간
    private let maxDataPoints = 100                                    // 최대 데이터 포인트 수
    private let motionUpdateInterval: TimeInterval = 1.0/30.0          // 30 FPS 업데이트 간격 (낮춤)
    private var simulationTimer: Timer?                                // 시뮬레이션용 타이머
    private var audioPlayer: AVAudioPlayer?                            // 알림 사운드 플레이어
    private var lastAlertPlayTime: Date?                               // 마지막 알림 재생 시각
    private let alertSoundCooldown: TimeInterval = 10                  // 알림 쿨다운(초)

    // MARK: - 상수
    private enum Constants {
        static let lowPassFilterFactor: Double = 0.2     // 저역 통과 필터 계수
        static let simulationPitchRange: ClosedRange<Double> = -30.0...30.0  // 시뮬레이션 피치 범위
    }

    // MARK: - 초기화
    init() {
        do {
            try setupBindings()
        } catch {
            lastError = "초기화 오류: \(error.localizedDescription)"
        }
        
    }

    deinit {
        Task { @MainActor in
            try? await cleanup()
        }
    }

    // MARK: - Public 메서드들
    @MainActor
    func start() async throws {
        // 이미 실행 중이면 중복 시작 방지
        guard !isDeviceConnected else { return }
        
        connectionStatus = "초기화 중..."
        lastError = nil
        
        do {
            // 지연된 초기화로 안정성 확보
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5초
            try await initializeMotionManager()
        } catch {
            lastError = "시작 오류: \(error.localizedDescription)"
            connectionStatus = "시작 실패"
            throw error
        }
    }

    @MainActor
    func stop() async throws {
        do {
            try await cleanup()
            connectionStatus = "중지됨"
            isDeviceConnected = false
        } catch {
            lastError = "중지 오류: \(error.localizedDescription)"
            throw error
        }
    }

    @MainActor
    func restart() async throws {
        do {
            try await stop()
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5초
            try await start()
        } catch {
            lastError = "재시작 오류: \(error.localizedDescription)"
            throw error
        }
    }

    @MainActor
    func resetSession() {
        do {
            pitchHistory.removeAll()
            poorPostureDuration = 0
            poorPostureStartTime = nil
            sessionStartTime = Date()
            totalSessionTime = 0
            poorPosturePercentage = 0
            lastError = nil
        } catch {
            lastError = "세션 리셋 오류: \(error.localizedDescription)"
        }
    }

    @MainActor
    func calibrateBaselinePosture() async {
        isCalibrating = true
        // 사용자에게 자세를 잡을 시간을 줌 (예: 3초)
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // 최근 데이터의 중앙값/평균으로 안정화된 기준 계산
        let recentPitches = Array(self.pitchHistory.suffix(30))
        let recentRolls = Array(self.rollHistory.suffix(30))

        let stabilizedPitch: Double
        let stabilizedRoll: Double

        if !recentPitches.isEmpty {
            stabilizedPitch = median(of: recentPitches)
        } else {
            stabilizedPitch = self.pitch
        }

        if !recentRolls.isEmpty {
            stabilizedRoll = median(of: recentRolls)
        } else {
            stabilizedRoll = self.roll
        }

        self.referencePitch = stabilizedPitch
        self.referenceRoll = stabilizedRoll
        
        isCalibrating = false
        // 보정이 완료되었음을 알리는 로직 추가 가능 (예: UI 업데이트)
    }

    // MARK: - Private 메서드들
    private func setupBindings() throws {
        // 지속 시간이 변경될 때 나쁜 자세 퍼센트 업데이트
        $poorPostureDuration
            .combineLatest($totalSessionTime)
            .map { duration, totalTime in
                totalTime > 0 ? Int((duration / totalTime) * 100) : 0
            }
            .assign(to: \.poorPosturePercentage, on: self)
            .store(in: &cancellables)
    }

    private func initializeMotionManager() async throws {
        // 기존 매니저 정리
        try await cleanup()
        guard #available(macOS 14.0, *) else { throw HeadphoneMotionError.motionManagerUnavailable }
        
        do {
            // 새로운 매니저 생성
            motionManager = CMHeadphoneMotionManager()
            
            guard let manager = motionManager else {
                throw HeadphoneMotionError.motionManagerUnavailable
            }
            
            // 안전한 권한 확인
            guard manager.isDeviceMotionAvailable else {
                connectionStatus = "AirPods Pro가 연결되지 않았습니다"
                try await startSimulationMode()
                return
            }
            
            // 실제 모션 업데이트 시작
            try await startRealMotionUpdates(manager)
        } catch {
            lastError = "모션 매니저 초기화 오류: \(error.localizedDescription)"
            try await startSimulationMode()
        }
    }
    
    private func startRealMotionUpdates(_ manager: CMHeadphoneMotionManager) async throws {
        connectionStatus = "AirPods Pro 연결 시도 중..."
        
        do {
            // 안전한 모션 업데이트 시작
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self else { return }
                
                if let error = error {
                    Task { @MainActor in
                        self.lastError = "연결 오류: \(error.localizedDescription)"
                        self.connectionStatus = "연결 오류: \(error.localizedDescription)"
                        try? await self.startSimulationMode()
                    }
                    return
                }

                guard let motion = motion else { return }
                
                Task { @MainActor in
                    try? await self.processMotionData(motion)
                }
            }
            
            // 연결 상태 확인 타이머
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2초
            if !isDeviceConnected {
                connectionStatus = "AirPods Pro 연결 실패 - 시뮬레이션 모드로 전환"
                try await startSimulationMode()
            }
        } catch {
            lastError = "실제 모션 업데이트 오류: \(error.localizedDescription)"
            throw HeadphoneMotionError.connectionFailed
        }
    }
    
    private func startSimulationMode() async throws {
        do {
            isSimulationMode = true
            connectionStatus = "시뮬레이션 모드 - AirPods Pro 연결을 기다리는 중"
            isDeviceConnected = true
            
            // 시뮬레이션 타이머 시작
            simulationTimer = Timer.scheduledTimer(withTimeInterval: motionUpdateInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    try? await self?.generateSimulatedMotion()
                }
            }
        } catch {
            lastError = "시뮬레이션 모드 오류: \(error.localizedDescription)"
            throw HeadphoneMotionError.simulationError
        }
    }
    
    private func generateSimulatedMotion() async throws {
        do {
            // 시뮬레이션된 모션 데이터 생성
            let simulatedPitch = Double.random(in: Constants.simulationPitchRange)
            let simulatedRoll = Double.random(in: -15.0...15.0)
            let simulatedYaw = Double.random(in: -10.0...10.0)
            
            // 직접 데이터 처리 (CMDeviceMotion 객체 생성 없이)
            try await processSimulatedMotion(
                pitch: simulatedPitch,
                roll: simulatedRoll,
                yaw: simulatedYaw
            )
        } catch {
            lastError = "시뮬레이션 모션 생성 오류: \(error.localizedDescription)"
            throw error
        }
    }
    
    private func processSimulatedMotion(pitch: Double, roll: Double, yaw: Double) async throws {
        do {
            // 시뮬레이션된 모션 데이터 직접 처리
            let newPitch = lowPassFilter(
                current: pitch,
                previous: self.pitch
            )

            // 메인 스레드에서 UI 업데이트
            self.pitch = newPitch
            self.roll = roll
            self.yaw = yaw
            // 시뮬레이션용 회전/가속/중력 값 생성
            self.rotationRate = (
//                x: Double.random(in: -2.0...2.0),
//                y: Double.random(in: -2.0...2.0),
//                z: Double.random(in: -2.0...2.0)
                x: 2,
                y: 2,
                z: 2,
            )
            self.userAcceleration = (
                x: Double.random(in: -0.2...0.2),
                y: Double.random(in: -0.2...0.2),
                z: Double.random(in: -0.2...0.2)
            )
            self.gravity = (
                x: Double.random(in: -1.0...1.0),
                y: Double.random(in: -1.0...1.0),
                z: Double.random(in: -1.0...1.0)
            )
            self.isDeviceConnected = true
            self.connectionStatus = "시뮬레이션 모드"
            // 현재 나쁜 자세 여부 갱신 (기준 자세 기준)
            self.isPoorPostureNow = ((newPitch - referencePitch) < poorPostureThreshold) || (abs(self.roll - referenceRoll) > rollThreshold)

            try await updatePitchHistory(newPitch)
            // 롤 히스토리 갱신
            rollHistory.append(self.roll)
            if rollHistory.count > maxDataPoints { rollHistory.removeFirst() }
            try await updatePostureState(newPitch: newPitch)
            try await updateSessionTimers(newPitch: newPitch)
        } catch {
            lastError = "시뮬레이션 모션 처리 오류: \(error.localizedDescription)"
            throw error
        }
    }

    private func processMotionData(_ motion: CMDeviceMotion) async throws {
        do {
            // 안전한 모션 데이터 처리
            let newPitch = lowPassFilter(
                current: motion.attitude.pitch * 180 / .pi,
                previous: pitch
            )

            // 메인 스레드에서 UI 업데이트
            self.pitch = newPitch
            self.roll = motion.attitude.roll * 180 / .pi
            self.yaw = motion.attitude.yaw * 180 / .pi
            // 회전 속도 / 사용자 가속도 / 중력
            self.rotationRate = (x: motion.rotationRate.x, y: motion.rotationRate.y, z: motion.rotationRate.z)
            self.userAcceleration = (x: motion.userAcceleration.x, y: motion.userAcceleration.y, z: motion.userAcceleration.z)
            self.gravity = (x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z)
            self.isDeviceConnected = true
            self.connectionStatus = self.isSimulationMode ? "시뮬레이션 모드" : "연결됨"
            // 현재 나쁜 자세 여부 갱신 (기준 자세 기준)
            self.isPoorPostureNow = ((newPitch - referencePitch) < poorPostureThreshold) || (abs(self.roll - referenceRoll) > rollThreshold)

            try await updatePitchHistory(newPitch)
            // 롤 히스토리 갱신
            rollHistory.append(self.roll)
            if rollHistory.count > maxDataPoints { rollHistory.removeFirst() }
            try await updatePostureState(newPitch: newPitch)
            try await updateSessionTimers(newPitch: newPitch)
        } catch {
            lastError = "모션 데이터 처리 오류: \(error.localizedDescription)"
            throw error
        }
    }

    private func updatePitchHistory(_ newPitch: Double) async throws {
        do {
            pitchHistory.append(newPitch)
            if pitchHistory.count > maxDataPoints {
                pitchHistory.removeFirst()
            }
        } catch {
            lastError = "피치 히스토리 업데이트 오류: \(error.localizedDescription)"
            throw error
        }
    }

    private func updatePostureState(newPitch: Double) async throws {
        do {
            let previousState = postureState
            let currentTime = Date()

            // 좋은 자세 검증: Pitch와 Roll 모두 기준 자세의 임계값 이내여야 함
            let pitchDelta = (newPitch - referencePitch)
            let isForwardBad = pitchDelta < poorPostureThreshold
            let isBackwardWarn = pitchDelta > warningThreshold
            let isRollBad = abs(roll - referenceRoll) > rollThreshold

            if isForwardBad || isBackwardWarn || isRollBad {
                let duration = postureState.lastGoodStateTime.distance(to: currentTime)
                let newState: PostureState = duration > 2.0 ?
                    .alert(pitch: newPitch, duration: duration) :
                    .warning(pitch: newPitch, timeAboveThreshold: duration)
                postureState = newState

                // 나쁜 자세(Alert)로 전환되면 알림 사운드 재생 (쿨다운 적용)
                if case .alert = newState {
                    // 이전 상태가 alert가 아닐 때만 사운드 재생
                    switch previousState {
                    case .alert:
                        break
                    default:
                        playAlertSoundIfAllowed()
                    }
                }
            } else {
                let duration = currentTime.timeIntervalSince(sessionStartTime)
                postureState = .good(postureDuration: duration)
            }
        } catch {
            lastError = "자세 상태 업데이트 오류: \(error.localizedDescription)"
            throw error
        }
    }

    private func updateSessionTimers(newPitch: Double) async throws {
        do {
            let currentTime = Date()
            let timeSinceLastUpdate = currentTime.timeIntervalSince(sessionStartTime)
            totalSessionTime += timeSinceLastUpdate
            sessionStartTime = currentTime

            print("--- Session Timer Update ---")
            print("timeSinceLastUpdate: \(timeSinceLastUpdate)")
            print("totalSessionTime: \(totalSessionTime)")
            print("poorPostureDuration: \(poorPostureDuration)")
            print("poorPosturePercentage: \(poorPosturePercentage)")

            // 나쁜 자세 누적: Pitch가 임계값 아래이거나 Roll이 임계값을 초과하면 누적
            if (newPitch - referencePitch) < poorPostureThreshold || abs(roll - referenceRoll) > rollThreshold {
                print("Posture is BAD.")
                if poorPostureStartTime == nil {
                    poorPostureStartTime = currentTime
                }
                poorPostureDuration += timeSinceLastUpdate
            } else {
                print("Posture is GOOD.")
                poorPostureStartTime = nil
            }
        } catch {
            lastError = "세션 타이머 업데이트 오류: \(error.localizedDescription)"
            throw error
        }
    }

    private func lowPassFilter(current: Double, previous: Double) -> Double {
        // 저역 통과 필터로 노이즈 제거
        return previous * (1.0 - Constants.lowPassFilterFactor) + current * Constants.lowPassFilterFactor
    }
    
    // 중앙값 계산 유틸리티 (잡음에 강함)
    private func median(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }
    
    private func cleanup() async throws {
        do {
            // 모션 매니저 정리
            if let manager = motionManager {
                if manager.isDeviceMotionActive {
                    manager.stopDeviceMotionUpdates()
                }
            }
            motionManager = nil
            
            // 시뮬레이션 타이머 정리
            simulationTimer?.invalidate()
            simulationTimer = nil
            
            // 구독 정리
            cancellables.removeAll()
            
            isSimulationMode = false
        } catch {
            lastError = "정리 오류: \(error.localizedDescription)"
            throw error
        }
    }

    // MARK: - Alert Sound
    private func playAlertSoundIfAllowed() {
        let now = Date()
        if let last = lastAlertPlayTime, now.timeIntervalSince(last) < alertSoundCooldown {
            return
        }

        do {
            if audioPlayer == nil {
                guard let url = Bundle.main.url(forResource: "default_notification", withExtension: "wav") else {
                    lastError = "알림 사운드 파일을 찾을 수 없습니다."
                    return
                }
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            }

            audioPlayer?.currentTime = 0
            audioPlayer?.numberOfLoops = 0
            audioPlayer?.play()
            lastAlertPlayTime = now
        } catch {
            lastError = "알림 사운드 재생 오류: \(error.localizedDescription)"
        }
    }
}

// MARK: - 자세 상태 열거형
enum PostureState: Equatable {
    case good(postureDuration: TimeInterval)                    // 좋은 자세
    case warning(pitch: Double, timeAboveThreshold: TimeInterval)  // 경고 자세
    case alert(pitch: Double, duration: TimeInterval)           // 알림 자세

    var lastGoodStateTime: Date {
        switch self {
        case .good(let duration):
            return Date().addingTimeInterval(-duration)
        default:
            return Date()
        }
    }

    var shouldTriggerHaptic: Bool {
        if case .alert = self {
            return true
        }
        return false
    }
}

