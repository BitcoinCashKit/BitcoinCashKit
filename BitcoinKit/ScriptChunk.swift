//
//  ScriptChunk.swift
//  BitcoinKit
//
//  Created by Akifumi Fujita on 2018/07/09.
//  Copyright © 2018年 Kishikawa Katsumi. All rights reserved.
//

import Foundation

public struct ScriptChunk {
    let scriptData: Data // Reference to the whole script binary data.
    var range: Range<Int> // A range of scriptData represented by this chunk.

    init(scriptData: Data) {
        self.scriptData = scriptData
        self.range = Range(-1...0) // ToDo
    }

    init(scriptData: Data, range: Range<Int>) {
        self.scriptData = scriptData
        self.range = range
    }

    // Operation to be executed.
    public var opcode: UInt8 {
        return UInt8(scriptData[range.lowerBound])
    }

    // Pushdata opcodes are not considered a single "opcode".
    // Attention: OP_0 is also "pushdata" code that pushes empty data.
    public var isOpcode: Bool {
        return opcode > Opcode.OP_PUSHDATA4
    }

    // Portion of scriptData defined by range.
    public var chunkData: Data {
        return scriptData.subdata(in: range)
    }

    public var pushData: Data? {
        guard !isOpcode else {
            return nil
        }
        var loc = 1
        switch opcode {
        case Opcode.OP_PUSHDATA1:
            loc += 1
        case Opcode.OP_PUSHDATA2:
            loc += 2
        case Opcode.OP_PUSHDATA4:
            loc += 4
        default:
            break
        }
        return scriptData.subdata(in: Range((range.lowerBound + loc)...(range.upperBound)))
    }

    // Returns YES if the data is represented with the most compact opcode.
    public var isDataCompact: Bool {
        guard !isOpcode else {
            return false
        }
        guard let data = pushData else {
            return false
        }
        switch opcode {
        case ...Opcode.OP_PUSHDATA1:
            return true // length fits in one byte under OP_PUSHDATA1.
        case Opcode.OP_PUSHDATA1:
            return data.count >= Opcode.OP_PUSHDATA1 // length should be less than OP_PUSHDATA1
        case Opcode.OP_PUSHDATA2:
            return !data.isEmpty
            //return data.count > 0xff // length should not fit in one byte
        case Opcode.OP_PUSHDATA4:
            return !data.isEmpty
            //return data.count > 0xffff // length should not fit in two bytes
        default:
            return false
        }
    }

    // String representation of a chunk.
    // OP_1NEGATE, OP_0, OP_1..OP_16 are represented as a decimal number.
    // Most compactly represented pushdata chunks >=128 bit are encoded as <hex string>
    // Smaller most compactly represented data is encoded as [<hex string>]
    // Non-compact pushdata (e.g. 75-byte string with PUSHDATA1) contains a decimal prefix denoting a length size before hex data in square brackets. Ex. "1:[...]", "2:[...]" or "4:[...]"
    // For both compat and non-compact pushdata chunks, if the data consists of all printable characters (0x20..0x7E), it is enclosed not in square brackets, but in single quotes as characters themselves. Non-compact string is prefixed with 1:, 2: or 4: like described above.

