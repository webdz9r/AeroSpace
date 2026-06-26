@testable import AppBundle
import Common
import XCTest

@MainActor
final class ControlTowerCommandTest: XCTestCase {
    override func setUp() async throws { setUpWorkspacesForTests() }

    func testParse() {
        assertEquals(parseCommand("control-tower").errorOrNil, nil)
        XCTAssertNotNil(parseCommand("control-tower foo").errorOrNil)
    }

    func testNormalizedTilesEvenHorizontalSplit() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply { // default orientation is .h in tests
            TestWindow.new(id: 1, parent: $0)
            TestWindow.new(id: 2, parent: $0)
        }
        let tiles = ControlTowerSnapshotBuilder.tiles(for: workspace)
        assertEquals(rect(tiles, 1), CGRect(x: 0, y: 0, width: 0.5, height: 1))
        assertEquals(rect(tiles, 2), CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
    }

    func testNormalizedTilesNestedOrientation() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply { // .h root
            TestWindow.new(id: 1, parent: $0)
            TilingContainer.newVTiles(parent: $0, adaptiveWeight: 1).apply {
                TestWindow.new(id: 2, parent: $0)
                TestWindow.new(id: 3, parent: $0)
            }
        }
        let tiles = ControlTowerSnapshotBuilder.tiles(for: workspace)
        assertEquals(rect(tiles, 1), CGRect(x: 0, y: 0, width: 0.5, height: 1))
        assertEquals(rect(tiles, 2), CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
        assertEquals(rect(tiles, 3), CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5))
    }

    func testNormalizedTilesRespectWeights() {
        let workspace = Workspace.get(byName: name)
        workspace.rootTilingContainer.apply { // .h root
            TestWindow.new(id: 1, parent: $0, adaptiveWeight: 3)
            TestWindow.new(id: 2, parent: $0, adaptiveWeight: 1)
        }
        let tiles = ControlTowerSnapshotBuilder.tiles(for: workspace)
        assertEquals(rect(tiles, 1), CGRect(x: 0, y: 0, width: 0.75, height: 1))
        assertEquals(rect(tiles, 2), CGRect(x: 0.75, y: 0, width: 0.25, height: 1))
    }

    private func rect(_ tiles: [CTTile], _ windowId: UInt32) -> CGRect? {
        tiles.first { $0.windowId == windowId }?.rect
    }
}
