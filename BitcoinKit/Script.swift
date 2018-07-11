//
//  Script.swift
//  BitcoinKit
//
//  Created by Kishikawa Katsumi on 2018/01/30.
//  Copyright © 2018 Kishikawa Katsumi. All rights reserved.
//

import Foundation

public class Script {
    public let chunks: [ScriptChunk] // An array of NSData objects (pushing data) or NSNumber objects (containing opcodes)

    // Cached serialized representations for -data and -string methods.
    //    - (NSData*) data {
    //    if (!_data) {
    //    // When we calculate data from scratch, it's important to respect actual offsets in the chunks as they may have been copied or shifted in subScript* methods.
    //    NSMutableData* md = [NSMutableData data];
    //    for (BTCScriptChunk* chunk in _chunks) {
    //    [md appendData:chunk.chunkData];
    //    }
    //    _data = md;
    //    }
    //    return _data;
    //    }
    // ToDo: キャッシュしたい
    public var data: Data {
        var md = Data()
        for chunk in self.chunks {
            md += chunk.chunkData
        }
        return md
    }

    public var multisigSignaturesRequired: Int? // Multisignature script attributes.
    public var multisigPublicKeys: [PublicKey]? // If multisig script is not detected, both are NULL.

    init() {
        self.chunks = [ScriptChunk]()
    }

    init(chunks: [ScriptChunk]) {
        self.chunks = chunks
    }

     convenience init(data: Data) {
        // It's important to keep around original data to correctly identify the size of the script for BTC_MAX_SCRIPT_SIZE check
        // and to correctly calculate hash for the signature because in BitcoinQT scripts are not re-serialized/canonicalized.
        guard let chunks = Script.parseData(data) else {
            self.init()
            return
        }
        self.init(chunks: chunks)
    }

    convenience init?(hex: String) {
        self.init(data: Data(hex: hex)!)
    }

    convenience init?(string: String) {
        guard let chunks = Script.parseString(string) else {
            return nil
        }
        self.init(chunks: chunks)
    }

