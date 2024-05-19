use aiken/bytearray
use aiken/cbor.{serialise}
use aiken/dict
use aiken/hash.{Blake2b_256, Hash, blake2b_256}
use aiken/interval
use aiken/list
use aiken/transaction.{
  DatumHash, InlineDatum, Output, ScriptContext, Spend, Transaction,
  ValidityRange, find_datum, find_input, find_script_outputs,
} as tx
use aiken/transaction/credential.{Address, Credential, ScriptCredential}
use aiken/transaction/value.{without_lovelace}
use soulbound/types.{
  After, All, Any, AtLeast, Before, Burn, BurnToken, ClaimRedeemerData,
  ClaimToken, DatumData, Mint, NativeScript, Policy, RedeemerData, Sig,
  VerificationKeyHash,
}

pub fn mint_validator(
  policy: Policy,
  script: Credential,
  redeemer: RedeemerData,
  ctx: ScriptContext,
) -> Bool {
  expect ScriptCredential(script_hash) = script
  let ScriptContext { transaction, purpose } = ctx
  expect
    check_policy(
      transaction.extra_signatories,
      transaction.validity_range,
      policy,
    )?
  expect tx.Mint(policy_id) = purpose
  let Transaction { outputs, mint, .. } = transaction
  when redeemer is {
    Mint(msg) -> {
      let policyHash = blake2b_256(serialise(policy))
      expect msg == "Issued"
      // TODO: allow multiple tokens mint/burn at once
      expect [(asset_name, amount)] =
        mint
          |> value.from_minted_value
          |> value.tokens(policy_id)
          |> dict.to_list()
      // Token must go to locking address
      expect Some(output) =
        list.find(
          outputs,
          fn(output) {
            let Address { payment_credential, .. } = output.address
            when payment_credential is {
              ScriptCredential(hash) -> (hash == script_hash)?
              _ -> False?
            }
          },
        )
      let Output { value: val, datum, .. } = output
      expect [(token_name, token_amount)] =
        val
          |> value.tokens(policy_id)
          |> dict.to_list()
      (asset_name == token_name)? && (amount == token_amount)? && amount == 1 && when
        datum
      is {
        DatumHash(hash) -> {
          expect Some(data) = find_datum([output], dict.new(), hash)
          check_datum(data, msg, policyHash)?
        }
        InlineDatum(data) -> check_datum(data, msg, policyHash)?
        _ -> False?
      }
    }
    Burn ->
      mint
        |> value.from_minted_value
        |> value.flatten
        |> list.all(
             fn(asset) {
               let (p, _, am) = asset
               p != policy_id || am == -1
             },
           )
  }
}

pub fn redeem_validator(
  datum: DatumData,
  redeemer: ClaimRedeemerData,
  ctx: ScriptContext,
) -> Bool {
  when redeemer is {
    ClaimToken -> {
      let DatumData { status, beneficiary, .. }: DatumData = datum
      if status != "Issued" {
        False?
      } else {
        let ScriptContext { transaction, purpose } = ctx
        expect Spend(my_output_reference) = purpose
        expect Some(input) =
          transaction.inputs
            |> tx.find_input(my_output_reference)
        let Output { address, value, .. } = input.output

        // get script output
        let Address { payment_credential, .. } = address
        expect ScriptCredential(script_hash) = payment_credential
        expect [output] = find_script_outputs(transaction.outputs, script_hash)

        // get output value and datum
        let Output { value: new_value, datum: new_datum, .. } = output

        // expected output data
        let output_data = DatumData { ..datum, status: "Claimed" }

        // must be signed by beneficiary
        let beneficiary_signed =
          list.has(transaction.extra_signatories, beneficiary)
        beneficiary_signed && without_lovelace(value) == without_lovelace(
          new_value,
        ) && when new_datum is {
          DatumHash(hash) -> {
            expect Some(data) = find_datum([output], dict.new(), hash)
            expect input_data: DatumData = data
            (output_data == input_data)?
          }

          InlineDatum(data) -> {
            expect input_data: DatumData = data
            (output_data == input_data)?
          }
          _ -> False?
        }
      }
    }
    BurnToken(policy) -> {
      let DatumData { policyId, .. }: DatumData = datum
      expect
        bytearray.compare(policyId, blake2b_256(serialise(policy))) == Equal
      let ScriptContext { transaction, purpose } = ctx
      expect
        check_policy(
          transaction.extra_signatories,
          transaction.validity_range,
          policy,
        )?
      let Transaction { mint, .. } = transaction
      expect Spend(my_output_reference) = purpose

      expect Some(input) =
        ctx.transaction.inputs
          |> find_input(my_output_reference)
      let Output { value: input_value, .. } = input.output
      // allow burning only one token at a time.
      expect [(p, name, am)] =
        mint
          |> value.from_minted_value
          |> value.flatten
      expect [(policy_id, asset_name, _)] =
        input_value
          |> value.without_lovelace
          |> value.flatten
      policy_id == p && asset_name == name && am == -1
    }
  }
}

