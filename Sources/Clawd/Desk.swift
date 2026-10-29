import Foundation

/// A window as CatWM reports it.
struct DeskWindow: Decodable, Sendable {
    let id: Int
    let pid: Int
    let focused: Bool
    let floating: Bool
    let minimized: Bool
    let fullscreen: Bool
    let visible: Bool
    let workspace: String?
    let screen: String?
}

/// A display as CatWM reports it, with the workspace it shows.
struct DeskScreen: Decodable, Sendable {
    let uuid: String
    let workspace: String
}

/// CatWM, over its Unix socket (`~/.config/catwm/catwm.sock`). Each call opens a short connection off
/// the main thread and gives nil when CatWM does not run or refuses the command.
enum Desk {
    static func windows() async -> [DeskWindow]? { await call("windows", as: [DeskWindow].self) }
    static func screens() async -> [DeskScreen]? { await call("screens", as: [DeskScreen].self) }

    @discardableResult static func show(_ workspace: String) async -> Bool {
        await call("workspace", ["workspace": argument(workspace)]) != nil
    }

    @discardableResult static func carry(to workspace: String) async -> Bool {
        await call("movetoworkspace", ["workspace": argument(workspace)]) != nil
    }

    @discardableResult static func send(to workspace: String) async -> Bool {
        await call("movetoworkspacesilent", ["workspace": argument(workspace)]) != nil
    }

    @discardableResult static func toggleFloating() async -> Bool {
        await call("togglefloating") != nil
    }

    /// `<display>/4` → `4`, `<display>/notes` → `name:notes`.
    static func argument(_ workspace: String) -> String {
        let last = workspace.split(separator: "/").last.map(String.init) ?? workspace
        return Int(last) != nil ? last : "name:\(last)"
    }

    static func number(_ workspace: String) -> Int {
        Int(workspace.split(separator: "/").last ?? "") ?? 0
    }

    private static func call<T: Decodable & Sendable>(_ command: String, as type: T.Type) async -> T? {
        guard let result = await call(command) else { return nil }
        return try? JSONDecoder().decode(T.self, from: result)
    }

    /// Sends one request line and gives the `result` of the matching reply as JSON.
    private static func call(_ command: String, _ args: [String: String] = [:]) async -> Data? {
        await AX.offMain {
            let environment = ProcessInfo.processInfo.environment
            let folder = environment["CATWM_INSTANCE"].map { "~/.config/catwm/instances/\($0)" } ?? "~/.config/catwm"
            let path = environment["CATWM_SOCKET"] ?? NSString(string: "\(folder)/catwm.sock").expandingTildeInPath

            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            guard path.utf8.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
            withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: Array(path.utf8) + [0]) }
            let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
            guard socket >= 0 else { return nil }
            defer { close(socket) }
            var on: Int32 = 1
            setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
            var timeout = timeval(tv_sec: 2, tv_usec: 0)
            setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard connected == 0,
                  let request = try? JSONSerialization.data(withJSONObject: ["id": 1, "command": command, "args": args])
            else { return nil }
            let line = request + Data("\n".utf8)
            guard line.withUnsafeBytes({ write(socket, $0.baseAddress, $0.count) }) == line.count else { return nil }

            var buffer = Data()
            var chunk = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let reply = buffer[buffer.startIndex..<newline]
                    buffer = Data(buffer[buffer.index(after: newline)...])
                    guard let object = try? JSONSerialization.jsonObject(with: reply) as? [String: Any],
                          object["id"] as? Int == 1 else { continue }
                    guard object["ok"] as? Bool == true else { return nil }
                    return try? JSONSerialization.data(withJSONObject: object["result"] ?? NSNull(), options: .fragmentsAllowed)
                }
                let count = read(socket, &chunk, chunk.count)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { return nil }
                buffer.append(contentsOf: chunk[0..<count])
            }
        }
    }
}
