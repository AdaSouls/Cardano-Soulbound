import { applyParams, readValidators } from "./utils.ts";
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
const addr = await Deno.readTextFile("./me.addr");

const validators = readValidators();
const redeem: SpendingValidator = {
    type: "PlutusV2",
    script: applyDoubleCborEncoding(validators.redeem.script)
};
const lockAddress = lucid.utils.validatorToAddress(redeem);
const scriptHash = lucid.utils.validatorToScriptHash(redeem);
const credential = new Constr(1, [scriptHash]);
const policy = {
    type: 'All',
    scripts: [
        {
            type: 'Sig',
            keyHash: lucid.utils.getAddressDetails(addr).paymentCredential?.hash,
            slot: null,
            require: null
        }
    ],
    keyHash: null,
    slot: null,
    require: null,
};

const { policyId } = applyParams(validators.mint.script, lucid, policy, credential);


const utxos = await lucid?.wallet.getUtxos()!;
console.log('UTXOS:', utxos);
console.log('PolicyId:', policyId);
console.log('Script Address:', lockAddress);

const utxo = utxos[0];

const lovelace = 1_000_000;
const tokenName = 'SoulBound#001';
const assetName = `${policyId}${fromText(tokenName)}`;

const msg = fromText("claimed");
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

const scriptUtxo: UTxO = {
    address: lockAddress,
    txHash: "b85d023ae8c8c2d65edbeee2211122c1e0687129a777e39a6b481db469bb3750",
    outputIndex: 0,
    assets: { lovelace: BigInt(1_396_440), [assetName]: BigInt(1) },
    datum: "d8799f581c3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da946697373756564a2446e616d654d536f756c426f756e64233030314776657273696f6e01ff"
}

const tx = await lucid
    .newTx()
    .collectFrom([utxo, scriptUtxo], Data.void())
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

