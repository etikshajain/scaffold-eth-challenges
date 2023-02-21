// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

/**
 * @title DEX Template
 * @author @etikshajain
 * @dev We want to create an automatic market where our contract will hold reserves of both ETH and 🎈 Balloons. These reserves will provide liquidity that allows anyone to swap between the assets.
 * NOTE: functions outlined here are what work with the front end of this branch/repo. Also return variable names that may need to be specified exactly may be referenced (if you are confused, see solutions folder in this repo and/or cross reference with front-end code).
 */
contract DEX {
    /* ========== GLOBAL VARIABLES ========== */

    using SafeMath for uint256; //outlines use of SafeMath for uint256 variables
    IERC20 token; //instantiates the imported contract
    uint256 public totalLiquidity;
    mapping (address => uint256) public liquidity;

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when ethToToken() swap transacted
     */
    event EthToTokenSwap(address swapper, string txDetails, uint256 ethInput, uint256 tokenOutput);

    /**
     * @notice Emitted when tokenToEth() swap transacted
     */
    event TokenToEthSwap(address swapper, string txDetails, uint256 tokensInput, uint256 ethOutput);

    /**
     * @notice Emitted when liquidity provided to DEX and mints LPTs.
     */
    event LiquidityProvided();

    /**
     * @notice Emitted when liquidity removed from DEX and decreases LPT count within DEX.
     */
    event LiquidityRemoved();

    /* ========== CONSTRUCTOR ========== */

    constructor(address token_addr) public {
        token = IERC20(token_addr); 
        //specifies the balloon token address that will hook into the interface and be used through the variable 'token'
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @notice initializes amount of tokens that will be transferred to the DEX itself from the erc20 contract mintee (and only them based on how Balloons.sol is written). Loads contract up with both ETH and Balloons.
     * @param tokens amount to be transferred to DEX
     * @return totalLiquidity is the number of LPTs minting as a result of deposits made to DEX contract
     * NOTE: since ratio is 1:1, this is fine to initialize the totalLiquidity (wrt to balloons) as equal to eth balance of contract.
     */
    function init(uint256 tokens) public payable returns (uint256) {
        // check that the dex already does not have liquidity
        require(totalLiquidity == 0, "Dex: init - already has liquidity");

        // init is 'payable', therefore receives ether = address(this).balance

        // update liquidity of ether
        totalLiquidity = address(this).balance;
        liquidity[msg.sender] = totalLiquidity;

        // 1. while deploying, dex.address was approved to transfer 100 balloons of balloon's deployer
        // 2. therefore, dex.address can transfer 100 balloons from balloon's deployer to any address
        // dex.address transfers tokens number of balloons from msg.sender(deployer) to dex.address
        bool sent = token.transferFrom(msg.sender, address(this), tokens);
        require(sent, "Dex init: Tokens did not transact!");
        console.log("dex init balloons after init: ", token.balanceOf(address(this)));
        console.log("dex init balloons after init: ", address(this).balance);

        return totalLiquidity;
    }

    /**
     * @notice returns yOutput, or yDelta for xInput (or xDelta)
     * @dev Follow along with the [original tutorial](https://medium.com/@austin_48503/%EF%B8%8F-minimum-viable-exchange-d84f30bd0c90) Price section for an understanding of the DEX's pricing model and for a price function to add to your contract. You may need to update the Solidity syntax (e.g. use + instead of .add, * instead of .mul, etc). Deploy when you are done.
     */
    function price(
        uint256 xInput,
        uint256 xReserves,
        uint256 yReserves
    ) public pure returns (uint256 yOutput) {
        // 0.3% fees
        // x_res*y_res = (x_res + x_in*0.997)*y_new  ==> y_out = y_res - y_new
        uint256 xInputWithFee = xInput.mul(997);
        uint256 numerator = xInputWithFee.mul(yReserves);
        uint256 denominator = (xReserves.mul(1000)).add(xInputWithFee);
        return (numerator / denominator);
    }

    /**
     * @notice returns liquidity for a user. Note this is not needed typically due to the `liquidity()` mapping variable being public and having a getter as a result. This is left though as it is used within the front end code (App.jsx).
     * if you are using a mapping liquidity, then you can use `return liquidity[lp]` to get the liquidity for a user.
     *
     */
    function getLiquidity(address lp) public view returns (uint256) {}

    /**
     * @notice sends Ether to DEX in exchange for $BAL
     */
    function ethToToken() public payable returns (uint256 tokenOutput) {
        require(msg.value > 0, "please send non zero Eth!");
        uint256 ethReserves = address(this).balance.sub(msg.value);
        uint256 tokenReserves = token.balanceOf(address(this));
        uint256 ethInput = msg.value;
        tokenOutput = price(ethInput, ethReserves, tokenReserves);

        // Transfer tokenOutput number of balloons from dex.address to msg.sender
        bool sent = token.transfer(msg.sender, tokenOutput);
        require(sent, "ethToToken(): Swap failed!");

        // emit event
        emit EthToTokenSwap(msg.sender, "Eth to Balloons", msg.value, tokenOutput);

        return tokenOutput;
    }

    /**
     * @notice sends $BAL tokens to DEX in exchange for Ether
     */
    function tokenToEth(uint256 tokenInput) public returns (uint256 ethOutput) {
        require(tokenInput > 0, "please send non zero tokens!");
        uint256 ethReserves = address(this).balance;
        uint256 tokenReserves = token.balanceOf(address(this));

        ethOutput = price(tokenInput, tokenReserves, ethReserves);

        // Transfer tokenInput number of balloons from msg.sender to dex.address
        bool sent_token = token.transferFrom(msg.sender, address(this), tokenInput);
        require(sent_token, "tokenToEth(): Swap failed!");

        // Transfer ethOutput number of eth from dex.address to msg.sender
        (bool sent_eth,) = msg.sender.call{value: ethOutput}("");
        require(sent_eth, "tokenToEth(): Swap failed!");

        // emit event
        emit TokenToEthSwap(msg.sender, "Balloons to ETH", tokenInput, ethOutput);

        return ethOutput;
    }

    /**
     * @notice allows deposits of $BAL and $ETH to liquidity pool
     * NOTE: parameter is the msg.value sent with this function call. That amount is used to determine the amount of $BAL needed as well and taken from the depositor.
     * NOTE: user has to make sure to give DEX approval to spend their tokens on their behalf by calling approve function prior to this function call.
     * NOTE: Equal parts of both assets will be removed from the user's wallet with respect to the price outlined by the AMM.
     */
    function deposit() public payable returns (uint256 tokensDeposited) {}

    /**
     * @notice allows withdrawal of $BAL and $ETH from liquidity pool
     * NOTE: with this current code, the msg caller could end up getting very little back if the liquidity is super low in the pool. I guess they could see that with the UI.
     */
    function withdraw(uint256 amount) public returns (uint256 eth_amount, uint256 token_amount) {}
}
