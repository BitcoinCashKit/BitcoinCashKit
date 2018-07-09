//
//  Opcode.swift
//  BitcoinKit
//
//  Created by Akifumi Fujita on 2018/07/09.
//  Copyright © 2018年 Kishikawa Katsumi. All rights reserved.
//

import Foundation

public struct Opcode {

    // 1. Operators pushing data on stack.
    
    // Push 1 byte 0x00 on the stack
    public static let OP_0 = 0x00
    public static let OP_FALSE = OP_0
    
    // Any opcode with value < PUSHDATA1 is a length of the string to be pushed on the stack.
    // So opcode 0x01 is followed by 1 byte of data, 0x09 by 9 bytes and so on up to 0x4b (75 bytes)
    
    // PUSHDATA<N> opcode is followed by N-byte length of the string that follows.
    public static let OP_PUSHDATA1 = 0x4c // followed by a 1-byte length of the string to push (allows pushing 0..255 bytes).
    public static let OP_PUSHDATA2 = 0x4d // followed by a 2-byte length of the string to push (allows pushing 0..65535 bytes).
    public static let OP_PUSHDATA4 = 0x4e // followed by a 4-byte length of the string to push (allows pushing 0..4294967295 bytes).
    public static let OP_1NEGATE   = 0x4f // pushes -1 number on the stack
    public static let OP_RESERVED  = 0x50 // Not assigned. If executed, transaction is invalid.
    
    // public static let OP_<N> pushes number <N> on the stack
    public static let OP_1  = 0x51
    public static let OP_TRUE = OP_1
    public static let OP_2  = 0x52
    public static let OP_3  = 0x53
    public static let OP_4  = 0x54
    public static let OP_5  = 0x55
    public static let OP_6  = 0x56
    public static let OP_7  = 0x57
    public static let OP_8  = 0x58
    public static let OP_9  = 0x59
    public static let OP_10 = 0x5a
    public static let OP_11 = 0x5b
    public static let OP_12 = 0x5c
    public static let OP_13 = 0x5d
    public static let OP_14 = 0x5e
    public static let OP_15 = 0x5f
    public static let OP_16 = 0x60
    
    // 2. Control flow operators
    
    public static let OP_NOP      = 0x61 // Does nothing
    public static let OP_VER      = 0x62 // Not assigned. If executed, transaction is invalid.
    
    // BitcoinQT executes all operators from public static let OP_IF to public static let OP_ENDIF even inside "non-executed" branch (to keep track of nesting).
    // Since public static let OP_VERIF and public static let OP_VERNOTIF are not assigned, even inside a non-executed branch they will fall in "default:" switch case
    // and cause the script to fail. Some other ops like public static let OP_VER can be present inside non-executed branch because they'll be skipped.
    public static let OP_IF       = 0x63 // If the top stack value is not 0, the statements are executed. The top stack value is removed.
    public static let OP_NOTIF    = 0x64 // If the top stack value is 0, the statements are executed. The top stack value is removed.
    public static let OP_VERIF    = 0x65 // Not assigned. Script is invalid with that opcode (even if inside non-executed branch).
    public static let OP_VERNOTIF = 0x66 // Not assigned. Script is invalid with that opcode (even if inside non-executed branch).
    public static let OP_ELSE     = 0x67 // Executes code if the previous public static let OP_IF or public static let OP_NOTIF was not executed.
    public static let OP_ENDIF    = 0x68 // Finishes if/else block
    
    public static let OP_VERIFY   = 0x69 // Removes item from the stack if it's not 0x00 or 0x80 (negative zero). Otherwise, marks script as invalid.
    public static let OP_RETURN   = 0x6a // Marks transaction as invalid.
    
