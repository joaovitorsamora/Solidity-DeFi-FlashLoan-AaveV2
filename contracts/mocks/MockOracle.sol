// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract MockOracle {
    uint256 public price;

    constructor(uint256 _price) {
        price = _price; // ex: 2000 * 1e8
    }

    function getAssetPrice(address) external view returns (uint256) {
        return price;
    }

    function setPrice(uint256 newPrice) external {
        price = newPrice;
    }
}
