import XCTest
@testable import DontGitASsh

final class GitBranchParserTests: XCTestCase {

    func testParseLocalBranches() {
        let output = """
        * main       abc1234 Latest commit message
          feature    def5678 Feature branch commit
          bugfix     ghi9012 Bug fix commit
        """

        let branches = GitBranchParser.parseLocal(output)

        XCTAssertEqual(branches.count, 3)

        XCTAssertEqual(branches[0].name, "main")
        XCTAssertTrue(branches[0].isCurrent)
        XCTAssertEqual(branches[0].commitHash, "abc1234")

        XCTAssertEqual(branches[1].name, "feature")
        XCTAssertFalse(branches[1].isCurrent)

        XCTAssertEqual(branches[2].name, "bugfix")
        XCTAssertFalse(branches[2].isCurrent)
    }

    func testParseRemoteBranches() {
        let output = """
          origin/HEAD -> origin/main
          origin/main
          origin/feature
          upstream/main
        """

        let branches = GitBranchParser.parseRemote(output)

        XCTAssertEqual(branches.count, 3) // HEAD pointer is skipped

        XCTAssertEqual(branches[0].name, "origin/main")
        XCTAssertTrue(branches[0].isRemote)
        XCTAssertEqual(branches[0].remoteName, "origin")
        XCTAssertEqual(branches[0].shortName, "main")

        XCTAssertEqual(branches[1].name, "origin/feature")
        XCTAssertEqual(branches[2].name, "upstream/main")
    }

    func testParseWithTracking() {
        let output = """
        * main       abc1234 [origin/main] Latest commit
          feature    def5678 [origin/feature: ahead 2] Feature work
          local      ghi9012 Local only branch
        """

        let branches = GitBranchParser.parseWithTracking(output)

        XCTAssertEqual(branches.count, 3)

        XCTAssertEqual(branches[0].name, "main")
        XCTAssertEqual(branches[0].trackingBranch, "origin/main")

        XCTAssertEqual(branches[1].name, "feature")
        XCTAssertEqual(branches[1].trackingBranch, "origin/feature")

        XCTAssertEqual(branches[2].name, "local")
        XCTAssertNil(branches[2].trackingBranch)
    }

    func testRemoteBranchProperties() {
        let branch = GitBranch(
            name: "origin/feature/new-stuff",
            isRemote: true,
            isCurrent: false,
            trackingBranch: nil,
            commitHash: nil
        )

        XCTAssertEqual(branch.remoteName, "origin")
        XCTAssertEqual(branch.shortName, "feature/new-stuff")
    }

    func testLocalBranchProperties() {
        let branch = GitBranch(
            name: "feature/new-stuff",
            isRemote: false,
            isCurrent: true,
            trackingBranch: "origin/feature/new-stuff",
            commitHash: "abc1234"
        )

        XCTAssertNil(branch.remoteName)
        XCTAssertEqual(branch.shortName, "feature/new-stuff")
    }
}
