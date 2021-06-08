[![CircleCI](https://circleci.com/gh/gelatodigital/uni-v3-lp-static.svg?style=shield&circle-token=4781a26056cdb3529137e8b0f085029cd6323020)](https://app.circleci.com/pipelines/github/gelatodigital/uni-v3-lp-static)
[![Coverage Status](https://coveralls.io/repos/github/gelatodigital/uni-v3-lp/badge.svg?branch=master&t=IlcAEC)](https://coveralls.io/github/gelatodigital/uni-v3-lp?branch=master)

# uni-v3-lp-static

A shared fungible (ERC20) position for Uniswap V3 passive liquidity providers. This pool is auto rebalanced by gelato network to reinvest accrued fees of the position. The position bounds are static and can only be changed by governance/admin. For dynamic auto rebalanced V3 pools see [this repo](https://github.com/gelatodigital/uni-v3-lp-dynamic)

# overview

### mint

```
    function mint(uint256 mintAmount, address receiver)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 liquidityMinted
        )
```

Arguments:

- `mintAmount` amount of G-UNI tokens to mint
- `receiver` account that receives the G-UNI tokens

Returns:

- `amount0` amount of token0 actually deposited into G-UNI
- `amount1` amount of token1 actually deposited into G-UNI
- `liquidityMinted` amount of liqudiity added to G-UNI position

Note: you should always end up depositing either `amount0Max` or `amount1Max` but not necessarily both. Always rely on these return values (or checking balance changes) to see how much was in fact transferred from msg.sender and deposited.

### burn

```
    function burn(uint256 _burnAmount, address _receiver)
        external
        nonReentrant
        returns (
            uint256 amount0,
            uint256 amount1,
            uint128 liquidityBurned
        )
```

- `_burnAmount` number of G-UNI tokens to burn
- `_receiver` account that receives the remitted token0 and token1

Returns:

- `amount0` amount of token0 remitted to \_receiver
- `amount1` amount of token1 remitted to \_receiver
- `liquidityBurned` amount of liquidity burned from G-UNI positon

### rebalance

```
    function rebalance(
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS,
        uint256 _feeAmount,
        address _paymentToken
    ) external gelatofy(_feeAmount, _paymentToken) {
```

Arguments:

- `_swapThresholdPrice` a sqrtPriceX96 which is used as the slippage parameter in uniswap v3 swaps.
- `_swapAmountBPS` amount to swap passed as basis points of current amount of leftover token held (e.g. "swap 50% of balance" would be a value of 5000)
- `_feeAmount` amount that gelato will take as a fee (`GelatoDiamond` checks against gas consumption so bot is not allowed to overcharge)
- `_paymentToken` the token in which `_feeAmount` is collected

Note: This method can only be called by gelato executors

### executiveRebalance

If governance/admin wants to change bounds of the underlying position, or wants to force a rebalance for any other reason, they are allowed to call this executive rebalance function.

```
    function executiveRebalance(
        int24 _newLowerTick,
        int24 _newUpperTick,
        uint160 _swapThresholdPrice,
        uint256 _swapAmountBPS
    ) external onlyOwner {
```

- `_newLowerTick` the tick to use as position lower bound on reinvestment
- `_newUpperTick` the tick to use as position upper bound on reinvestment
- `_swapThresholdPrice` a sqrtPriceX96 which is used as the slippage parameter in uniswap v3 swaps.
- `_swapAmountBPS` amount to swap passed as basis points of current amount of leftover token held (e.g. "swap 50% of balance" would be a value of 5000)

Note: still happy to remove this function if we'd rather it wasn't exposed.

# test

yarn

yarn test
