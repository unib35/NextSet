//
//  ContentView.swift
//  NextSet
//
//  Created by 이종민 on 9/16/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.scenePhase) private var scenePhase
    @State private var confirmsEnd = false
    @State private var showsSettings = false

    var body: some View {
        #if DEBUG
        if let page = WidgetGalleryView.requestedPage {
            WidgetGalleryView(page: page)
        } else {
            main
        }
        #else
        main
        #endif
    }

    private var main: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            screen
                .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: timer.session.phase)
        .overlay(alignment: .top) {
            // 헤더(모드·톱니) 바로 아래, 큰 숫자 위의 빈 공간. 하단은 프리셋·버튼과 겹쳐 읽기 어려웠다.
            if let toast = timer.toast {
                ToastView(message: toast)
                    .padding(.top, 72)
                    .transition(.opacity.combined(with: .offset(y: -8)))
            }
        }
        .animation(.easeOut(duration: 0.3), value: timer.toast)
        .alert(timer.settings.mode == .single ? String(localized: "End this timer?") : String(localized: "End this workout?"), isPresented: $confirmsEnd) {
            Button(String(localized: "Save and end"), role: .destructive) { timer.endWorkout() }
            Button(String(localized: "Keep going"), role: .cancel) {}
        } message: {
            Text(String(localized: "Your workout summary will be saved to Recent workouts."))
        }
        .environment(\.requestWorkoutEnd, { confirmsEnd = true })
        // 설정 시트는 화면(phase)보다 위에서 띄운다 — 휴식 중에 열어 둔 채 휴식이 끝나도 닫히지 않는다.
        .sheet(isPresented: $showsSettings) {
            SettingsSheet()
                .environment(timer)
        }
        .environment(\.requestSettings, { showsSettings = true })
        .preferredColorScheme(.dark)
        .onChange(of: scenePhase, initial: true) { _, phase in
            timer.scenePhaseChanged(isActive: phase == .active)
            BackgroundGrace.shared.sceneChanged(isActive: phase == .active,
                                                restEndsAt: timer.session.phase == .running ? timer.session.endDate : nil)
        }
        .onOpenURL { url in
            timer.handleURL(url)  // 3e 위젯 탭 → nextset://start
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch timer.session.phase {
        case .idle: SetupView()
        case .running, .paused: RunningView()
        case .done: RestDoneView()
        case .finished: SummaryView()
        }
    }
}

#Preview {
    ContentView()
        .environment(RestTimer(notifications: RestNotifications(isEnabled: false)))
}
