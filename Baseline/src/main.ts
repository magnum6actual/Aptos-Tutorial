import { Account, FaucetClient, RestClient } from "./utility";
import { readFileSync } from "fs";

const createAndFundAccounts = async () => {
  console.log("\n=== Creating keypairs ===");
  const alice = new Account();
  console.log(`Alice: ${alice.address()}`);
  alice.saveAccount("./.secrets/alice.key");

  const bob = new Account();
  console.log(`Bob: ${bob.address()}`);
  bob.saveAccount("./.secrets/bob.key");

  const tickets = new Account();
  console.log(`Tickets: ${tickets.address()}`);
  tickets.saveAccount("./.secrets/tickets.key");

  const restClient = new RestClient();
  const faucetClient = new FaucetClient(restClient);

  console.log("\n=== Funding accounts ===");
  await faucetClient.fundAccount(alice.pubKey(), 10_000_000);
  await faucetClient.fundAccount(bob.pubKey(), 10_000_000);
  await faucetClient.fundAccount(tickets.pubKey(), 10_000_000);

  console.log("\n=== Initial Balances ===");
  console.log(`Alice: ${await restClient.accountBalance(alice.address())}`);
  console.log(`Bob: ${await restClient.accountBalance(bob.address())}`);
  console.log(`Tickets: ${await restClient.accountBalance(tickets.address())}`);
};

const loadAccounts = async () => {
  console.log("\n=== Loading keypairs ===");
  const alice = new Account("./.secrets/alice.key");
  console.log(`Alice: ${alice.address()}`);

  const bob = new Account("./.secrets/bob.key");
  console.log(`Bob: ${bob.address()}`);

  const tickets = new Account("./.secrets/tickets.key");
  console.log(`Tickets: ${tickets.address()}`);

  const restClient = new RestClient();
  const faucetClient = new FaucetClient(restClient);

  console.log("\n=== Current Balances ===");
  console.log(`Alice: ${await restClient.accountBalance(alice.address())}`);
  console.log(`Bob: ${await restClient.accountBalance(bob.address())}`);
  console.log(`Tickets: ${await restClient.accountBalance(tickets.address())}`);
};

const publishModule = async (modulePath: string, account: Account) => {
  const moduleHex = readFileSync(modulePath).toString("hex");
  console.log("Publishing...");
  const restClient = new RestClient();
  let txHash = await restClient.publishModule(account, moduleHex);
  await restClient.waitForTransaction(txHash);
  console.log("Publish complete.");
};

const publishTicketsModule = () => {
  const tickets = new Account("./.secrets/tickets.key");
  const modulePath = "../Tickets/build/tutorials/bytecode_modules/Tickets.mv";
  publishModule(modulePath, tickets);
};

//createAndFundAccounts();

//loadAccounts();

//publishTicketsModule();
