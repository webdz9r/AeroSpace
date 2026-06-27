import AppKit
import Common
import Foundation

/// Persist the window layout (which window lives on which workspace, plus the exact tiling tree and
/// the visible/focused workspaces) to disk, and restore it on the next startup — so restarting
/// AeroSpace doesn't collapse every window onto one workspace.
///
/// Matching is by `windowId` (CGWindowID), which is stable across an AeroSpace-only restart as long
/// as the owning apps keep running. Windows whose id is gone (app relaunched / reboot) are skipped.
/// Gated by `config.restoreWindowsOnStartup`.

private let persistedLayoutVersion = 1

private struct PersistedLayout: Codable {
    let version: Int
    let world: FrozenWorld
    let focusedWorkspace: String?
}

private var windowLayoutStateUrl: URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
    let suffix = isDebug ? "-debug" : ""
    return base.appending(path: "AeroSpace/window-layout\(suffix).json")
}

@MainActor private var lastSavedData: Data? = nil
@MainActor private var saveDebounceTask: Task<Void, Never>? = nil

@MainActor func captureFrozenWorld() -> FrozenWorld {
    let allWs = Workspace.all
    return FrozenWorld(
        workspaces: allWs.map { FrozenWorkspace($0) },
        monitors: monitors.map(FrozenMonitor.init),
        windowIds: allWs.flatMap { collectAllWindowIdsRecursive($0) }.toSet(),
    )
}

/// Coalesce rapid layout changes into a single debounced write.
@MainActor func scheduleSaveWindowLayout() {
    guard config.restoreWindowsOnStartup else { return }
    saveDebounceTask?.cancel()
    saveDebounceTask = Task.startUnstructured { @MainActor in
        try? await Task.sleep(for: .seconds(1))
        if Task.isCancelled { return }
        saveWindowLayoutNow()
    }
}

@MainActor func saveWindowLayoutNow() {
    guard config.restoreWindowsOnStartup else { return }
    let payload = PersistedLayout(
        version: persistedLayoutVersion,
        world: captureFrozenWorld(),
        focusedWorkspace: focus.workspace.name,
    )
    guard let data = try? JSONEncoder.aeroSpaceDefault.encode(payload) else { return }
    if data == lastSavedData { return } // nothing changed since last write
    lastSavedData = data
    let url = windowLayoutStateUrl
    _ = Result { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) }
    try? data.write(to: url, options: .atomic)
}

/// Read the persisted layout from disk and restore it. Returns true if a layout was restored.
@MainActor @discardableResult
func restoreWindowLayoutOnStartup() -> Bool {
    guard config.restoreWindowsOnStartup else { return false }
    guard let data = try? Data(contentsOf: windowLayoutStateUrl),
          let payload = try? JSONDecoder().decode(PersistedLayout.self, from: data),
          payload.version == persistedLayoutVersion
    else { return false }
    lastSavedData = data // don't immediately rewrite the same content
    return restoreFrozenWorld(payload.world, focusedWorkspace: payload.focusedWorkspace)
}

/// Restore a frozen world into the live tree. Disk-free so it can be unit tested. Modeled on
/// `restoreClosedWindowsCacheIfNeeded` but with no per-window guard and tolerant of windows that no
/// longer exist; orphaned windows (present live but absent from the snapshot) are re-tiled onto the
/// workspace they were on so they're never left unbound.
@MainActor @discardableResult
func restoreFrozenWorld(_ world: FrozenWorld, focusedWorkspace: String?) -> Bool {
    let monitorsByCorner = monitors.grouped { $0.rect.topLeftCorner }
    // Capture id->window from the live tree up front, before any unbinding. This is independent of
    // where a window is currently bound (so re-tiling/orphan moves don't lose it) and works both in
    // the real app and in unit tests (where windows aren't in MacWindow.allWindowsMap).
    let liveWindows = Dictionary(
        Workspace.all.flatMap { $0.allLeafWindowsRecursive }.map { ($0.windowId, $0) },
        uniquingKeysWith: { first, _ in first },
    )

    for frozenWorkspace in world.workspaces {
        let workspace = Workspace.get(byName: frozenWorkspace.name)
        _ = monitorsByCorner[frozenWorkspace.monitor.topLeftCorner]?.singleOrNil()?.setActiveWorkspace(workspace)
        for frozen in frozenWorkspace.floatingWindows {
            liveWindows[frozen.id]?.bindAsFloatingWindow(to: workspace)
        }
        for frozen in frozenWorkspace.macosUnconventionalWindows {
            liveWindows[frozen.id]?.bindAsFloatingWindow(to: workspace)
        }
        let prevRoot = workspace.rootTilingContainer
        let potentialOrphans = prevRoot.allLeafWindowsRecursive
        prevRoot.unbindFromParent()
        restoreTreeRecursiveTolerant(frozenWorkspace.rootTilingNode, parent: workspace, index: INDEX_BIND_LAST, live: liveWindows)
        for window in (potentialOrphans - workspace.rootTilingContainer.allLeafWindowsRecursive) {
            window.bind(to: workspace.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        }
    }

    for monitor in world.monitors {
        _ = monitorsByCorner[monitor.topLeftCorner]?.singleOrNil()?
            .setActiveWorkspace(Workspace.get(byName: monitor.visibleWorkspace))
    }
    if let focusedName = focusedWorkspace {
        _ = Workspace.get(byName: focusedName).focusWorkspace()
    }
    return true
}

/// Rebuild a tiling subtree from a frozen snapshot, skipping windows that no longer exist (so a single
/// closed window doesn't truncate the rest of the container).
@MainActor
private func restoreTreeRecursiveTolerant(
    _ frozen: FrozenContainer,
    parent: NonLeafTreeNodeObject,
    index: Int,
    live: [UInt32: Window],
) {
    let container = TilingContainer(
        parent: parent,
        adaptiveWeight: frozen.weight,
        frozen.orientation,
        frozen.layout,
        index: index,
    )
    var boundIndex = 0
    for child in frozen.children {
        switch child {
            case .window(let frozenWindow):
                guard let window = live[frozenWindow.id] else { continue } // skip missing
                window.bind(to: container, adaptiveWeight: frozenWindow.weight, index: boundIndex)
                boundIndex += 1
            case .container(let frozenChild):
                restoreTreeRecursiveTolerant(frozenChild, parent: container, index: boundIndex, live: live)
                boundIndex += 1
        }
    }
}
