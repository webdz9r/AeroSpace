import AppKit
import Common
import SwiftUI

@MainActor
final class ControlTowerModel: ObservableObject {
    let workspaces: [CTWorkspace]
    let columns: Int
    let showMonitorLabel: Bool
    @Published var selectedIndex: Int

    var onSelect: ((String) -> Void)?
    var onCancel: (() -> Void)?

    init(snapshot: ControlTowerSnapshot) {
        workspaces = snapshot.workspaces
        columns = max(1, min(4, Int(ceil(Double(max(workspaces.count, 1)).squareRoot()))))
        showMonitorLabel = snapshot.monitorCount > 1
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

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 22), count: model.columns)
    }

    // Cap and center the content so it reads as a focused panel even on ultrawide displays.
    private var maxContentWidth: CGFloat { CGFloat(model.columns) * 360 }

    var body: some View {
        ZStack {
            // Subtle extra dim on top of the window's frosted backdrop; also the click-to-cancel target.
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { model.cancel() }

            if model.workspaces.isEmpty {
                Text("No open windows")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                GeometryReader { geo in
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 22) {
                            ForEach(Array(model.workspaces.enumerated()), id: \.element.id) { idx, ws in
                                WorkspaceCardView(
                                    workspace: ws,
                                    isSelected: idx == model.selectedIndex,
                                    showMonitor: model.showMonitorLabel,
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { model.select(index: idx) }
                            }
                        }
                        .frame(maxWidth: maxContentWidth)
                        // Center horizontally within the full width, and vertically when it fits.
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .frame(minHeight: geo.size.height, alignment: .center)
                    }
                }
                VStack {
                    Spacer()
                    HintBar()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct HintBar: View {
    var body: some View {
        HStack(spacing: 16) {
            hint("↑ ↓ ← →", "navigate")
            hint("return", "switch")
            hint("esc", "cancel")
        }
        .font(.system(size: 11))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.bottom, 14)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
        }
    }
}

private struct WorkspaceCardView: View {
    let workspace: CTWorkspace
    let isSelected: Bool
    let showMonitor: Bool

    private var borderColor: Color {
        if isSelected { return .accentColor }
        if workspace.isFocused { return .white.opacity(0.5) }
        return .white.opacity(0.14)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(workspace.name)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                if workspace.isFocused {
                    Text("focused")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                } else if workspace.isVisible {
                    Image(systemName: "dot.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green.opacity(0.9))
                }
                Spacer(minLength: 4)
                if showMonitor {
                    Text(workspace.monitorName)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            SchematicView(tiles: workspace.tiles)
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(14)
        .background(Color.white.opacity(isSelected ? 0.16 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 3 : 1.5),
        )
        .shadow(color: .black.opacity(isSelected ? 0.45 : 0), radius: 16, y: 6)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isSelected)
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
                            width: max(6, tile.rect.width * geo.size.width - 3),
                            height: max(6, tile.rect.height * geo.size.height - 3),
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
                .fill(Color.white.opacity(tile.isFloating ? 0.42 : 0.26))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1),
                )
            VStack(spacing: 4) {
                if let icon = tile.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
                if tile.showsName {
                    Text(tile.appName)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 4)
                }
            }
            .padding(3)
        }
    }
}