    convenience init?(address: Address) {
//        if ([address isKindOfClass:[BTCPublicKeyAddress class]]) {
//            // OP_DUP OP_HASH160 <hash> OP_EQUALVERIFY OP_CHECKSIG
//            NSMutableData* resultData = [NSMutableData data];
//
//            BTCOpcode prefix[] = {OP_DUP, OP_HASH160};
//            [resultData appendBytes:prefix length:sizeof(prefix)];
//
//            unsigned char length = address.data.length;
//            [resultData appendBytes:&length length:sizeof(length)];
//
//            [resultData appendData:address.data];
//
//            BTCOpcode suffix[] = {OP_EQUALVERIFY, OP_CHECKSIG};
//            [resultData append Bytes:suffix length:sizeof(suffix)];
//
//            return [self initWithData:resultData];
//        }
        if address.type == .pubkeyHash {
            var resultData: Data = Data()

            resultData += Opcode.OP_DUP
            resultData += Opcode.OP_HASH160

            let length = VarInt(address.data.count)
            resultData += length.serialized()
            resultData += address.data

            resultData += Opcode.OP_EQUALVERIFY
            resultData += Opcode.OP_CHECKSIG
            self.init(data: resultData)

        } else if address.type == .scriptHash {
            var resultData: Data = Data()

            resultData += Opcode.OP_HASH160

            let length = VarInt(address.data.count)
            resultData += length.serialized()
            resultData += address.data

            resultData += Opcode.OP_EQUAL

            self.init(data: resultData)
        } else {
            return nil
        }
    }

//    // OP_<M> <pubkey1> ... <pubkeyN> OP_<N> OP_CHECKMULTISIG
//    - (id) initWithPublicKeys:(NSArray*)publicKeys signaturesRequired:(NSUInteger)signaturesRequired {
    convenience init?(publicKeys: [PublicKey], signaturesRequired: Int) {
//        // First make sure the arguments make sense.
//
//        // We need at least one signature
//        if (signaturesRequired == 0) return nil;
        guard signaturesRequired > 0 else {
            return nil
        }
//
//        // And we cannot have more signatures than available pubkeys.
//        if (signaturesRequired > publicKeys.count) return nil;
        guard publicKeys.count > signaturesRequired else {
            return nil
        }
//
//        // Both M and N should map to OP_<1..16>
//        BTCOpcode m_opcode = BTCOpcodeForSmallInteger(signaturesRequired);
//        BTCOpcode n_opcode = BTCOpcodeForSmallInteger(publicKeys.count);
//        if (m_opcode == OP_INVALIDOPCODE) return nil;
//        if (n_opcode == OP_INVALIDOPCODE) return nil;
        let m_opcode: UInt8 = Opcode.opcodeForSmallInteger(smallInteger: signaturesRequired)
        let n_opcode: UInt8 = Opcode.opcodeForSmallInteger(smallInteger: publicKeys.count)

        guard m_opcode != Opcode.OP_INVALIDOPCODE && n_opcode != Opcode.OP_INVALIDOPCODE else {
            return nil
        }

//        // Every pubkey should be present.
//        for (NSData* pkdata in publicKeys) {
//            if (![pkdata isKindOfClass:[NSData class]] || pkdata.length == 0) return nil;
//        }
//        for pubkey in publicKeys {
//            guard !pubkey.raw.isEmpty else {
//                return nil
//            }
//        }

//
//        NSMutableData* data = [NSMutableData data];
//
//        [data appendBytes:&m_opcode length:sizeof(m_opcode)];
        var data: Data = Data()
        data += m_opcode
//
//        for (NSData* pubkey in publicKeys) {
//            NSData* d = [BTCScriptChunk scriptDataForPushdata:pubkey preferredLengthEncoding:-1];
//
//            if (d.length == 0) return nil; // invalid data
//
//            [data appendData:d];
//        }
        for pubkey in publicKeys {
            //let d: Data = ScriptChunk.scriptDataForPushdata(for pushdata: pubkey, preferredLengthEncoding: -1)
            let d = Data()
            guard !d.isEmpty else {
                return nil
            }
            data += d
        }

//        [data appendBytes:&n_opcode length:sizeof(n_opcode)];
//
//        BTCOpcode checkmultisig_opcode = OP_CHECKMULTISIG;
//        [data appendBytes:&checkmultisig_opcode length:sizeof(checkmultisig_opcode)];
        data += n_opcode
        data += Opcode.OP_CHECKMULTISIG

//
//        if (self = [self initWithData:data]) {
//            _multisigSignaturesRequired = signaturesRequired;
//            _multisigPublicKeys = publicKeys;
//        }
//        return self;

        self.init(data: data)
        self.multisigSignaturesRequired = signaturesRequired
        self.multisigPublicKeys = publicKeys
    }

//    - (NSString*) hex {
//    return BTCHexFromData(self.data);
//    }
    public var hex: String {
        return self.data.hex
    }

//    - (NSString*) string {
//    if (!_string) {
//    NSMutableArray* buffer = [NSMutableArray array];
//
//    for (BTCScriptChunk* chunk in _chunks) {
//    [buffer addObject:[chunk string]];
//    }
//
//    _string = [buffer componentsJoinedByString:@" "];
//    }
//    return _string;
//    }
    // キャッシュしたい
    public var string: String {
        var buffer = [String]()
        for chunk in self.chunks {
            if let string = chunk.string {
                buffer.append(string)
            }
        }
        return buffer.joined()
    }

//    - (NSMutableArray*) parseData:(NSData*)data {
    private static func parseData(_ data: Data) -> [ScriptChunk]? {
//    if (data.length == 0) return [NSMutableArray array];
        guard !data.isEmpty else {
            return nil
        }
//
//    NSMutableArray* chunks = [NSMutableArray array];
        var chunks = [ScriptChunk]()
//
//    int i = 0;
//    int length = (int)data.length;
        var i = 0
        let count = data.count
//
//    while (i < length) {
//    BTCScriptChunk* chunk = [BTCScriptChunk parseChunkFromData:data offset:i];
//
//    // Exit if failed to parse
//    if (!chunk) return nil;
//
//    [chunks addObject:chunk];
//
//    i += chunk.range.length;
//    }
//    return chunks;
//    }
        while i < count {
            guard let chunk = ScriptChunk.parseChunkFromData(scriptData: data, offset: i) else {
                return nil
            }
            chunks.append(chunk)

            i += chunk.range.count
        }
        return chunks
    }

