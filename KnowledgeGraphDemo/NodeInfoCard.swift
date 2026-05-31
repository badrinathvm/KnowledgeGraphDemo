import SwiftUI

struct NodeInfoCard: View {
    let node: GraphNode
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Type badge
            Text(node.label)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(labelColor.opacity(0.25), in: Capsule())
                .foregroundStyle(labelColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(node.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let rating = movieRating {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        .font(.caption)
                        .foregroundStyle(Color(red: 1.0, green: 0.75, blue: 0.0))
                }

                if let year = releaseYear {
                    Text(year)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var labelColor: Color {
        switch node.label {
        case "Movie":  return Color(red: 0.2, green: 0.5, blue: 0.9)
        case "Person": return Color(red: 0.2, green: 0.75, blue: 0.4)
        case "Genre":  return Color(red: 0.95, green: 0.6, blue: 0.1)
        default:       return .gray
        }
    }

    private var movieRating: Double? {
        guard case .number(let v) = node.properties?["imdbRating"] else { return nil }
        return v
    }

    private var releaseYear: String? {
        guard case .string(let v) = node.properties?["released"] else { return nil }
        return String(v.prefix(4))  // "1995-11-22" → "1995"
    }
}
