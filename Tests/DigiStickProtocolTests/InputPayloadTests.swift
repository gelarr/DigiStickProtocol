@testable import DigiStickProtocol
import XCTest

final class InputPayloadTests: XCTestCase {
    private struct Vector {
        let name: String
        let payload: InputPayload
        let bytes: [UInt8]
    }

    private let vectors: [Vector] = [
        Vector(
            name: "centered, no buttons",
            payload: InputPayload(x: 0, y: 0, buttons: 0),
            bytes: [0x01, 0x00, 0x00, 0x00, 0x00, 0x00]
        ),
        Vector(
            name: "small positive x, negative y, two buttons",
            payload: InputPayload(x: 1, y: -1, buttons: 0b00000011),
            bytes: [0x01, 0x01, 0x00, 0xff, 0xff, 0x03]
        ),
        Vector(
            name: "extremes: x max, y min, all buttons",
            payload: InputPayload(x: Int16.max, y: Int16.min, buttons: 0xff),
            bytes: [0x01, 0xff, 0x7f, 0x00, 0x80, 0xff]
        ),
        Vector(
            name: "endianness: low byte first",
            payload: InputPayload(x: 0x1234, y: 0x5678, buttons: 0x9a),
            bytes: [0x01, 0x34, 0x12, 0x78, 0x56, 0x9a]
        ),
    ]

    func testEncodingMatchesKnownVectors() {
        for vector in vectors {
            XCTAssertEqual([UInt8](vector.payload.data), vector.bytes, vector.name)
        }
    }

    func testDecodingMatchesKnownVectors() throws {
        for vector in vectors {
            let decoded = try InputPayload(data: Data(vector.bytes))
            XCTAssertEqual(decoded, vector.payload, vector.name)
        }
    }

    // MARK: - Round trip

    func testRoundTripAcrossRange() throws {
        let samples: [Int16] = [Int16.min, -32767, -256, -1, 0, 1, 255, 256, 32766, Int16.max]
        for x in samples {
            for y in samples {
                let original = InputPayload(x: x, y: y, buttons: UInt8(truncatingIfNeeded: x ^ y))
                let decoded = try InputPayload(data: original.data)
                XCTAssertEqual(decoded, original)
            }
        }
    }

    func testEncodedSizeIsByteCount() {
        XCTAssertEqual(InputPayload(x: 0, y: 0, buttons: 0).data.count, InputPayload.byteCount)
    }

    // MARK: - Rejection

    func testRejectsWrongLength() {
        for length in [0, 1, 5, 7, 64] {
            let data = Data(repeating: 0x01, count: length)
            XCTAssertThrowsError(try InputPayload(data: data), "length \(length)") { error in
                XCTAssertEqual(
                    error as? InputPayload.DecodingError,
                    .invalidLength(expected: InputPayload.byteCount, actual: length)
                )
            }
        }
    }

    func testRejectsUnsupportedVersion() {
        for version: UInt8 in [0x00, 0x02, 0xff] {
            let data = Data([version, 0, 0, 0, 0, 0])
            XCTAssertThrowsError(try InputPayload(data: data), "version \(version)") { error in
                XCTAssertEqual(
                    error as? InputPayload.DecodingError,
                    .unsupportedVersion(version)
                )
            }
        }
    }

    // MARK: - Data slices

    func testDecodesFromDataSliceWithNonZeroStartIndex() throws {
        let packet: [UInt8] = [0xaa, 0xbb, 0x01, 0x34, 0x12, 0x78, 0x56, 0x9a]
        let slice = Data(packet)[2...]
        XCTAssertNotEqual(slice.startIndex, 0)

        let decoded = try InputPayload(data: slice)
        XCTAssertEqual(decoded, InputPayload(x: 0x1234, y: 0x5678, buttons: 0x9a))
    }
}
