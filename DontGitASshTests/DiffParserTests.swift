import XCTest
@testable import DontGitASsh

final class DiffParserTests: XCTestCase {

    func testParseSimpleDiff() {
        let diffOutput = """
        diff --git a/file.txt b/file.txt
        index abc123..def456 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,4 @@
         line 1
        -old line 2
        +new line 2
        +new line 3
         line 3
        """

        let diff = DiffParser.parse(diffOutput)

        XCTAssertEqual(diff.files.count, 1)

        let file = diff.files[0]
        XCTAssertEqual(file.oldPath, "file.txt")
        XCTAssertEqual(file.newPath, "file.txt")
        XCTAssertFalse(file.isNew)
        XCTAssertFalse(file.isDeleted)
        XCTAssertEqual(file.hunks.count, 1)

        let hunk = file.hunks[0]
        XCTAssertEqual(hunk.oldStart, 1)
        XCTAssertEqual(hunk.oldCount, 3)
        XCTAssertEqual(hunk.newStart, 1)
        XCTAssertEqual(hunk.newCount, 4)
        XCTAssertEqual(hunk.lines.count, 5)

        XCTAssertEqual(hunk.lines[0].type, .context)
        XCTAssertEqual(hunk.lines[1].type, .deletion)
        XCTAssertEqual(hunk.lines[2].type, .addition)
        XCTAssertEqual(hunk.lines[3].type, .addition)
        XCTAssertEqual(hunk.lines[4].type, .context)
    }

    func testParseNewFile() {
        let diffOutput = """
        diff --git a/newfile.txt b/newfile.txt
        new file mode 100644
        index 0000000..abc123
        --- /dev/null
        +++ b/newfile.txt
        @@ -0,0 +1,3 @@
        +line 1
        +line 2
        +line 3
        """

        let diff = DiffParser.parse(diffOutput)

        XCTAssertEqual(diff.files.count, 1)

        let file = diff.files[0]
        XCTAssertTrue(file.isNew)
        XCTAssertEqual(file.newPath, "newfile.txt")
    }

    func testParseDeletedFile() {
        let diffOutput = """
        diff --git a/deleted.txt b/deleted.txt
        deleted file mode 100644
        index abc123..0000000
        --- a/deleted.txt
        +++ /dev/null
        @@ -1,3 +0,0 @@
        -line 1
        -line 2
        -line 3
        """

        let diff = DiffParser.parse(diffOutput)

        XCTAssertEqual(diff.files.count, 1)

        let file = diff.files[0]
        XCTAssertTrue(file.isDeleted)
        XCTAssertEqual(file.oldPath, "deleted.txt")
    }

    func testParseMultipleFiles() {
        let diffOutput = """
        diff --git a/file1.txt b/file1.txt
        --- a/file1.txt
        +++ b/file1.txt
        @@ -1 +1 @@
        -old
        +new
        diff --git a/file2.txt b/file2.txt
        --- a/file2.txt
        +++ b/file2.txt
        @@ -1 +1 @@
        -foo
        +bar
        """

        let diff = DiffParser.parse(diffOutput)

        XCTAssertEqual(diff.files.count, 2)
        XCTAssertEqual(diff.files[0].displayPath, "file1.txt")
        XCTAssertEqual(diff.files[1].displayPath, "file2.txt")
    }

    func testParseMultipleHunks() {
        let diffOutput = """
        diff --git a/file.txt b/file.txt
        --- a/file.txt
        +++ b/file.txt
        @@ -1,3 +1,3 @@
         line 1
        -old line 2
        +new line 2
         line 3
        @@ -10,3 +10,3 @@
         line 10
        -old line 11
        +new line 11
         line 12
        """

        let diff = DiffParser.parse(diffOutput)

        XCTAssertEqual(diff.files.count, 1)
        XCTAssertEqual(diff.files[0].hunks.count, 2)

        XCTAssertEqual(diff.files[0].hunks[0].oldStart, 1)
        XCTAssertEqual(diff.files[0].hunks[1].oldStart, 10)
    }

    func testLineNumbers() {
        let diffOutput = """
        diff --git a/file.txt b/file.txt
        --- a/file.txt
        +++ b/file.txt
        @@ -5,4 +5,5 @@
         line 5
        -old line 6
        +new line 6
        +extra line
         line 7
         line 8
        """

        let diff = DiffParser.parse(diffOutput)
        let hunk = diff.files[0].hunks[0]

        // Context line
        XCTAssertEqual(hunk.lines[0].oldLineNumber, 5)
        XCTAssertEqual(hunk.lines[0].newLineNumber, 5)

        // Deletion
        XCTAssertEqual(hunk.lines[1].oldLineNumber, 6)
        XCTAssertNil(hunk.lines[1].newLineNumber)

        // Addition
        XCTAssertNil(hunk.lines[2].oldLineNumber)
        XCTAssertEqual(hunk.lines[2].newLineNumber, 6)

        // Another addition
        XCTAssertNil(hunk.lines[3].oldLineNumber)
        XCTAssertEqual(hunk.lines[3].newLineNumber, 7)

        // Context after additions
        XCTAssertEqual(hunk.lines[4].oldLineNumber, 7)
        XCTAssertEqual(hunk.lines[4].newLineNumber, 8)
    }

    func testAdditionsAndDeletionsCounts() {
        let diffOutput = """
        diff --git a/file.txt b/file.txt
        --- a/file.txt
        +++ b/file.txt
        @@ -1,5 +1,6 @@
         context
        -deleted 1
        -deleted 2
        +added 1
        +added 2
        +added 3
         context
         context
        """

        let diff = DiffParser.parse(diffOutput)
        let file = diff.files[0]

        XCTAssertEqual(file.additions, 3)
        XCTAssertEqual(file.deletions, 2)
        XCTAssertEqual(diff.totalAdditions, 3)
        XCTAssertEqual(diff.totalDeletions, 2)
    }
}
