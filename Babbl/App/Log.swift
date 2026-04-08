import os.log

enum Log {
    static let general = Logger(subsystem: "com.babbl.app", category: "General")
    static let audio = Logger(subsystem: "com.babbl.app", category: "Audio")
    static let transcriber = Logger(subsystem: "com.babbl.app", category: "Transcriber")
    static let textInserter = Logger(subsystem: "com.babbl.app", category: "TextInserter")
    static let hotkey = Logger(subsystem: "com.babbl.app", category: "Hotkey")
}
