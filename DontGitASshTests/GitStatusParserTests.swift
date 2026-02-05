import XCTest
@testable import DontGitASsh

final class GitStatusParserTests: XCTestCase {

    func testParseStatusWithBranchInfo() {
        let output = """
        # branch.oid abc123def456
        # branch.head main
        # branch.upstream origin/main
        # branch.ab +2 -1
        """

        let status = GitStatusParser.parse(output)

        XCTAssertEqual(status.branch, "main")
        XCTAssertEqual(status.upstream, "origin/main")
        XCTAssertEqual(status.ahead, 2)
        XCTAssertEqual(status.behind, 1)
    }

    func testParseModifiedFile() {
        let output = """
        # branch.head main
        1 .M N... 100644 100644 100644 abc123 def456 modified.txt
        """

        let status = GitStatusParser.parse(output)

        XCTAssertEqual(status.files.count, 1)
        let file = status.files[0]
        XCTAssertEqual(file.path, "modified.txt")
        XCTAssertEqual(file.stagedStatus, .unmodified)
        XCTAssertEqual(file.unstagedStatus, .modified)
    }

    func testParseStagedFile() {
        let output = """
        # branch.head main
        1 M. N... 100644 100644 100644 abc123 def456 staged.txt
        """

        let status = GitStatusParser.parse(output)

        XCTAssertEqual(status.files.count, 1)
        let file = status.files[0]
        XCTAssertEqual(file.path, "staged.txt")
        XCTAssertEqual(file.stagedStatus, .modified)
        XCTAssertEqual(file.unstagedStatus, .unmodified)
        XCTAssertTrue(file.isStaged)
    }

    func testParseUntrackedFile() {
        let output = """
        # branch.head main
        ? untracked.txt
        """

        let status = GitStatusParser.parse(output)

        XCTAssertEqual(status.files.count, 1)
        let file = status.files[0]
        XCTAssertEqual(file.path, "untracked.txt")
        XCTAssertEqual(file.status, .untracked)
    }

    func testParseMultipleFiles() {
        let output = """
        # branch.head main
        1 M. N... 100644 100644 100644 abc123 def456 staged.txt
        1 .M N... 100644 100644 100644 abc123 def456 modified.txt
        1 A. N... 000000 100644 100644 000000 abc123 added.txt
        1 D. N... 100644 000000 000000 abc123 000000 deleted.txt
        ? untracked.txt
        """

        let status = GitStatusParser.parse(output)

        XCTAssertEqual(status.files.count, 5)
        XCTAssertEqual(status.stagedFiles.count, 3) // staged, added, deleted
        XCTAssertEqual(status.unstagedFiles.count, 1) // modified
        XCTAssertEqual(status.untrackedFiles.count, 1)
    }

    func testParseSimpleStatus() {
        let output = """
        M  staged.txt
         M modified.txt
        A  added.txt
        ?? untracked.txt
        """

        let files = GitStatusParser.parseSimple(output)

        XCTAssertEqual(files.count, 4)

        XCTAssertEqual(files[0].path, "staged.txt")
        XCTAssertTrue(files[0].isStaged)

        XCTAssertEqual(files[1].path, "modified.txt")
        XCTAssertTrue(files[1].hasUnstagedChanges)

        XCTAssertEqual(files[2].path, "added.txt")
        XCTAssertEqual(files[2].status, .added)

        XCTAssertEqual(files[3].path, "untracked.txt")
        XCTAssertEqual(files[3].status, .untracked)
    }
}
