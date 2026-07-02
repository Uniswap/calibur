## Architecture
Generated diagrams for the architecture of the Calibur contract.

## Inheritance Diagram

```mermaid
classDiagram
    Calibur --|> ICalibur
    Calibur --|> ERC7821
    Calibur --|> ERC1271
    Calibur --|> ERC4337Account
    Calibur --|> KeyManagement
    Calibur --|> NonceManager
    Calibur --|> ERC7914
    Calibur --|> ERC7201
    Calibur --|> ERC7739
    Calibur --|> EIP712
    Calibur --|> Receiver
    
    ICalibur --|> IKeyManagement
    ICalibur --|> IERC4337Account
    ICalibur --|> IERC7821
    ICalibur --|> IERC1271
    ICalibur --|> IEIP712
    ICalibur --|> IERC5267
    ICalibur --|> IERC7201
    ICalibur --|> IERC7914
    ICalibur --|> INonceManager
    
    EIP712 --|> IERC5267
    ERC4337Account --|> IAccount
    
    class Calibur {
        +execute(BatchedCall batchedCall)
        +execute(SignedBatchedCall signedBatchedCall, bytes wrappedSignature)
        +execute(bytes32 mode, bytes executionData)
        +executeUserOp(PackedUserOperation userOp, bytes32)
        +validateUserOp(PackedUserOperation userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        +isValidSignature(bytes32 digest, bytes wrappedSignature)
    }
```

## Sequence Diagrams

### Direct execute() Flow

```mermaid
sequenceDiagram
    participant SignerAccount as EOA (delegated to Calibur)
    participant Account as Calibur
    participant Hook
    participant Target
    
    Note over SignerAccount, Account: EOA is delegated to Calibur via EIP-7702
    SignerAccount->>Account: execute(BatchedCall batchedCall)
    Account->>Account: Check if sender keyHash is owner or valid key (_isOwnerOrValidKey)
    Account->>Account: _processBatch(batchedCall, keyHash)
    loop For each call in batchedCall.calls
        Account->>Account: _process(call, keyHash)
        Account->>Account: If to == address(0), replace with address(this)
        Account->>Account: getKeySettings(keyHash)
        Account->>Account: Check if admin for self-calls
        
        opt If hook exists
            Account->>Hook: handleBeforeExecute(keyHash, to, value, data)
            Hook-->>Account: beforeExecuteData
        end
        
        Account->>+Target: to.call{value}(data)
        Target-->>-Account: (success, output)
        
        opt If hook exists
            Account->>Hook: handleAfterExecute(keyHash, success, output, beforeExecuteData)
        end
        
        opt If !success && batchedCall.revertOnFailure
            Account-->>SignerAccount: revert CallFailed(output)
        end
    end
```

### Signature-based execute() Flow

```mermaid
sequenceDiagram
    actor Signer
    participant Relayer
    participant Account as Calibur
    participant Hook
    participant Target
    
    Signer->>Signer: Create SignedBatchedCall structure
    Signer->>Signer: Sign the hash with private key
    Signer->>Relayer: Send signed transaction data
    Relayer->>+Account: execute(SignedBatchedCall, wrappedSignature)
    Account->>Account: Check if sender is executor or executor is address(0)
    Account->>Account: _handleVerifySignature(signedBatchedCall, wrappedSignature)
    Account->>Account: Check if deadline expired
    Account->>Account: _useNonce(signedBatchedCall.nonce)
    Account->>Account: Decode wrappedSignature into (signature, hookData)
    Account->>Account: hashTypedData(signedBatchedCall.hash())
    Account->>Account: getKey(signedBatchedCall.keyHash)
    Account->>Account: key.verify(digest, signature)
    
    opt If !isValid
        Account-->>Relayer: revert InvalidSignature()
    end
    
    Account->>Account: getKeySettings(signedBatchedCall.keyHash)
    Account->>Account: _checkExpiry(settings)
    
    opt If hook has AFTER_VERIFY_SIGNATURE permission
        Account->>Hook: handleAfterVerifySignature(keyHash, digest, hookData)
    end
    
    Account->>Account: _processBatch(signedBatchedCall.batchedCall, signedBatchedCall.keyHash)
    
    loop For each call in batchedCall.calls
        Account->>Account: _process(call, keyHash)
        Account->>Account: getKeySettings(keyHash)
        Account->>Account: Check if admin for self-calls
        
        opt If hook exists
            Account->>Hook: handleBeforeExecute(keyHash, to, value, data)
            Hook-->>Account: beforeExecuteData
        end
        
        Account->>+Target: to.call{value}(data)
        Target-->>-Account: (success, output)
        
        opt If hook exists
            Account->>Hook: handleAfterExecute(keyHash, success, output, beforeExecuteData)
        end
        
        opt If !success && batchedCall.revertOnFailure
            Account-->>Relayer: revert CallFailed(output)
        end
    end
    
    Account-->>-Relayer: Success
```

### ERC7821 execute() Flow

