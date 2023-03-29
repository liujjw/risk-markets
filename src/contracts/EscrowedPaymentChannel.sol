// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <=0.7.0;

/* A payment channel that can be interrupted and closed at any time by payer.
   Guarantees a certain payment to receiver and return of unused escrow to 
   sender. */
contract EscrowedPaymentChannel {
    
    struct Payment {
        uint256 frequency; // in seconds
        uint256 amountToPayEveryInterval;
        uint256 startTime;
        bool closed; // re-entrancy prevention
        bool init;
        uint256 escrow;
        address payable recipient;
    }
    
    mapping(address => Payment) channels;
    // mapping(address => mapping(uint => Payment)) channels;

    function newPaymentChannel(
        address payable _payer,
        address payable _recipient, 
        uint256 _frequency, //secs
        uint256 _amountToPayEveryInterval, //wei
        uint256 _escrow //wei
    ) 
        public 
        payable 
    {   
        // close the old one first
        Payment memory oldChannel = channels[_payer];
        if (oldChannel.init == true) {
            require(oldChannel.closed == true);
        }
        require(msg.value == _escrow);
        require(_amountToPayEveryInterval <= msg.value);
        Payment memory pay = Payment({
            frequency: _frequency, 
            amountToPayEveryInterval: _amountToPayEveryInterval, 
            startTime: block.timestamp, 
            closed: false, 
            init: true,
            escrow: msg.value,
            recipient: _recipient
        }); 
        channels[_payer] = pay;
        // emit log 
    }
    
    function close() public { // gas too high? 
        Payment storage pay = channels[msg.sender];
        require(pay.init);
        require(!pay.closed);
        pay.closed = true;
        uint256 elapsedTime = block.timestamp - pay.startTime; // can be manipulated by miners
        uint256 numPayments = uint256(elapsedTime) / uint256(pay.frequency); // rounds down 
        uint256 amount = numPayments * pay.amountToPayEveryInterval;
        require(pay.escrow >= amount);
        pay.recipient.transfer(amount);
        msg.sender.transfer(pay.escrow - amount);
        // emit log 
    }
    
}