    // Some other guys (BitcoinQT, bitcoin-ruby) encode "small enough" integers in decimal numbers and do that differently.
    // BitcoinQT encodes any data less than 4 bytes as a decimal number.
    // bitcoin-ruby encodes 2..16 as decimals, 0 and -1 as opcode names and the rest is in hex.
    // Now no matter which encoding you use, it can be parsed incorrectly.
    // Also: pushdata operations are typically encoded in a raw data which can be encoded in binary differently.
    // This means, you'll never be able to parse a sane-looking script into only one binary.
    // So forget about relying on parsing this thing exactly. Typically, we either have very small numbers (0..16),
    // or very big numbers (hashes and pubkeys).
    public var string: String? {
        if isOpcode {
            switch opcode {
            case Opcode.OP_0:
                return "OP_0"
            case Opcode.OP_1NEGATE:
                return "OP_1NEGATE"
            case Opcode.OP_1...Opcode.OP_16:
                return "OP_\(opcode + 1 - Opcode.OP_1)"
            default:
                return Opcode.getOpcodeName(with: opcode)
            }
        } else {
            var string: String
            guard let data = pushData, !data.isEmpty else {
                return "OP_0" // Empty data is encoded as OP_0.
            }
            if isASCIIData(data: data) {
                string = "" // ToDo
            } else {
                string = data.hex

                // Shorter than 128-bit chunks are wrapped in square brackets to avoid ambiguity with big all-decimal numbers.
                if data.count < 16 {
                    string = "[\(string)]"
                }
            }
            // Non-compact data is prefixed with an appropriate length prefix.
            if !isDataCompact {
                var prefix = 1
                if opcode == Opcode.OP_PUSHDATA2 {
                    prefix = 2
                } else if opcode == Opcode.OP_PUSHDATA4 {
                    prefix = 4
                }
                string = String(prefix) + ":" + string
            }
            return string
        }
    }

    private func isASCIIData(data: Data) -> Bool {
        for i in 0...data.count {
            let ch = data[i]
            if !(ch >= 0x20 && ch <= 0x7E) {
                return false
            }
        }
        return true
    }

    // If encoding is -1, then the most compact will be chosen.
    // Valid values: -1, 0, 1, 2, 4.
    // Returns nil if preferredLengthEncoding can't be used for data, or data is nil or too big.
    public func scriptDataForPushdata(data: Data?, preferredLengthEncoding: Int) -> Data? {
        guard data != nil else {
            return nil
        }
        return scriptData   // ToDo
    }

//    + (BTCScriptChunk*) parseChunkFromData:(NSData*)scriptData offset:(NSUInteger)offset {
    public static func parseChunkFromData(scriptData: Data, offset: Int) -> ScriptChunk? {
//    // Data should fit at least one opcode.
//    if (scriptData.length < (offset + 1)) return nil;
        guard scriptData.count >= (offset + 1) else {
            return nil
        }
//
//    const uint8_t* bytes = ((const uint8_t*)[scriptData bytes]);
//    BTCOpcode opcode = bytes[offset];
        let opcode = scriptData[offset]

//        if (opcode <= OP_PUSHDATA4) {
//            // push data opcode
//            int length = (int)scriptData.length;
//
//            BTCScriptChunk* chunk = [[BTCScriptChunk alloc] init];
//            chunk.scriptData = scriptData;
        if opcode <= Opcode.OP_PUSHDATA4 {
            let count = scriptData.count

            var chunk: ScriptChunk = ScriptChunk(scriptData: scriptData)

//            if (opcode < OP_PUSHDATA1) {
//                uint8_t dataLength = opcode;
//                NSUInteger chunkLength = sizeof(opcode) + dataLength;
//
//                if (offset + chunkLength > length) return nil;
//
//                chunk.range = NSMakeRange(offset, chunkLength);
//            }
            if opcode < Opcode.OP_PUSHDATA1 {
                let dataLength = opcode
                let chunkLength = MemoryLayout.size(ofValue: opcode) + Int(dataLength)

                guard offset + chunkLength <= count else {
                    return nil
                }
                chunk.range = Range(offset...(offset + chunkLength - 1))

//                else if (opcode == OP_PUSHDATA1) {
//                    uint8_t dataLength;
//
//                    if (offset + sizeof(dataLength) > length) return nil;
//
//                    memcpy(&dataLength, bytes + offset + sizeof(opcode), sizeof(dataLength));
//
//                    NSUInteger chunkLength = sizeof(opcode) + sizeof(dataLength) + dataLength;
//
//                    if (offset + chunkLength > length) return nil;
//
//                    chunk.range = NSMakeRange(offset, chunkLength);
//                }
            } else if opcode == Opcode.OP_PUSHDATA1 {
                var dataLength = UInt8()
                guard offset + MemoryLayout.size(ofValue: dataLength) <= count else {
                    return nil
                }
                _ = scriptData.withUnsafeBytes {
                    memcpy(&dataLength, $0 + offset + MemoryLayout.size(ofValue: opcode), MemoryLayout.size(ofValue: dataLength))
                }
                let chunkLength = MemoryLayout.size(ofValue: opcode) + MemoryLayout.size(ofValue: dataLength) + Int(dataLength)
                guard offset + chunkLength <= count else {
                    return nil
                }
                chunk.range = Range(offset...(offset + chunkLength - 1))
            } else if opcode == Opcode.OP_PUSHDATA2 {
                var dataLength = UInt16()
                guard offset + MemoryLayout.size(ofValue: dataLength) <= count else {
                    return nil
                }
                _ = scriptData.withUnsafeBytes {
                    memcpy(&dataLength, $0 + offset + MemoryLayout.size(ofValue: opcode), MemoryLayout.size(ofValue: dataLength))
                }
                dataLength = CFSwapInt16LittleToHost(dataLength)
                let chunkLength = MemoryLayout.size(ofValue: opcode) + MemoryLayout.size(ofValue: dataLength) + Int(dataLength)
                guard offset + chunkLength <= count else {
                    return nil
                }
                chunk.range = Range(offset...(offset + chunkLength - 1))
            } else if opcode == Opcode.OP_PUSHDATA4 {
                var dataLength = UInt32()
                guard offset + MemoryLayout.size(ofValue: dataLength) <= count else {
                    return nil
                }
                _ = scriptData.withUnsafeBytes {
                    memcpy(&dataLength, $0 + offset + MemoryLayout.size(ofValue: opcode), MemoryLayout.size(ofValue: dataLength))
                }
                // QUESTION: dataLength = CFSwapInt16LittleToHost(dataLength)になっているがInt32の間違い？
                dataLength = CFSwapInt32LittleToHost(dataLength)
                let chunkLength = MemoryLayout.size(ofValue: opcode) + MemoryLayout.size(ofValue: dataLength) + Int(dataLength)
                guard offset + chunkLength <= count else {
                    return nil
                }
                chunk.range = Range(offset...(offset + chunkLength - 1))
            }
            return chunk

//        else {
//            // simple opcode
//            BTCScriptChunk* chunk = [[BTCScriptChunk alloc] init];
//            chunk.scriptData = scriptData;
//            chunk.range = NSMakeRange(offset, sizeof(opcode));
//            return chunk;
//        }
        } else {
            let chunk = ScriptChunk(scriptData: scriptData, range: Range(offset...offset + MemoryLayout.size(ofValue: opcode) - 1))
            return chunk
        }
    }

