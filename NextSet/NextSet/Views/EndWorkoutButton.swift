import SwiftUI

private struct RequestWorkoutEndKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var requestWorkoutEnd: () -> Void {
        get { self[RequestWorkoutEndKey.self] }
        set { self[RequestWorkoutEndKey.self] = newValue }
    }
}

/// A visible exit in every active workout state, with protection against accidental taps.
struct EndWorkoutButton: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.requestWorkoutEnd) private var requestEnd
    var onOrange = false

    var body: some View {
        Button {
            requestEnd()
        } label: {
            Label(timer.settings.mode == .single ? String(localized: "End timer") : String(localized: "End workout"), systemImage: "stop.circle")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .foregroundStyle(onOrange ? Color.black : Color.danger)
    }
}
