import { Lucid, MintingPolicy, SpendingValidator, applyParamsToScript, toHex, fromHex, applyDoubleCborEncoding, Data, C } from "https://deno.land/x/lucid@0.10.7/mod.ts";
import blueprint from "../plutus.json" assert { type: "json" };

export type Validators = {
  redeem: SpendingValidator;
  mint: MintingPolicy;
};

export function readValidators(): Validators {
  const redeem = blueprint.validators.find((v) => v.title === "soulbound.redeem");

  if (!redeem) {
    throw new Error("Redeem validator not found");
  }

  const mint = blueprint.validators.find((v) => v.title === "soulbound.mint");

  if (!mint) {
    throw new Error("Mint validator not found");
  }

  return {
    redeem: {
      type: "PlutusV2",
      script: redeem.compiledCode,
    },
    mint: {
      type: "PlutusV2",
      script: mint.compiledCode,
    },
  };
}

export type AppliedValidators = {
  mint: MintingPolicy;
  redeem: SpendingValidator;
  policyId: string;
  lockAddress: string;
};

const ScriptType = Data.Enum([
  Data.Literal("Sig"),
  Data.Literal("All"),
  Data.Literal("Any"),
  Data.Literal("AtLeast"),
  Data.Literal("After"),
  Data.Literal("Before"),
]);
type ScriptType = Data.Static<typeof ScriptType>;

const NativeScript = Data.Object({
  type: ScriptType,
  keyHash: Data.Nullable(Data.Bytes({ minLength: 28, maxLength: 28 })),
  slot: Data.Nullable(Data.Integer()),
  require: Data.Nullable(Data.Integer())
});
type NativeScript = Data.Static<typeof NativeScript>;

const PolicySchema = Data.Object({
  type: ScriptType,
  keyHash: Data.Nullable(Data.Bytes({ minLength: 28, maxLength: 28 })),
  slot: Data.Nullable(Data.Integer()),
  require: Data.Nullable(Data.Integer()),
  scripts: Data.Nullable(Data.Array(NativeScript))
});
export type Policy = Data.Static<typeof PolicySchema>;
export const Policy = PolicySchema as unknown as Policy;

const CredentialSchema = Data.Enum([
  Data.Object({ VerificationKeyCredential: Data.Tuple([Data.Bytes({ minLength: 28, maxLength: 28 })]) }),
  Data.Object({ ScriptCredential: Data.Tuple([Data.Bytes({ minLength: 28, maxLength: 28 })]) }),
]);
export type Credential = Data.Static<typeof CredentialSchema>;
export const Credential = CredentialSchema as unknown as Credential;

const MintSchema = Data.Object({
  policy: PolicySchema,
  script: CredentialSchema,
  nonce: Data.Bytes()
});
type Mint = Data.Static<typeof MintSchema>;
const Mint = MintSchema as unknown as Mint;

const MintRedeemerSchema = Data.Enum([
  Data.Object({ Mint: Data.Object({ msg: Data.Bytes() }) }),
  Data.Literal("Burn")
]);
export type MintRedeemer = Data.Static<typeof MintRedeemerSchema>;
export const MintRedeemer = MintRedeemerSchema as unknown as MintRedeemer;

const ClaimRedeemerSchema = Data.Enum([
  Data.Literal("ClaimToken"),
  Data.Object({ BurnToken: Data.Object({ policy: PolicySchema }) })
]);
export type ClaimRedeemer = Data.Static<typeof ClaimRedeemerSchema>;
export const ClaimRedeemer = ClaimRedeemerSchema as unknown as ClaimRedeemer;

const DatumMetadataSchema = Data.Object({
  policyId: Data.Bytes({ minLength: 32, maxLength: 32 }),
  beneficiary: Data.Bytes(),
  status: Data.Bytes(),
  metadata: Data.Object({
    data: Data.Any(),
    version: Data.Integer(),
    extra: Data.Nullable(Data.Any())
  }),
});
export type DatumMetadata = Data.Static<typeof DatumMetadataSchema>;
export const DatumMetadata = DatumMetadataSchema as unknown as DatumMetadata;

export function applyParams(
  mint_script: string,
  redeem_script: string,
  lucid: Lucid,
  policy: Policy,
  // credential: Credential,
  nonce?: string
): AppliedValidators {

  // const redeemParams = Data.from(Data.to(policy, Policy))
  const redeem: SpendingValidator = {
    type: "PlutusV2",
    script: applyDoubleCborEncoding(redeem_script)
  };
  const lockAddress = lucid.utils.validatorToAddress(redeem);
  const scriptHash = lucid.utils.validatorToScriptHash(redeem);
  const credential: Credential = { ScriptCredential: [scriptHash] };

  const mintParams = Data.from(Data.to({
    policy: policy,
    script: credential,
    nonce: nonce || randomNonce()
  }, Mint));

  const mint: MintingPolicy = {
    type: "PlutusV2",
    script: applyDoubleCborEncoding(applyParamsToScript(mint_script,
      [
        mintParams
      ]
    ))
  };

  const policyId = lucid.utils.validatorToScriptHash(mint);

  return {
    mint,
    redeem,
    policyId,
    lockAddress
  };
}

export function randomNonce(s = 32): string {
  if (s % 2 == 1) {
    throw new Deno.errors.InvalidData("Only even sizes are supported");
  }
  const buf = new Uint8Array(s / 2);
  crypto.getRandomValues(buf);
  let nonce = "";
  for (let i = 0; i < buf.length; ++i) {
    nonce += ("0" + buf[i].toString(16)).slice(-2);
  }
  console.log('Nonce:', nonce);
  return nonce;
}

export function hashPolicy(policy: Policy): string {
  const cborData = Data.to(policy, Policy);
  // console.log('CborData:', cborData);
  return toHex(C.hash_blake2b256(fromHex(cborData)));
}