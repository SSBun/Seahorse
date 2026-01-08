import Foundation
import OSLog

/// A centralized logging utility wrapper around OSLog.
/// Usage:
/// Log.info("Message", category: .network)
/// Log.error("Error occurred", category: .database)
struct Log {
    // MARK: - Categories
    
    /// Extension to define categories for the app
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.seahorse"
}

extension Logger {
    static let general = Logger(subsystem: Log.subsystem, category: "general")
    static let network = Logger(subsystem: Log.subsystem, category: "network")
    static let database = Logger(subsystem: Log.subsystem, category: "database")
    static let ui = Logger(subsystem: Log.subsystem, category: "ui")
    static let paste = Logger(subsystem: Log.subsystem, category: "paste")
    static let storage = Logger(subsystem: Log.subsystem, category: "storage")
    static let ai = Logger(subsystem: Log.subsystem, category: "ai")
    static let parsing = Logger(subsystem: Log.subsystem, category: "parsing")
}

extension Log {
    // MARK: - Logging Methods
    
    /// Log a debug message (verbose, for development)
    @inline(__always)
    static func debug(_ message: String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
#if DEBUG
        let fileName = (file as NSString).lastPathComponent
        category.debug("[\(fileName):\(line)] \(function) -> \(message, privacy: .public)")
#else
        _ = message
        _ = category
        _ = file
        _ = function
        _ = line
#endif
    }
    
    /// Log an informational message (general flow)
    static func info(_ message: String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        category.info("[\(fileName):\(line)] \(function) -> \(message, privacy: .public)")
    }
    
    /// Log a warning (something unexpected but handled)
    static func warning(_ message: String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        category.warning("[\(fileName):\(line)] \(function) -> ⚠️ \(message, privacy: .public)")
    }
    
    /// Log an error (something failed)
    static func error(_ message: String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        category.error("[\(fileName):\(line)] \(function) -> ❌ \(message, privacy: .public)")
    }
    
    /// Log a fault (critical error, potential crash)
    static func fault(_ message: String, category: Logger = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        category.fault("[\(fileName):\(line)] \(function) -> 💥 \(message, privacy: .public)")
    }
}

/// Global debug logger.
/// - Prints via system OSLog in DEBUG builds
/// - Compiles out in RELEASE builds
@inline(__always)
func DLog(
    _ message: @autoclosure () -> String,
    category: Logger = .general,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
#if DEBUG
    Log.debug(message(), category: category, file: file, function: function, line: line)
#else
    _ = message
    _ = category
    _ = file
    _ = function
    _ = line
#endif
}