    // Stack ops
    public static let OP_TOALTSTACK   = 0x6b // Moves item from the stack to altstack
    public static let OP_FROMALTSTACK = 0x6c // Moves item from the altstack to stack
    public static let OP_2DROP = 0x6d
    public static let OP_2DUP  = 0x6e
    public static let OP_3DUP  = 0x6f
    public static let OP_2OVER = 0x70
    public static let OP_2ROT  = 0x71
    public static let OP_2SWAP = 0x72
    public static let OP_IFDUP = 0x73
    public static let OP_DEPTH = 0x74
    public static let OP_DROP  = 0x75
    public static let OP_DUP   = 0x76
    public static let OP_NIP   = 0x77
    public static let OP_OVER  = 0x78
    public static let OP_PICK  = 0x79
    public static let OP_ROLL  = 0x7a
    public static let OP_ROT   = 0x7b
    public static let OP_SWAP  = 0x7c
    public static let OP_TUCK  = 0x7d
    
    // Splice ops
    public static let OP_CAT    = 0x7e // Disabled opcode. If executed, transaction is invalid.
    public static let OP_SUBSTR = 0x7f // Disabled opcode. If executed, transaction is invalid.
    public static let OP_LEFT   = 0x80 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_RIGHT  = 0x81 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_SIZE   = 0x82
    
    // Bit logic
    public static let OP_INVERT = 0x83 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_AND    = 0x84 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_OR     = 0x85 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_XOR    = 0x86 // Disabled opcode. If executed, transaction is invalid.
    
    public static let OP_EQUAL = 0x87       // Last two items are removed from the stack and compared. Result (true or false) is pushed to the stack.
    public static let OP_EQUALVERIFY = 0x88 // Same as public static let OP_EQUAL, but removes the result from the stack if it's true or marks script as invalid.
    
    public static let OP_RESERVED1 = 0x89 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_RESERVED2 = 0x8a // Disabled opcode. If executed, transaction is invalid.
    
    // Numeric
    public static let OP_1ADD      = 0x8b // adds 1 to last item, pops it from stack and pushes result.
    public static let OP_1SUB      = 0x8c // substracts 1 to last item, pops it from stack and pushes result.
    public static let OP_2MUL      = 0x8d // Disabled opcode. If executed, transaction is invalid.
    public static let OP_2DIV      = 0x8e // Disabled opcode. If executed, transaction is invalid.
    public static let OP_NEGATE    = 0x8f // negates the number, pops it from stack and pushes result.
    public static let OP_ABS       = 0x90 // replaces number with its absolute value
    public static let OP_NOT       = 0x91 // replaces number with True if it's zero, False otherwise.
    public static let OP_0NOTEQUAL = 0x92 // replaces number with True if it's not zero, False otherwise.
    
    public static let OP_ADD    = 0x93 // (x y -- x+y)
    public static let OP_SUB    = 0x94 // (x y -- x-y)
    public static let OP_MUL    = 0x95 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_DIV    = 0x96 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_MOD    = 0x97 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_LSHIFT = 0x98 // Disabled opcode. If executed, transaction is invalid.
    public static let OP_RSHIFT = 0x99 // Disabled opcode. If executed, transaction is invalid.
    
    public static let OP_BOOLAND            = 0x9a
    public static let OP_BOOLOR             = 0x9b
    public static let OP_NUMEQUAL           = 0x9c
    public static let OP_NUMEQUALVERIFY     = 0x9d
    public static let OP_NUMNOTEQUAL        = 0x9e
    public static let OP_LESSTHAN           = 0x9f
    public static let OP_GREATERTHAN        = 0xa0
    public static let OP_LESSTHANOREQUAL    = 0xa1
    public static let OP_GREATERTHANOREQUAL = 0xa2
    public static let OP_MIN                = 0xa3
    public static let OP_MAX                = 0xa4
    
    public static let OP_WITHIN = 0xa5
    
    // Crypto
    public static let OP_RIPEMD160      = 0xa6
    public static let OP_SHA1           = 0xa7
    public static let OP_SHA256         = 0xa8
    public static let OP_HASH160        = 0xa9
    public static let OP_HASH256        = 0xaa
    public static let OP_CODESEPARATOR  = 0xab // This opcode is rarely used because it's useless, but we need to support it anyway.
    public static let OP_CHECKSIG       = 0xac
    public static let OP_CHECKSIGVERIFY = 0xad
    public static let OP_CHECKMULTISIG  = 0xae
    public static let OP_CHECKMULTISIGVERIFY = 0xaf
    
