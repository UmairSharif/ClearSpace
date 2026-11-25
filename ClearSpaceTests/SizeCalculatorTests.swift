import XCTest
@testable import ClearSpace

final class SizeCalculatorTests: XCTestCase {
    private var root: TemporaryDirectory!

    override func setUpWithError() throws {
        root = try TemporaryDirectory()
    }

    override func tearDown() {
        root = nil
    }

    func testMissingPathIsZero() {
        XCTAssertEqual(SizeCalculator.allocatedSize(of: root.path("nothing-here")), 0)
    }

    func testFileSizeIsAtLeastItsLength() throws {
        let file = try root.makeFile("a.bin", size: Bytes.megabyte)
        XCTAssertGreaterThanOrEqual(SizeCalculator.allocatedSize(of: file), Int64(Bytes.megabyte))
    }

    func testFolderSizeSumsNestedFiles() throws {
        try root.makeFile("folder/a.bin", size: Bytes.megabyte)
        try root.makeFile("folder/sub/b.bin", size: 2 * Bytes.megabyte)
        let size = SizeCalculator.allocatedSize(of: root.path("folder"))
        XCTAssertGreaterThanOrEqual(size, Int64(3 * Bytes.megabyte))
        XCTAssertLessThan(size, Int64(4 * Bytes.megabyte))
    }

    func testEmptyFolderIsZero() throws {
        let folder = try root.makeDirectory("empty")
        XCTAssertEqual(SizeCalculator.allocatedSize(of: folder), 0)
    }
}
