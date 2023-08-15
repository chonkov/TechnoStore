// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*

You challenge is to create the following smart contract:

Your Contract
Using Remix/Hardhat develop a contract for a TechnoLime Store.

______________________________________________________________________

- The administrator (owner) of the store should be able to add new products and the quantity of them.
Това е ясно. Направил си го. Можеш да сложиш един modifier за проверка валидността на данните.

- The administrator should not be able to add the same product twice, just quantity.
Това си го направил. Нямам забележки

- Buyers (clients) should be able to see the available products and buy them by their id.
Подаваш ID, откъде го взимаш този customer?  Не ти трябва според мен да пазиш нов struct за customer. Можеш да решиш тази задача само с 2 мапинга (единия вложен). Помисли за оптимизация и дали ти трябва struct-a Customer.


- Buyers should be able to return products if they are not satisfied (within a certain period in blocktime: 100 blocks).
Доволен съм. Просто като помислиш по горния коментар и се отървеш от Customer struct-a, ще стане по-чисто.

- A client cannot buy the same product more than one time.
Доволен съм. Същото като горе.

- The clients should not be able to buy a product more times than the quantity in the store unless a product is returned or added by the administrator (owner)
Доволен съм, НО защо сетваш AMOUNT = 1? AMOUNT-a можеш да го сетваш като добавяш продукт. Не разбирам защо ти е това 

uint constant AMOUNT = 1;

- Everyone should be able to see the addresses of all clients that have ever bought a given product.
Тук ти трябва 1 гетер. Ти си написал бая гетери. Помисли дали ти трябват? Можеш да ползваш default-ното поведение на solidity s public variables. 

*/

error Library__CallerHasApprovedInsufficientAmount();
error Library__InsufficientAmount();
error Library__ProductAlreadyBought();
error Library__ProductNotBought();
error Library__RefundExpired();

library Library {
    struct Product {
        mapping(string => uint) quantityOfProduct;
        mapping(string => uint) priceOf;
        mapping(string => address[]) buyers;
        // --------------------------------------------------
        // product: string -> customer: address -> timestamp: uint
        mapping(string => mapping(address => uint)) boughtAt;
    }

    function addProduct(
        Product storage product,
        string calldata _product,
        uint amount,
        uint price
    ) public {
        // Check the price(in tokens) - if it is > 0, then the product has already been added
        if (product.priceOf[_product] > 0) {
            product.quantityOfProduct[_product] += amount;
        } else {
            product.quantityOfProduct[_product] = amount;
            product.priceOf[_product] = price;
        }
    }

    function buyProduct(
        Product storage product,
        string calldata _product,
        address _customer,
        IERC20 token
    ) public {
        // Check if the store contract(caller) has any allowance in order to use 'transferFrom'
        if (
            token.allowance(msg.sender, address(this)) <
            product.priceOf[_product]
        ) {
            revert Library__CallerHasApprovedInsufficientAmount();
        }
        // Check if there is at least one product
        if (product.quantityOfProduct[_product] == 0) {
            revert Library__InsufficientAmount();
        }
        // Check if this customer(msg.sender/tx.origin) has already bought it
        if (product.boughtAt[_product][_customer] > 0) {
            revert Library__ProductAlreadyBought();
        }

        product.quantityOfProduct[_product] -= 1;
        product.buyers[_product].push(msg.sender);
        product.boughtAt[_product][_customer] = block.number;

        // TransferFrom:
        token.transferFrom(
            msg.sender,
            address(this),
            product.priceOf[_product]
        );
    }

    function refundProduct(
        Product storage product,
        string calldata _product,
        address _customer,
        IERC20 token
    ) public {
        // The block.number can be checked and if it is == 0 - revert
        if (product.boughtAt[_product][_customer] == 0) {
            revert Library__ProductNotBought();
        }
        if (block.number - product.boughtAt[_product][_customer] > 100) {
            revert Library__RefundExpired();
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

    IERC20 immutable token;

    string[] public products;
    Library.Product product;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function addProduct(
        string calldata _product,
        uint quantity,
        uint price
    ) external onlyOwner {
        product.addProduct(_product, quantity, price);
        products.push(_product);

        emit TechnoStore__ProductAdded(_product, quantity);
    }

    function buyProduct(uint i) external {
        string memory _product = products[i];
        product.buyProduct(_product, msg.sender, token);

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
