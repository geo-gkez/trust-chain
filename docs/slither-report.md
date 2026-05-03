**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [timestamp](#timestamp) (2 results) (Low)
## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-0
[TrustChain.createBatch(bytes32,uint8,Category,uint8,uint128,bytes32,uint48)](src/TrustChain.sol#L115-L151) uses timestamp for comparisons
	Dangerous comparisons:
	- [expiryDate != 0 && expiryDate < block.timestamp](src/TrustChain.sol#L129)

src/TrustChain.sol#L115-L151


 - [ ] ID-1
[TrustChain._registerUser(address,bytes32,Role)](src/TrustChain.sol#L232-L239) uses timestamp for comparisons
	Dangerous comparisons:
	- [users[account].ethAddress != address(0)](src/TrustChain.sol#L234)

src/TrustChain.sol#L232-L239


