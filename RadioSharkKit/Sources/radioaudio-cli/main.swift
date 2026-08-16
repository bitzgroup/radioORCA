import Foundation
import RadioSharkKit

// radioaudio-cli
// Minimal CLI for manually verifying radioSHARK 2's USB audio input against
// a real device: live monitoring passthrough and AAC recording
// (see docs/implementation-plan.md, Phase 2).

func printUsage() {
    let message = """
    Usage: radioaudio-cli [-m <seconds>] [-r <seconds>] [-s <label>]
        -m    Live-monitor (play input straight to output) for N seconds
        -r    Record for N seconds (implies -m for that duration)
        -s    Station label used in the recording's filename (e.g. FM80.0)

    Recordings are saved to ~/Music/radioORCA/. Requires a connected
    radioSHARK 2 (its USB audio input is auto-detected by device name).
    """
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("Error: " + message + "\n").utf8))
    exit(1)
}

var monitorSeconds: Double?
var recordSeconds: Double?
var stationLabel: String?

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    printUsage()
    exit(1)
}

var index = 0
@MainActor
func nextValue(for flag: String) -> String {
    guard index < arguments.count else { fail("\(flag) requires a value") }
    defer { index += 1 }
    return arguments[index]
}

while index < arguments.count {
    let flag = arguments[index]
    index += 1
    switch flag {
    case "-m":
        let raw = nextValue(for: flag)
        guard let value = Double(raw) else { fail("invalid value for -m: \(raw)") }
        monitorSeconds = value
    case "-r":
        let raw = nextValue(for: flag)
        guard let value = Double(raw) else { fail("invalid value for -r: \(raw)") }
        recordSeconds = value
    case "-s":
        stationLabel = nextValue(for: flag)
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        printUsage()
        exit(1)
    }
}

let controller = AudioEngineController()
do {
    try controller.start()
} catch {
    fail("\(error)")
}

let duration = max(monitorSeconds ?? 0, recordSeconds ?? 0)
guard duration > 0 else {
    fail("specify -m and/or -r")
}

if let recordSeconds, recordSeconds > 0 {
    do {
        let url = try controller.startRecording(stationLabel: stationLabel)
        print("Recording to \(url.path)")
    } catch {
        fail("\(error)")
    }
}

Thread.sleep(forTimeInterval: duration)

controller.stopRecording()
controller.stop()

print("OK")
