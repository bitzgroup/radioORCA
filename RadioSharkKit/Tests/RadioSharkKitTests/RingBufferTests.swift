import Testing

@testable import RadioSharkKit

@Suite("RingBuffer")
struct RingBufferTests {
    @Test("書き込んだ範囲内は読み出せる")
    func readWithinWrittenRange() {
        var buffer = RingBuffer(capacity: 10, initialElement: 0)
        buffer.write([1, 2, 3, 4, 5])
        #expect(buffer.read(from: 0, count: 5) == [1, 2, 3, 4, 5])
        #expect(buffer.read(from: 1, count: 3) == [2, 3, 4])
    }

    @Test("容量を超えた分は古い要素を上書きする")
    func overwritesOldestOnWrap() {
        var buffer = RingBuffer(capacity: 4, initialElement: 0)
        buffer.write([1, 2, 3, 4, 5, 6])  // 4,5,6が残り、1,2は上書きされる想定ではなく…
        // capacity=4なので直近4件 (3,4,5,6) だけが読み出せる
        #expect(buffer.oldestAvailableIndex == 2)
        #expect(buffer.read(from: 2, count: 4) == [3, 4, 5, 6])
    }

    @Test("上書き済みの範囲を読み出そうとするとnil")
    func readingOverwrittenRangeReturnsNil() {
        var buffer = RingBuffer(capacity: 4, initialElement: 0)
        buffer.write([1, 2, 3, 4, 5, 6])
        #expect(buffer.read(from: 0, count: 1) == nil)
        #expect(buffer.read(from: 1, count: 4) == nil)  // 一部が上書き済み
    }

    @Test("未書き込みの範囲を読み出そうとするとnil")
    func readingUnwrittenRangeReturnsNil() {
        var buffer = RingBuffer(capacity: 4, initialElement: 0)
        buffer.write([1, 2])
        #expect(buffer.read(from: 0, count: 3) == nil)
    }

    @Test("totalWrittenは書き込み総数を単調増加で追跡する")
    func totalWrittenTracksAllWrites() {
        var buffer = RingBuffer(capacity: 4, initialElement: 0)
        buffer.write([1, 2, 3])
        buffer.write([4, 5, 6])
        #expect(buffer.totalWritten == 6)
    }
}
