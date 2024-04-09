use aiken/dict
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
          check_datum(data, msg)?
        }
        InlineDatum(data) -> check_datum(data, msg)?
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
  policy: Policy,
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
    BurnToken -> {
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

fn check_datum(data: Data, msg: ByteArray) -> Bool {
  expect DatumData { status, .. }: DatumData = data
  status == msg
}
