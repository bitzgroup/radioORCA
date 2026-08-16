import Foundation
import RadioSharkKit

// radiosh-cli
// Minimal CLI for manually verifying a real radioSHARK 2 device's LED and
// tuner control. Exists to reach parity with the historical `rslight`/`radiosh`
// command-line tools during development (see docs/implementation-plan.md,
// Phase 1 / M1).

func printUsage() {
    let message = """
    Usage: radiosh-cli [-b <0-127>] [-r <0-127>] [-f <MHz>] [-a <kHz>] [-w <seconds>]
        -b    Set the blue LED brightness (0-127)
        -r    Set the red LED (recording indicator) brightness (0-127)
        -f    Switch to FM and tune to the given frequency (MHz)
        -a    Switch to AM and tune to the given frequency (kHz)
        -w    Hold the HID connection open for N seconds before exiting (diagnostic)

    All given options are applied in order.
    """
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("Error: " + message + "\n").utf8))
    exit(1)
}

var blueLight: UInt8?
var redLight: UInt8?
var fmMegahertz: Double?
var amKilohertz: Int?
var holdSeconds: Double?

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
    case "-b":
        let raw = nextValue(for: flag)
        guard let value = UInt8(raw) else { fail("invalid value for -b: \(raw)") }
        blueLight = min(value, 127)
    case "-r":
        let raw = nextValue(for: flag)
        guard let value = UInt8(raw) else { fail("invalid value for -r: \(raw)") }
        redLight = min(value, 127)
    case "-f":
        let raw = nextValue(for: flag)
        guard let value = Double(raw) else { fail("invalid value for -f: \(raw)") }
        fmMegahertz = value
    case "-a":
        let raw = nextValue(for: flag)
        guard let value = Int(raw) else { fail("invalid value for -a: \(raw)") }
        amKilohertz = value
    case "-w":
        let raw = nextValue(for: flag)
        guard let value = Double(raw) else { fail("invalid value for -w: \(raw)") }
        holdSeconds = value
    case "-h", "--help":
        printUsage()
        exit(0)
    default:
        printUsage()
        exit(1)
    }
}

let controller = HIDController()
do {
    try controller.connect()
} catch {
    fail("\(error)")
}

do {
    if let blueLight { try controller.setBlueLight(level: blueLight) }
    if let redLight { try controller.setRedLight(level: redLight) }
    if let fmMegahertz { try controller.tuneFM(megahertz: fmMegahertz) }
    if let amKilohertz { try controller.tuneAM(kilohertz: amKilohertz) }
} catch {
    fail("\(error)")
}

if let holdSeconds {
    // Diagnostic: keep the HID connection (IOHIDManager) open instead of
    // closing it immediately, to distinguish "the command didn't work" from
    // "the process exited before you could see the change".
    Thread.sleep(forTimeInterval: holdSeconds)
}

print("OK")
