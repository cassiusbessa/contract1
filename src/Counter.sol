// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

contract Counter {
    uint256 public number;
    address public owner;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
