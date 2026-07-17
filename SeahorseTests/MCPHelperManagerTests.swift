import XCTest
@testable import Seahorse

final class MCPHelperManagerTests: XCTestCase {
    func testMatchingHelperProcessIDsOnlyReturnsExactNodeCommand() {
        let helperPath = "/Users/test/My Apps/Seahorse/MCPHelper/dist/index.js"
        let processList = """
          101 node /Users/test/My Apps/Seahorse/MCPHelper/dist/index.js
          102 node /Users/test/My Apps/Seahorse/MCPHelper/dist/index.js.backup
          103 node /Users/other/Seahorse/MCPHelper/dist/index.js
          104 /opt/homebrew/bin/node /Users/test/My Apps/Seahorse/MCPHelper/dist/index.js
          105 Seahorse
          106 /Users/test/My Apps/Seahorse/MCPHelper/node /Users/test/My Apps/Seahorse/MCPHelper/dist/index.js
        """

        XCTAssertEqual(
            MCPHelperManager.matchingHelperProcessIDs(
                in: processList,
                helperScriptPath: helperPath
            ),
            [101, 106]
        )
    }
}
