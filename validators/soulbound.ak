use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/list
use aiken/transaction.{
  DatumHash, InlineDatum, NoDatum, Output, ScriptContext, Spend, Transaction,
  find_datum, find_script_outputs,
} as tx
use aiken/transaction/credential.{
  Address, Credential, ScriptCredential, VerificationKey,
}
use aiken/transaction/value.{
  MintedValue, Value, from_asset, to_minted_value, without_lovelace,
}

type DatumData {
  beneficiary: VerificationKeyHash,
  status: ByteArray,
  metadata: Data,
}

type RedeemerData {
  Mint { msg: ByteArray }
  Burn
}

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

validator(script: Credential) {
  fn mint(redeemer: RedeemerData, ctx: ScriptContext) -> Bool {
    expect ScriptCredential(script_hash) = script
    let ScriptContext { transaction, purpose } = ctx
    expect tx.Mint(policy_id) = purpose
    let Transaction { outputs, mint, .. } = transaction
    expect [(asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(policy_id)
        |> dict.to_list()
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
    when redeemer is {
      Mint(msg) -> {
        let Output { value: val, datum, .. } = output
        expect [(token_name, token_amount)] =
          val
            |> value.tokens(policy_id)
            |> dict.to_list()
        (msg == "issued")? && (asset_name == token_name)? && (amount == token_amount)? && (amount == 1)? && when
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
      Burn -> todo @"burn"
    }
  }
}

validator {
  fn redeem(datum: DatumData, _rdmr: Void, ctx: ScriptContext) -> Bool {
    let DatumData { status, beneficiary, .. }: DatumData = datum
    if status != "issued" {
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
      let output_data = DatumData { ..datum, status: "claimed" }

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
}

fn check_datum(data: Data, msg: ByteArray) -> Bool {
  expect DatumData { status, .. }: DatumData = data
  status == msg
}

// tests

test mint_ok() {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "issued" }
  let metadata = "soulbound"
  let data = DatumData { status: "issued", beneficiary, metadata }
  let val: Value = from_asset(policy_id, asset_name, 1)
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: InlineDatum(data),
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: to_minted_value(val), outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  mint(script, redeemer, context)
}

test mint_wrong_redeemer_msg() fail {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "wrong_redeemer" }
  let metadata = "soulbound"
  let data = DatumData { status: "issued", beneficiary, metadata }
  let val: Value = from_asset(policy_id, asset_name, 1)
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: InlineDatum(data),
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: to_minted_value(val), outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  expect mint(script, redeemer, context)
  False
}

test mint_wrong_datum_msg() fail {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "issued" }
  let metadata = "soulbound"
  let data = DatumData { status: "__issued", beneficiary, metadata }
  let val: Value = from_asset(policy_id, asset_name, 1)
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: InlineDatum(data),
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: to_minted_value(val), outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  expect mint(script, redeemer, context)
  False
}

test mint_wrong_asset_name() fail {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000001"
  let token_name = #"000000"
  let redeemer = Mint { msg: "issued" }
  let metadata = "soulbound"
  let data = DatumData { status: "issued", beneficiary, metadata }
  let val: Value = from_asset(policy_id, asset_name, 1)
  let mintValue: MintedValue =
    to_minted_value(from_asset(policy_id, token_name, 1))
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: InlineDatum(data),
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: mintValue, outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  expect mint(script, redeemer, context)
  False
}

test mint_wrong_quantity() fail {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "issued" }
  let metadata = "soulbound"
  let data = DatumData { status: "issued", beneficiary, metadata }
  let val: Value = from_asset(policy_id, asset_name, 1)
  let mintValue: MintedValue =
    to_minted_value(from_asset(policy_id, asset_name, 2))
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: InlineDatum(data),
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: mintValue, outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  expect mint(script, redeemer, context)
  False
}

test mint_wrong_quantity_negative() fail {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "issued" }
  let metadata = "soulbound"
  let data = DatumData { status: "issued", beneficiary, metadata }
  let val: Value = from_asset(policy_id, asset_name, -1)
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: InlineDatum(data),
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: to_minted_value(val), outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  expect mint(script, redeemer, context)
  False
}

test mint_wrong_quantity_positive() fail {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "issued" }
  let metadata = "soulbound"
  let data = DatumData { status: "issued", beneficiary, metadata }
  let val: Value = from_asset(policy_id, asset_name, 2)
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: InlineDatum(data),
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: to_minted_value(val), outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  expect mint(script, redeemer, context)
  False
}

test mint_wrong_datum_none() fail {
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "issued" }
  let val: Value = from_asset(policy_id, asset_name, 1)
  let output =
    Output {
      address: Address { payment_credential: script, stake_credential: None },
      value: val,
      datum: NoDatum,
      reference_script: None,
    }
  let init_tx = tx.placeholder()
  let placeholder_tx =
    Transaction { ..init_tx, mint: to_minted_value(val), outputs: [output] }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  expect mint(script, redeemer, context)
  False
}
