import { applyParams, readValidators } from "./utils.ts";
import {
    Blockfrost,
    Constr,
    Data,
    Lucid,
    fromText,
    getAddressDetails,
} from "https://deno.land/x/lucid@0.9.3/mod.ts";
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


const validatos = readValidators();

const { mint, policyId, lockAddress } = applyParams(validatos, lucid);


const utxos = await lucid?.wallet.getUtxos()!;
console.log('UTXOS:', utxos);
console.log('PolicyId:', policyId);
console.log('Script Address:', lockAddress);

const utxo = utxos[0];

const lovelace = 1_000_000;
const tokenName = 'SoulBound#001';
const assetName = `${policyId}${fromText(tokenName)}`;

const msg = fromText("issued");
const mintRedeemer = Data.to(new Constr(0, [msg]));
const beneficiary = getAddressDetails(utxo.address).paymentCredential!.hash;

const datum = Data.to(new Constr(0, [
    beneficiary,
    msg,
    Data.fromJson({
        name: tokenName,
        version: 1
    })
]))

console.log(datum);

const tx = await lucid
    .newTx()
    .collectFrom([utxo])
    // use the mint validator
    .attachMintingPolicy(mint)
    // mint 1 of the asset
    .mintAssets(
        { [assetName]: BigInt(1) },
        // this redeemer is the first argument to the gift_card validator
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
    .complete();
const txSigned = await tx.sign().complete();
console.log(txSigned.toString());

const txHash = await txSigned.submit();
console.log('Tx Id:', txHash);
const success = await lucid.awaitTx(txHash);
console.log('Success?', success);

