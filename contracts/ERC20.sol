// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title An ERC20Permit contract
 * @author Georgi Chonkov
 * @notice You can use this contract for basic simulations
 */
contract Token is ERC20Permit {
    /**
     *  @notice {EIP2612} `name` and {EIP20} `name` MUST be the same
     * @dev Initializes the {EIP2612} `name` and {EIP20} `name` & `symbol`
     */
    constructor()
        ERC20Permit("LimeTechno Store Token")
        ERC20("LimeTechno Store Token", "LTSK")
    {
        _mint(_msgSender(), 10000);
    }
}
