pragma solidity ^0.7.0;

contract Events {
    // emitted when user buys junior ERC20 tokens
    event LogBuyJuniorTokens(address indexed sy, uint256 amt, uint256 getId, uint256 setId);
    // emitted when user sells junior ERC20 tokens and forfeits their share of the debt
    event LogSellJuniorTokens(address indexed sy, uint256 amt, uint256 getId, uint256 setId);

    event LogBuySeniorBond(address indexed sy, uint256 indexed seniorBondId, uint256 getId, uint256 setId);

    event LogRedeemSeniorBond(address indexed sy, uint256 indexed seniorBondId, uint256 getId, uint256 setId);

    event LogBuyJuniorBond(address indexed sy, uint256 indexed amt, uint256 getId, uint256 setId);

    event LogRedeemJuniorBond(address indexed sy, uint256 indexed juniorBondId, uint256 getId, uint256 setId);
}
