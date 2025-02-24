-include .env

all : install build

build :; @forge build

install:
	@forge install uniswap/permit2 --no-commit && forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-commit 

slither:
	@slither . --config-file ./slither.config.json --skip-assembly

# `default` is the first account in the local anvil network

deployPermit2:
	@forge script script/DeployPermit2.s.sol:DeployPermit2 --rpc-url $(ANVIL_RPC_URL) --account default --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --broadcast -vvvv

deployPermit2Bank:
	@forge script script/DeployPermit2Bank.s.sol:DeployPermit2Bank --rpc-url $(ANVIL_RPC_URL) --account default --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --broadcast -vvvv

deposit:
	@forge script script/Deposit.s.sol:Deposit --rpc-url $(ANVIL_RPC_URL) --account default --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --broadcast -vvvv

get-user-token-amount:
	@forge script script/GetUserTokenAmount.s.sol:GetUserTokenAmount --rpc-url $(ANVIL_RPC_URL) --account default --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --broadcast -vvvv

withdraw:
	@forge script script/Withdraw.s.sol:Withdraw --rpc-url $(ANVIL_RPC_URL) --account default --sender 0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266 --broadcast -vvvv

demo : deployPermit2 deployPermit2Bank deposit get-user-token-amount withdraw get-user-token-amount