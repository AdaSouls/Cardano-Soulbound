import { applyParams, readValidators, MintRedeemer, DatumMetadata, Credential, Policy, ClaimRedeemer } from "./utils.ts";
import {
    Blockfrost,
    Data,
    Lucid,
    SpendingValidator,
    UTxO,
    applyDoubleCborEncoding,
    fromText,
    getAddressDetails,
} from "https://deno.land/x/lucid@0.10.7/mod.ts";
import { load } from "https://deno.land/std@0.208.0/dotenv/mod.ts";

const env = await load();

const lucid = await Lucid.new(
    new Blockfrost(
        "https://cardano-preview.blockfrost.io/api/v0",
        env["BLOCKFROST_PROJECT_ID"]
    ),
    "Preview"
);

lucid.selectWalletFromPrivateKey(await Deno.readTextFile("./me.sk"));
const addr = await Deno.readTextFile("./me.addr");

const validators = readValidators();

const signerKey = lucid.utils.getAddressDetails(addr).paymentCredential!.hash
const policy: Policy = {
    type: 'All',
    scripts: [
        {
            type: 'Sig',
            keyHash: signerKey,
            slot: null,
            require: null
        }
    ],
    keyHash: null,
    slot: null,
    require: null,
};

const nonce = "9565b074c5c930aff80cac59a2278b70";
const { mint, redeem, policyId, lockAddress } = applyParams(validators.mint.script, validators.redeem.script, lucid, policy, nonce);

const utxos = await lucid?.wallet.getUtxos()!;
console.log('UTXOS:', utxos);
console.log('PolicyId:', policyId);
console.log('Script Address:', lockAddress);

const utxo = utxos[0];

const tokenName = 'SoulboundTest#001';
const assetName = `${policyId}${fromText(tokenName)}`;

const minter: MintRedeemer = "Burn";
const mintRedeemer = Data.to(minter, MintRedeemer);
const claimer: ClaimRedeemer = { BurnToken: { policy } };
const claimRedeemer = Data.to(claimer, ClaimRedeemer);

const tokenUtxo: UTxO = {
    address: lockAddress,
    txHash: "265b849d27d66340aab24d338eddef6cbbd0ac1dd24393b1d45554da08216186",
    outputIndex: 0,
    assets: { lovelace: BigInt(1_948_120), [assetName]: BigInt(1) },
    datum: "d8799f58209ebffc56dfcbcff39113378280d535430f768b0821bbd293f7a4546bb8d73fa8581c3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da947436c61696d6564d8799fa158383636366438663831396165666162383666313635646432343961626436646365623234613133386536363432336137326630326162613935a151536f756c626f756e645465737423303031a2446e616d6551536f756c626f756e64546573742330303143666f6f4362617201d87a80ffff"
}

const validTo = Date.now() + (60 * 60 * 24 * 1000); // 1 day
const tx = await lucid
    .newTx()
    .collectFrom([utxo, tokenUtxo], claimRedeemer)
    // use the mint validator
    .attachMintingPolicy(mint)
    // burn 1 of the asset
    .mintAssets(
        { [assetName]: BigInt(-1) },
        // this redeemer is the first argument
        mintRedeemer
    )
    .attachSpendingValidator(redeem)
    .addSignerKey(signerKey)
    .validTo(validTo)
    .complete();
const txSigned = await tx.sign().complete();
console.log(txSigned.toString());

const txHash = await txSigned.submit();
console.log('Tx Id:', txHash);
const success = await lucid.awaitTx(txHash);
console.log('Success?', success);
