# Canxium Bridge Contracts

Smart contract of Canxium Bridge V1.

Include two contracts, one for Canxium main chain and one for side chain. By default, only 30% of the coin/token deposited to contract are
under control of operator wallet and can be release directly. The rest need to be approved by admin wallet to increase security.

The entire balance will be transferred to the Bridge V2 contract via the Withdraw function to become truly decentralized bridge soon.

Deployment steps:
```shell
npx hardhat compile
npx hardhat run scripts/deploy.ts
```
