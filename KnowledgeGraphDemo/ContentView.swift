//
//  ContentView.swift
//  KnowledgeGraphDemo
//
//  Created by Rani Badri on 5/31/26.
//

import SwiftUI

struct ContentView: View {
    @State private var vm = GraphViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Light background ──────────────────────────────────────────
            Color(white: 0.96).ignoresSafeArea()

            GraphCanvasView(vm: vm).ignoresSafeArea()
            HighlightPulseLayer(vm: vm).ignoresSafeArea()

            // Loading spinner
            if vm.isLoading && vm.positionedNodes.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().tint(.accentColor).scaleEffect(1.5)
                    Text("Loading graph…").font(.caption).foregroundStyle(.secondary)
                }
            }

            // ── Top overlay ───────────────────────────────────────────────
            VStack(spacing: 0) {
                // Selected node info card
                if let node = vm.selectedNode {
                    NodeInfoCard(node: node) { vm.selectedNode = nil }
                        .padding(.top, 8)
                }

                HStack(alignment: .center) {
                    // Zoom level badge
                    Text(String(format: "%.2f×", vm.zoomScale))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.regularMaterial, in: Capsule())

                    Spacer()

                    // Zoom controls: − / ⊙ / +
                    HStack(spacing: 0) {
                        zoomButton(icon: "minus") { vm.zoomOut() }
                        Divider().frame(height: 20)
                        zoomButton(icon: "arrow.up.left.and.down.right.magnifyingglass") { vm.resetZoom() }
                        Divider().frame(height: 20)
                        zoomButton(icon: "plus")  { vm.zoomIn() }
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                    Text("\(vm.positionedNodes.count) nodes")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 6)

                Spacer()

                // Node-type legend — bottom-left, above answer panel
                HStack(spacing: 10) {
                    legendDot("Movie",  Color(red: 0.25, green: 0.55, blue: 0.95))
                    legendDot("Person", Color(red: 0.15, green: 0.75, blue: 0.35))
                    legendDot("Genre",  Color(red: 0.95, green: 0.55, blue: 0.05))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, vm.answer == nil ? 72 : 230)
            }
            .animation(.spring(response: 0.3), value: vm.selectedNode?.id)

            // ── Bottom: answer + query bar ────────────────────────────────
            VStack(spacing: 0) {
                if let answer = vm.answer {
                    AnswerPanelView(text: answer) {
                        vm.answer = nil
                        vm.highlightedIds = []
                        vm.resetZoom()
                    }
                }
                QueryBarView(vm: vm)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.answer != nil)
        }
        .task { await vm.loadGraph() }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("Retry") { Task { await vm.loadGraph() } }
            Button("Dismiss") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 28)
        }
    }

    @ViewBuilder
    private func legendDot(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
