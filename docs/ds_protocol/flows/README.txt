FLOWS
1 Token issuance
2 Token transfer
3 Dividend Distribution
4 Voting


Token issuance: Issuer mints tokens via DSToken, which uses TokenLibrary for custom rules and updates balances in TokenDataStore.

Token Transfer: User transfers tokens; DSToken checks compliance with ComplianceService before TokenLibrary updates balances.

Dividend Distribution: Issuer triggers dividend distribution; DSApp fetches investors from DSToken and notifies them via CommsService.

Voting: Issuer starts vote via DSApp; investors are notified, vote through DSToken, and results are calculated and shared.




src/buidl/DSToken/contracts


@0xe184d6c ➜ .../src/buidl/DSToken/contracts (main) $ tree
.
├── compliance
│   ├── ComplianceConfigurationService.sol
│   ├── ComplianceService.sol
│   ├── ComplianceServiceRegulated.sol
│   ├── ComplianceServiceWhitelisted.sol
│   ├── IDSComplianceConfigurationService.sol
│   ├── IDSComplianceService.sol
│   ├── IDSComplianceServicePartitioned.sol
│   ├── IDSLockManager.sol
│   ├── IDSLockManagerPartitioned.sol
│   ├── IDSPartitionsManager.sol
│   └── IDSWalletManager.sol
├── data-stores
│   ├── ComplianceConfigurationDataStore.sol
│   ├── ComplianceServiceDataStore.sol
│   ├── OmnibusTBEControllerDataStore.sol
│   ├── ServiceConsumerDataStore.sol
│   └── TokenDataStore.sol
├── omnibus
│   ├── IDSOmnibusTBEController.sol
│   ├── IDSOmnibusWalletController.sol
│   └── OmnibusTBEController.sol
├── registry
│   └── IDSRegistryService.sol
├── service
│   ├── IDSServiceConsumer.sol
│   └── ServiceConsumer.sol
├── token
│   ├── DSToken.sol
│   ├── IDSToken.sol
│   ├── IDSTokenPartitioned.sol
│   ├── StandardToken.sol
│   ├── TokenLibrary.sol
│   └── TokenPartitionsLibrary.sol
├── trust
│   └── IDSTrustService.sol
└── utils
    ├── BaseDSContract.sol
    └── CommonUtils.sol