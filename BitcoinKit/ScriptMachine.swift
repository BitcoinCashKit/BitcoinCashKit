//
//  ScriptMachine.swift
//  BitcoinKit
//
//  Created by Akifumi Fujita on 2018/07/13.
//  Copyright © 2018年 Kishikawa Katsumi. All rights reserved.
//

import Foundation

enum ScriptVerification {
    case StrictEncoding // enforce strict conformance to DER and SEC2 for signatures and pubkeys (aka SCRIPT_VERIFY_STRICTENC)
    case EvenS // enforce lower S values (below curve halforder) in signatures (aka SCRIPT_VERIFY_EVEN_S, depends on STRICTENC)
}

public enum ScriptMachineError: Error {
    case scriptError(String)
}

// P2SH BIP16 didn't become active until Apr 1 2012. All txs before this timestamp should not be verified with P2SH rule.
let BTC_BIP16_TIMESTAMP: UInt32 = 1_333_238_400

// Scripts longer than 10000 bytes are invalid.
let BTC_MAX_SCRIPT_SIZE: Int = 10_000

// Maximum number of bytes per "pushdata" operation
let BTC_MAX_SCRIPT_ELEMENT_SIZE: Int = 520; // bytes

// Number of public keys allowed for OP_CHECKMULTISIG
let BTC_MAX_KEYS_FOR_CHECKMULTISIG: Int = 20

// Maximum number of operations allowed per script (excluding pushdata operations and OP_<N>)
// Multisig op additionally increases count by a number of pubkeys.
let BTC_MAX_OPS_PER_SCRIPT: Int = 201

// ScriptMachine is a stack machine (like Forth) that evaluates a predicate
// returning a bool indicating valid or not. There are no loops.
// You can -copy a machine which will copy all the parameters and the stack state.
class ScriptMachine {

    // "To" transaction that is signed by an inputScript.
    // Required parameter.
    public var transaction: Transaction?

    // An index of the tx input in the `transaction`.
    // Required parameter.
    public var inputIndex: Int?

    // Overrides inputScript from transaction.inputs[inputIndex].
    // Useful for testing, but useless if you need to test CHECKSIG operations. In latter case you still need a full transaction.
    public var inpuScript: Script?

    // A timestamp of the current block. Default is current timestamp.
    // This is used to test for P2SH scripts or other changes in the protocol that may happen in the future.
    // If not specified, defaults to current timestamp thus using the latest protocol rules.
    public var blockTimestamp: UInt32 = UInt32(NSTimeIntervalSince1970)

    // Flags affecting verification. Default is the most liberal verification.
    // One can be stricter to not relay transactions with non-canonical signatures and pubkey (as BitcoinQT does).
    // Defaults in CoreBitcoin: be liberal in what you accept and conservative in what you send.
    // So we try to create canonical purist transactions but have no problem accepting and working with non-canonical ones.
    public var verificationFlags: ScriptVerification?

    // Stack contains NSData objects that are interpreted as numbers, bignums, booleans or raw data when needed.
    public var stack: Data = Data()

    // Used in ALTSTACK ops.
    public var altStack: Data = Data()

    // Holds an array of @YES and @NO values to keep track of if/else branches.
    public var conditionStack = [Bool]()

    // Currently executed script.
    public var script: Script?

    // Current opcode.
    public var opcode: UInt8 = 0

    // Current payload for any "push data" operation.
    public var pushedData: Data?

    // Current opcode index in _script.
    public var opIndex: Int = 0

    // Index of last OP_CODESEPARATOR
    public var lastCodeSepartorIndex: Int = 0

    // Keeps number of executed operations to check for limit.
    public var opCount: Int = 0

    public var opFailed: Bool?

    init() {
        stack = Data()
        altStack = Data()
        conditionStack = [Bool]()
    }

//    - (id) initWithTransaction:(BTCTransaction*)tx inputIndex:(uint32_t)inputIndex {
//    if (!tx) return nil;
//    // BitcoinQT would crash right before VerifyScript if the input index was out of bounds.
//    // So even though it returns 1 from SignatureHash() function when checking for this condition,
//    // it never actually happens. So we too will not check for it when calculating a hash.
//    if (inputIndex >= tx.inputs.count) return nil;
//    if (self = [self init]) {
//    _transaction = tx;
//    _inputIndex = inputIndex;
//    }
//    return self;
//    }
    // This will return nil if the transaction is nil, or inputIndex is out of bounds.
    // You can use -init if you want to run scripts without signature verification (so no transaction is needed).
    convenience init?(tx: Transaction, inputIndex: Int) {
        guard !tx.serialized().isEmpty else {
            return nil
        }

        // BitcoinQT would crash right before VerifyScript if the input index was out of bounds.
        // So even though it returns 1 from SignatureHash() function when checking for this condition,
        // it never actually happens. So we too will not check for it when calculating a hash.
        guard inputIndex < tx.inputs.count else {
            return nil
        }
        self.init()
        self.transaction = tx
        self.inputIndex = inputIndex
    }

//    - (void) resetStack {
//    _stack = [NSMutableArray array];
//    _altStack = [NSMutableArray array];
//    _conditionStack = [NSMutableArray array];
//    }
    public func resetStack() {
        stack = Data()
        altStack = Data()
        conditionStack = [Bool]()
    }

