import Foundation

/// A single controller input sample, sent from the iOS client to the macOS server.
///
/// Wire format, protocol version 1 (6 bytes, little-endian, no padding):
///
/// | Offset | Size | Field     | Notes                                    |
/// |--------|------|-----------|------------------------------------------|
/// | 0      | 1    | `version` | Must equal `InputPayload.protocolVersion` |
/// | 1      | 2    | `x`       | `Int16`, little-endian                   |
/// | 3      | 2    | `y`       | `Int16`, little-endian                   |
/// | 5      | 1    | `buttons` | Bitmask, bit 0 = button 1                |
///
/// Every field is encoded explicitly, byte by byte. The wire format never
/// depends on Swift's in-memory struct layout or the host's endianness.
public struct InputPayload: Equatable, Sendable {

    /// Wire protocol version written to, and required from, every packet.
    public static let protocolVersion: UInt8 = 1

    /// Exact size of an encoded payload in bytes.
    public static let byteCount = 6

    public var x: Int16
    public var y: Int16
    public var buttons: UInt8

    public init(x: Int16, y: Int16, buttons: UInt8) {
        self.x = x
        self.y = y
        self.buttons = buttons
    }

    public enum DecodingError: Error, Equatable {
        case invalidLength(expected: Int, actual: Int)
        case unsupportedVersion(UInt8)
    }

    /// Decodes a payload, throwing if the length or protocol version is wrong.
    public init(data: Data) throws {
        guard data.count == Self.byteCount else {
            throw DecodingError.invalidLength(expected: Self.byteCount, actual: data.count)
        }

        // Copy into an array so indices start at 0, even for a Data slice.
        let bytes = [UInt8](data)

        guard bytes[0] == Self.protocolVersion else {
            throw DecodingError.unsupportedVersion(bytes[0])
        }

        self.x = Int16(bitPattern: UInt16(bytes[1]) | (UInt16(bytes[2]) << 8))
        self.y = Int16(bitPattern: UInt16(bytes[3]) | (UInt16(bytes[4]) << 8))
        self.buttons = bytes[5]
    }

    /// The encoded wire representation of this payload.
    public var data: Data {
        let xBits = UInt16(bitPattern: x)
        let yBits = UInt16(bitPattern: y)
        return Data([
            Self.protocolVersion,
            UInt8(truncatingIfNeeded: xBits),
            UInt8(truncatingIfNeeded: xBits >> 8),
            UInt8(truncatingIfNeeded: yBits),
            UInt8(truncatingIfNeeded: yBits >> 8),
            buttons
        ])
    }
}
