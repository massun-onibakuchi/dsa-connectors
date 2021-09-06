pragma solidity ^0.7.0;

/**
 * @title BarnBridge Smart Yield.
 * @dev lending: fixed interest rate and variable interest rate
 */

import { TokenInterface } from "../../../common/interfaces.sol";
import { Stores } from "../../../common/stores.sol";
import { Helpers } from "./helpers.sol";
import { Events } from "./events.sol";
import { SmartYieldInterface } from "./interface.sol";

abstract contract BarnBridgeSmartYieldResolver is Events, Helpers {
    /**
     * @dev  enters the junior tranche, buy jTokens
     * @notice jToken,an ERC-20 token that represents ownership in the tranche, are minted at an 1:1 ratio to the underlying asset.
     *  The exchange rate between a jToken and its underlying asset represents the token holder’s gain/loss.
     * @param token The address of the token to deposit.
     * @param sy smart yield contract address.
     * @param amt The amount of the token to deposit. (For max: `uint256(-1)`)
     * @param minTokens minimum output tokens
     * @param deadline deadline timestamp
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokens deposited.
     */
    function buyJuniorTokensRaw(
        address token,
        address sy,
        uint256 amt,
        uint256 minTokens,
        uint256 deadline,
        uint256 getId,
        uint256 setId
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 _amt = getUint(getId, amt);

        SmartYieldInterface smartYield = SmartYieldInterface(sy);
        TokenInterface tokenContract = TokenInterface(token);

        _amt = _amt == uint256(-1) ? tokenContract.balanceOf(address(this)) : _amt;

        approve(tokenContract, smartYield.pool(), _amt);

        uint256 initialBal = tokenContract.balanceOf(address(this));
        smartYield.buyTokens(_amt, minTokens, deadline);
        uint256 finalBal = tokenContract.balanceOf(address(this));

        _amt = sub(initialBal, finalBal);

        setUint(setId, _amt);

        _eventName = "LogBuyJuniorTokens(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(sy, _amt, getId, setId);
    }

    /**
     * @dev  enters the junior tranche, buy jTokens
     * @notice jToken,an ERC-20 token that represents ownership in the tranche, are minted at an 1:1 ratio to the underlying asset.
     *  The exchange rate between a jToken and its underlying asset represents the token holder’s gain/loss.
     * @param tokenId id
     * @param amt The amount of the token to deposit. (For max: `uint256(-1)`)
     * @param minTokens minimum output tokens
     * @param deadline deadline timestamp
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokens deposited.
     */
    function buyJuniorTokens(
        string calldata tokenId,
        uint256 amt,
        uint256 minTokens,
        uint256 deadline,
        uint256 getId,
        uint256 setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, , address smartYield) = bbMapping.getMapping(tokenId);
        (_eventName, _eventParam) = buyJuniorTokensRaw(token, smartYield, amt, minTokens, deadline, getId, setId);
    }

    /**
     * @dev sell jTokens instantly
     * @notice A junior token holder has the option to sell his tokens before maturity,
     *  but he will have to forfeit his potential future gain in order to protect the senior bond holders’ guaranteed gains.
     * @param token The address of the token to withdraw.
     * @param sy smart yield contract address.
     * @param amt The amount of the token to withdraw. (For max: `uint256(-1)`)
     * @param minUnderlying minimum underlying
     * @param deadline deadline timestamp
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokens withdrawn.
     */
    function sellJuniorTokensRaw(
        address token,
        address sy,
        uint256 amt,
        uint256 minUnderlying,
        uint256 deadline,
        uint256 getId,
        uint256 setId
    ) public payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 _amt = getUint(getId, amt);

        SmartYieldInterface smartYield = SmartYieldInterface(sy);
        TokenInterface tokenContract = TokenInterface(token);

        _amt = _amt == uint256(-1) ? smartYield.balanceOf(address(this)) : _amt;

        uint256 _tokenAmt = wdiv(_amt, sub(smartYield.price(), wdiv(smartYield.abondDebt(), smartYield.totalSupply())));

        uint256 initialBal = tokenContract.balanceOf(address(this));
        smartYield.sellTokens(_tokenAmt, minUnderlying, deadline);
        uint256 finalBal = tokenContract.balanceOf(address(this));

        _amt = sub(finalBal, initialBal);

        setUint(setId, _amt);

        _eventName = "LogSellJuniorTokens(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(token, _amt, getId, setId);
    }

    /**
     * @dev sell jTokens instantly
     * @notice A junior token holder has the option to sell his tokens before maturity,
     *  but he will have to forfeit his potential future gain in order to protect the senior bond holders’ guaranteed gains.
     * @param tokenId id
     * @param amt The amount of the token to withdraw. (For max: `uint256(-1)`)
     * @param minTokens minimum output tokens
     * @param deadline deadline timestamp
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokens withdrawn.
     */
    function sellJuniorTokens(
        string calldata tokenId,
        uint256 amt,
        uint256 minTokens,
        uint256 deadline,
        uint256 getId,
        uint256 setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        (address token, , address smartYield) = bbMapping.getMapping(tokenId);
        (_eventName, _eventParam) = sellJuniorTokensRaw(token, smartYield, amt, minTokens, deadline, getId, setId);
    }

    /**
     * @dev Purchase a senior bond
     * @notice A bond carries principal, gain, issuance timestamp, maturity timestamp and liquidation control
     * @param token The address of the underlying ERC20 token to deposit.
     * @param sy smart yield contract address.
     * @param amt The amount of the underlying token to deposit. (For max: `uint256(-1)`)
     * @param minGain minimum gain
     * @param deadline deadline timestamp
     * @param forDays bond life days
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokens deposited.
     */
    function buySeniorBond(
        address token,
        address sy,
        uint256 amt,
        uint256 minGain,
        uint256 deadline,
        uint16 forDays,
        uint256 getId,
        uint256 setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 _amt = getUint(getId, amt);

        SmartYieldInterface smartYield = SmartYieldInterface(sy);
        TokenInterface tokenContract = TokenInterface(token);

        _amt = _amt == uint256(-1) ? tokenContract.balanceOf(address(this)) : _amt;

        approve(tokenContract, smartYield.pool(), _amt);
        uint256 bondId = smartYield.buyBond(_amt, minGain, deadline, forDays);

        setUint(setId, bondId);

        _eventName = "LogBuySeniorBond(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(sy, bondId, getId, setId);
    }

    /**
     * @dev redeem Senior Bond
     * @notice If the bond has reached maturity, the function sends the bond holder principal + gain - fee.
     * @param sy smart yield contract address.
     * @param bondId the ERC721 bond id.
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokens withdrawn.
     */
    function redeemSeniorBond(
        address sy,
        uint256 bondId,
        uint256 getId,
        uint256 setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 _bondId = getUint(getId, bondId);

        SmartYieldInterface smartYield = SmartYieldInterface(sy);

        smartYield.redeemBond(_bondId);

        _eventName = "LogRedeemSeniorBond(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(sy, _bondId, getId, setId);
    }

    /**
     * @dev buy junior Bond. In order to not forfeit his gain,a jToken holder can mint a junior bond using his jTokens, which he can only redeem on maturity.
     * @notice jTokens are transferred to the contract and a junior bond is minted for the user.
     * @param sy smart yield contract address.
     * @param amt The address of the token to deposit.
     * @param maxMaturesAt max bond matures at timestamp
     * @param deadline deadline timestamp
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokens deposited.
     */
    function buyJuniorBond(
        address sy,
        uint256 amt,
        uint256 maxMaturesAt,
        uint256 deadline,
        uint256 getId,
        uint256 setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 _amt = getUint(getId, amt);

        SmartYieldInterface smartYield = SmartYieldInterface(sy);

        _amt = _amt == uint256(-1) ? smartYield.balanceOf(address(this)) : _amt;

        // approve(TokenInterface(sy), sy, _amt);
        uint256 initialBal = smartYield.balanceOf(address(this));
        smartYield.buyJuniorBond(_amt, maxMaturesAt, deadline);
        uint256 finalBal = smartYield.balanceOf(address(this));

        _amt = sub(initialBal, finalBal);

        setUint(setId, _amt);

        _eventName = "LogBuyJuniorBond(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(sy, _amt, getId, setId);
    }

    /**
     * @dev once matured, redeem a jBond for underlying
     * @notice see buyJuniorBond()
     * @param sy smart yield contract address.
     * @param jBondId The bond id
     * @param getId ID to retrieve amt.
     * @param setId ID stores the amount of tokeaarns deposited.
     */
    function redeemJuniorBond(
        address sy,
        uint256 jBondId,
        uint256 getId,
        uint256 setId
    ) external payable returns (string memory _eventName, bytes memory _eventParam) {
        uint256 _jBondId = getUint(getId, jBondId);

        SmartYieldInterface smartYield = SmartYieldInterface(sy);

        smartYield.redeemJuniorBond(jBondId);

        _eventName = "LogRedeemJuniorBond(address,uint256,uint256,uint256)";
        _eventParam = abi.encode(sy, _jBondId, getId, setId);
    }
}

contract ConnectV2BarnBridgeSmartYield is BarnBridgeSmartYieldResolver {
    string public constant name = "BarnBridgeSmartYield-v1.0";
}
