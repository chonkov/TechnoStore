// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "hardhat/console.sol";

contract Token is ERC20Permit {
    // Needed for computing the correct hash. Declared here just as in 'ERC20Permit', because it's private
    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    constructor()
        ERC20Permit("LimeTechno Store")
        ERC20("LimeTechno Store", "LTTK")
    {
        _mint(_msgSender(), 10000);
    }
}
