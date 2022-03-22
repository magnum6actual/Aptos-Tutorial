// Copyright (c) The Aptos Foundation
// SPDX-License-Identifier: Apache-2.0

import { sha3_256 } from "js-sha3";
import fetch from "cross-fetch";
import { SignKeyPair, sign } from "tweetnacl";
import assert from "assert";
import { writeFileSync, readFileSync } from "fs";

export const TESTNET_URL = "https://fullnode.devnet.aptoslabs.com";
export const FAUCET_URL = "https://faucet.devnet.aptoslabs.com";

/** A subset of the fields of a TransactionRequest, for this tutorial */
export type TxnRequest = Record<string, any> & { sequence_number: string };

/** Represents an account as well as the private, public key-pair for the Aptos blockchain */
export class Account {
  signingKey: SignKeyPair;

  constructor(path: string = "", seed?: Uint8Array | undefined) {
    if (seed) {
      this.signingKey = sign.keyPair.fromSeed(seed);
    } else if (path) {
      this.signingKey = this.loadAccount(path);
    } else {
      this.signingKey = sign.keyPair();
    }
  }

  /** Returns the address associated with the given account */
  address(): string {
    return this.authKey().slice(-32);
  }

  /** Returns the authKey for the associated account */
  authKey(): string {
    let hash = sha3_256.create();
    hash.update(Buffer.from(this.signingKey.publicKey));
    hash.update("\x00");
    return hash.hex();
  }

  /** Returns the public key for the associated account */
  pubKey(): string {
    return Buffer.from(this.signingKey.publicKey).toString("hex");
  }

  saveAccount(path: string) {
    // saving as a string to make file human readable
    writeFileSync(path, this.signingKey.secretKey.toString());
  }

  loadAccount(path: string): SignKeyPair {
    // readable file incurs more work to load back to keypair
    const content = readFileSync(path).toString();
    const keyArray = Uint8Array.from(
      content.split(",").map((value) => {
        return parseInt(value);
      })
    );
    return sign.keyPair.fromSecretKey(Buffer.from(keyArray));
  }
}

/** A wrapper around the Aptos-core Rest API */
export class RestClient {
  url: string;

  constructor(url: string = "") {
    if (url) {
      this.url = url;
    } else {
      this.url = TESTNET_URL;
    }
  }

  /** Returns the sequence number and authentication key for an account */
  async account(accountAddress: string): Promise<Record<string, string> & { sequence_number: string }> {
    const response = await fetch(`${this.url}/accounts/${accountAddress}`, { method: "GET" });
    if (response.status != 200) {
      assert(response.status == 200, await response.text());
    }
    return await response.json();
  }

  /** Returns all resources associated with the account */
  async accountResources(accountAddress: string): Promise<Record<string, any> & { type: string }> {
    const response = await fetch(`${this.url}/accounts/${accountAddress}/resources`, { method: "GET" });
    if (response.status != 200) {
      assert(response.status == 200, await response.text());
    }
    return await response.json();
  }

  /** Publish a new module to the blockchain within the specified account */
  async publishModule(accountFrom: Account, moduleHex: string): Promise<string> {
    const payload = {
      type: "module_bundle_payload",
      modules: [{ bytecode: `0x${moduleHex}` }],
    };
    const txnRequest = await this.generateTransaction(accountFrom.address(), payload);
    const signedTxn = await this.signTransaction(accountFrom, txnRequest);
    const res = await this.submitTransaction(accountFrom, signedTxn);
    return res["hash"];
  }

  /** Generates a transaction request that can be submitted to produce a raw transaction that
   can be signed, which upon being signed can be submitted to the blockchain. */
  async generateTransaction(sender: string, payload: Record<string, any>): Promise<TxnRequest> {
    const account = await this.account(sender);
    const seqNum = parseInt(account["sequence_number"]);
    return {
      sender: `0x${sender}`,
      sequence_number: seqNum.toString(),
      max_gas_amount: "1000",
      gas_unit_price: "1",
      gas_currency_code: "XUS",
      // Unix timestamp, in seconds + 10 minutes
      expiration_timestamp_secs: (Math.floor(Date.now() / 1000) + 600).toString(),
      payload: payload,
    };
  }

