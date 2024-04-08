use aiken/hash.{Blake2b_224, Hash}
use aiken/time.{PosixTime}
use aiken/transaction/credential.{Credential, VerificationKey}

pub type DatumMetadata {
  data: Data,
  version: Int,
  extra: Option<Data>,
}

pub type DatumData {
  beneficiary: VerificationKeyHash,
  status: ByteArray,
  metadata: DatumMetadata,
}

pub type RedeemerData {
  Mint { msg: ByteArray }
  Burn
}

pub type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type ScriptType {
  Sig
  All
  Any
  AtLeast
  After
  Before
}

pub type NativeScript {
  ntype: ScriptType,
  keyHash: Option<VerificationKeyHash>,
  slot: Option<PosixTime>,
  require: Option<Int>,
}

pub type Policy {
  pType: ScriptType,
  pKeyHash: Option<VerificationKeyHash>,
  pSlot: Option<PosixTime>,
  pRequire: Option<Int>,
  scripts: Option<List<NativeScript>>,
}

pub type MintParams {
  policy: Policy,
  script: Credential,
  // random value to generate different policy when policy and credentails are the same
  nonce: ByteArray,
}
