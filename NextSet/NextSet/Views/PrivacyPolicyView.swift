import SwiftUI

/// 네트워크 연결 없이 읽을 수 있는 개인정보 안내. 공개 웹 문서는 출시 자료에서 관리한다.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button { dismiss() } label: {
                    Label(String(localized: "Settings"), systemImage: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .foregroundStyle(Color.brand)
                .accessibilityLabel(String(localized: "Back"))
                Text(String(localized: "Privacy Policy"))
                    .font(.largeTitle.bold())
                Text(String(localized: "Last updated: September 22, 2026"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                PolicyMarkdown(content: Self.content)
                if let url = URL(string: "https://unib35.github.io/NextSet/\(Bundle.main.preferredLocalizations.first == "ko" ? "ko" : "en")/privacy.html") {
                    Link(String(localized: "View policy online"), destination: url)
                        .font(.body.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .background(Color.sheet)
        .foregroundStyle(.white)
        .tint(Color.brand)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    static var content: String {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return String(localized: "Unable to load the Privacy Policy. Please restart the app.")
        }
        return text
    }
}

/// 정책에서 사용하는 소제목·문단·목록을 렌더링한다. 본문은 현지화된 번들 리소스에서 관리한다.
private struct PolicyMarkdown: View {
    let content: String

    private var blocks: [String] {
        content.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                if block.hasPrefix("## ") {
                    Text(String(block.dropFirst(3)))
                        .font(.title3.bold())
                        .padding(.top, 16)
                        .accessibilityAddTraits(.isHeader)
                } else if block.hasPrefix("- ") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(block.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("•").foregroundStyle(Color.brand)
                                    .accessibilityHidden(true)
                                markdown(String(line.dropFirst(line.hasPrefix("- ") ? 2 : 0)))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else {
                    markdown(block)
                }
            }
        }
        .font(.body)
        .lineSpacing(5)
        .textSelection(.enabled)
    }

    private func markdown(_ text: String) -> Text {
        Text((try? AttributedString(markdown: text,
                                   options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
             ?? AttributedString(text))
    }
}