  /** Converts a transaction request produced by `generate_transaction` into a properly signed
   transaction, which can then be submitted to the blockchain. */
  async signTransaction(accountFrom: Account, txnRequest: TxnRequest): Promise<TxnRequest> {
    const response = await fetch(`${this.url}/transactions/signing_message`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(txnRequest),
    });
    if (response.status != 200) {
      assert(response.status == 200, (await response.text()) + " - " + JSON.stringify(txnRequest));
    }
    const result: Record<string, any> & { message: string } = await response.json();
    const toSign = Buffer.from(result["message"].substring(2), "hex");
    const signature = sign(toSign, accountFrom.signingKey.secretKey);
    const signatureHex = Buffer.from(signature).toString("hex").slice(0, 128);
    txnRequest["signature"] = {
      type: "ed25519_signature",
      public_key: `0x${accountFrom.pubKey()}`,
      signature: `0x${signatureHex}`,
    };
    return txnRequest;
  }

  /** Submits a signed transaction to the blockchain. */
  async submitTransaction(accountFrom: Account, txnRequest: TxnRequest): Promise<Record<string, any>> {
    const response = await fetch(`${this.url}/transactions`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(txnRequest),
    });
    if (response.status != 202) {
      assert(response.status == 202, (await response.text()) + " - " + JSON.stringify(txnRequest));
    }
    return await response.json();
  }

  async transactionPending(txnHash: string): Promise<boolean> {
    const response = await fetch(`${this.url}/transactions/${txnHash}`, { method: "GET" });
    if (response.status == 404) {
      return true;
    }
    if (response.status != 200) {
      assert(response.status == 200, await response.text());
    }
    return (await response.json())["type"] == "pending_transaction";
  }

  /** Waits up to 10 seconds for a transaction to move past pending state */
  async waitForTransaction(txnHash: string) {
    let count = 0;
    while (await this.transactionPending(txnHash)) {
      assert(count < 10);
      await new Promise((resolve) => setTimeout(resolve, 1000));
      count += 1;
      if (count >= 10) {
        throw new Error(`Waiting for transaction ${txnHash} timed out!`);
      }
    }
  }

  /** Returns the test coin balance associated with the account */
  async accountBalance(accountAddress: string): Promise<number | null> {
    const resources = await this.accountResources(accountAddress);
    for (const key in resources) {
      const resource = resources[key];
      if (resource["type"] == "0x1::TestCoin::Balance") {
        return parseInt(resource["data"]["coin"]["value"]);
      }
    }
    return null;
  }

  /** Transfer a given coin amount from a given Account to the recipient's account address.
   Returns the sequence number of the transaction used to transfer. */
  async transfer(accountFrom: Account, recipient: string, amount: number): Promise<string> {
    const payload: { function: string; arguments: string[]; type: string; type_arguments: any[] } = {
      type: "script_function_payload",
      function: "0x1::TestCoin::transfer",
      type_arguments: [],
      arguments: [`0x${recipient}`, amount.toString()],
    };
    const txnRequest = await this.generateTransaction(accountFrom.address(), payload);
    const signedTxn = await this.signTransaction(accountFrom, txnRequest);
    const res = await this.submitTransaction(accountFrom, signedTxn);
    return res["hash"].toString();
  }
}

/** Faucet creates and funds accounts. This is a thin wrapper around that. */
export class FaucetClient {
  url: string;
  restClient: RestClient;

  constructor(restClient: RestClient, url: string = "") {
    if (url) {
      this.url = url;
    } else {
      this.url = FAUCET_URL;
    }
    this.restClient = restClient;
  }

  /** This creates an account if it does not exist and mints the specified amount of
   coins into that account */
  async fundAccount(pubKey: string, amount: number) {
    const url = `${this.url}/mint?amount=${amount}&pub_key=${pubKey}`;
    const response = await fetch(url, { method: "POST" });
    if (response.status != 200) {
      assert(response.status == 200, await response.text());
    }
    const tnxHashes = (await response.json()) as Array<string>;
    for (const tnxHash of tnxHashes) {
      await this.restClient.waitForTransaction(tnxHash);
    }
  }
}
