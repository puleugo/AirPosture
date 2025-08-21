//
//  ContentView.swift
//  TAKOYAKKI
//
//  Simplified container for tabs (RootView).
//

import SwiftUI

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

#Preview {
    RootView().environmentObject(HeadphoneMotionManager())
}


