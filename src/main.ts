import { Account } from "./utility";

const alice = new Account();
alice.saveAccount("./.secrets/alice.key");

const bob = new Account();
bob.saveAccount("./.secrets/bob.key");

const tickets = new Account();
tickets.saveAccount("./.secrets/tickets.key");
