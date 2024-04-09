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

const nonce = "9565b074c5c930aff80cac59a2278b68";
const { mint, redeem, policyId, lockAddress } = applyParams(validators.mint.script, validators.redeem.script, lucid, policy, nonce);

const utxos = await lucid?.wallet.getUtxos()!;
console.log('UTXOS:', utxos);
console.log('PolicyId:', policyId);
console.log('Script Address:', lockAddress);

const utxo = utxos[0];

const tokenName = 'SoulBound#001';
const assetName = `${policyId}${fromText(tokenName)}`;

const minter: MintRedeemer = "Burn";
const mintRedeemer = Data.to(minter, MintRedeemer);
const claimer: ClaimRedeemer = "BurnToken";
const claimRedeemer = Data.to(claimer, ClaimRedeemer);

const tokenUtxo: UTxO = {
    address: lockAddress,
    txHash: "20618798cabdd8fc91756b3865c73b699c90ed3c343eaf11ada229c398ae2777",
    outputIndex: 0,
    assets: { lovelace: BigInt(1_749_860), [assetName]: BigInt(1) },
    datum: "d8799f581c3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da947436c61696d6564d8799fa158383732323562636633613131316263326239653561623962323730663233376364323466663036656634383863623933383166666461386639a14d536f756c426f756e6423303031a2446e616d654d536f756c426f756e642330303143666f6f4362617201d87a80ffff"
}

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
    .complete();
const txSigned = await tx.sign().complete();
console.log(txSigned.toString());

const txHash = await txSigned.submit();
console.log('Tx Id:', txHash);
const success = await lucid.awaitTx(txHash);
console.log('Success?', success);
