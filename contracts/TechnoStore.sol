// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title IERC20Permit interface
 * @author Georgi Chonkov
 * @notice You can use this interface for interacting with ERC20Permit tokens
 */
interface IERC20P is IERC20, IERC20Permit {

}

/**
 * @title Implementation/Library contract
 * @author Georgi Chonkov
 * @notice The library implements all methods underneath the `TechnoStore` contract
 */
library Library {
    struct Product {
        mapping(string => uint) quantityOfProduct;
        mapping(string => uint) priceOf;
        mapping(string => address[]) buyers;
        // --------------------------------------------------
        // product: string -> customer: address -> timestamp/blockNumber: uint
        mapping(string => mapping(address => uint)) boughtAt;
    }

    /**
     * @dev Verify inputs and update the storage of the calling contract
     * @notice Add new product to the store
     * @param product - storage reference to the product struct
     * @param products - storage reference to the products array
     * @param _product - name of new product to be added
     * @param amount - the quantity of the product
     * @param price - the price of the product
     */
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

    /**
     * @dev Validate that a purchase can be made and update the storage
     * @notice Allow an address to buy a product
     * @param product - storage reference to the product struct
     * @param _product - name of new product to be added
     * @param _customer - address of the customer willing to buy a product
     * @param token - interface of the token, with which permits can be made
     * @param amount - the amount of tokens to be transferred
     * @param deadline - the last valid timestamp for the approval of tokens
     * @param v - last byte of the signature
     * @param r - first 32 bytes of the signature
     * @param s - second 32 bytes of the signature
     */
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

    /**
     * @dev Validate that a refund can be made and update the storage
     * @notice Allow an address/customer to refund a product
     * @param product - storage reference to the product struct
     * @param _product - name of new product to be refunded
     * @param _customer - address of the customer willing to refund a product
     * @param token - interface of the token, through which the transfer of tokens (refund) can be made
     */
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

    /**
     * @dev Calculates refund - 80% of the price of the given product
     * @param price - tokens, with which the calculcation will be made
     * @return refund
     */
    function _refund(uint price) private pure returns (uint) {
        return (price * 4) / 5;
    }

    /**
     * @dev Returns quantity of a product
     * @param product - storage reference to the product struct
     * @param _product - name of product
     * @return quantity
     */
    function getQuantityOf(
        Product storage product,
        string calldata _product
    ) external view returns (uint) {
        return product.quantityOfProduct[_product];
    }

    /**
     * @dev Returns price of a product
     * @param product - storage reference to the product struct
     * @param _product - name of product
     * @return price
     */
    function getPriceOf(
        Product storage product,
        string calldata _product
    ) external view returns (uint) {
        return product.priceOf[_product];
    }

    /**
     * @dev Returns an array of all addresses that have ever bought a given product
     * @param product - storage reference to the product struct
     * @param _product - name of product
     * @return buyers
     */
    function getBuyersOf(
        Product storage product,
        string calldata _product
    ) external view returns (address[] memory) {
        return product.buyers[_product];
    }

    /**
     * @dev Returns the exact time a product has been bought
     * @param product - storage reference to the product struct
     * @param _product - name of product
     * @param _customer - address of a customer
     * @return timestamp
     */
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
