# Uniswap Hooks - Donation

This is a Uniswap Hooks project that allows a Uniswap user to donate away a percentage of their currency when swapping tokens.

It performs this by hooking the afterSwap function and looking at the swap parameters in order to figure out how much to give away.

There can only be one recipient for each user. There is no upper cap for how much a user can give away.

# Build
forge b

# Test
forge test -vvv

# Deploy (in PowerShell)
forge script AfterSwapHookDonationDeployScript  --rpc-url $env:DEPLOY_URL --private-key $env:FOUNDRY_PRIVATE_KEY --broadcast --gas-price 10000000000000000000 -vvv

Chee-Wee, Chua  
12 Sep 2024.


