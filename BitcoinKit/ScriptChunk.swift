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
        self.range = Range(-1...0) // ToDo: 適当な値を入れたい。
    }

    init(scriptData: Data, range: Range<Int>) {
        self.scriptData = scriptData
        self.range = range
    }

//     Operation to be executed.
//    - (BTCOpcode) opcode {
//    return (BTCOpcode)((const unsigned char*)_scriptData.bytes)[_range.location];
//    }
    public var opcode: UInt8 {
        return UInt8(scriptData[range.lowerBound])
    }

//    - (BOOL) isOpcode {
//    BTCOpcode opcode = [self opcode];
//    // Pushdata opcodes are not considered a single "opcode".
//    // Attention: OP_0 is also "pushdata" code that pushes empty data.
//    if (opcode <= OP_PUSHDATA4) return NO;
//    return YES;
//    }
    public var isOpcode: Bool {
        return opcode > Opcode.OP_PUSHDATA4
    }

//    - (NSData*) chunkData {
//    return [_scriptData subdataWithRange:_range];
//    }
    // Portion of scriptData defined by range.
    public var chunkData: Data {
        return scriptData.subdata(in: range)
    }

//    // Data being pushed. Returns nil if the opcode is not OP_PUSHDATA*.
//    - (NSData*) pushdata {
//    if (self.isOpcode) return nil;
//    BTCOpcode opcode = [self opcode];
//    NSUInteger loc = 1;
//    if (opcode == OP_PUSHDATA1) {
//    loc += 1;
//    } else if (opcode == OP_PUSHDATA2) {
//    loc += 2;
//    } else if (opcode == OP_PUSHDATA4) {
//    loc += 4;
//    }
//    return [_scriptData subdataWithRange:NSMakeRange(_range.location + loc, _range.length - loc)];
//    }
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

