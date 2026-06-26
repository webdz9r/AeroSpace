import AppKit
import Common
import SwiftUI

@MainActor
final class ControlTowerModel: ObservableObject {
    let workspaces: [CTWorkspace]
    let columns: Int
    @Published var selectedIndex: Int

    var onSelect: ((String) -> Void)?
    var onCancel: (() -> Void)?

    init(snapshot: ControlTowerSnapshot) {
        workspaces = snapshot.workspaces
        columns = max(1, min(4, Int(ceil(Double(max(workspaces.count, 1)).squareRoot()))))
        selectedIndex = snapshot.focusedIndex ?? 0
    }

    private func clamp(_ i: Int) -> Int { max(0, min(i, workspaces.count - 1)) }

    func moveLeft() { selectByOffset(-1) }
    func moveRight() { selectByOffset(1) }
    func moveUp() { selectByOffset(-columns, wrap: false) }
    func moveDown() { selectByOffset(columns, wrap: false) }

    private func selectByOffset(_ delta: Int, wrap: Bool = true) {
        guard !workspaces.isEmpty else { return }
        if wrap {
            selectedIndex = (selectedIndex + delta + workspaces.count) % workspaces.count
        } else {
            let next = selectedIndex + delta
            if workspaces.indices.contains(next) { selectedIndex = next }
        }
    }

    /// Type-to-jump: select the workspace whose name matches the typed character.
    func jump(to character: String) {
        let needle = character.lowercased()
        if let i = workspaces.firstIndex(where: { $0.name.lowercased() == needle }) {
            selectedIndex = i
        }
    }

    func select(index: Int) {
        selectedIndex = clamp(index)
        confirm()
    }

    func confirm() {
        guard workspaces.indices.contains(selectedIndex) else { onCancel?(); return }
        onSelect?(workspaces[selectedIndex].name)
    }

    func cancel() { onCancel?() }
}

struct ControlTowerView: View {
    @ObservedObject var model: ControlTowerModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { model.cancel() }

            if model.workspaces.isEmpty {
                Text("No open windows")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: model.columns),
                        spacing: 24,
                    ) {
                        ForEach(Array(model.workspaces.enumerated()), id: \.element.id) { idx, ws in
                            WorkspaceCardView(workspace: ws, isSelected: idx == model.selectedIndex)
                                .contentShape(Rectangle())
                                .onTapGesture { model.select(index: idx) }
                        }
                    }
                    .padding(48)
                }
            }
        }
    }
}

private struct WorkspaceCardView: View {
    let workspace: CTWorkspace
    let isSelected: Bool

    private var borderColor: Color {
        if isSelected { return .accentColor }
        if workspace.isFocused { return .white.opacity(0.55) }
        return .white.opacity(0.12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(workspace.name)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.white)
                if workspace.isVisible {
                    Image(systemName: "dot.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.9))
                }
                Spacer(minLength: 4)
                Text(workspace.monitorName)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.5))
            }

            SchematicView(tiles: workspace.tiles)
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(Color.white.opacity(isSelected ? 0.14 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 3 : 1.5),
        )
    }
}

private struct SchematicView: View {
    let tiles: [CTTile]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(tiles) { tile in
                    TileView(tile: tile)
                        .frame(
                            width: max(4, tile.rect.width * geo.size.width - 3),
                            height: max(4, tile.rect.height * geo.size.height - 3),
                        )
                        .offset(
                            x: tile.rect.minX * geo.size.width + 1.5,
                            y: tile.rect.minY * geo.size.height + 1.5,
                        )
                }
            }
        }
    }
}

private struct TileView: View {
    let tile: CTTile

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(tile.isFloating ? 0.22 : 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1),
                )
            VStack(spacing: 3) {
                if let icon = tile.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                }
                Text(tile.appName)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 4)
            }
            .padding(2)
        }
    }
}
