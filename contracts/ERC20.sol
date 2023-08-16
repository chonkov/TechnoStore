// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Token is ERC20Permit {
    constructor()
        ERC20Permit("LimeTechno Store")
        ERC20("LimeTechno Store Token", "LTTK")
    {
        _mint(_msgSender(), 10000);
    }
}
