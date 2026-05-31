import CoreGraphics

struct PositionedNode: Identifiable {
    let node: GraphNode
    var position: CGPoint
    var velocity: CGPoint = .zero

    var id: String    { node.id }
    var label: String { node.label }
    var name: String  { node.name }
}
