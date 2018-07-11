//
//  ScriptTests.swift
//  BitcoinKitTests
//
//  Created by Akifumi Fujita on 2018/07/11.
//  Copyright © 2018年 Kishikawa Katsumi. All rights reserved.
//

import XCTest
@testable import BitcoinKit

class ScriptTests: XCTestCase {
    
//    + (void) testBinarySerialization {
//    // Empty script
//    {
//    NSAssert([[[BTCScript alloc] init].data isEqual:[NSData data]], @"Default script should be empty.");
//    NSAssert([[[BTCScript alloc] initWithData:[NSData data]].data isEqual:[NSData data]], @"Empty script should be empty.");
//    }
//
//    }
    func testBinarySerialization() {
        XCTAssertEqual(Script().data, Data())
        XCTAssertEqual(Script(data: Data()).data, Data())
    }
    
//    + (void) testStringSerialization {
//    //NSLog(@"tx = %@", BTCHexFromData(BTCReversedData(BTCDataFromHex(@"..."))));
//
//    NSData* yrashkScript = BTCDataFromHex(@"52210391e4786b4c7637c160247ad6d5702d9bb2860cbb8130d59b0fd9808a0220d50f2102e191fcff2849099988fbe1592b6788707a61401058c09ef97363c9d96c43a0cf21027f10a51295e8e96d5957f3665168426249a006e548e48cbfa5882d2bf89ab67e2103d39801bafef0cc3c211101a54a47874c0a835efa2c17c47ebbe380c803345a2354ae");
//
//    BTCScript* script = [[BTCScript alloc] initWithData:yrashkScript];
//
//    NSAssert(script, @"sanity check");
//    //NSLog(@"Script: %@", script);
//    }
    func testStringSerialization() {
        let yrashkScript: Data = Data(hex: "52210391e4786b4c7637c160247ad6d5702d9bb2860cbb8130d59b0fd9808a0220d50f2102e191fcff2849099988fbe1592b6788707a61401058c09ef97363c9d96c43a0cf21027f10a51295e8e96d5957f3665168426249a006e548e48cbfa5882d2bf89ab67e2103d39801bafef0cc3c211101a54a47874c0a835efa2c17c47ebbe380c803345a2354ae")!
        let script = Script(data: yrashkScript)
        XCTAssertNotNil(script)
    }
    
    func testStandardScript() {
        let script = Script(data: Data(hex: "76a9147ab89f9fae3f8043dcee5f7b5467a0f0a6e2f7e188ac")!)
        XCTAssertTrue(script.isPayToPublicKeyHashScript)
        
        let address = try! AddressFactory.create("1CBtcGivXmHQ8ZqdPgeMfcpQNJrqTrSAcG")
        let script2 = Script(address: address)
        XCTAssertEqual(script2!.data, script.data)
        XCTAssertEqual(script2!.string, script.string)
    }
}
