import XCTest
@testable import DontGitASsh

final class HunkSelectionTests: XCTestCase {

    func createSampleHunk() -> GitHunk {
        GitHunk(
            header: "@@ -1,5 +1,6 @@",
            oldStart: 1,
            oldCount: 5,
            newStart: 1,
            newCount: 6,
            lines: [
                DiffLine(type: .context, content: "context 1", oldLineNumber: 1, newLineNumber: 1, rawLine: " context 1"),
                DiffLine(type: .deletion, content: "deleted", oldLineNumber: 2, newLineNumber: nil, rawLine: "-deleted"),
                DiffLine(type: .addition, content: "added 1", oldLineNumber: nil, newLineNumber: 2, rawLine: "+added 1"),
                DiffLine(type: .addition, content: "added 2", oldLineNumber: nil, newLineNumber: 3, rawLine: "+added 2"),
                DiffLine(type: .context, content: "context 2", oldLineNumber: 3, newLineNumber: 4, rawLine: " context 2"),
            ]
        )
    }

    func testFullSelection() {
        let hunk = createSampleHunk()
        let selection = HunkSelection(hunk: hunk, fullySelected: true)

        XCTAssertTrue(selection.isFullySelected)
        // Should contain indices 1, 2, 3 (the deletion and two additions)
        XCTAssertEqual(selection.selectedLines, [1, 2, 3])
    }

    func testEmptySelection() {
        let hunk = createSampleHunk()
        let selection = HunkSelection(hunk: hunk, fullySelected: false)

        XCTAssertFalse(selection.isFullySelected)
        XCTAssertTrue(selection.selectedLines.isEmpty)
    }

    func testToggleLine() {
        let hunk = createSampleHunk()
        var selection = HunkSelection(hunk: hunk, fullySelected: false)

        // Toggle an addition
        selection.toggleLine(2, in: hunk)
        XCTAssertTrue(selection.selectedLines.contains(2))
        XCTAssertFalse(selection.isFullySelected)

        // Toggle it off
        selection.toggleLine(2, in: hunk)
        XCTAssertFalse(selection.selectedLines.contains(2))
    }

    func testToggleContextLineDoesNothing() {
        let hunk = createSampleHunk()
        var selection = HunkSelection(hunk: hunk, fullySelected: false)

        // Try to toggle a context line (index 0)
        selection.toggleLine(0, in: hunk)
        XCTAssertTrue(selection.selectedLines.isEmpty)

        // Try to toggle another context line (index 4)
        selection.toggleLine(4, in: hunk)
        XCTAssertTrue(selection.selectedLines.isEmpty)
    }

    func testSelectAll() {
        let hunk = createSampleHunk()
        var selection = HunkSelection(hunk: hunk, fullySelected: false)

        selection.selectAll(in: hunk)

        XCTAssertTrue(selection.isFullySelected)
        XCTAssertEqual(selection.selectedLines, [1, 2, 3])
    }

    func testDeselectAll() {
        let hunk = createSampleHunk()
        var selection = HunkSelection(hunk: hunk, fullySelected: true)

        selection.deselectAll()

        XCTAssertFalse(selection.isFullySelected)
        XCTAssertTrue(selection.selectedLines.isEmpty)
    }

    func testPartialSelectionUpdatesFullySelectedState() {
        let hunk = createSampleHunk()
        var selection = HunkSelection(hunk: hunk, fullySelected: false)

        // Select all changeable lines one by one
        selection.toggleLine(1, in: hunk)
        XCTAssertFalse(selection.isFullySelected)

        selection.toggleLine(2, in: hunk)
        XCTAssertFalse(selection.isFullySelected)

        selection.toggleLine(3, in: hunk)
        XCTAssertTrue(selection.isFullySelected)

        // Deselect one
        selection.toggleLine(2, in: hunk)
        XCTAssertFalse(selection.isFullySelected)
    }

    func testHunkToPatch() {
        let hunk = createSampleHunk()
        let patch = hunk.toPatch(filePath: "test.txt")

        XCTAssertTrue(patch.contains("--- a/test.txt"))
        XCTAssertTrue(patch.contains("+++ b/test.txt"))
        XCTAssertTrue(patch.contains("@@ -1,5 +1,6 @@"))
        XCTAssertTrue(patch.contains(" context 1"))
        XCTAssertTrue(patch.contains("-deleted"))
        XCTAssertTrue(patch.contains("+added 1"))
    }

    func testHunkToSelectivePatch() {
        let hunk = createSampleHunk()

        // Select only the additions, not the deletion
        let selectedLines: Set<Int> = [2, 3]

        let patch = hunk.toSelectivePatch(filePath: "test.txt", selectedLineIndices: selectedLines)

        XCTAssertNotNil(patch)

        // The deletion should be converted to context
        // The patch should not contain the deletion line
        XCTAssertFalse(patch!.contains("-deleted"))

        // The additions should be present
        XCTAssertTrue(patch!.contains("+added 1"))
        XCTAssertTrue(patch!.contains("+added 2"))
    }

    func testSelectivePatchWithNoSelectionReturnsNil() {
        let hunk = createSampleHunk()
        let selectedLines: Set<Int> = []

        let patch = hunk.toSelectivePatch(filePath: "test.txt", selectedLineIndices: selectedLines)

        XCTAssertNil(patch)
    }
}
