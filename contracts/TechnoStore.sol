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
    uint constant AMOUNT = 1;

    struct Product {
        string[] products; // import it outside of the array
        mapping(string => uint) quantityOfProduct; // ok
        mapping(string => uint) indexOfProduct; // remove
        mapping(string => uint) prizeOf;
        mapping(string => address[]) buyers;
        mapping(string => bool) added;
        mapping(address => string[]) boughtProducts;
        mapping(address => mapping(string => uint)) boughtAt;
    }

    function addProduct(
        Product storage product,
        string calldata _product,
        uint amount,
        uint prize
    ) public {
        if (product.added[_product]) {
            product.quantityOfProduct[_product] += amount;
        } else {
            product.quantityOfProduct[_product] = amount;
            product.indexOfProduct[_product] = product.products.length;
            product.prizeOf[_product] = prize;
            product.added[_product] = true;
            product.products.push(_product);
        }
    }

    function buyProduct(
        Product storage product,
        address _customer,
        uint i,
        IERC20 token
    ) public {
        string memory _product = product.products[i];

        // Check if the store contract(caller) has any allowance in order to use 'transferFrom'
        if (
            token.allowance(msg.sender, address(this)) <
            product.prizeOf[_product]
        ) {
            revert Library__CallerHasApprovedInsufficientAmount();
        }
        // Check if there is at least one product
        if (product.quantityOfProduct[_product] < AMOUNT) {
            revert Library__InsufficientAmount();
        }
        // Check if this customer(msg.sender/tx.origin) has already bought it
        if (product.boughtAt[_customer][_product] > 0) {
            revert Library__ProductAlreadyBought();
        }

        // Веднъж един лаптоп
        product.quantityOfProduct[_product] -= AMOUNT; // -= 1
        product.buyers[_product].push(msg.sender);
        product.boughtAt[_customer][_product] = block.number;
        product.boughtProducts[_customer].push(_product);
        // TransferFrom:
        token.transferFrom(
            msg.sender,
            address(this),
            product.prizeOf[_product]
        );
    }

    function refundProduct(
        Product storage product,
        address _customer,
        uint i,
        IERC20 token
    ) public {
        string memory _product = product.products[i];

        // Instead of using another mapping storing if an address has already bought product,
        // the block.number can be checked and if it is == 0 - revert
        if (product.boughtAt[_customer][_product] == 0) {
            revert Library__ProductNotBought();
        }
        if (block.number - product.boughtAt[_customer][_product] > 100) {
            revert Library__RefundExpired();
        }

        product.quantityOfProduct[_product] += AMOUNT;
        uint length = product.buyers[_product].length;
        product.buyers[_product][i] = product.buyers[_product][length - 1];
        product.buyers[_product].pop();
        delete product.boughtAt[_customer][_product]; // reset it back to 0
        length = product.boughtProducts[_customer].length;
        product.boughtProducts[_customer][i] = product.boughtProducts[
            _customer
        ][length - 1];
        product.boughtProducts[_customer].pop();
        // Transfer and refund 80% of the init prize:
        token.transfer(msg.sender, _refund(product.prizeOf[_product]));
    }

    // Calculates refund - 80% of the prize of the given product
    function _refund(uint prize) private pure returns (uint) {
        return (prize * 4) / 5;
    }

    function getProduct(
        Product storage product,
        uint i
    ) external view returns (string memory) {
        return product.products[i];
    }

    function getAllProducts(
        Product storage product
    ) external view returns (string[] memory) {
        return product.products;
    }

    function getIndexOf(
        Product storage product,
        string memory _product
    ) external view returns (uint) {
        return product.indexOfProduct[_product];
    }

    function getQuantityOf(
        Product storage product,
        string memory _product
    ) external view returns (uint) {
        return product.quantityOfProduct[_product];
    }

    function getBuyersOf(
        Product storage product,
        string memory _product
    ) external view returns (address[] memory) {
        return product.buyers[_product];
    }

    function getAmountOfProducts(
        Product storage product
    ) external view returns (uint) {
        return product.products.length;
    }

    function getAmountOfBoughtProducts(
        Product storage product,
        address _customer
    ) external view returns (uint) {
        return product.boughtProducts[_customer].length;
    }

    function boughtProduct(
        Product storage product,
        address _customer,
        uint i
    ) external view returns (string memory) {
        return product.boughtProducts[_customer][i];
    }

    function boughtAtTimestamp(
        Product storage product,
        address _customer,
        uint i
    ) external view returns (uint) {
        return
            product.boughtAt[_customer][product.boughtProducts[_customer][i]];
    }
}

contract TechnoStore is Ownable {
    event TechnoStore__ProductAdded(string indexed, uint indexed);
    event TechnoStore__ProductBought(string indexed, address indexed);
    event TechnoStore__ProductRefunded(string indexed, address indexed);

    using Library for Library.Product;

    IERC20 immutable token;

    Library.Product product;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function addProduct(
        string calldata _product,
        uint quantity,
        uint prize
    ) external onlyOwner {
        product.addProduct(_product, quantity, prize);

        emit TechnoStore__ProductAdded(_product, quantity);
    }

    function buyProduct(uint i) external {
        product.buyProduct(msg.sender, i, token);
        string memory _product = product.getProduct(i);

        emit TechnoStore__ProductBought(_product, msg.sender);
    }

    function refundProduct(uint i) external {
        product.refundProduct(msg.sender, i, token);
        string memory _product = product.getProduct(i);

        emit TechnoStore__ProductRefunded(_product, msg.sender);
    }

    /*

    GETTERS

    */

    function getProduct(uint i) external view returns (string memory) {
        return product.getProduct(i);
    }

    function getAllProducts() external view returns (string[] memory) {
        return product.getAllProducts();
    }

    function getIndexOf(string memory _product) external view returns (uint) {
        return product.getIndexOf(_product);
    }

    function getQuantityOf(
        string memory _product
    ) external view returns (uint) {
        return product.getQuantityOf(_product);
    }

    function getBuyersOf(
        string memory _product
    ) external view returns (address[] memory) {
        return product.getBuyersOf(_product);
    }

    function getAmountOfProducts() external view returns (uint) {
        return product.getAmountOfProducts();
    }

    function getAmountOfBoughtProducts(
        address _customer
    ) external view returns (uint) {
        return product.getAmountOfBoughtProducts(_customer);
    }

    function boughtProduct(
        address _customer,
        uint i
    ) external view returns (string memory) {
        return product.boughtProduct(_customer, i);
    }

    function boughtAt(address _customer, uint i) external view returns (uint) {
        return product.boughtAtTimestamp(_customer, i);
    }
}
