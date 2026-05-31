import SwiftUI

struct AnswerPanelView: View {
    let text: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Answer", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)
                Spacer()
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            ScrollView {
                MarkdownView(markdown: text)
                    .padding(.bottom, 4)
            }
            .frame(maxHeight: 200)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
