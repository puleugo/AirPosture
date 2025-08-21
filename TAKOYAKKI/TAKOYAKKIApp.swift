//
//  TAKOYAKKIApp.swift
//  TAKOYAKKI
//
//  Created by 임채성 on 8/20/25.
//

import SwiftUI

// macOS용 AirPods 자세 교정 서비스 메인 앱
@main
struct TAKOYAKKIApp: App {
    @StateObject private var headphoneMotionManager = HeadphoneMotionManager()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(headphoneMotionManager)
                .frame(minWidth: 800, minHeight: 600) // macOS 최소 윈도우 크기 설정
        }
        .windowStyle(HiddenTitleBarWindowStyle()) // 타이틀 바 숨김
    }
}
