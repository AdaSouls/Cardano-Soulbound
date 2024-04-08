use aiken/transaction.{ScriptContext}
use soulbound/functions.{mint_validator, redeem_validator}
use soulbound/types.{DatumData, MintParams, RedeemerData}

validator(params: MintParams) {
  fn mint(redeemer: RedeemerData, ctx: ScriptContext) -> Bool {
    let MintParams { policy, script, .. } = params
    mint_validator(policy, script, redeemer, ctx)
  }
}

validator {
  fn redeem(datum: DatumData, rdmr: Void, ctx: ScriptContext) -> Bool {
    redeem_validator(datum, rdmr, ctx)
  }
}
