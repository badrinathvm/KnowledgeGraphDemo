import SwiftUI

struct QueryBarView: View {
    @Bindable var vm: GraphViewModel

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask about the movies…", text: $vm.queryText)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .submitLabel(.send)
                .onSubmit { Task { await vm.submitQuery() } }

            Button {
                Task { await vm.submitQuery() }
            } label: {
                Image(systemName: vm.isLoading ? "ellipsis.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? .blue : .gray)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !vm.queryText.trimmingCharacters(in: .whitespaces).isEmpty && !vm.isLoading
    }
}