//    // Returns YES if the data is represented with the most compact opcode.
//    - (BOOL) isDataCompact {
//    if (self.isOpcode) return NO;
//    BTCOpcode opcode = [self opcode];
//    NSData* data = [self pushdata];
//    if (opcode < OP_PUSHDATA1) return YES; // length fits in one byte under OP_PUSHDATA1.
//    if (opcode == OP_PUSHDATA1) return data.length >= OP_PUSHDATA1; // length should be less than OP_PUSHDATA1
//    if (opcode == OP_PUSHDATA2) return data.length > 0xff; // length should not fit in one byte
//    if (opcode == OP_PUSHDATA4) return data.length > 0xffff; // length should not fit in two bytes
//    return NO;
//    }
    public var isDataCompact: Bool {
        guard !isOpcode else {
            return false
        }
        guard let data = pushData else {
            return false
        }
        switch opcode {
        case ...Opcode.OP_PUSHDATA1:
            return true
        case Opcode.OP_PUSHDATA1:
            return data.count >= Opcode.OP_PUSHDATA1
        case Opcode.OP_PUSHDATA2:
            return data.count > (0xff)
        case Opcode.OP_PUSHDATA4:
            return data.count > (0xffff)
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
//        if (self.isOpcode) {
//            if (opcode == OP_0) return @"OP_0";
//            if (opcode == OP_1NEGATE) return @"OP_1NEGATE";
//            if (opcode >= OP_1 && opcode <= OP_16) {
//                return [NSString stringWithFormat:@"OP_%u", ((int)opcode + 1 - (int)OP_1)];
//            } else {
//                return BTCNameForOpcode(opcode);
//            }
//        }
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

//        else {
//            NSData* data = [self pushdata];
//
//            NSString* string = nil;
//            // Empty data is encoded as OP_0.
//            if (data.length == 0) {
//                string = @"OP_0";
//            } else if ([self isASCIIData:data]) {
//                string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
//
//                // Escape escapes & single quote characters.
//                string = [string stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
//                string = [string stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
//
//                // Wrap in single quotes. Why not double? Because they are already used in JSON and we don't want to multiply the mess.
//                string = [NSString stringWithFormat:@"'%@'", string];
//            }
        } else {
            var string: String
            guard let data = pushData, !data.isEmpty else {
                return "OP_0" // Empty data is encoded as OP_0.
            }

            if isASCIIData(data: data) {
                string = String(data: data, encoding: String.Encoding.ascii)!
                string = string.replacingOccurrences(of: "\\", with: "\\\\")
                string = string.replacingOccurrences(of: "'", with: "\\'")
                string = "'" + string + "'"

//            else {
//                string = BTCHexFromData(data);
//
//                // Shorter than 128-bit chunks are wrapped in square brackets to avoid ambiguity with big all-decimal numbers.
//                if (data.length < 16) {
//                    string = [NSString stringWithFormat:@"[%@]", string];
//                }
//            }
            } else {
                string = data.hex

                if data.count < 16 {
                    string = "[\(string)]"
                }
            }

//            // Non-compact data is prefixed with an appropriate length prefix.
//            if (![self isDataCompact]) {
//                int prefix = 1;
//                if (opcode == OP_PUSHDATA2) prefix = 2;
//                if (opcode == OP_PUSHDATA4) prefix = 4;
//                string = [NSString stringWithFormat:@"%d:%@", prefix, string];
//            }
//            return string;
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

//    - (BOOL) isASCIIData:(NSData*)data {
//    BOOL isASCII = YES;
//    for (int i = 0; i < data.length; i++) {
//    char ch = ((const char*)data.bytes)[i];
//    if (!(ch >= 0x20 && ch <= 0x7E)) {
//    isASCII = NO;
//    break;
//    }
//    }
//    return isASCII;
//    }
    private func isASCIIData(data: Data) -> Bool {
        for ch in data {
            if !(ch >= 0x20 && ch <= 0x7E) {
                return false
            }
        }
        return true
    }

    // If encoding is -1, then the most compact will be chosen.
    // Valid values: -1, 0, 1, 2, 4.
    // Returns nil if preferredLengthEncoding can't be used for data, or data is nil or too big.
//    + (NSData*) scriptDataForPushdata:(NSData*)data preferredLengthEncoding:(int)preferredLengthEncoding {
    public static func scriptDataForPushdata(data: Data?, preferredLengthEncoding: Int) -> Data? {
//        if (!data) return nil;
        guard let data = data else {
            return nil
        }
//        NSMutableData* scriptData = [NSMutableData data];
        var scriptData = Data()

//        if (data.length < OP_PUSHDATA1 && preferredLengthEncoding <= 0) {
//            uint8_t len = data.length;
//            [scriptData appendBytes:&len length:sizeof(len)];
//            [scriptData appendData:data];
//        }
        if data.count < Opcode.OP_PUSHDATA1 && preferredLengthEncoding <= 0 {
            let count = data.count
            scriptData += count
            scriptData += data

//        else if (data.length <= 0xff && (preferredLengthEncoding == -1 || preferredLengthEncoding == 1)) {
//            uint8_t op = OP_PUSHDATA1;
//            uint8_t len = data.length;
//            [scriptData appendBytes:&op length:sizeof(op)];
//            [scriptData appendBytes:&len length:sizeof(len)];
//            [scriptData appendData:data];
//        }
        } else if data.count <= (0xff) && (preferredLengthEncoding == -1 || preferredLengthEncoding == 1) {
            let opcode = Opcode.OP_PUSHDATA1
            let count = data.count
            scriptData += opcode
            scriptData += count
            scriptData += data
        } else if data.count <= (0xffff) && (preferredLengthEncoding == -1 || preferredLengthEncoding == 2) {
            let opcode = Opcode.OP_PUSHDATA2
            let count = data.count
            scriptData += opcode
            scriptData += count
            scriptData += data
            // QESTION: (unsigned long long)data.length <= 0xffffffffull は以下のような変換で良いのか
        } else if CUnsignedLong(data.count) <= 0xffffffff && (preferredLengthEncoding == -1 || preferredLengthEncoding == 4) {
            let opcode = Opcode.OP_PUSHDATA4
            let count = data.count
            scriptData += opcode
            scriptData += count
            scriptData += data
        } else {
            // Invalid preferredLength encoding or data size is too big.
            return nil
        }
        return scriptData
    }

//    + (BTCScriptChunk*) parseChunkFromData:(NSData*)scriptData offset:(NSUInteger)offset {
    // swiftlint:disable:next cyclomatic_complexity
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

    internal func copy() -> ScriptChunk {
        return ScriptChunk(scriptData: scriptData, range: range)
    }
}
