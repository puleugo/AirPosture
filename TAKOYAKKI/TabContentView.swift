//
//  TabContentView.swift
//  TAKOYAKKI
//
//  Created by 임채성 on 8/20/25.
//

import SwiftUI

// 탭 기반 메인 ContentView
struct TabContentView: View {
    @StateObject private var headphoneMotionManager = HeadphoneMotionManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView()
                .environmentObject(headphoneMotionManager)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("메인")
                }
                .tag(0)
            
            SettingsView()
                .environmentObject(headphoneMotionManager)
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("설정")
                }
                .tag(1)
        }
        .accentColor(.blue)
    }
}

#Preview {
    TabContentView()
}
