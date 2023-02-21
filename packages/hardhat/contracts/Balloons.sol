pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract Balloons is ERC20 {
    constructor() ERC20("Balloons", "BAL") {
        _mint(msg.sender, 1000 ether); // mints 1000 balloons!
    }

    function transfer(address to, uint256 amount) public override returns(bool) {
        console.log("balloon transfer msg.sender: ", msg.sender);
        return super.transfer(to, amount);
    }

    function approve(address spender, uint256 amount) public override returns(bool){
        console.log("balloon approve msg.sender: ", msg.sender);
        return super.approve(spender, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns(bool){
        console.log("balloon transferFrom msg.sender: ", msg.sender);
        return super.transferFrom(from, to, amount);
    }
}
