import Foundation
import CoreGraphics
import Observation
import SwiftUI

@Observable
@MainActor
final class GraphViewModel {
    var positionedNodes: [PositionedNode] = []
    var edges: [GraphEdge] = []
    var highlightedIds: Set<String> = []
    var answer: String? = nil
    var isLoading = false
    var queryText = ""
    var canvasSize: CGSize = .zero
    var errorMessage: String? = nil
    var zoomScale: CGFloat = 1.0
    var panOffset: CGPoint = .zero
    var selectedNode: GraphNode? = nil

    private var layoutTask: Task<Void, Never>?
    private var circleCenter:     CGPoint = .zero
    private var virtualCircleSize: CGFloat = 0

    func loadGraph() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let data = try await GraphAPIClient.shared.fetchGraph()
            let n = data.nodes.count

            // Phyllotaxis (golden-angle sunflower) layout.
            // Every node is placed at angle = i × goldenAngle, radius = k × √i.
            // This distributes nodes uniformly inside a circle with no overlaps.
            let goldenAngle: CGFloat = .pi * (3.0 - sqrt(5.0)) // ≈ 137.5°
            let k: CGFloat = 14                                  // ring spacing in px
            let outerR = k * sqrt(CGFloat(max(n - 1, 1)))
            let pad    = k * 2
            let ctr    = CGPoint(x: outerR + pad, y: outerR + pad)
            let virtualSize = (outerR + pad) * 2

            positionedNodes = data.nodes.enumerated().map { (i, node) in
                let angle = CGFloat(i) * goldenAngle
                let r     = k * sqrt(CGFloat(i))
                return PositionedNode(
                    node: node,
                    position: CGPoint(x: ctr.x + r * cos(angle),
                                     y: ctr.y + r * sin(angle))
                )
            }
            edges = data.edges

            // Store for resetZoom()
            circleCenter      = ctr
            virtualCircleSize = virtualSize

            // Initial zoom: fit the full circle onto the shorter screen dimension
            let scrW = canvasSize == .zero ? 390.0 : canvasSize.width
            let scrH = canvasSize == .zero ? 800.0 : canvasSize.height
            let fitScale = min(scrW, scrH) / virtualSize * 0.92
            zoomScale = max(0.2, fitScale)
            panOffset = CGPoint(x: scrW / 2 - ctr.x * zoomScale,
                                y: scrH / 2 - ctr.y * zoomScale)

            // Force-directed layout only for small graphs (≤200 nodes)
            if n <= 200 { startLayoutLoop() }

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitQuery() async {
        let q = queryText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isLoading = true
        answer = nil
        highlightedIds = []
        defer { isLoading = false }
        do {
            let response = try await GraphAPIClient.shared.query(q)
            answer = response.answer
            highlightedIds = Set(response.highlightedNodeIds)
            queryText = ""
            panToHighlighted()   // auto-scroll to results
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // ── Zoom controls ────────────────────────────────────────────────────
    func zoomIn()  { adjustZoom(by: 1.5) }
    func zoomOut() { adjustZoom(by: 1 / 1.5) }

    func resetZoom() {
        guard virtualCircleSize > 0 else { return }
        let scrW = canvasSize == .zero ? 390.0 : canvasSize.width
        let scrH = canvasSize == .zero ? 800.0 : canvasSize.height
        let fit  = min(scrW, scrH) / virtualCircleSize * 0.92
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
            zoomScale = max(0.2, fit)
            panOffset = CGPoint(x: scrW / 2 - circleCenter.x * zoomScale,
                                y: scrH / 2 - circleCenter.y * zoomScale)
        }
    }

    private func adjustZoom(by factor: CGFloat) {
        let newScale = max(0.1, min(zoomScale * factor, 8.0))
        let cx = (canvasSize == .zero ? 390.0 : canvasSize.width)  / 2
        let cy = (canvasSize == .zero ? 800.0 : canvasSize.height) / 2
        let ratio = newScale / zoomScale
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            panOffset = CGPoint(x: cx - (cx - panOffset.x) * ratio,
                                y: cy - (cy - panOffset.y) * ratio)
            zoomScale = newScale
        }
    }

    // Zoom + pan so all found nodes fit comfortably on screen
    private func panToHighlighted() {
        let hl = positionedNodes.filter { highlightedIds.contains($0.id) }
        guard !hl.isEmpty else { return }
        let xs = hl.map { $0.position.x }
        let ys = hl.map { $0.position.y }
        let cx = ((xs.min() ?? 0) + (xs.max() ?? 0)) / 2
        let cy = ((ys.min() ?? 0) + (ys.max() ?? 0)) / 2
        let spreadX = ((xs.max() ?? 0) - (xs.min() ?? 0)) + 120
        let spreadY = ((ys.max() ?? 0) - (ys.min() ?? 0)) + 120
        let scrW = canvasSize == .zero ? 390.0 : canvasSize.width
        let scrH = canvasSize == .zero ? 800.0 : canvasSize.height
        // Fit all highlights + margin; cap between 0.8× and 3×
        let newScale = max(0.8, min(scrW / spreadX, scrH * 0.55 / spreadY, 3.0))
        withAnimation(.spring(response: 0.7, dampingFraction: 0.85)) {
            zoomScale = newScale
            panOffset = CGPoint(x: scrW / 2 - cx * newScale,
                                y: scrH / 2 - cy * newScale)
        }
    }

    private func startLayoutLoop() {
        layoutTask?.cancel()
        layoutTask = Task.detached(priority: .userInitiated) { [weak self] in
            var iteration = 0
            while !Task.isCancelled && iteration < 200 {
                iteration += 1
                guard let self else { break }
                let (currentNodes, edgeList, size) = await MainActor.run {
                    let sz = self.canvasSize == .zero
                        ? CGSize(width: 390, height: 700) : self.canvasSize
                    return (self.positionedNodes, self.edges, sz)
                }
                var updated = currentNodes
                ForceDirectedLayout.tick(nodes: &updated, edges: edgeList, canvasSize: size)
                let maxVel = updated.reduce(0.0) {
                    max($0, max(abs($1.velocity.x), abs($1.velocity.y)))
                }
                let result = updated
                await MainActor.run { self.positionedNodes = result }
                if maxVel < 0.5 { break }
                try? await Task.sleep(nanoseconds: 16_666_667)
            }
        }
    }
}
