import AppKit
import Common
import SwiftUI

/// Full-screen, interactive overlay that shows every non-empty workspace as a schematic and lets the
/// user switch to one. Modeled on the existing HUD panels (`NSPanelHud`, `VolumePanel`) but, unlike
/// them, it accepts keyboard focus so it can be navigated.
@MainActor
final class ControlTowerPanel: NSPanel {
    static let shared = ControlTowerPanel()

    private var model: ControlTowerModel?
    private var isShown = false

    private init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false,
        )
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        backgroundColor = .clear
        hasShadow = false
        isOpaque = false
    }

    // Borderless panels are non-key by default; allow it so keyboard navigation works.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func toggle() {
        if isShown { hide() } else { show() }
    }

    private func show() {
        let snapshot = ControlTowerSnapshotBuilder.capture()
        let model = ControlTowerModel(snapshot: snapshot)
        model.onSelect = { [weak self] name in self?.switchTo(name) }
        model.onCancel = { [weak self] in self?.cancelAndRestoreFocus() }
        self.model = model

        // Frosted-glass backdrop so the desktop recedes and the schematic reads clearly.
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.appearance = NSAppearance(named: .darkAqua)
        blur.autoresizingMask = [.width, .height]
        let host = NSHostingView(rootView: ControlTowerView(model: model))
        host.autoresizingMask = [.width, .height]
        let container = NSView()
        container.addSubview(blur)
        container.addSubview(host)
        contentView = container

        setFrame(activeScreenFrame(), display: true)
        blur.frame = container.bounds
        host.frame = container.bounds
        isShown = true
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    private func hide() {
        isShown = false
        orderOut(nil)
        contentView = nil
        model = nil
    }

    private func switchTo(_ workspaceName: String) {
        hide()
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        Task.startUnstructured {
            try await runLightSession(.menuBarButton, token) {
                _ = Workspace.get(byName: workspaceName).focusWorkspace()
            }
        }
    }

    private func cancelAndRestoreFocus() {
        hide()
        // Re-assert focus on the current workspace so Esc is a true no-op even though showing the
        // panel briefly stole key focus.
        guard let token: RunSessionGuard = .isServerEnabled else { return }
        Task.startUnstructured {
            try await runLightSession(.menuBarButton, token) {
                _ = focus.workspace.focusWorkspace()
            }
        }
    }

    private func activeScreenFrame() -> NSRect {
        let screensId = focus.workspace.workspaceMonitor.monitorAppKitNsScreenScreensId
        let screens = NSScreen.screens
        let screen = screens.indices.contains(screensId - 1) ? screens[screensId - 1] : (NSScreen.main ?? screens.first)
        return screen?.frame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
    }

    override func keyDown(with event: NSEvent) {
        guard let model else { super.keyDown(with: event); return }
        switch event.keyCode {
            case 53: model.cancel() // esc
            case 36, 76: model.confirm() // return, keypad enter
            case 123: model.moveLeft() // left
            case 124: model.moveRight() // right
            case 125: model.moveDown() // down
            case 126: model.moveUp() // up
            default:
                if let chars = event.charactersIgnoringModifiers, chars.count == 1,
                   let scalar = chars.unicodeScalars.first, scalar.value >= 0x20
                {
                    model.jump(to: chars)
                } else {
                    super.keyDown(with: event)
                }
        }
    }

    // Esc also arrives here via the responder chain on some keyboards/layouts.
    override func cancelOperation(_ sender: Any?) {
        model?.cancel()
    }
}
