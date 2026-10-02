import Foundation

/// Log de depuracion opcional: solo escribe si existe ~/.listtab-debug  ->  ~/Library/Logs/ListTab.log
enum Log {
    private static let flag = NSString(string: "~/.listtab-debug").expandingTildeInPath
    private static let path = NSString(string: "~/Library/Logs/ListTab.log").expandingTildeInPath

    static func write(_ msg: @autoclosure () -> String) {
        guard FileManager.default.fileExists(atPath: flag) else { return }
        let line = "\(Date().formatted(.iso8601.time(includingFractionalSeconds: true))) \(msg())\n"
        if let h = FileHandle(forWritingAtPath: path) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
        else { try? line.write(toFile: path, atomically: true, encoding: .utf8) }
    }
}
