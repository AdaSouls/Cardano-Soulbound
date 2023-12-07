import { Lucid, MintingPolicy, SpendingValidator, applyParamsToScript, toHex, fromHex, Constr, applyDoubleCborEncoding } from "https://deno.land/x/lucid@0.9.3/mod.ts";
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

  const mint = blueprint.validators.find(
    (v) => v.title === "soulbound.mint"
  );

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
  redeem: SpendingValidator;
  mint: MintingPolicy;
  policyId: string;
  lockAddress: string;
};

export function applyParams(
  validators: Validators,
  lucid: Lucid
): AppliedValidators {

  const redeem: SpendingValidator = { 
    type: "PlutusV2", 
    script: applyDoubleCborEncoding(validators.redeem.script) };
  const lockAddress = lucid.utils.validatorToAddress(redeem);
  const scriptHash = lucid.utils.validatorToScriptHash(redeem);

  const credential = new Constr(1, [scriptHash]);
  const mint: MintingPolicy = {
    type: "PlutusV2",
    script: applyDoubleCborEncoding(applyParamsToScript(validators.mint.script, [credential]))
  };

  const policyId = lucid.utils.validatorToScriptHash(mint);

  return {
    redeem,
    mint,
    policyId,
    lockAddress
  };
}