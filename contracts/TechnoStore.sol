// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

interface IERC20P is IERC20, IERC20Permit {}

library Library {
    struct Product {
        mapping(string => uint) quantityOfProduct;
        mapping(string => uint) priceOf;
        mapping(string => address[]) buyers;
        // --------------------------------------------------
        // product: string -> customer: address -> timestamp/blockNumber: uint
        mapping(string => mapping(address => uint)) boughtAt;
    }

    function addProduct(
        Product storage product,
        string[] storage products,
        string calldata _product,
        uint amount,
        uint price
    ) public {
        if (price == 0 || amount == 0) {
            revert("Library__InvalidInputs");
        }

        if (
            product.priceOf[_product] > 0
        ) // Check the price(in tokens) - if it is > 0, then the product has already been added
        {
            product.quantityOfProduct[_product] += amount;
        } else {
            product.quantityOfProduct[_product] = amount;
            product.priceOf[_product] = price;
            products.push(_product);
        }
    }

    function buyProduct(
        Product storage product,
        string calldata _product,
        address _customer,
        IERC20P token,
        uint amount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        if (product.quantityOfProduct[_product] == 0) {
            revert("Library__InsufficientAmount");
        }

        // Check if this customer(msg.sender/tx.origin) has already bought it
        if (product.boughtAt[_product][_customer] > 0) {
            revert("Library__ProductAlreadyBought");
        }

        product.quantityOfProduct[_product] -= 1;
        product.buyers[_product].push(msg.sender);
        product.boughtAt[_product][_customer] = block.number;

        token.permit(
            msg.sender,
            address(this),
            amount, // amount >= product.priceOf[_product], else the tx reverts
            deadline,
            v,
            r,
            s
        );
        token.transferFrom(msg.sender, address(this), amount);
    }

    function refundProduct(
        Product storage product,
        string calldata _product,
        address _customer,
        IERC20P token
    ) public {
        // The block.number can be checked and if it is == 0 - revert
        if (product.boughtAt[_product][_customer] == 0) {
            revert("Library__ProductNotBought");
        }
        if (block.number - product.boughtAt[_product][_customer] > 100) {
            revert("Library__RefundExpired");
        }

        product.quantityOfProduct[_product] += 1;
        delete product.boughtAt[_product][_customer]; // reset timestamp back to 0

        token.transfer(msg.sender, _refund(product.priceOf[_product]));
    }

    // Calculates refund - 80% of the price of the given product
    function _refund(uint price) private pure returns (uint) {
        return (price * 4) / 5;
    }

    function getQuantityOf(
        Product storage product,
        string calldata _product
    ) external view returns (uint) {
        return product.quantityOfProduct[_product];
    }

    function getPriceOf(
        Product storage product,
        string calldata _product
    ) external view returns (uint) {
        return product.priceOf[_product];
    }

    function getBuyersOf(
        Product storage product,
        string calldata _product
    ) external view returns (address[] memory) {
        return product.buyers[_product];
    }

    function boughtAtTimestamp(
        Product storage product,
        string calldata _product,
        address _customer
    ) external view returns (uint) {
        return product.boughtAt[_product][_customer];
    }
}

contract TechnoStore is Ownable {
    event TechnoStore__ProductAdded(string indexed, uint indexed);
    event TechnoStore__ProductBought(string indexed, address indexed);
    event TechnoStore__ProductRefunded(string indexed, address indexed);

    using Library for Library.Product;

    IERC20P public immutable token;

    string[] public products;
    Library.Product product;

    constructor(address _token) {
        token = IERC20P(_token);
    }

    function addProduct(
        string calldata _product,
        uint quantity,
        uint price
    ) external onlyOwner {
        product.addProduct(products, _product, quantity, price);

        emit TechnoStore__ProductAdded(_product, quantity);
    }

    function buyProduct(
        uint i,
        uint amount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        string memory _product = products[i];
        product.buyProduct(
            _product,
            msg.sender,
            token,
            amount,
            deadline,
            v,
            r,
            s
        );

        emit TechnoStore__ProductBought(_product, msg.sender);
    }

    function refundProduct(uint i) external {
        string memory _product = products[i];
        product.refundProduct(_product, msg.sender, token);

        emit TechnoStore__ProductRefunded(_product, msg.sender);
    }

    /*

    GETTERS

    */

    function getQuantityOf(
        string calldata _product
    ) external view returns (uint) {
        return product.getQuantityOf(_product);
    }

    function getPriceOf(string calldata _product) external view returns (uint) {
        return product.getPriceOf(_product);
    }

    function getBuyersOf(
        string calldata _product
    ) external view returns (address[] memory) {
        return product.getBuyersOf(_product);
    }

    function getAmountOfProducts() external view returns (uint) {
        return products.length;
    }

    function boughtAt(
        string calldata _product,
        address _customer
    ) external view returns (uint) {
        return product.boughtAtTimestamp(_product, _customer);
    }
}
