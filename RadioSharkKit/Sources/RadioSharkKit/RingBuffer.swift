/// A fixed-capacity circular buffer that silently overwrites the oldest
/// elements once full (never grows, never blocks).
///
/// This is the storage layer under `TimeshiftBuffer`. It's kept generic
/// and free of AVFoundation/Foundation so its bookkeeping (wraparound,
/// "what range is still readable") can be unit tested directly, the same
/// way `FrequencyCodec`/`HIDReports` are tested without real hardware.
public struct RingBuffer<Element> {
    public let capacity: Int
    private var storage: [Element]

    /// Total number of elements ever written (monotonically increasing;
    /// not wrapped — use it as an absolute index into the logical stream).
    public private(set) var totalWritten: Int64 = 0

    public init(capacity: Int, initialElement: Element) {
        precondition(capacity > 0, "capacity must be positive")
        self.capacity = capacity
        self.storage = [Element](repeating: initialElement, count: capacity)
    }

    /// The smallest absolute index still readable. `0` until the buffer
    /// has filled up and started overwriting itself.
    public var oldestAvailableIndex: Int64 {
        max(0, totalWritten - Int64(capacity))
    }

    /// Appends elements, overwriting the oldest ones once `capacity` is
    /// exceeded.
    public mutating func write(_ elements: [Element]) {
        for element in elements {
            storage[Int(totalWritten % Int64(capacity))] = element
            totalWritten += 1
        }
    }

    /// Reads `count` elements starting at absolute `index`. Returns `nil`
    /// if any part of the requested range has already been overwritten,
    /// or hasn't been written yet.
    public func read(from index: Int64, count: Int) -> [Element]? {
        guard
            count > 0,
            index >= oldestAvailableIndex,
            index + Int64(count) <= totalWritten
        else {
            return nil
        }

        var result = [Element]()
        result.reserveCapacity(count)
        for offset in 0..<Int64(count) {
            result.append(storage[Int((index + offset) % Int64(capacity))])
        }
        return result
    }
}
