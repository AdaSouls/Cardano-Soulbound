# Cardano Soulbound

In this repo you'll find the smart contracts for [Soulbound-CIP](https://github.com/AdaSouls/CIPs/tree/master/CIP-0888). All soulbound collections can specify a set of rules to restrict who, how and when tokens can be minted/claimed/burnt. Such rules are the equivalent to a native script meaning you can specify signers (e.g. All, Any, AtLeast, One) and before and after time constraint. Furthemore tokens metadata should have a `beneficiary` who can claim the token and a status (either `Issued` or `Claimed`). Tokens can only be claimend by the `beneficiary` with status `Issued`.

Normal flow starts minting the token which will have declared the `beneficiary` and status `Issued`. Then beneficiary can claim the token to start owning it. Tokens can be removed if the policy rules in the collection are met at any time (whether the token is claimed or not).


Smart Contracts code is based on aiken (`aiken-lang/stdlib v1.7.0`) and are parameterized, meaning you'll need to specify the policy restrictions for your collection which will effectively create the unique policy id for it. See the offchain section for more details.

## Building

```sh
aiken build
```

## Testing

To run all smart contract tests, simply do:

```sh
aiken check
```
### Offchain tests

Offchain code depends on [Deno](https://deno.com/) although you can make the neccessary modifications to run it with Nodejs.

These tests are targeting `preview` network by default but you can change to any other network you want, just make sure the wallet is changed as well and have enough funds to perform transactions and lock ADA with tokens.

Before running the test you'll need to create three files: `.env`, `me.sk` and `me.addr`.

`.env` file will have a valid Blockfrost project id (default `preview`):

```sh
BLOCKFROST_PROJECT_ID=preview123...
```
The other two files corresponding to a cardano wallet the code will be using to build/sign transactions.

`me.sk` is the private key for the address used on each transaction. `me.addr` is the file having the address itself. There is a script called `generate-credentials.ts` at root dir in this repo which you can run in order to get those files (`deno run --allow-net --allow-write generate-credentials.ts`)

`me.sk`
```sh
ed25519_sk1...
```

`me.addr`
```sh
addr_test1...
```
### Getting funds

Once you have an address to use you just need to add some funds to it. In this demo we'll show you how you can get funds from  [the Cardano faucet](https://docs.cardano.org/cardano-testnet/tools/faucet) on the `preview` network to our newly created address (inside `me.addr`).

> [!WARNING]
> Make sure to select "Preview Testnet" as network.

You'll find three typecript files inside `src` folder responsables of `mint`, `claim` and `burn` souldbound tokens.

Here are an example of how you can run any of them:
```sh
deno run --allow-all src/mint.ts 
deno run --allow-all src/claim.ts 
deno run --allow-all src/burn.ts 
```
> [!WARNING]
> Don't run all scripts at once! Script for claim and burn need to manually setup the token UTxO in order to use refer to it in the transaction.

First we're going to mint a new soulbound token:
```sh
deno run --allow-all src/mint.ts 
```
The script above will finished indicating the transaction was submitted successfuly and providing the transaction id to inspect on any network explorer:
```sh
Tx Id: 4740635c320ffd50bc43f7ec480f4dd97fe890c6ec0536761d7b11c8bf65c814
Success? true
```

Get the transaction id and navigate to [cardanoscan tx](https://preview.cardanoscan.io/transaction/4740635c320ffd50bc43f7ec480f4dd97fe890c6ec0536761d7b11c8bf65c814). You'll find the new token minted there
![Screen Shot 2024-04-19 at 2 33 45 PM](https://github.com/AdaSouls/Cardano-Soulbound/assets/16786232/68863c3d-a106-45aa-8884-4be57e9c9d31)


> [!NOTE]
> Sometimes network explores takes a while to reflect new transactions

On Cardanoscan UTxO transaction's section you'll find something like this, showing the new token locked into the smart contract address with a datum representing the token's metadata (See more about metadata here: [Soulbound-CIP](https://github.com/AdaSouls/CIPs/tree/master/CIP-0888)). The metadata in our case looks like this:

```json
{
    "beneficiary": "3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da9", // this is the address payment credential hash
    "status": "Issued",
    "metadata": {
        "data": {
          "7225bcf3a111bc2b9e5ab9b270f237cd24ff06ef488cb9381ffda8f9": {
              "SoulboundTest#001": {
                  "name": "SoulboundTest#001",
                  "foo": "bar"
              }
          }
        },
        "version": 1,
    }
}
```

In order to claim the token you need to run `src/claim.ts` script. But before doing that we need to change the UTxO to the token we just minted. Change code from line 87-93 according to your data:
```ts
const tokenUtxo: UTxO = {
    address: lockAddress,
    txHash: "4740635c320ffd50bc43f7ec480f4dd97fe890c6ec0536761d7b11c8bf65c814",
    outputIndex: 0,
    assets: { lovelace: BigInt(1_797_270), [assetName]: BigInt(1) },
    datum: "d8799f581c3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da946497373756564d8799fa158383732323562636633613131316263326239653561623962323730663233376364323466663036656634383863623933383166666461386639a151536f756c626f756e645465737423303031a2446e616d6551536f756c626f756e64546573742330303143666f6f4362617201d87a80ffff"
}
```

> [!WARNING]
> Pay special attention to the amount of lovelace locked in the UTxO (`1797270` in this case)

Once the data corresponding to the token's UTxO is set, we are ready to claim the token. This code assume the beneficiary added when token was minted is the same address we are using for build all transactions (address inside `me.addr`)
```sh
deno run --allow-all src/claim.ts 
```

Output will be similar to this:
```sh
Tx Id: 445a2487e25b629691a32114b68f13b31e27bdd0dfc3380f8b221a272ace866d
Success? true
```
[cardanoscan tx](https://preview.cardanoscan.io/transaction/445a2487e25b629691a32114b68f13b31e27bdd0dfc3380f8b221a272ace866d)
![Screen Shot 2024-04-19 at 2 55 46 PM](https://github.com/AdaSouls/Cardano-Soulbound/assets/16786232/fd8474f1-4c10-444e-b4ec-b4fc8d32b83c)


New transaction will have the token with the new metadata:
```json
{
    "beneficiary": "3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da9", // this is the address payment credential hash
    "status": "Claimed",
    "metadata": {
        "data": {
          "7225bcf3a111bc2b9e5ab9b270f237cd24ff06ef488cb9381ffda8f9": {
              "SoulboundTest#001": {
                  "name": "SoulboundTest#001",
                  "foo": "bar"
              }
          }
        },
        "version": 1,
    }
}
```

Finally we're going to burn the token. To do so we need to follow the same process we did when claiming the token, meaning we need to find the last UTxO (the one associated with the claim transaction) and update `src/burn.ts` with that info.

Update `burn.ts` code from line 63 to 69 with your data:
```ts
const tokenUtxo: UTxO = {
    address: lockAddress,
    txHash: "445a2487e25b629691a32114b68f13b31e27bdd0dfc3380f8b221a272ace866d",
    outputIndex: 0,
    assets: { lovelace: BigInt(1_801_580), [assetName]: BigInt(1) },
    datum: "d8799f581c3dce7844f36b23b8c3f90afba40aa188e7f1d3f6e8acd1d544ed1da947436c61696d6564d8799fa158383732323562636633613131316263326239653561623962323730663233376364323466663036656634383863623933383166666461386639a151536f756c626f756e645465737423303031a2446e616d6551536f756c626f756e64546573742330303143666f6f4362617201d87a80ffff"
}
```
After the UTxO is ready we just need to run the script:
```sh
deno run --allow-all src/burn.ts 
```
Resulot will show the transaction id as well
```sh
Tx Id: 008c73029e5c5bb48b8afa664db16a7fa5cfeec68ccbb1a7654028ed2bd5d260
Success? true
```

After that transaction is confirmed the token will be effectively removed from the blockchain [cardanoscan tx](https://preview.cardanoscan.io/transaction/008c73029e5c5bb48b8afa664db16a7fa5cfeec68ccbb1a7654028ed2bd5d260). 
![Screen Shot 2024-04-19 at 4 11 52 PM](https://github.com/AdaSouls/Cardano-Soulbound/assets/16786232/e835db51-52a9-4c5a-9dad-bd5d348c0ef9)
![Screen Shot 2024-04-19 at 4 12 07 PM](https://github.com/AdaSouls/Cardano-Soulbound/assets/16786232/ff96a067-1387-4de8-954a-9ef38c1b08e1)
