**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [timestamp](#timestamp) (3 results) (Low)
## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-0
[TrustChain.createBatch(bytes32,uint8,Category,uint8,uint128,bytes32,uint48)](src/TrustChain.sol#L118-L154) uses timestamp for comparisons
	Dangerous comparisons:
	- [expiryDate != 0 && expiryDate < block.timestamp](src/TrustChain.sol#L132)

src/TrustChain.sol#L118-L154


 - [ ] ID-1
[TrustChain._registerUser(address,bytes32,Role)](src/TrustChain.sol#L254-L261) uses timestamp for comparisons
	Dangerous comparisons:
	- [users[account].ethAddress != address(0)](src/TrustChain.sol#L256)

src/TrustChain.sol#L254-L261


 - [ ] ID-2
[TrustChain._transition(Batch,bytes32,Status,bytes32)](src/TrustChain.sol#L289-L301) uses timestamp for comparisons
	Dangerous comparisons:
	- [b.expiryDate != 0 && b.expiryDate < block.timestamp](src/TrustChain.sol#L294)

src/TrustChain.sol#L289-L301


