import Foundation

enum SimulationError: LocalizedError {
    case failed
    case invalidResult

    var errorDescription: String? {
        switch self {
        case .failed: return "Icarus Verilog không chạy được phép đo."
        case .invalidResult: return "Dữ liệu trả về từ Verilog sai định dạng."
        }
    }
}

struct Reading {
    let level: Int
    let valid: Bool
    let outputs: [Bool]
}

struct Simulation {
    let executable: String
    let binary: String

    func measure(distance: Int, noEcho: Bool) throws -> Reading {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable, binary, "+distance_cm=\(distance)",
                             "+no_echo=\(noEcho ? 1 : 0)"]
        process.standardOutput = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw SimulationError.failed }

        let line = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .first { $0.hasPrefix("RESULT ") }
        let fields = line?.split(separator: " ").dropFirst().map(String.init) ?? []
        guard fields.count == 6, let level = Int(fields[0]), (0...3).contains(level),
              fields.dropFirst().allSatisfy({ $0 == "0" || $0 == "1" }) else {
            throw SimulationError.invalidResult
        }
        return Reading(level: level, valid: fields[1] == "1",
                       outputs: fields.dropFirst(2).map { $0 == "1" })
    }
}