```mermaid
sequenceDiagram
    participant SignerAccount as EOA (delegated to Calibur)
    participant Account as Calibur
    participant Hook
    participant Target
    
    Note over SignerAccount, Account: EOA is delegated to Calibur via EIP-7702
    SignerAccount->>Account: execute(bytes32 mode, bytes executionData)
    Account->>Account: mode.isBatchedCall()
    opt If !mode.isBatchedCall()
        Account-->>SignerAccount: revert UnsupportedExecutionMode()
    end
    
    Account->>Account: abi.decode(executionData) to Call[]
    Account->>Account: Create BatchedCall with calls and mode.revertOnFailure()
    Account->>Account: execute(batchedCall)
    Account->>Account: Check if sender keyHash is owner or valid key
    Account->>Account: _processBatch(batchedCall, keyHash)
    
    loop For each call in batchedCall.calls
        Account->>Account: _process(call, keyHash)
        Account->>Account: If to == address(0), replace with address(this)
        Account->>Account: getKeySettings(keyHash)
        Account->>Account: Check if admin for self-calls
        
        opt If hook exists
            Account->>Hook: handleBeforeExecute(keyHash, to, value, data)
            Hook-->>Account: beforeExecuteData
        end
        
        Account->>+Target: to.call{value}(data)
        Target-->>-Account: (success, output)
        
        opt If hook exists
            Account->>Hook: handleAfterExecute(keyHash, success, output, beforeExecuteData)
        end
        
        opt If !success && batchedCall.revertOnFailure
            Account-->>SignerAccount: revert CallFailed(output)
        end
    end
    
    Account-->>SignerAccount: Success
```

### ERC4337 UserOp Flow

```mermaid
sequenceDiagram
    actor Signer
    participant Bundler
    participant EntryPoint
    participant Account as Calibur
    participant Hook
    participant Target
    
    Signer->>Signer: Create UserOperation with (keyHash, signature, hookData)
    Signer->>Signer: Sign userOpHash
    Signer->>Bundler: Submit UserOperation
    
    Bundler->>+EntryPoint: handleOps([userOp], beneficiary)
    EntryPoint->>+Account: validateUserOp(userOp, userOpHash, missingAccountFunds)
    
    Account->>Account: _payEntryPoint(missingAccountFunds)
    Account->>Account: Decode signature to (keyHash, signature, hookData)
    Account->>Account: getKey(keyHash)
    Account->>Account: key.verify(userOpHash, signature)
    Account->>Account: getKeySettings(keyHash)
    
    Account->>Account: Calculate validationData with expiry and isValid
    
    opt If hook exists
        Account->>Hook: handleAfterValidateUserOp(keyHash, userOp, userOpHash, validationData, hookData)
    end
    
    Account-->>-EntryPoint: Return validationData
    
    EntryPoint->>+Account: executeUserOp(userOp, userOpHash)
    Account->>Account: Decode signature to extract keyHash
    Account->>Account: Decode callData to BatchedCall
    Account->>Account: _processBatch(batchedCall, keyHash)
    
    loop For each call in batchedCall.calls
        Account->>Account: _process(call, keyHash)
        Account->>Account: If to == address(0), replace with address(this)
        Account->>Account: getKeySettings(keyHash)
        Account->>Account: Check if admin for self-calls
        
        opt If hook exists
            Account->>Hook: handleBeforeExecute(keyHash, to, value, data)
            Hook-->>Account: beforeExecuteData
        end
        
        Account->>+Target: to.call{value}(data)
        Target-->>-Account: (success, output)
        
        opt If hook exists
            Account->>Hook: handleAfterExecute(keyHash, success, output, beforeExecuteData)
        end
        
        opt If !success && batchedCall.revertOnFailure
            Account-->>EntryPoint: revert CallFailed(output)
        end
    end
    
    Account-->>-EntryPoint: Success
    EntryPoint-->>-Bundler: Success
```

### ERC1271 isValidSignature Flow

```mermaid
sequenceDiagram
    participant VerifyingContract
    participant Account as Calibur
    participant Hook
    
    VerifyingContract->>+Account: isValidSignature(bytes32 digest, bytes wrappedSignature)
    
    alt ERC7739 Sentinel Check
        Account->>Account: Check if wrappedSignature length is 0 and digest matches sentinel
        Account-->>VerifyingContract: Return 0x77390001
    else Raw Root Key Signature Check
        Account->>Account: Check if wrappedSignature is a raw signature (64 or 65 bytes)
        Account->>Account: Try to verify with root key
        opt If signature is valid
            Account-->>VerifyingContract: Return _1271_MAGIC_VALUE
        end
        opt If signature is invalid
            Account-->>VerifyingContract: Return _1271_INVALID_VALUE
        end
    end
    
    Account->>Account: Decode wrappedSignature to (keyHash, signature, hookData)
    Account->>Account: getKey(keyHash)
    
    Account->>Account: Try _isValidTypedDataSig(key, digest, domainBytes(), signature)
    Account->>Account: If that fails, try _isValidNestedPersonalSig(key, digest, domainSeparator(), signature)
    
    opt If !isValid
        Account-->>VerifyingContract: Return _1271_INVALID_VALUE
    end
    
    Account->>Account: getKeySettings(keyHash)
    Account->>Account: _checkExpiry(settings)
    
    opt If hook has AFTER_IS_VALID_SIGNATURE permission
        Account->>Hook: afterIsValidSignature(keyHash, digest, hookData)
    end
    
    Account-->>-VerifyingContract: Return _1271_MAGIC_VALUE
```

### ERC7914 Native ETH Approval Flow

```mermaid
sequenceDiagram
    participant Caller
    participant Account as Calibur
    participant Spender
    
    Caller->>+Account: approveNative(spender, amount)
    Account->>Account: Check onlyThis modifier
    Account->>Account: nativeAllowance[spender] = amount
    Account->>Account: Emit ApproveNative event
    Account-->>-Caller: Return true

    Spender->>+Account: transferFromNative(from, recipient, amount)
    Account->>Account: If amount == 0, return true
    Account->>Account: Check if from == address(this)
    Account->>Account: Check if nativeAllowance[msg.sender] >= amount
    Account->>Account: Update allowance if not max
    Account->>Account: Emit NativeAllowanceUpdated event if allowance updated
    Account->>+recipient: Transfer ETH value with call
    recipient-->>-Account: Success
    Account->>Account: Emit TransferFromNative event
    Account-->>-Spender: Return true
    
    Note over Account: If transfer fails at any point, revert with TransferNativeFailed
```