    // Expansion
    public static let OP_NOP1  = 0xb0
    public static let OP_NOP2  = 0xb1
    public static let OP_NOP3  = 0xb2
    public static let OP_NOP4  = 0xb3
    public static let OP_NOP5  = 0xb4
    public static let OP_NOP6  = 0xb5
    public static let OP_NOP7  = 0xb6
    public static let OP_NOP8  = 0xb7
    public static let OP_NOP9  = 0xb8
    public static let OP_NOP10 = 0xb9
    
    public static let OP_INVALIDOPCODE = 0xff
    
    private static let OpcodeForNameDictionary: [String: Int] = [
        "OP_0":                   OP_0,
        "OP_FALSE":               OP_FALSE,
        "OP_PUSHDATA1":           OP_PUSHDATA1,
        "OP_PUSHDATA2":           OP_PUSHDATA2,
        "OP_PUSHDATA4":           OP_PUSHDATA4,
        "OP_1NEGATE":             OP_1NEGATE,
        "OP_RESERVED":            OP_RESERVED,
        "OP_1":                   OP_1,
        "OP_TRUE":                OP_TRUE,
        "OP_2":                   OP_2,
        "OP_3":                   OP_3,
        "OP_4":                   OP_4,
        "OP_5":                   OP_5,
        "OP_6":                   OP_6,
        "OP_7":                   OP_7,
        "OP_8":                   OP_8,
        "OP_9":                   OP_9,
        "OP_10":                  OP_10,
        "OP_11":                  OP_11,
        "OP_12":                  OP_12,
        "OP_13":                  OP_13,
        "OP_14":                  OP_14,
        "OP_15":                  OP_15,
        "OP_16":                  OP_16,
        "OP_NOP":                 OP_NOP,
        "OP_VER":                 OP_VER,
        "OP_IF":                  OP_IF,
        "OP_NOTIF":               OP_NOTIF,
        "OP_VERIF":               OP_VERIF,
        "OP_VERNOTIF":            OP_VERNOTIF,
        "OP_ELSE":                OP_ELSE,
        "OP_ENDIF":               OP_ENDIF,
        "OP_VERIFY":              OP_VERIFY,
        "OP_RETURN":              OP_RETURN,
        "OP_TOALTSTACK":          OP_TOALTSTACK,
        "OP_FROMALTSTACK":        OP_FROMALTSTACK,
        "OP_2DROP":               OP_2DROP,
        "OP_2DUP":                OP_2DUP,
        "OP_3DUP":                OP_3DUP,
        "OP_2OVER":               OP_2OVER,
        "OP_2ROT":                OP_2ROT,
        "OP_2SWAP":               OP_2SWAP,
        "OP_IFDUP":               OP_IFDUP,
        "OP_DEPTH":               OP_DEPTH,
        "OP_DROP":                OP_DROP,
        "OP_DUP":                 OP_DUP,
        "OP_NIP":                 OP_NIP,
        "OP_OVER":                OP_OVER,
        "OP_PICK":                OP_PICK,
        "OP_ROLL":                OP_ROLL,
        "OP_ROT":                 OP_ROT,
        "OP_SWAP":                OP_SWAP,
        "OP_TUCK":                OP_TUCK,
        "OP_CAT":                 OP_CAT,
        "OP_SUBSTR":              OP_SUBSTR,
        "OP_LEFT":                OP_LEFT,
        "OP_RIGHT":               OP_RIGHT,
        "OP_SIZE":                OP_SIZE,
        "OP_INVERT":              OP_INVERT,
        "OP_AND":                 OP_AND,
        "OP_OR":                  OP_OR,
        "OP_XOR":                 OP_XOR,
        "OP_EQUAL":               OP_EQUAL,
        "OP_EQUALVERIFY":         OP_EQUALVERIFY,
        "OP_RESERVED1":           OP_RESERVED1,
        "OP_RESERVED2":           OP_RESERVED2,
        "OP_1ADD":                OP_1ADD,
        "OP_1SUB":                OP_1SUB,
        "OP_2MUL":                OP_2MUL,
        "OP_2DIV":                OP_2DIV,
        "OP_NEGATE":              OP_NEGATE,
        "OP_ABS":                 OP_ABS,
        "OP_NOT":                 OP_NOT,
        "OP_0NOTEQUAL":           OP_0NOTEQUAL,
        "OP_ADD":                 OP_ADD,
        "OP_SUB":                 OP_SUB,
        "OP_MUL":                 OP_MUL,
        "OP_DIV":                 OP_DIV,
        "OP_MOD":                 OP_MOD,
        "OP_LSHIFT":              OP_LSHIFT,
        "OP_RSHIFT":              OP_RSHIFT,
        "OP_BOOLAND":             OP_BOOLAND,
        "OP_BOOLOR":              OP_BOOLOR,
        "OP_NUMEQUAL":            OP_NUMEQUAL,
        "OP_NUMEQUALVERIFY":      OP_NUMEQUALVERIFY,
        "OP_NUMNOTEQUAL":         OP_NUMNOTEQUAL,
        "OP_LESSTHAN":            OP_LESSTHAN,
        "OP_GREATERTHAN":         OP_GREATERTHAN,
        "OP_LESSTHANOREQUAL":     OP_LESSTHANOREQUAL,
        "OP_GREATERTHANOREQUAL":  OP_GREATERTHANOREQUAL,
        "OP_MIN":                 OP_MIN,
        "OP_MAX":                 OP_MAX,
        "OP_WITHIN":              OP_WITHIN,
        "OP_RIPEMD160":           OP_RIPEMD160,
        "OP_SHA1":                OP_SHA1,
        "OP_SHA256":              OP_SHA256,
        "OP_HASH160":             OP_HASH160,
        "OP_HASH256":             OP_HASH256,
        "OP_CODESEPARATOR":       OP_CODESEPARATOR,
        "OP_CHECKSIG":            OP_CHECKSIG,
        "OP_CHECKSIGVERIFY":      OP_CHECKSIGVERIFY,
        "OP_CHECKMULTISIG":       OP_CHECKMULTISIG,
        "OP_CHECKMULTISIGVERIFY": OP_CHECKMULTISIGVERIFY,
        "OP_NOP1":                OP_NOP1,
        "OP_NOP2":                OP_NOP2,
        "OP_NOP3":                OP_NOP3,
        "OP_NOP4":                OP_NOP4,
        "OP_NOP5":                OP_NOP5,
        "OP_NOP6":                OP_NOP6,
        "OP_NOP7":                OP_NOP7,
        "OP_NOP8":                OP_NOP8,
        "OP_NOP9":                OP_NOP9,
        "OP_NOP10":               OP_NOP10,
        "OP_INVALIDOPCODE":       OP_INVALIDOPCODE
    ]
    
