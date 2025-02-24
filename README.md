# Simple Permit2 Bank

This is a simple bank that users can deposit ERC20 tokens into using Permit2, which they can later withdraw. Normally this requires granting an allowance to the bank contract and then having the bank perform the transferFrom() on the token itself but Permit2 allows us to skip that hassle!

# Getting Started

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [foundry](https://getfoundry.sh/)
  - You'll know you did it right if you can run `forge --version` and you see a response like `forge 0.3.0 (5a8bd89 2024-12-19T17:17:10.245193696Z)`

## Quickstart

```
git clone https://github.com/cqlyj/simple-permit2-demo
cd simple-permit2-demo
make
```

# Usage

1. Set up your environment variables:

```bash
cp .env.example .env
```

1. Fill in the `.env` file with your own values if you want to deploy to a different network.
2. Before running the demo, you need to set up your wallet(For this case we would use the default anvil wallet):

```bash
cast wallet import default --interactive
```

Here I would call it `default`, you can find the private key in the anvil network and a interactive prompt will show as below:

```bash
    Enter private key:
    Enter password:
    `default` keystore was saved successfully. Address: address-corresponding-to-private-key
```

Please keep in mind the password you entered, this will be needed for you moving forward with the private key.

And if you change the name from `default` to something else, you need to update in the `Makefile` as well. Also the `sender` needs to be your address.

```diff
deploy:
-	@forge script script/DeployPermit2.s.sol:DeployPermit2 --rpc-url $(ANVIL_RPC_URL) --account default --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -vvvv
+    @forge script script/DeployPermit2.s.sol:DeployPermit2 --rpc-url $(ANVIL_RPC_URL) --account YOUR_ACCOUNT_NAME --sender YOUR_ADDRESS --broadcast -vvvv
```

Same for any other command in `Makefile` which ask for your account name and sender addresses.

4. Also update the address in `script/Deposit.s.sol`, `script/Withdraw.s.sol` and `script/GetUserTokenAmount.s.sol` with your own address.

In `script/Deposit.s.sol`:

```diff
address constant DEFAULT_ANVIL_WALLET =
-        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
+        YOUR_ADDRESS;
```

In `script/Withdraw.s.sol`:

```diff
address constant DEFAULT_ANVIL_WALLET =
-        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
+        YOUR_ADDRESS;
```

5. Start your anvil chain and run the demo:

```bash
anvil
```

In a new terminal:

```bash
make demo
```

Or any other command you want to run. You can find all the provided commands in the `Makefile`.

If you run into issues like this:

```bash
← [Revert] custom error 0x815e1d64
```

You need to update some addresses in those scripts like the `Permit2` contract address and `token` address. This may happen if you change the address and network other than the default one.

Then you can see the process of deploying the `Permit2` contract and `Permit2Bank` contract, depositing tokens, withdrawing tokens and getting the user token amount.

## Contact

Luo Yingjie - [luoyingjie0721@gmail.com](luoyingjie0721@gmail.com)
