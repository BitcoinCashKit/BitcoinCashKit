//
//  Script.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/01/30.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

public struct Script2 {
    public let chunks: [ScriptChunk] // An array of NSData objects (pushing data) or NSNumber objects (containing opcodes)
    public let data: Data // Cached serialized representations for -data and -string methods.

    init(chunks: [ScriptChunk]) {
        self.chunks = chunks
        self.data = Data()
    }

    init(data: Data) throws {
        // It's important to keep around original data to correctly identify the size of the script for BTC_MAX_SCRIPT_SIZE check
        // and to correctly calculate hash for the signature because in BitcoinQT scripts are not re-serialized/canonicalized.
        guard let chunks = Script2.parseData(data) else {
            throw ScriptError.invalid
        }
        self.data = data
        self.chunks = chunks
    }

    init(hex: String) throws {
        try self.init(data: Data(hex: hex)!)
    }

    init(string: String) throws {
        guard let chunks = Script2.parseString(string) else {
            throw ScriptError.invalid
        }
        self.init(chunks: chunks)
    }

    private static func parseData(_ data: Data) -> [ScriptChunk]? {
        return nil
    }

    private static func parseString(_ string: String) -> [ScriptError]? {
        return nil
    }
}

public enum ScriptError: Error {
    case invalid
}

public struct Script {
    // Opcode
    public static let OP_DUP: UInt8 = 0x76
    public static let OP_HASH160: UInt8 = 0xa9
    public static let OP_0: UInt8 = 0x14
    public static let OP_EQUALVERIFY: UInt8 = 0x88
    public static let OP_CHECKSIG: UInt8 = 0xac

    // Standard Transaction to Bitcoin address (pay-to-pubkey-hash)
    // scriptPubKey: OP_DUP OP_HASH160 OP_0 <pubKeyHash> OP_EQUALVERIFY OP_CHECKSIG
    public static func buildPublicKeyHashOut(pubKeyHash: Data) -> Data {
        let tmp: Data = Data() + OP_DUP + OP_HASH160 + OP_0 + pubKeyHash + OP_EQUALVERIFY
        return tmp + OP_CHECKSIG
    }

    public static func isPublicKeyHashOut(_ script: Data) -> Bool {
        return script.count == 25 &&
            script[0] == OP_DUP && script[1] == OP_HASH160 && script[2] == OP_0 &&
            script[23] == OP_EQUALVERIFY && script[24] == OP_CHECKSIG
    }

    public static func getPublicKeyHash(from script: Data) -> Data {
        return script[3..<23]
    }
}
