import XCTest
@testable import DontGitASsh

final class GitLogParserTests: XCTestCase {

    func testParseSingleCommit() {
        let output = "abc123def456789|abc123d|Add new feature|John Doe|john@example.com|2024-01-15T10:30:00+00:00|def456789"

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.count, 1)

        let commit = commits[0]
        XCTAssertEqual(commit.hash, "abc123def456789")
        XCTAssertEqual(commit.shortHash, "abc123d")
        XCTAssertEqual(commit.message, "Add new feature")
        XCTAssertEqual(commit.author, "John Doe")
        XCTAssertEqual(commit.authorEmail, "john@example.com")
        XCTAssertEqual(commit.parentHashes, ["def456789"])
    }

    func testParseMultipleCommits() {
        let output = """
        abc123|abc1|Commit 1|Alice|alice@example.com|2024-01-15T10:00:00+00:00|def456
        def456|def4|Commit 2|Bob|bob@example.com|2024-01-14T09:00:00+00:00|ghi789
        ghi789|ghi7|Initial commit|Alice|alice@example.com|2024-01-13T08:00:00+00:00|
        """

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.count, 3)
        XCTAssertEqual(commits[0].shortHash, "abc1")
        XCTAssertEqual(commits[1].shortHash, "def4")
        XCTAssertEqual(commits[2].shortHash, "ghi7")
    }

    func testParseMergeCommit() {
        let output = "abc123|abc1|Merge branch 'feature'|John|john@example.com|2024-01-15T10:00:00+00:00|def456 ghi789"

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.count, 1)

        let commit = commits[0]
        XCTAssertTrue(commit.isMerge)
        XCTAssertEqual(commit.parentHashes.count, 2)
        XCTAssertEqual(commit.parentHashes[0], "def456")
        XCTAssertEqual(commit.parentHashes[1], "ghi789")
    }

    func testParseCommitWithNoParent() {
        let output = "abc123|abc1|Initial commit|John|john@example.com|2024-01-15T10:00:00+00:00|"

        let commits = GitLogParser.parse(output)

        XCTAssertEqual(commits.count, 1)
        XCTAssertTrue(commits[0].parentHashes.isEmpty)
    }

    func testCommitSubjectAndBody() {
        let commit = GitCommit(
            hash: "abc123",
            shortHash: "abc1",
            message: "First line\n\nThis is the body\nWith multiple lines",
            author: "John",
            authorEmail: "john@example.com",
            date: Date(),
            parentHashes: []
        )

        XCTAssertEqual(commit.subject, "First line")
        XCTAssertEqual(commit.body, "This is the body\nWith multiple lines")
    }

    func testCommitWithNoBody() {
        let commit = GitCommit(
            hash: "abc123",
            shortHash: "abc1",
            message: "Just a subject line",
            author: "John",
            authorEmail: "john@example.com",
            date: Date(),
            parentHashes: []
        )

        XCTAssertEqual(commit.subject, "Just a subject line")
        XCTAssertNil(commit.body)
    }
}
