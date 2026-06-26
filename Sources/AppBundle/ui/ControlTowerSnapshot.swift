import AppKit
import Common

/// A value-type, read-only snapshot of the current workspaces and their window layout, captured on
/// the `@MainActor` when Control Tower opens. The SwiftUI layer renders from this and holds no live
/// tree references.
struct ControlTowerSnapshot {
    let workspaces: [CTWorkspace]

    /// Index into `workspaces` of the currently focused workspace, if it's shown.
    var focusedIndex: Int? { workspaces.firstIndex { $0.isFocused } }
}

struct CTWorkspace: Identifiable {
    let name: String
    let monitorName: String
    let isVisible: Bool
    let isFocused: Bool
    let tiles: [CTTile]
    var id: String { name }
}

/// One window drawn inside a workspace card. `rect` is normalized to the workspace (0...1, top-left
/// origin, y-down) so the view can scale it to any card size.
struct CTTile: Identifiable {
    let windowId: UInt32
    let appName: String
    let icon: NSImage?
    let rect: CGRect
    let isFloating: Bool
    var id: UInt32 { windowId }
}

enum ControlTowerSnapshotBuilder {
    @MainActor
    static func capture() -> ControlTowerSnapshot {
        let focusedName = focus.workspace.name
        let nonEmpty = Workspace.all.filter { !$0.isEffectivelyEmpty }
        // Order: by monitor (sorted), then by workspace name (Workspace.all is already name-sorted).
        let monitorOrder: [CGPoint: Int] = Dictionary(
            uniqueKeysWithValues: sortedMonitors.enumerated().map { ($0.element.rect.topLeftCorner, $0.offset) },
        )
        let ordered = nonEmpty.sorted { lhs, rhs in
            let lo = monitorOrder[lhs.workspaceMonitor.rect.topLeftCorner] ?? Int.max
            let ro = monitorOrder[rhs.workspaceMonitor.rect.topLeftCorner] ?? Int.max
            return lo != ro ? lo < ro : lhs < rhs
        }
        let workspaces = ordered.map { ws in
            CTWorkspace(
                name: ws.name,
                monitorName: ws.workspaceMonitor.name,
                isVisible: ws.isVisible,
                isFocused: ws.name == focusedName,
                tiles: tiles(for: ws),
            )
        }
        return ControlTowerSnapshot(workspaces: workspaces)
    }

    // MARK: normalized layout

    /// Compute normalized (0...1) tile rects for a workspace by walking the tiling tree (orientation +
    /// weights), mirroring `layoutTiles` in `layout/layoutRecursive.swift` but gap-free and resolution-
    /// independent. Robust for hidden workspaces (windows are off-screen, but the tree/weights persist).
    @MainActor
    static func tiles(for workspace: Workspace) -> [CTTile] {
        var result: [CTTile] = []
        layout(workspace.rootTilingContainer, CGRect(x: 0, y: 0, width: 1, height: 1), into: &result)
        // Floating windows: a small cascade in the center, drawn on top.
        let floating = workspace.floatingWindows
        for (i, window) in floating.enumerated() {
            let step = 0.06 * CGFloat(i)
            let size = 0.4
            let origin = 0.3 + step
            let rect = CGRect(
                x: min(origin, 0.55), y: min(origin, 0.55),
                width: size, height: size,
            )
            result.append(makeTile(window, rect, isFloating: true))
        }
        return result
    }

    @MainActor
    private static func layout(_ node: TreeNode, _ rect: CGRect, into out: inout [CTTile]) {
        switch node.nodeCases {
            case .window(let window):
                out.append(makeTile(window, rect, isFloating: false))
            case .tilingContainer(let container):
                let children = container.children
                guard !children.isEmpty else { return }
                let orientation = container.orientation
                // Accordion windows overlap; for a schematic, split evenly so every app is visible.
                let fractions: [CGFloat] = switch container.layout {
                    case .accordion: Array(repeating: 1 / CGFloat(children.count), count: children.count)
                    case .tiles: tileFractions(children, orientation)
                }
                var offset: CGFloat = 0
                for (child, frac) in zip(children, fractions) {
                    let childRect: CGRect = orientation == .h
                        ? CGRect(x: rect.minX + offset * rect.width, y: rect.minY, width: frac * rect.width, height: rect.height)
                        : CGRect(x: rect.minX, y: rect.minY + offset * rect.height, width: rect.width, height: frac * rect.height)
                    layout(child, childRect, into: &out)
                    offset += frac
                }
            case .workspace(let ws):
                layout(ws.rootTilingContainer, rect, into: &out)
            case .floatingWindowsContainer, .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return // handled separately / not shown
        }
    }

    @MainActor
    private static func tileFractions(_ children: [TreeNode], _ orientation: Orientation) -> [CGFloat] {
        let weights = children.map { max($0.getWeight(orientation), 0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return Array(repeating: 1 / CGFloat(children.count), count: children.count) }
        return weights.map { $0 / total }
    }

    @MainActor
    private static func makeTile(_ window: Window, _ rect: CGRect, isFloating: Bool) -> CTTile {
        let bundlePath = window.app.bundlePath
        let icon = bundlePath.map { NSWorkspace.shared.icon(forFile: $0) }
        return CTTile(
            windowId: window.windowId,
            appName: window.app.name ?? "?",
            icon: icon,
            rect: rect,
            isFloating: isFloating,
        )
    }
}