    public static func getOpcodeName(with opcode: Int) -> String {
        let name = OpcodeForNameDictionary.filter{ $0.1 == opcode }.map{ $0.0 }
        guard !name.isEmpty else {
            return "OP_UNKNOWN"
        }
        return name[0]
    }
    
    public static func getOpcode(with name: String) -> Int {
        guard let opcode = OpcodeForNameDictionary[name] else {
            return OP_INVALIDOPCODE
        }
        return opcode
    }
    
    // Returns OP_1NEGATE, OP_0 .. OP_16 for ints from -1 to 16.
    // Returns OP_INVALIDOPCODE for other ints.
    public static func opcodeForSmallInteger(smallInteger: Int) -> Int {
        switch smallInteger {
        case -1:
            return OP_1NEGATE
        case 0:
            return OP_0
        case (1...16):
            return OP_1 + (smallInteger - 1)
        default:
            return OP_INVALIDOPCODE
        }
    }
    
    // Converts opcode OP_<N> or OP_1NEGATE to an integer value.
    // If incorrect opcode is given, NSIntegerMax is returned.
    public static func smallIntegerFromOpcode(opcode: Int) -> Int {
        switch opcode {
        case OP_1NEGATE:
            return -1
        case OP_0:
            return 0
        case (OP_1...OP_16):
            return opcode - (OP_1 - 1)
        default:
            return LONG_MAX
        }
    }
}
