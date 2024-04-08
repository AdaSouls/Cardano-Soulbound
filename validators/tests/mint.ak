use aiken/transaction.{InlineDatum,
  NoDatum, Output, ScriptContext, Transaction} as tx
use aiken/transaction/credential.{Address, ScriptCredential}
use aiken/transaction/value.{MintedValue, Value, from_asset, to_minted_value}
use soulbound/functions.{mint_validator}
use soulbound/types.{DatumData, DatumMetadata, Mint, Policy, Sig}

// tests
test mint_ok() {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  //   scripts: None,
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "Issued" }
  let metadata = DatumMetadata { data: "soulbound", version: 1, extra: None }
  let data = DatumData { status: "Issued", beneficiary, metadata }
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
    Transaction {
      ..init_tx,
      mint: to_minted_value(val),
      outputs: [output],
      extra_signatories: [
        #"00000000000000000000000000000000000000000000000000000000",
      ],
    }
  let context =
    ScriptContext { purpose: tx.Mint(policy_id), transaction: placeholder_tx }
  mint_validator(policy, script, redeemer, context)
}

test mint_wrong_redeemer_msg() fail {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "wrong_redeemer" }
  let metadata = DatumMetadata { data: "soulbound", version: 1, extra: None }
  let data = DatumData { status: "Issued", beneficiary, metadata }
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
  expect mint_validator(policy, script, redeemer, context)
  False
}

test mint_wrong_datum_msg() fail {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "Issued" }
  let metadata = DatumMetadata { data: "soulbound", version: 1, extra: None }
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
  expect mint_validator(policy, script, redeemer, context)
  False
}

test mint_wrong_asset_name() fail {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000001"
  let token_name = #"000000"
  let redeemer = Mint { msg: "Issued" }
  let metadata = DatumMetadata { data: "soulbound", version: 1, extra: None }
  let data = DatumData { status: "Issued", beneficiary, metadata }
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
  expect mint_validator(policy, script, redeemer, context)
  False
}

test mint_wrong_quantity() fail {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "Issued" }
  let metadata = DatumMetadata { data: "soulbound", version: 1, extra: None }
  let data = DatumData { status: "Issued", beneficiary, metadata }
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
  expect mint_validator(policy, script, redeemer, context)
  False
}

test mint_wrong_quantity_negative() fail {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "Issued" }
  let metadata = DatumMetadata { data: "soulbound", version: 1, extra: None }
  let data = DatumData { status: "Issued", beneficiary, metadata }
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
  expect mint_validator(policy, script, redeemer, context)
  False
}

test mint_wrong_quantity_positive() fail {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let beneficiary = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "Issued" }
  let metadata = DatumMetadata { data: "soulbound", version: 1, extra: None }
  let data = DatumData { status: "Issued", beneficiary, metadata }
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
  expect mint_validator(policy, script, redeemer, context)
  False
}

test mint_wrong_datum_none() fail {
  let policy =
    Policy {
      pType: Sig,
      pKeyHash: Some(
        #"00000000000000000000000000000000000000000000000000000000",
      ),
      pSlot: None,
      pRequire: None,
      scripts: None,
    }
  let script =
    ScriptCredential(
      #"00000000000000000000000000000000000000000000000000000000",
    )
  let policy_id = #"00000000000000000000000000000000000000000000000000000000"
  let asset_name = #"000000"
  let redeemer = Mint { msg: "Issued" }
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
  expect mint_validator(policy, script, redeemer, context)
  False
}
