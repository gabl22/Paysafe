// SPDX-License-Identifier: MIT
// gabl22 @ github.com

pragma solidity >=0.8.0 <0.9.0;

//AMOUNTS ARE GIVEN AND STORED IN WEI

// Version 0x01

import "./Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PaySafe is Ownable {

    enum PaymentState {
        INDEXED,
        REVOKED,
        PENDING,
        PAID
    }

    struct Payment {
        PaymentState state;
        address from;
        address to;
        uint amount;
        uint bail;
    }

    using Counters for Counters.Counter;
    Counters.Counter private idCounter;

    mapping(uint => Payment) public payments;

    constructor() {
        //idCounter = Counter();
    }

    function createPayment(address to, uint amount, uint bail) public payable returns(uint){
        require(msg.value >= (amount + bail), "Error: Insufficient funds deposited (needs amout + bail)");
        require(msg.sender != to, "Error: You cannot send yourself money");
        Payment memory payment = Payment({
            state: PaymentState.INDEXED,
            from: msg.sender,
            to: to,
            amount: amount,
            bail: bail
        });
        uint id = idCounter.current();
        payments[id] = payment;
        idCounter.increment();
        payable(address(tx.origin)).transfer(msg.value - (amount + bail));
        return id;
    }

    function deposit(uint id) public payable {
        require(msg.sender == payments[id].to, "Error: No deposit accepted here");
        require(payments[id].state == PaymentState.INDEXED, "Error: You already paid or this payment got revoked");
        require(msg.value >= payments[id].bail, "Error: Insufficient funds deposited");
        payments[id].state == PaymentState.PENDING;
        payable(address(tx.origin)).transfer(msg.value - payments[id].bail);
    }

    function revoke(uint id) public {
        require(msg.sender == payments[id].from || msg.sender == payments[id].to, "Error: You are not a part of this payment");
        require(payments[id].state == PaymentState.INDEXED || payments[id].state == PaymentState.PENDING, "Error: Payment already completed/revoked");
        if (msg.sender == payments[id].from) {
            require(payments[id].state == PaymentState.INDEXED, "Error: Payment in process");
            payments[id].state = PaymentState.REVOKED;
            payable(address(payments[id].from)).transfer(payments[id].amount + payments[id].bail);
        } else if (msg.sender == payments[id].to) {
            if(payments[id].state == PaymentState.PENDING) {
                payable(address(payments[id].to)).transfer(payments[id].bail);
            }
            payments[id].state = PaymentState.REVOKED;
            payable(address(payments[id].from)).transfer(payments[id].amount + payments[id].bail);
        }
    }

    function confirm(uint id) public {
        require(msg.sender == payments[id].from, "Error: You can't confirm this payment");
        require(payments[id].state == PaymentState.PENDING, "Error: This Payment is not confirmable.");
        payments[id].state = PaymentState.PAID;
        payable(address(payments[id].from)).transfer(payments[id].bail);
        payable(address(payments[id].to)).transfer(payments[id].bail + payments[id].amount);
    }

    function getPayment(uint id) public view returns(Payment memory) {
        return payments[id];
    }

    function getPayments() public view returns (Payment[] memory){
        Payment[] memory ret = new Payment[](idCounter.current());
        for (uint i = 0; i < idCounter.current(); i++) {
            ret[i] = payments[i];
        }
        return ret;
    }
}
