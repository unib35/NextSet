import SwiftUI

/// 시안 색. 앱·위젯·워치가 같은 값을 쓴다.
extension Color {
    static let brand = Color(red: 1, green: 149 / 255, blue: 0)                      // #FF9500
    static let danger = Color(red: 1, green: 69 / 255, blue: 58 / 255)               // #FF453A
    static let card = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)          // #1C1C1E
    static let cardRaised = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)    // #2C2C2E
    static let sheet = Color(red: 17 / 255, green: 17 / 255, blue: 17 / 255)         // #111
    static let finalCountdown = Color(red: 179 / 255, green: 95 / 255, blue: 0)      // #B35F00
    static let surface = Color.white.opacity(0.11)  // 검정·마지막 3초 배경 모두에서 쓰는 버튼 면
}
