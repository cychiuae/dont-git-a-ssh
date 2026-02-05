import XCTest
@testable import DontGitASsh

final class SSHConfigParserTests: XCTestCase {

    func testParseSimpleHost() {
        let config = """
        Host myserver
            HostName 192.168.1.100
            User admin
            Port 2222
            IdentityFile ~/.ssh/id_rsa
        """

        let hosts = SSHConfigParser.parse(content: config)

        XCTAssertEqual(hosts.count, 1)
        let host = hosts[0]
        XCTAssertEqual(host.name, "myserver")
        XCTAssertEqual(host.hostName, "192.168.1.100")
        XCTAssertEqual(host.user, "admin")
        XCTAssertEqual(host.port, 2222)
        XCTAssertTrue(host.identityFile?.hasSuffix(".ssh/id_rsa") ?? false)
    }

    func testParseMultipleHosts() {
        let config = """
        Host server1
            HostName server1.example.com
            User alice

        Host server2
            HostName server2.example.com
            User bob
            Port 22022
        """

        let hosts = SSHConfigParser.parse(content: config)

        XCTAssertEqual(hosts.count, 2)

        XCTAssertEqual(hosts[0].name, "server1")
        XCTAssertEqual(hosts[0].hostName, "server1.example.com")
        XCTAssertEqual(hosts[0].user, "alice")
        XCTAssertNil(hosts[0].port)

        XCTAssertEqual(hosts[1].name, "server2")
        XCTAssertEqual(hosts[1].hostName, "server2.example.com")
        XCTAssertEqual(hosts[1].user, "bob")
        XCTAssertEqual(hosts[1].port, 22022)
    }

    func testParseHostWithoutHostName() {
        let config = """
        Host github.com
            User git
            IdentityFile ~/.ssh/github_key
        """

        let hosts = SSHConfigParser.parse(content: config)

        XCTAssertEqual(hosts.count, 1)
        let host = hosts[0]
        XCTAssertEqual(host.name, "github.com")
        XCTAssertNil(host.hostName)
        XCTAssertEqual(host.effectiveHostName, "github.com")
        XCTAssertEqual(host.user, "git")
    }

    func testSkipComments() {
        let config = """
        # This is a comment
        Host myserver
            # Another comment
            HostName example.com
            User admin
        """

        let hosts = SSHConfigParser.parse(content: config)

        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].name, "myserver")
        XCTAssertEqual(hosts[0].hostName, "example.com")
    }

    func testSkipEmptyLines() {
        let config = """

        Host myserver

            HostName example.com

            User admin

        """

        let hosts = SSHConfigParser.parse(content: config)

        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].name, "myserver")
    }

    func testWildcardPatternDetection() {
        let config = """
        Host *
            ServerAliveInterval 60

        Host *.example.com
            User admin

        Host myserver
            HostName 192.168.1.1
        """

        let hosts = SSHConfigParser.parse(content: config)

        XCTAssertEqual(hosts.count, 3)
        XCTAssertTrue(hosts[0].isPattern) // *
        XCTAssertTrue(hosts[1].isPattern) // *.example.com
        XCTAssertFalse(hosts[2].isPattern) // myserver
    }

    func testDisplayString() {
        let hostWithUserAndPort = SSHConfigHost(
            name: "test",
            hostName: "example.com",
            user: "admin",
            port: 2222,
            identityFile: nil
        )
        XCTAssertEqual(hostWithUserAndPort.displayString, "admin@example.com:2222")

        let hostWithUserOnly = SSHConfigHost(
            name: "test",
            hostName: "example.com",
            user: "admin",
            port: nil,
            identityFile: nil
        )
        XCTAssertEqual(hostWithUserOnly.displayString, "admin@example.com")

        let hostWithDefaultPort = SSHConfigHost(
            name: "test",
            hostName: "example.com",
            user: "admin",
            port: 22,
            identityFile: nil
        )
        XCTAssertEqual(hostWithDefaultPort.displayString, "admin@example.com")

        let hostWithoutUser = SSHConfigHost(
            name: "test",
            hostName: "example.com",
            user: nil,
            port: 2222,
            identityFile: nil
        )
        XCTAssertEqual(hostWithoutUser.displayString, "example.com:2222")
    }

    func testCaseInsensitiveKeys() {
        let config = """
        HOST myserver
            HOSTNAME example.com
            USER admin
            PORT 22
        """

        let hosts = SSHConfigParser.parse(content: config)

        XCTAssertEqual(hosts.count, 1)
        XCTAssertEqual(hosts[0].name, "myserver")
        XCTAssertEqual(hosts[0].hostName, "example.com")
        XCTAssertEqual(hosts[0].user, "admin")
        XCTAssertEqual(hosts[0].port, 22)
    }

    func testEmptyConfig() {
        let config = ""
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertTrue(hosts.isEmpty)
    }

    func testConfigWithOnlyComments() {
        let config = """
        # Comment 1
        # Comment 2
        """
        let hosts = SSHConfigParser.parse(content: config)
        XCTAssertTrue(hosts.isEmpty)
    }
}
