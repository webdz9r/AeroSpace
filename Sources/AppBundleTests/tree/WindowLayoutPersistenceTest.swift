@testable import AppBundle
import Common
import XCTest

@MainActor
final class WindowLayoutPersistenceTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testFrozenWorldCodableRoundTrip() throws {
        Workspace.get(byName: "1").rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        let world = captureFrozenWorld()
        let data = try JSONEncoder.aeroSpaceDefault.encode(world)
        let decoded = try JSONDecoder().decode(FrozenWorld.self, from: data)
        // Round-trip preserves the windows and the tree structure.
        assertEquals(decoded.windowIds, world.windowIds)
        let ws1 = decoded.workspaces.first { $0.name == "1" }
        assertEquals(ws1?.rootTilingNode.children.count, 2) // window(1) + nested v_tiles container
        if case .container(let nested)? = ws1?.rootTilingNode.children.last {
            assertEquals(nested.orientation, .v)
            assertEquals(nested.children.count, 2) // window(2), window(3)
        } else {
            XCTFail("expected nested container")
        }
    }

    func testRestoreReassignsWindowsAndLayout() {
        let ws1 = Workspace.get(byName: "1")
        ws1.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        let ws2 = Workspace.get(byName: "2")
        ws2.rootTilingContainer.apply { TestWindow.new(id: 4, parent: $0) }

        let snapshot = captureFrozenWorld()
        let ws1Layout = ws1.rootTilingContainer.layoutDescription

        // Simulate the restart collapse: every window ends up on a single workspace.
        Window.get(byId: 4)!.bind(to: ws1.rootTilingContainer, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
        assertEquals(ws2.isEffectivelyEmpty, true)

        assertEquals(restoreFrozenWorld(snapshot, focusedWorkspace: nil), true)

        assertEquals(Window.get(byId: 1)?.nodeWorkspace?.name, "1")
        assertEquals(Window.get(byId: 2)?.nodeWorkspace?.name, "1")
        assertEquals(Window.get(byId: 3)?.nodeWorkspace?.name, "1")
        assertEquals(Window.get(byId: 4)?.nodeWorkspace?.name, "2")
        assertEquals(ws1.rootTilingContainer.layoutDescription, ws1Layout) // exact split restored
    }

    func testRestoreToleratesMissingWindow() {
        let ws1 = Workspace.get(byName: "1")
        ws1.rootTilingContainer.apply {
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
            TestWindow.new(id: 3, parent: $0)
        }
        let snapshot = captureFrozenWorld()

        // Window 2 was closed since the snapshot.
        Window.get(byId: 2)?.unbindFromParent()

        assertEquals(restoreFrozenWorld(snapshot, focusedWorkspace: nil), true)
        // Siblings still restored, missing window simply skipped (no crash, no truncation).
        assertEquals(ws1.rootTilingContainer.layoutDescription, .h_tiles([.window(1), .window(3)]))
    }
}
