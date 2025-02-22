-include .env

install:
	@forge install uniswap/permit2 --no-commit && forge install OpenZeppelin/openzeppelin-contracts@v5.2.0 --no-commit

slither:
	@slither . --config-file ./slither.config.json --skip-assembly