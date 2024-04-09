use aiken/transaction.{ScriptContext}
use soulbound/functions.{mint_validator, redeem_validator}
use soulbound/types.{
  ClaimRedeemerData, DatumData, MintParams, Policy, RedeemerData,
}

validator(params: MintParams) {
  fn mint(redeemer: RedeemerData, ctx: ScriptContext) -> Bool {
    let MintParams { policy, script, .. } = params
    mint_validator(policy, script, redeemer, ctx)
  }
}

validator(policy: Policy) {
  fn redeem(
    datum: DatumData,
    rdmr: ClaimRedeemerData,
    ctx: ScriptContext,
  ) -> Bool {
    redeem_validator(policy, datum, rdmr, ctx)
  }
}
