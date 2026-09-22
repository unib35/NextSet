import SwiftUI

/// 6c 힌트 카드: 왼쪽 아이콘 상자(오렌지 15%), 설명 한 줄, 오른쪽 작은 동작 글자.
struct HintCard: View {
    let systemImage: String
    let text: String
    var primary: (label: String, action: () -> Void)? = nil   // 예: "보기"
    let dismissLabel: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.brand)
                .frame(width: 36, height: 36)
                .background(Color.brand.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
            if let primary {
                Button(action: primary.action) {
                    Text(primary.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .padding(.horizontal, 6)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button(action: onDismiss) {
                Text(dismissLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 4)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.card, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }
}