    // ToDo: not implemented
    private static func parseString(_ string: String) -> [ScriptChunk]? {
        return nil
    }

//    - (BOOL) isStandard {
//    return [self isPayToPublicKeyHashScript]
//    || [self isPayToScriptHashScript]
//    || [self isPublicKeyScript]
//    || [self isStandardMultisignatureScript];
//    }
    public var isStandard: Bool {
        return isPayToPublicKeyHashScript
            || isPayToScriptHashScript
            || isPublicKeyScript
            || isStandardMultisignatureScript
    }

//    - (BOOL) isPublicKeyScript {
//    if (_chunks.count != 2) return NO;
//    return [self pushdataAtIndex:0].length > 1
//    && [self opcodeAtIndex:1] == OP_CHECKSIG;
//    }
    public var isPublicKeyScript: Bool {
        guard chunks.count == 2 else {
            return false
        }
        guard let pushdata = pushdata(at: 0) else {
            return false
        }
        return pushdata.count > 1 && opcode(at: 1) == Opcode.OP_CHECKSIG
    }

//    - (BOOL) isHash160Script {
//    return [self isPayToPublicKeyHashScript];
//    }
    public var isHash160Script: Bool {
        return isPayToPublicKeyHashScript
    }

//    - (BOOL) isPayToPublicKeyHashScript {
//    if (_chunks.count != 5) return NO;
//
//    BTCScriptChunk* dataChunk = [self chunkAtIndex:2];
//
//    return [self opcodeAtIndex:0] == OP_DUP
//    && [self opcodeAtIndex:1] == OP_HASH160
//    && !dataChunk.isOpcode
//    && dataChunk.range.length == 21
//    && [self opcodeAtIndex:3] == OP_EQUALVERIFY
//    && [self opcodeAtIndex:4] == OP_CHECKSIG;
//    }
    public var isPayToPublicKeyHashScript: Bool {
        guard chunks.count == 5 else {
            return false
        }
        let dataChunk = chunk(at: 2)
        return opcode(at: 0) == Opcode.OP_DUP
            && opcode(at: 1) == Opcode.OP_HASH160
            && !dataChunk.isOpcode
            && dataChunk.range.count == 21
            && opcode(at: 3) == Opcode.OP_EQUALVERIFY
            && opcode(at: 4) == Opcode.OP_CHECKSIG
    }

//    - (BOOL) isPayToScriptHashScript {
//    // TODO: check against the original serialized form instead of parsed chunks because BIP16 defines
//    // P2SH script as an exact byte template. Scripts using OP_PUSHDATA1/2/4 are not valid P2SH scripts.
//    // To do that we have to maintain original script binary data and each chunk should keep a range in that data.
//
//    if (_chunks.count != 3) return NO;
//
//    BTCScriptChunk* dataChunk = [self chunkAtIndex:1];
//
//    return [self opcodeAtIndex:0] == OP_HASH160
//    && !dataChunk.isOpcode
//    && dataChunk.range.length == 21          // this is enough to match the exact byte template, any other encoding will be larger.
//    && [self opcodeAtIndex:2] == OP_EQUAL;
//    }
    public var isPayToScriptHashScript: Bool {
        guard chunks.count == 3 else {
            return false
        }
        let dataChunk = chunk(at: 1)
        return opcode(at: 0) == Opcode.OP_HASH160
            && !dataChunk.isOpcode
            && dataChunk.range.count == 21
            && opcode(at: 2) == Opcode.OP_EQUAL
    }

//    // Returns YES if the script ends with P2SH check.
//    // Not used in CoreBitcoin. Similar code is used in bitcoin-ruby. I don't know if we'll ever need it.
//    - (BOOL) endsWithPayToScriptHash {
//    if (_chunks.count < 3) return NO;
//
//    return [self opcodeAtIndex:-3] == OP_HASH160
//    && [self pushdataAtIndex:-2].length == 20
//    && [self opcodeAtIndex:-1] == OP_EQUAL;
//    }
    public var endsWithPayToScriptHash: Bool {
        guard chunks.count >= 3 else {
            return false
        }
        return opcode(at: -3) == Opcode.OP_HASH160
            && pushdata(at: -2)?.count == 20
            && opcode(at: -1) == Opcode.OP_EQUAL
    }

//    - (BOOL) isStandardMultisignatureScript {
//    if (![self isMultisignatureScript]) return NO;
//    return _multisigPublicKeys.count <= 3;
//    }
    public var isStandardMultisignatureScript: Bool {
        guard isMultisignatureScript else {
            return false
        }
        guard let multisigPublicKeys = multisigPublicKeys else {
            return false
        }
        return multisigPublicKeys.count <= 3
    }

//    - (BOOL) isMultisignatureScript {
//    if (_multisigSignaturesRequired == 0) {
//    [self detectMultisigScript];
//    }
//    return _multisigSignaturesRequired > 0;
//    }
    public var isMultisignatureScript: Bool {
        if multisigSignaturesRequired == 0 {
            detectMultisigScript()
        }
        guard let multisigSignaturesRequired = multisigSignaturesRequired else {
            return false
        }
        return multisigSignaturesRequired > 0
    }

//    // If typical multisig tx is detected, sets two ivars:
//    // _multisigSignaturesRequired, _multisigPublicKeys.
//    - (void) detectMultisigScript {
    private func detectMultisigScript() {
//    // multisig script must have at least 4 ops ("OP_1 <pubkey> OP_1 OP_CHECKMULTISIG")
//    if (_chunks.count < 4) return;
        guard chunks.count >= 4 else {
            return
        }
//
//    // The last op is multisig check.
//    if ([self opcodeAtIndex:-1] != OP_CHECKMULTISIG) return;
        guard opcode(at: -1) == Opcode.OP_CHECKMULTISIG else {
            return
        }
//
//    BTCOpcode m_opcode = [self opcodeAtIndex:0];
//    BTCOpcode n_opcode = [self opcodeAtIndex:-2];
        let m_opcode: UInt8 = opcode(at: 0)
        let n_opcode: UInt8 = opcode(at: -2)
//
//    NSInteger m = BTCSmallIntegerFromOpcode(m_opcode);
//    NSInteger n = BTCSmallIntegerFromOpcode(n_opcode);
//    if (m <= 0 || m == NSIntegerMax) return;
//    if (n <= 0 || n == NSIntegerMax || n < m) return;
        let m: Int = Opcode.smallIntegerFromOpcode(opcode: m_opcode)
        let n: Int = Opcode.smallIntegerFromOpcode(opcode: n_opcode)
        guard m > 0 && m != LONG_MAX else { // QUESTION: NSIntegerMaxはLONG_MAXで良いのか？
            return
        }
        guard n > 0 && n != LONG_MAX && n >= m else { // QUESTION: NSIntegerMaxはLONG_MAXで良いのか？
            return
        }
//
//    // We must have correct number of pubkeys in the script. 3 extra ops: OP_<M>, OP_<N> and OP_CHECKMULTISIG
//    if (_chunks.count != (3 + n)) return;
        guard chunks.count == 3 + n else {
            return
        }
//
//    NSMutableArray* list = [NSMutableArray array];
//    for (int i = 1; i <= n; i++) {
//    NSData* data = [self pushdataAtIndex:i];
//    if (!data) return;
//    [list addObject:data];
//    }
        var list: Data = Data()
        for i in 0...n {
            guard let data = pushdata(at: i) else {
                return
            }
            list += data
        }
//
//    // Now we extracted all pubkeys and verified the numbers.
//    _multisigSignaturesRequired = m;
//    _multisigPublicKeys = list;
//    }
        self.multisigSignaturesRequired = m
        // self.multisigPublicKeys = list // ToDo: multisigPublicKeysが[PublicKey]なので、Dataをキャスト出来ない
    }

//    - (BOOL) isDataOnly {
//    // Include both PUSHDATA ops and OP_0..OP_16 literals.
//    for (BTCScriptChunk* chunk in _chunks) {
//    if (chunk.opcode > OP_16) {
//    return NO;
//    }
//    }
//    return YES;
//    }
    public var isDataOnly: Bool {
        for chunk in chunks {
            if chunk.opcode > Opcode.OP_16 {
                return false
            }
        }
        return true
    }

//    - (NSArray*) scriptChunks {
//    return [_chunks copy];
//    }
    public var scriptChunks: [ScriptChunk] {
        return chunks.map { $0.copy() }
    }

//    - (void) enumerateOperations:(void(^)(NSUInteger opIndex, BTCOpcode opcode, NSData* pushdata, BOOL* stop))block {
//    if (!block) return;
//
//    NSUInteger opIndex = 0;
//    for (BTCScriptChunk* chunk in _chunks) {
//    if (chunk.isOpcode) {
//    BTCOpcode opcode = chunk.opcode;
//    BOOL stop = NO;
//    block(opIndex, opcode, nil, &stop);
//    if (stop) return;
//    } else {
//    NSData* data = chunk.pushdata;
//    BOOL stop = NO;
//    block(opIndex, OP_INVALIDOPCODE, data, &stop);
//    if (stop) return;
//    }
//    opIndex++;
//    }
//    }
    // blockでstopの値を変更しているので、blockの返り値で新しいstopの値を取るようにしています
    public func enumerateOperations(block: ((_ opIndex: Int, _ opcode: UInt8, _ pushData: Data?, _ stop: Bool) -> Bool)?) {
        guard let block = block else {
            return
        }
        var opIndex = 0
        for chunk in chunks {
            if chunk.isOpcode {
                let opcode = chunk.opcode
                let stop = false
                if block(opIndex, opcode, nil, stop) {
                    return
                }
            } else {
                let data = chunk.pushData
                let stop = false
                if block(opIndex, Opcode.OP_INVALIDOPCODE, data, stop) {
                    return
                }
            }
            opIndex += 1
        }
    }

//    - (BTCAddress*) standardAddress {
//    if ([self isPayToPublicKeyHashScript]) {
//    if (_chunks.count != 5) return nil;
//
//    BTCScriptChunk* dataChunk = [self chunkAtIndex:2];
//
//    if (!dataChunk.isOpcode && dataChunk.range.length == 21) {
//    return [BTCPublicKeyAddress addressWithData:dataChunk.pushdata];
//    }
//    } else if ([self isPayToScriptHashScript]) {
//    if (_chunks.count != 3) return nil;
//
//    BTCScriptChunk* dataChunk = [self chunkAtIndex:1];
//
//    if (!dataChunk.isOpcode && dataChunk.range.length == 21) {
//    return [BTCScriptHashAddress addressWithData:dataChunk.pushdata];
//    }
//    }
//    return nil;
//    }
    public var standardAddress: Address? {
        if isPayToPublicKeyHashScript {
            guard chunks.count == 5 else {
                return nil
            }
            let dataChunk = chunk(at: 2)

            if !dataChunk.isOpcode && dataChunk.range.count == 21 {
                // return [BTCPublicKeyAddress addressWithData:dataChunk.pushdata];
                // QUESTION: BTCPublicKeyAddressでinitしているけど、dataChunk.pushdataだけではnetworkが分からない

            }
        } else if isPayToScriptHashScript {
            guard chunks.count == 3 else {
                return nil
            }
            let dataChunk = chunk(at: 1)

            if !dataChunk.isOpcode && dataChunk.range.count == 21 {
                // return [BTCScriptHashAddress addressWithData:dataChunk.pushdata];
                // QUESTION: BTCScriptHashAddressでinitしているけど、dataChunk.pushdataだけではnetworkが分からない
            }
        }
        return nil
    }