// Helper functions

fn check_policy(
  signers: List<VerificationKeyHash>,
  validRange: ValidityRange,
  policy: Policy,
) -> Bool {
  let Policy { pType, pKeyHash, pSlot, pRequire, scripts } = policy
  when pType is {
    All ->
      when scripts is {
        Some(scrpts) ->
          list.all(
            scrpts,
            fn(n) { check_policy_script(n, signers, validRange) },
          )
        None -> False
      }
    Any ->
      when scripts is {
        Some(scrpts) ->
          list.any(
            scrpts,
            fn(n) { check_policy_script(n, signers, validRange) },
          )
        None -> False
      }
    AtLeast ->
      when (scripts, pRequire) is {
        (Some(scrpts), Some(require)) ->
          list.count(
            scrpts,
            fn(n) { check_policy_script(n, signers, validRange) },
          ) >= require
        _ -> False
      }
    _ ->
      check_policy_script(
        NativeScript {
          ntype: pType,
          keyHash: pKeyHash,
          slot: pSlot,
          require: pRequire,
        },
        signers,
        validRange,
      )
  }
}

fn check_policy_script(
  script: NativeScript,
  signers: List<VerificationKeyHash>,
  validRange: ValidityRange,
) -> Bool {
  let NativeScript { ntype, keyHash, slot, .. } = script
  when ntype is {
    Sig -> {
      expect Some(hash) = keyHash
      list.has(signers, hash)?
    }
    After -> {
      expect Some(timeSlot) = slot
      interval.is_entirely_after(validRange, timeSlot)
    }
    Before -> {
      expect Some(timeSlot) = slot
      interval.is_entirely_before(validRange, timeSlot)
    }
    _ -> False
  }
}

fn check_datum(
  data: Data,
  msg: ByteArray,
  policyHash: Hash<Blake2b_256, ByteArray>,
) -> Bool {
  expect DatumData { policyId, status, .. }: DatumData = data
  (policyId == policyHash)? && (bytearray.length(policyId) == 32)? && status == msg
}
// Function to hash the serialized Policy
// fn hash_policy(policy: Policy) -> ByteArray {
//   let serialized_policy = serialize_policy(policy)
//   blake2b_256(serialized_policy)
// }

// // Function to serialize the Policy type
// fn serialize_policy(policy: Policy) -> ByteArray {
//   let pType_bytes = serialize_script_type(policy.pType)
//   let pKeyHash_bytes =
//     when policy.pKeyHash is {
//       Some(keyHash) -> serialize_verification_key_hash(keyHash)
//       None -> #[]
//     }

//   let pSlot_bytes =
//     when policy.pSlot is {
//       Some(slot) -> serialize_posix_time(slot)
//       None -> #[]
//     }

//   let pRequire_bytes =
//     when policy.pRequire is {
//       Some(req) -> serialize_int(req)
//       None -> #[]
//     }

//   let scripts_bytes =
//     when policy.scripts is {
//       Some(scripts) -> serialize_native_scripts(scripts)
//       None -> #[]
//     }

//   bytearray.concat(
//     #[],
//     // #[pType_bytes, pKeyHash_bytes, pSlot_bytes, pRequire_bytes, scripts_bytes],
//     #[],
//   )
// }

// // Assuming basic serialization functions for these types
// fn serialize_script_type(script_type: ScriptType) -> ByteArray {
//   // Replace with actual serialization logic
//   // bytearray.from_string(script_type.to_string())
//   #[]
// }

// fn serialize_verification_key_hash(key_hash: VerificationKeyHash) -> ByteArray {
//   // Replace with actual serialization logic
//   key_hash
// }

// fn serialize_posix_time(time: PosixTime) -> ByteArray {
//   // Replace with actual serialization logic
//   time
// }

// fn serialize_int(int: Int) -> ByteArray {
//   // Convert the integer to bytes (big-endian representation)
//   ByteArray.from_int(int)
// }

// fn serialize_native_scripts(scripts: List<NativeScript>) -> ByteArray {
//   // Replace with actual serialization logic
//   let script_bytes =
//     list.map(scripts, fn(script) { ByteArray.from_string(script.to_string()) })
//   ByteArray.concat(script_bytes)
// }
