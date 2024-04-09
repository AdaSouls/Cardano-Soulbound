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
console.log('Redeemer:', mintRedeemer);

const tokenUtxo: UTxO = {
    address: lockAddress,
    txHash: "14de38d13a5b354441e9a4ba2700d6e30ed4142f79533b2e312b082f68c6e3ec",
    outputIndex: 0,
    assets: { lovelace: BigInt(1_749_860), [assetName]: BigInt(1) },
    datum: "d8799f581c3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da947436c61696d6564d8799fa158386362353965303338636466303536373764303065353365363937356434363133626134306236626637396434626639326337643139383563a14d536f756c426f756e6423303031a2446e616d654d536f756c426f756e642330303143666f6f4362617201d87a80ffff"
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
    // .payToContract(
    //     lockAddress,
    //     {
    //         inline: datum,
    //     },
    //     {
    //         lovelace: BigInt(lovelace),
    //         [assetName]: BigInt(1)
    //     }
    // )
    .addSignerKey(signerKey)
    .complete();
const txSigned = await tx.sign().complete();
console.log(txSigned.toString());

const txHash = await txSigned.submit();
console.log('Tx Id:', txHash);
const success = await lucid.awaitTx(txHash);
console.log('Success?', success);
