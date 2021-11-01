// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract TokenFarm is Ownable {
    // stake token
    // unstake token
    // issue token
    // add allowed token
    // get ETH price

    address[] public allowedTokens;
    // mapping token address > staker address > token amount
    mapping(address => mapping(address => uint256)) public stakingBalance;
    // mapping user address > uniquetoken staked
    mapping(address => uint256) public uniqueTokenStaked;
    // mapping token > pricefeed
    mapping(address => address) public tokenPriceFeedMapping;
    // staker address
    address[] public stakers;
    IERC20 public dappToken;

    constructor(address _dappTokenAddress) public {
        dappToken = IERC20(_dappTokenAddress);
    }

    function setPriceFeedContract(address _token, address _priceFeed)
        public
        onlyOwner
    {
        tokenPriceFeedMapping[_token] = _priceFeed;
    }

    function stakeToken(address _token, uint256 _amount) public {
        // how much they stake
        // what kind of token, whether allowed token
        require(tokenIsAllowed(_token), "This token is not allowed");
        require(
            _amount > 0,
            "The amount should be greater than minimum amount"
        );
        // We don't own the ecr20 contract, we need transferFrom of IERC20 interface, via _token address
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        // get how many unique staked tokens they have, if one add, we add them to the list, if more than 1, we don't need.
        updateUniqueTokenStaked(msg.sender, _token);
        // staking balance
        stakingBalance[_token][msg.sender] =
            stakingBalance[_token][msg.sender] +
            _amount;
        // If this the first time, add user to staker list
        if (uniqueTokenStaked[msg.sender] == 1) {
            stakers.push(msg.sender);
        }
    }

    // issue reward token
    function issueToken() public onlyOwner {
        // what kind of token to issue
        // how much token should issue
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address recipient = stakers[stakersIndex];
            uint256 userTotalStakedValue = getUserTotalStakedValue(recipient);
            dappToken.transfer(recipient, userTotalStakedValue);
        }
    }

    function unstakeToken(address _token) public {
        uint256 balance = stakingBalance[_token][msg.sender];
        require(balance > 0, "Staking balance cannot be 0");
        IERC20(_token).transfer(msg.sender, balance);
        stakingBalance[_token][msg.sender] = 0;
        uniqueTokenStaked[msg.sender] = uniqueTokenStaked[msg.sender] - 1;
    }

    function getUserTotalStakedValue(address _user)
        public
        view
        returns (uint256)
    {
        uint256 totalValue = 0;
        require(uniqueTokenStaked[_user] > 0, "No token staked");
        // loop each allowedtoken
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            totalValue =
                totalValue +
                getUserSingleTokenValue(
                    _user,
                    allowedTokens[allowedTokensIndex]
                );
        }
        return totalValue;
    }

    function getUserSingleTokenValue(address _user, address _token)
        public
        view
        returns (uint256)
    {
        if (uniqueTokenStaked[_user] <= 0) {
            return 0;
        }
        // price of token * stakingBalance[_token][_user]
        (uint256 price, uint256 decimals) = getTokenValue(_token);
        return ((price * stakingBalance[_token][_user]) / (10**decimals));
    }

    function getTokenValue(address _token)
        public
        view
        returns (uint256, uint256)
    {
        // price feed address
        address priceFeedAddress = tokenPriceFeedMapping[_token];
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeedAddress
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        uint256 decimals = uint256(priceFeed.decimals());
        return (uint256(price), decimals);
    }

    // get if user has stake token before
    function updateUniqueTokenStaked(address _user, address _token) internal {
        if (stakingBalance[_token][_user] <= 0) {
            uniqueTokenStaked[_user] = uniqueTokenStaked[_user] + 1;
        }
    }

    // add token to allowed token list
    function addAllowedTokens(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    // check if this token in our allowed token list
    function tokenIsAllowed(address _token) public returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }
}
