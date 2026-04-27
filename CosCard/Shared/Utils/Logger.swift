import Foundation
import os.log

enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "CosCard"

    static func log(_ message: String, category: String = "App") {
        let log = OSLog(subsystem: subsystem, category: category)
        os_log("%{public}@", log: log, type: .default, message)
    }

    static func error(_ message: String, category: String = "App") {
        let log = OSLog(subsystem: subsystem, category: category)
        os_log("%{public}@", log: log, type: .error, message)
    }

    static func debug(_ message: String, category: String = "App") {
        let log = OSLog(subsystem: subsystem, category: category)
        os_log("%{public}@", log: log, type: .debug, message)
    }
}
