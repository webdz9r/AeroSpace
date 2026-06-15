@testable import AppBundle
import Common
import XCTest

@MainActor
final class StickyCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testStickyOnFloatsTheWindow() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply {
                TestWindow.new(id: 1, parent: $0)
            }
        }
        assertEquals(workspace.focusWorkspace(), true)
        let window = Window.get(byId: 1).orDie()
        assertEquals(window.isSticky, false)
        assertEquals(window.isFloating, false)

        try await parseCommand("sticky --window-id 1 on").cmdOrDie.run(.defaultEnv, .emptyStdin)

        assertEquals(window.isSticky, true)
        assertEquals(window.isFloating, true) // sticky is scoped to floating windows
        assertEquals(window.nodeWorkspace, workspace)
    }

    func testStickyToggleAndOff() async throws {
        let workspace = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply { TestWindow.new(id: 1, parent: $0) }
        }
        assertEquals(workspace.focusWorkspace(), true)
        let window = Window.get(byId: 1).orDie()

        try await parseCommand("sticky --window-id 1 toggle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, true)

        try await parseCommand("sticky --window-id 1 toggle").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, false)

        try await parseCommand("sticky --window-id 1 off").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.isSticky, false)
    }

    func testStickyWindowFollowsWorkspaceSwitch() async throws {
        let ws1 = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply { TestWindow.new(id: 1, parent: $0) }
        }
        assertEquals(ws1.focusWorkspace(), true)
        let window = Window.get(byId: 1).orDie()

        try await parseCommand("sticky --window-id 1 on").cmdOrDie.run(.defaultEnv, .emptyStdin)
        assertEquals(window.nodeWorkspace, ws1)

        // Switch to another workspace on the same monitor -> sticky window must come along
        let ws2 = Workspace.get(byName: "sticky-follow-target")
        assertEquals(ws2.focusWorkspace(), true)

        assertEquals(window.nodeWorkspace, ws2)
        assertEquals(window.isFloating, true)
    }

    func testNonStickyWindowDoesNotFollow() {
        let ws1 = Workspace.get(byName: name).apply {
            $0.rootTilingContainer.apply { TestWindow.new(id: 1, parent: $0) }
        }
        assertEquals(ws1.focusWorkspace(), true)
        let window = Window.get(byId: 1).orDie()

        let ws2 = Workspace.get(byName: "sticky-noop-target")
        assertEquals(ws2.focusWorkspace(), true)

        assertEquals(window.nodeWorkspace, ws1) // stayed put
    }
}