    // ToDo: BTCScriptHashAddressとBTCScriptHashAddressTestnetというクラスが必要
    // そもそも、そのようなクラスを作るか問題
    /*
    // Wraps the recipient into an output P2SH script (OP_HASH160 <20-byte hash of the recipient> OP_EQUAL).
    - (BTCScript*) scriptHashScript {
    return [[BTCScript alloc] initWithAddress:[self scriptHashAddress]];
    }
    
    // Returns BTCScriptHashAddress that hashes this script.
    // Equivalent to [[script scriptHashScript] standardAddress] or [BTCScriptHashAddress addressWithData:BTCHash160(script.data)]
    - (BTCScriptHashAddress*) scriptHashAddress {
    return [BTCScriptHashAddress addressWithData:BTCHash160(self.data)];
    }
    
    - (BTCScriptHashAddressTestnet*) scriptHashAddressTestnet {
    return [BTCScriptHashAddressTestnet addressWithData:BTCHash160(self.data)];
    }
    */

//    - (BTCScriptChunk*) chunkAtIndex:(NSInteger)index {
//    BTCScriptChunk* chunk = _chunks[index < 0 ? (_chunks.count + index) : index];
//    return chunk;
//    }
    public func chunk(at index: Int) -> ScriptChunk {
        return chunks[index < 0 ? chunks.count + index : index]
    }

//    // Returns an opcode in a chunk.
//    // If the chunk is data, not an opcode, returns OP_INVALIDOPCODE
//    // Raises exception if index is out of bounds.
//    - (BTCOpcode) opcodeAtIndex:(NSInteger)index {
//    BTCScriptChunk* chunk = _chunks[index < 0 ? (_chunks.count + index) : index];
//
//    if (chunk.isOpcode) return chunk.opcode;
//
//    // If the chunk is not actually an opcode, return invalid opcode.
//    return OP_INVALIDOPCODE;
//    }
    public func opcode(at index: Int) -> UInt8 {
        let chunk = chunks[index < 0 ? chunks.count + index : index]
        guard chunk.isOpcode else {
            return Opcode.OP_INVALIDOPCODE
        }
        return chunk.opcode
    }

//    // Returns NSData in a chunk.
//    // If chunk is actually an opcode, returns nil.
//    // Raises exception if index is out of bounds.
//    - (NSData*) pushdataAtIndex:(NSInteger)index {
//    BTCScriptChunk* chunk = _chunks[index < 0 ? (_chunks.count + index) : index];
//
//    if (chunk.isOpcode) return nil;
//
//    return chunk.pushdata;
//    }
    public func pushdata(at index: Int) -> Data? {
        let chunk = chunks[index < 0 ? chunks.count + index : index]
        guard !chunk.isOpcode else {
            return nil
        }
        return chunk.pushData
    }

//    // Returns bignum from pushdata or nil.
//    - (BTCBigNumber*) bignumberAtIndex:(NSInteger)index {
//    NSData* data = [self pushdataAtIndex:index];
//    if (!data) return nil;
//    BTCBigNumber* bn = [[BTCBigNumber alloc] initWithSignedLittleEndian:data];
//    return bn;
//    }
    public func bignumber(at index: Int) -> VarInt? {    // QUESTION: BTCBigNumberに当たるものは何？
        guard let data = pushdata(at: index) else {
            return nil
        }
        return VarInt.deserialize(data)
    }

}

public struct KishikawaScript {
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
