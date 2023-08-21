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
        ERC20("LimeTechno Store Token", "LTTK")
    {
        _mint(_msgSender(), 10000);
    }

    // Exact same as the implementation in 'ERC20Permit', just with added logs for debugging
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(
                _PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                _useNonce(owner),
                deadline
            )
        );
        console.logBytes32(structHash);

        bytes32 hash = _hashTypedDataV4(structHash);
        console.logBytes32(hash);

        address signer = ECDSA.recover(hash, v, r, s);
        console.log("Signer: %s", signer);
        console.log("Owner: %s", owner);

        require(signer == owner, "ERC20Permit: invalid signature");

        _approve(owner, spender, value);
    }

    function test(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (address) {
        // solhint-disable-next-line

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                _domainSeparatorV4(),
                keccak256(
                    abi.encode(
                        _PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces(owner),
                        deadline
                    )
                )
            )
        );

        address recoveredAddress = ecrecover(digest, v, r, s);
        return recoveredAddress;
    }
}