    public static func parseChunkFromData2(scriptData: Data, offset: Int) -> ScriptChunk? {
        // Data should fit at least one opcode.
        guard scriptData.count >= (offset + 1) else {
            return nil
        }

        let opcode = scriptData[offset]

        if opcode <= Opcode.OP_PUSHDATA4 {
            // push data opcode
            let count = scriptData.count
            var chunk: ScriptChunk = ScriptChunk(scriptData: scriptData)

            if opcode < Opcode.OP_PUSHDATA1 {
                let dataLength = opcode
                let chunkLength = MemoryLayout.size(ofValue: opcode) + Int(dataLength)

                guard (offset + chunkLength) <= count else {
                    return nil
                }
                chunk.range = Range(offset...(offset + chunkLength))
            } else if opcode == Opcode.OP_PUSHDATA1 {
                let dataLength: UInt8
//                guard (offset + MemoryLayout.size(ofValue: dataLength) <= count) else {
//                    return nil
//                }
                //dataLength =
            }
            return chunk
        } else {
            // simple opcode
            let range = Range(offset...(offset + MemoryLayout.size(ofValue: opcode)))
            return ScriptChunk(scriptData: scriptData, range: range)
        }
    }

    internal func copy() -> ScriptChunk {
        return ScriptChunk(scriptData: scriptData, range: range)
    }
}
