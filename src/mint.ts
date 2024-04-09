import { applyParams, readValidators, MintRedeemer, DatumMetadata, Credential, Policy } from "./utils.ts";
import {
    Blockfrost,
    Data,
    Lucid,
    SpendingValidator,
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
const { mint, policyId, lockAddress } = applyParams(validators.mint.script, validators.redeem.script, lucid, policy, nonce);

const utxos = await lucid?.wallet.getUtxos()!;
console.log('UTXOS:', utxos);
console.log('PolicyId:', policyId);
console.log('Script Address:', lockAddress);

const utxo = utxos[0];

const lovelace = 1_000_000;
const tokenName = 'SoulBound#001';
const assetName = `${policyId}${fromText(tokenName)}`;

const beneficiary = getAddressDetails(utxo.address).paymentCredential!.hash;

const msg = fromText("Issued");
// const mintRedeemer = Data.to(new Constr(0, [msg]));
const minter: MintRedeemer = { Mint: { msg } };
const mintRedeemer = Data.to(minter, MintRedeemer);
console.log('Redeemer:', mintRedeemer);


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

const tx = await lucid
    .newTx()
    .collectFrom([utxo])
    // use the mint validator
    .attachMintingPolicy(mint)
    // mint 1 of the asset
    .mintAssets(
        { [assetName]: BigInt(1) },
        // this redeemer is the first argument
        mintRedeemer
    )
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
    .addSignerKey(signerKey)
    .complete();
const txSigned = await tx.sign().complete();
console.log(txSigned.toString());

const txHash = await txSigned.submit();
console.log('Tx Id:', txHash);
const success = await lucid.awaitTx(txHash);
console.log('Success?', success);
