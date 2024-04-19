import { ClaimRedeemer, Credential, DatumMetadata, Policy, applyParams, readValidators } from "./utils.ts";
import {
    Blockfrost,
    Constr,
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
const { redeem, policyId, lockAddress } = applyParams(validators.mint.script, validators.redeem.script, lucid, policy, nonce);


const utxos = await lucid?.wallet.getUtxos()!;
console.log('UTXOS:', utxos);
console.log('PolicyId:', policyId);
console.log('Script Address:', lockAddress);

const utxo = utxos[0];

const lovelace = 1_000_000;
const tokenName = 'SoulboundTest#001';
const assetName = `${policyId}${fromText(tokenName)}`;

const msg = fromText("Claimed");
const beneficiary = getAddressDetails(utxo.address).paymentCredential!.hash;

const data = Data.fromJson({
    [policyId]: {
        [tokenName]: {
            name: tokenName,
            foo: "bar"
        }
    }
})
const d: DatumMetadata = {
    beneficiary,
    status: msg,
    metadata: {
        data,
        version: 1n,
        extra: null
    }
}

const datum = Data.to(d, DatumMetadata);
console.log('Datum', datum);
const claimer: ClaimRedeemer = "ClaimToken";
const claimRedeemer = Data.to(claimer, ClaimRedeemer);

const tokenUtxo: UTxO = {
    address: lockAddress,
    txHash: "4740635c320ffd50bc43f7ec480f4dd97fe890c6ec0536761d7b11c8bf65c814",
    outputIndex: 0,
    assets: { lovelace: BigInt(1_797_270), [assetName]: BigInt(1) },
    datum: "d8799f581c3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da946497373756564d8799fa158383732323562636633613131316263326239653561623962323730663233376364323466663036656634383863623933383166666461386639a151536f756c626f756e645465737423303031a2446e616d6551536f756c626f756e64546573742330303143666f6f4362617201d87a80ffff"
}

const tx = await lucid
    .newTx()
    .collectFrom([utxo, tokenUtxo], claimRedeemer)
    .addSignerKey(beneficiary)
    // consume script
    .attachSpendingValidator(redeem)
    .payToContract(
        lockAddress,
        {
            inline: datum,
        },
        {
            lovelace: BigInt(lovelace),
            [assetName]: BigInt(1)
        }
    )
    .complete();
const txSigned = await tx.sign().complete();
console.log(txSigned.toString());

const txHash = await txSigned.submit();
console.log('Tx Id:', txHash);
const success = await lucid.awaitTx(txHash);
console.log('Success?', success);