    public var shouldVerifyP2SH: Bool {
        return blockTimestamp >= BTC_BIP16_TIMESTAMP
    }

    public func verify(with outputScript: Script?) -> Bool {
        // self.inputScript allows to override transaction so we can simply testing.
//        BTCScript* inputScript = self.inputScript;
        let inputScript: Script

//        if (!inputScript) {
//            // Sanity check: transaction and its input should be consistent.
//            if (!(self.transaction && self.inputIndex < self.transaction.inputs.count)) {
//                [NSException raise:@"BTCScriptMachineException"  format:@"transaction and valid inputIndex are required for script verification."];
//                return NO;
//            }
//            if (!outputScript) {
//                [NSException raise:@"BTCScriptMachineException"  format:@"non-nil outputScript is required for script verification."];
//                return NO;
//            }
//
//            BTCTransactionInput* txInput = self.transaction.inputs[self.inputIndex];
//            inputScript = txInput.signatureScript;
//        }
        if let script = self.inpuScript {
            inputScript = script
        } else {
            // Sanity check: transaction and its input should be consistent.
            guard let tx = self.transaction, let inputIndex = self.inputIndex, inputIndex < tx.inputs.count else {
                print("transaction and valid inputIndex are required for script verification.")
                return false
            }
            guard outputScript != nil else {
                print("non-nil outputScript is required for script verification.")
                return false
            }
            let txInput: TransactionInput = tx.inputs[inputIndex]
            guard let script = Script(data: txInput.signatureScript) else {
                return false
            }
            inputScript = script
        }

        // First step: run the input script which typically places signatures, pubkeys and other static data needed for outputScript.
//        if (![self runScript:inputScript error:errorOut]) {
//            // errorOut is set by runScript
//            return NO;
//        }
        guard run(script: inputScript) else {
            return false
        }

        // Make a copy of the stack if we have P2SH script.
        // We will run deserialized P2SH script on this stack if other verifications succeed.
//        BOOL shouldVerifyP2SH = [self shouldVerifyP2SH] && outputScript.isPayToScriptHashScript;
//        NSMutableArray* stackForP2SH = shouldVerifyP2SH ? [_stack mutableCopy] : nil;
        let shouldVerifyP2SH: Bool = self.shouldVerifyP2SH && (outputScript?.isPayToScriptHashScript ?? false)
        let stackForP2SH: Data? = shouldVerifyP2SH ? stack : nil

        // Second step: run output script to see that the input satisfies all conditions laid in the output script.
//        if (![self runScript:outputScript error:errorOut]) {
//            // errorOut is set by runScript
//            return NO;
//        }
        guard run(script: outputScript) else {
            return false
        }

        // We need to have something on stack
//        if (_stack.count == 0) {
//            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Stack is empty after script execution.", @"")];
//            return NO;
//        }
        guard !stack.isEmpty else {
            print("Stack is empty after script execution.")
            return false
        }

        // The last value must be YES.
//        if ([self boolAtIndex:-1] == NO) {
//            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Last item on the stack is boolean NO.", @"")];
//            return NO;
//        }
        guard bool(at: -1) else {
            print("Last item on the stack is boolean NO.")
            return false
        }

        // Additional validation for spend-to-script-hash transactions:
//        if (shouldVerifyP2SH) {
        if shouldVerifyP2SH {
            // BitcoinQT: scriptSig must be literals-only
//            if (![inputScript isDataOnly]) {
//                if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Input script for P2SH spending must be literals-only.", @"")];
//                return NO;
//            }
            guard inputScript.isDataOnly else {
                print("Input script for P2SH spending must be literals-only.")
                return false
            }

//            if (stackForP2SH.count == 0) {
//                [NSException raise:@"BTCScriptMachineException"  format:@"internal inconsistency: stackForP2SH cannot be empty at this point."];
//                return NO;
//            }
            guard var stackForP2SH = stackForP2SH, !stackForP2SH.isEmpty else {
                // stackForP2SH cannot be empty here, because if it was the
                // P2SH  HASH <> EQUAL  scriptPubKey would be evaluated with
                // an empty stack and the runScript: above would return NO.
                print("internal inconsistency: stackForP2SH cannot be empty at this point.")
                return false
            }

            // Instantiate the script from the last data on the stack.
//            BTCScript* providedScript = [[BTCScript alloc] initWithData:[stackForP2SH lastObject]];
            guard let last = stackForP2SH.last, let providedScript = Script(data: Data(bytes: [last])) else {
                print("Script initialization fails")
                return false
            }

            // Remove it from the stack.
//            [stackForP2SH removeObjectAtIndex:stackForP2SH.count - 1];
            stackForP2SH.removeLast()

            // Replace current stack with P2SH stack.
//            [self resetStack];
//            _stack = stackForP2SH;
            resetStack()
            self.stack = stackForP2SH

//            if (![self runScript:providedScript error:errorOut]) {
//                return NO;
//            }
            guard run(script: providedScript) else {
                return false
            }

            // We need to have something on stack
//            if (_stack.count == 0) {
//                if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Stack is empty after script execution.", @"")];
//                return NO;
//            }
            guard !stack.isEmpty else {
                print("Stack is empty after script execution.")
                return false
            }

            // The last value must be YES.
//            if ([self boolAtIndex:-1] == NO) {
//                if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Last item on the stack is boolean NO.", @"")];
//                return NO;
//            }
            guard bool(at: -1) else {
                print("Last item on the stack is boolean NO.")
                return false
            }
        }

        // If nothing failed, validation passed.
        return true
    }

//    - (BOOL) runScript:(BTCScript*)script error:(NSError**)errorOut {
    public func run(script: Script?) -> Bool {
//    if (!script) {
//    [NSException raise:@"BTCScriptMachineException"  format:@"non-nil script is required for -runScript:error: method."];
//    return NO;
//    }
        guard let script = script else {
            print("non-nil script is required for -runScript:error: method.")
            return false
        }

//        if (script.data.length > BTC_MAX_SCRIPT_SIZE) {
//            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Script binary is too long.", @"")];
//            return NO;
//        }
        guard script.data.count > BTC_MAX_SCRIPT_SIZE else {
            print("Script binary is too long.")
            return false
        }

        // Altstack should be reset between script runs.
//        _altStack = [NSMutableArray array];
//
//        _script = script;
//        _opIndex = 0;
//        _opcode = 0;
//        _pushdata = nil;
//        _lastCodeSeparatorIndex = 0;
//        _opCount = 0;

        altStack = Data()

        opIndex = 0
        opcode = 0
        pushedData = nil
        lastCodeSepartorIndex = 0
        opCount = 0

//        __block BOOL opFailed = NO;
//        [script enumerateOperations:^(NSUInteger opIndex, BTCOpcode opcode, NSData *pushdata, BOOL *stop) {
//
//            _opIndex = opIndex;
//            _opcode = opcode;
//            _pushdata = pushdata;
//
//            if (![self executeOpcodeError:errorOut])
//            {
//            opFailed = YES;
//            *stop = YES;
//            }
//            }];
        opFailed = false
        script.enumerateOperations(block: { [weak self] opIndex, opcode, pushedData -> Bool in
            self?.opIndex = opIndex
            self?.opcode = opcode
            self?.pushedData = pushedData

            guard let result = self?.executeOpcode(), result else {
                self?.opFailed = true
                return true
            }
            return false
        })

//        if (opFailed) {
//            return NO;
//        }
        guard opFailed ?? false else {    // QUESTION: 直前で値を代入しているからopFailedはnilでは必ずない。強制アンラップしたい
            return false
        }

//        if (_conditionStack.count > 0) {
//            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Condition branches not balanced.", @"")];
//            return NO;
//        }
        guard !conditionStack.isEmpty else {
            print("Condition branches not balanced.")
            return false
        }

        return true
    }

//    - (BOOL) executeOpcodeError:(NSError**)errorOut {
    // swiftlint:disable:next cyclomatic_complexity
    private func executeOpcode() -> Bool {
//        if (pushdata.length > BTC_MAX_SCRIPT_ELEMENT_SIZE) {
//            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Pushdata chunk size is too big.", @"")];
//            return NO;
//        }
        guard pushedData == nil || pushedData!.count <= BTC_MAX_SCRIPT_ELEMENT_SIZE else {
            print("Pushdata chunk size is too big.")
            return false
        }

//        if (opcode > OP_16 && !_pushdata && ++_opCount > BTC_MAX_OPS_PER_SCRIPT) {
//            if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Exceeded the allowed number of operations per script.", @"")];
//            return NO;
//        }
        guard opcode <= Opcode.OP_16 || pushedData != nil || opCount <= BTC_MAX_OPS_PER_SCRIPT else {
            print("Exceeded the allowed number of operations per script.")
            return false
        }

        // Disabled opcodes
        // TODO: BCHで復活したOpcodeを変更する
        if (opcode == Opcode.OP_CAT ||
            opcode == Opcode.OP_SUBSTR ||
            opcode == Opcode.OP_LEFT ||
            opcode == Opcode.OP_RIGHT ||
            opcode == Opcode.OP_INVERT ||
            opcode == Opcode.OP_AND ||
            opcode == Opcode.OP_OR ||
            opcode == Opcode.OP_XOR ||
            opcode == Opcode.OP_2MUL ||
            opcode == Opcode.OP_2DIV ||
            opcode == Opcode.OP_MUL ||
            opcode == Opcode.OP_DIV ||
            opcode == Opcode.OP_MOD ||
            opcode == Opcode.OP_LSHIFT ||
            opcode == Opcode.OP_RSHIFT) {
            print("Attempt to execute a disabled opcode.")
            return false
        }

//        BOOL shouldExecute = ([_conditionStack indexOfObject:@NO] == NSNotFound);
        let shouldExecute: Bool = !conditionStack.contains(false)

//        if (shouldExecute && pushdata) {
//            [_stack addObject:pushdata];
//        }
        if let pushedData = pushedData, shouldExecute {
            stack += pushedData

//        } else if (shouldExecute || (OP_IF <= opcode && opcode <= OP_ENDIF)) {
        } else if shouldExecute || (Opcode.OP_IF <= opcode && opcode <= Opcode.OP_ENDIF) {
            // this basically means that OP_VERIF and OP_VERNOTIF will always fail the script, even if not executed.
            switch opcode {
            //
            // Push value
            //
            case Opcode.OP_NEGATE, Opcode.OP_1...Opcode.OP_16:
                // ( -- value)
//                BTCBigNumber* bn = [[BTCBigNumber alloc] initWithInt64:(int)opcode - (int)(OP_1 - 1)];
//                [_stack addObject:bn.signedLittleEndian];
                let bn: Int = Int(opcode) - Int(Opcode.OP_1 - 1)
                stack += bn.littleEndian    // QUESTION: SwiftはデフォルトでlittleEndian？
            //
            // Control
            //
            case Opcode.OP_NOP, Opcode.OP_NOP1...Opcode.OP_NOP10:
                break
            case Opcode.OP_IF, Opcode.OP_NOTIF:
                // <expression> if [statements] [else [statements]] endif
//                BOOL value = NO;
//                if (shouldExecute) {
//                    if (_stack.count < 1) {
//                        if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
//                        return NO;
//                    }
//                    value = [self boolAtIndex:-1];
//                    if (opcode == OP_NOTIF) {
//                        value = !value;
//                    }
//                    [self popFromStack];
//                }
//                [_conditionStack addObject:@(value)];
                var value: Bool = false
                if shouldExecute {
                    guard stack.count >= 1 else {
                        print("at least one item is needed") // TODO: implement scriptErrorOpcodeRequiresItemsOnStack
                        return false
                    }
                    value = opcode == Opcode.OP_IF ? bool(at: -1) : !bool(at: -1)
                    stack.removeLast()
                }
                conditionStack.append(value)
            case Opcode.OP_ELSE:
//                if (_conditionStack.count == 0) {
//                    if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Expected an OP_IF or OP_NOTIF branch before OP_ELSE.", @"")];
//                    return NO;
//                }
//
//                // Invert last condition.
//                BOOL f = [[_conditionStack lastObject] boolValue];
//                [_conditionStack removeObjectAtIndex:_conditionStack.count - 1];
//                [_conditionStack addObject:@(!f)];
                guard !conditionStack.isEmpty else {
                    print("Expected an OP_IF or OP_NOTIF branch before OP_ELSE.")
                    return false
                }
                let last = conditionStack.popLast()!
                conditionStack.append(!last)
            case Opcode.OP_ENDIF:
//                if (_conditionStack.count == 0) {
//                    if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"Expected an OP_IF or OP_NOTIF branch before OP_ENDIF.", @"")];
//                    return NO;
//                }
//                [_conditionStack removeObjectAtIndex:_conditionStack.count - 1];
                guard !conditionStack.isEmpty else {
                    print("Expected an OP_IF or OP_NOTIF branch before OP_ENDIF.")
                    return false
                }
                conditionStack.removeLast()
            case Opcode.OP_VERIFY:
                // (true -- ) or
                // (false -- false) and return
//                if (_stack.count < 1) {
//                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
//                    return NO;
//                }
//
//                BOOL value = [self boolAtIndex:-1];
//                if (value) {
//                    [self popFromStack];
//                } else {
//                    if (errorOut) *errorOut = [self scriptError:NSLocalizedString(@"OP_VERIFY failed.", @"")];
//                    return NO;
//                }
                guard stack.count >= 1 else {
                    print("at least one item is needed") // TODO: implement scriptErrorOpcodeRequiresItemsOnStack
                    return false
                }
                if bool(at: -1) {
                    stack.removeLast()
                } else {
                    print("OP_VERIFY failed.")
                    return false
                }
            case Opcode.OP_RETURN:
                print("OP_RETURN executed.")
                return false
            //
            // Stack ops
            //
            case Opcode.OP_TOALTSTACK:
//                if (_stack.count < 1) {
//                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:1];
//                    return NO;
//                }
//                [_altStack addObject:[self dataAtIndex:-1]];
//                [self popFromStack];
                guard stack.count >= 1 else {
                    print("at least one item is needed") // TODO: implement scriptErrorOpcodeRequiresItemsOnStack
                    return false
                }
                altStack.append(stack.popLast()!)
            case Opcode.OP_FROMALTSTACK:
//                if (_altStack.count < 1) {
//                    if (errorOut) *errorOut = [self scriptError:[NSString stringWithFormat:NSLocalizedString(@"%@ requires one item on altstack", @""), BTCNameForOpcode(opcode)]];
//                    return NO;
//                }
//                [_stack addObject:_altStack[_altStack.count - 1]];
//                [_altStack removeObjectAtIndex:_altStack.count - 1];
                guard altStack.count >= 1 else {
                    print("at least one item is needed") // TODO: implement scriptErrorOpcodeRequiresItemsOnStack
                    return false
                }
                stack.append(altStack.popLast()!)
            case Opcode.OP_2DROP:
                // (x1 x2 -- )
//                if (_stack.count < 2) {
//                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
//                    return NO;
//                }
//                [self popFromStack];
//                [self popFromStack];
                guard stack.count >= 2 else {
                    print("at least two items are needed") // TODO: implement scriptErrorOpcodeRequiresItemsOnStack
                    return false
                }
                stack.removeLast()
                stack.removeLast()
            case Opcode.OP_2DUP:
                // (x1 x2 -- x1 x2 x1 x2)
//                if (_stack.count < 2) {
//                if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:2];
//                return NO;
//                }
//                NSData* data1 = [self dataAtIndex:-2];
//                NSData* data2 = [self dataAtIndex:-1];
//                [_stack addObject:data1];
//                [_stack addObject:data2];
                guard stack.count >= 2 else {
                    print("at least two items are needed") // TODO: implement scriptErrorOpcodeRequiresItemsOnStack
                    return false
                }
                stack.append(stack[-2])
                stack.append(stack[-1])
            case Opcode.OP_3DUP:
                // (x1 x2 x3 -- x1 x2 x3 x1 x2 x3)
//                if (_stack.count < 3) {
//                    if (errorOut) *errorOut = [self scriptErrorOpcodeRequiresItemsOnStack:3];
//                    return NO;
//                }
//                NSData* data1 = [self dataAtIndex:-3];
//                NSData* data2 = [self dataAtIndex:-2];
//                NSData* data3 = [self dataAtIndex:-1];
//                [_stack addObject:data1];
//                [_stack addObject:data2];
//                [_stack addObject:data3];
                guard stack.count >= 3 else {
                    print("at least three items are needed") // TODO: implement scriptErrorOpcodeRequiresItemsOnStack
                    return false
                }
                stack.append(stack[-3])
                stack.append(stack[-2])
                stack.append(stack[-1])
            default:
                break
            }
        }

        return true
    }

    // TODO: not implemented
    private func bool(at index: Int) -> Bool {
        return false
    }

}
