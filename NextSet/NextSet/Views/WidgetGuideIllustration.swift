import SwiftUI

/// 설명용 iPhone 화면. 강조 테두리와 손 모양은 안내를 위한 표시이며 시스템 UI가 아니다.
/// 실제 화면 비율을 고정해 시스템 글자 크기와 무관하게 그림의 위치 관계를 유지한다.
struct WidgetGuideIllustration: View {
    let tab: WidgetGuideTab

    private var caption: String {
        switch tab {
        case .lock: String(localized: "Tap just below the clock")
        case .home: String(localized: "Add a widget from the Edit menu")
        case .controlCenter: String(localized: "Add a control at the bottom")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            phone
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Text("2")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 22, height: 22)
                    .background(Color.brand, in: Circle())
                Text(caption)
                    .font(.system(size: 14, weight: .semibold))
            }
            .accessibilityElement(children: .combine)
            Text(String(localized: "Example screen showing where to add it"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, -8)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 24))
    }

    private var phone: some View {
        ZStack {
            wallpaper
                .frame(width: 218, height: 450)
                .clipped()
            VStack(spacing: 0) {
                statusBar
                switch tab {
                case .lock: lockScreen
                case .home: homeScreen
                case .controlCenter: controlCenter
                }
            }
            VStack {
                Capsule().fill(.black).frame(width: 64, height: 19).padding(.top, 9)
                Spacer()
                Capsule().fill(.white.opacity(0.9)).frame(width: 76, height: 3).padding(.bottom, 8)
            }
        }
        .frame(width: 218, height: 450)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(5)
        .background(.black, in: RoundedRectangle(cornerRadius: 37, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 37, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 12, y: 8)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, .medium)
    }

    private var wallpaper: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.22, blue: 0.32),
                                    Color(red: 0.28, green: 0.40, blue: 0.49),
                                    Color(red: 0.08, green: 0.13, blue: 0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Ellipse().fill(Color.cyan.opacity(0.18))
                .frame(width: 310, height: 390).rotationEffect(.degrees(-35))
                .offset(x: 100, y: 120).blur(radius: 20)
            Ellipse().fill(Color.black.opacity(0.3))
                .frame(width: 300, height: 380).rotationEffect(.degrees(30))
                .offset(x: -100, y: 190).blur(radius: 12)
        }
        .overlay(.black.opacity(tab == .controlCenter ? 0.35 : 0))
    }

    private var statusBar: some View {
        HStack(spacing: 3) {
            Text(tab == .lock ? "" : "9:41").font(.system(size: 9, weight: .semibold))
            Spacer()
            Image(systemName: "cellularbars")
            Image(systemName: "wifi")
            Image(systemName: "battery.100percent")
        }
        .font(.system(size: 8, weight: .semibold))
        .padding(.horizontal, 18)
        .frame(height: 38)
    }

    private var lockScreen: some View {
        VStack(spacing: 10) {
            HStack {
                pill(String(localized: "Cancel"))
                Spacer()
                pill(String(localized: "Done"))
            }
            .padding(.top, 4)
            Text(String(localized: "Saturday, September 19"))
                .font(.system(size: 13, weight: .medium)).padding(.top, 12)
            Text("9:41")
                .font(.system(size: 62, weight: .semibold, design: .rounded))
                .tracking(-3)
                .frame(maxWidth: .infinity)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.45)))
            Text(String(localized: "Add Widgets"))
                .frame(maxWidth: .infinity).frame(height: 43)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .modifier(GuideTarget())
            Spacer()
            HStack {
                roundIcon("flashlight.off.fill")
                Spacer()
                roundIcon("camera.fill")
            }
            HStack(spacing: 4) {
                Circle().fill(.white).frame(width: 4, height: 4)
                Circle().fill(.white.opacity(0.3)).frame(width: 4, height: 4)
            }.padding(.top, 10)
            Text(String(localized: "Natural")).font(.system(size: 9)).padding(.bottom, 23)
        }
        .padding(.horizontal, 14)
    }

    private var homeScreen: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 17) {
                HStack {
                    pill(String(localized: "Edit"))
                    Spacer()
                    pill(String(localized: "Done"))
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                    appIcon("message.fill", String(localized: "Messages"), .green)
                    appIcon("calendar", String(localized: "Calendar"), .white, ink: .red)
                    appIcon("camera.fill", String(localized: "Camera"), .gray)
                    appIcon("sun.max.fill", String(localized: "Weather"), .blue)
                    appIcon("clock.fill", String(localized: "Clock"), .black)
                    appIcon("map.fill", String(localized: "Maps"), .green)
                    appIcon("note.text", String(localized: "Notes"), .yellow, ink: .black)
                    appIcon("gearshape.fill", String(localized: "Settings"), .gray)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                    Circle().fill(.white.opacity(0.4)).frame(width: 4, height: 4)
                }
                HStack(spacing: 12) {
                    dockIcon("phone.fill", .green)
                    dockIcon("safari.fill", .blue)
                    dockIcon("message.fill", .green)
                    dockIcon("music.note", .pink)
                }
                .padding(10)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 22))
                .padding(.bottom, 18)
            }
            // 편집 메뉴를 펼친 상태. 배경 앱보다 사용자가 눌러야 할 항목을 선명하게 그린다.
            VStack(spacing: 0) {
                menuRow(String(localized: "Add Widget"), "plus")
                    .modifier(GuideTarget())
                Divider().overlay(.white.opacity(0.15))
                menuRow(String(localized: "Customize"), "slider.horizontal.3")
                Divider().overlay(.white.opacity(0.15))
                menuRow(String(localized: "Edit Wallpaper"), "photo")
            }
            .background(Color(white: 0.2).opacity(0.98), in: RoundedRectangle(cornerRadius: 14))
            .frame(width: 156)
            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
            .padding(.top, 34)
        }
        .padding(.horizontal, 13)
        .padding(.top, 4)
    }

    private var controlCenter: some View {
        VStack(spacing: 12) {
            HStack {
                roundIcon("plus", size: 23)
                Spacer()
                roundIcon("power", size: 23)
            }
            HStack(spacing: 9) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        roundIcon("airplane", color: .orange, size: 31)
                        roundIcon("antenna.radiowaves.left.and.right", color: .green, size: 31)
                    }
                    HStack(spacing: 10) {
                        roundIcon("wifi", color: .blue, size: 31)
                        roundIcon("wave.3.right", color: .blue, size: 31)
                    }
                }
                .frame(width: 90, height: 90).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
                VStack(spacing: 14) {
                    Image(systemName: "music.note").font(.system(size: 20))
                    Text(String(localized: "Not Playing")).font(.system(size: 9))
                    HStack(spacing: 14) {
                        Image(systemName: "backward.fill")
                        Image(systemName: "play.fill")
                        Image(systemName: "forward.fill")
                    }.font(.system(size: 10))
                }
                .frame(width: 90, height: 90).background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 24))
            }
            HStack(spacing: 10) {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        roundIcon("lock.rotation", size: 39)
                        roundIcon("rectangle.on.rectangle", size: 39)
                    }
                    Label(String(localized: "Focus"), systemImage: "moon.fill")
                        .frame(width: 90, height: 39)
                        .background(.white.opacity(0.15), in: Capsule())
                }
                slider("sun.max.fill", level: 0.6)
                slider("speaker.wave.2.fill", level: 0.4)
            }
            HStack(spacing: 12) {
                ForEach(["flashlight.off.fill", "timer", "plus.forwardslash.minus", "camera.fill"], id: \.self) { symbol in
                    roundIcon(symbol, size: 38)
                }
            }
            Spacer()
            Label(String(localized: "Add a Control"), systemImage: "plus")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(.white.opacity(0.15), in: Capsule())
                .modifier(GuideTarget())
                .padding(.bottom, 32)
        }
        .padding(.horizontal, 14)
        .padding(.top, 9)
    }

    private func pill(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(.white.opacity(0.17), in: Capsule())
    }

    private func roundIcon(_ symbol: String, color: Color = .white.opacity(0.15), size: CGFloat = 29) -> some View {
        Image(systemName: symbol).font(.system(size: size * 0.43, weight: .medium))
            .frame(width: size, height: size).background(color, in: Circle())
    }

    private func dockIcon(_ symbol: String, _ color: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 19))
            .frame(width: 33, height: 33)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 8))
    }

    private func appIcon(_ symbol: String, _ title: String, _ color: Color, ink: Color = .white) -> some View {
        VStack(spacing: 4) {
            dockIcon(symbol, color).foregroundStyle(ink)
                .overlay(alignment: .topLeading) {
                    Image(systemName: "minus").font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black).frame(width: 12, height: 12)
                        .background(Color(white: 0.8), in: Circle()).offset(x: -4, y: -4)
                }
            Text(title).font(.system(size: 8))
        }
    }

    private func menuRow(_ title: String, _ symbol: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Image(systemName: symbol)
        }.padding(.horizontal, 12).frame(height: 38)
    }

    private func slider(_ symbol: String, level: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Capsule().fill(.white.opacity(0.15))
            Rectangle().fill(.white.opacity(0.85)).frame(height: 90 * level)
            Image(systemName: symbol).foregroundStyle(.black.opacity(0.65)).padding(.bottom, 12)
        }
        .frame(width: 39, height: 90).clipShape(Capsule())
    }
}

private struct GuideTarget: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Color.brand, lineWidth: 2))
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                    .offset(x: 6, y: 18)
            }
    }
}
