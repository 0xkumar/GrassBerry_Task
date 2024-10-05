// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

contract PurchaseWorkflow {
    // Enums to track purchase status
    enum PurchaseStatus { 
        Created,
        PaymentSubmitted,
        PaymentApproved,
        MerchantConfirmed,
        Completed,
        Cancelled,
        Declined
    }

    // Structure to store purchase details
    struct Purchase {
        uint256 purchaseId;
        address buyer;
        address merchant;
        uint256 amount;
        PurchaseStatus status;
        uint256 timestamp;
        string productId;
        bool isRefunded;
    }

    // State variables
    mapping(uint256 => Purchase) public purchases;
    uint256 public purchaseCounter;
    address public owner;
    
    // Events for tracking purchase flow
    event PurchaseCreated(uint256 indexed purchaseId, address indexed buyer, string productId);
    event PaymentSubmitted(uint256 indexed purchaseId);
    event PaymentApproved(uint256 indexed purchaseId);
    event MerchantConfirmed(uint256 indexed purchaseId);
    event PurchaseCompleted(uint256 indexed purchaseId);
    event PurchaseCancelled(uint256 indexed purchaseId);
    event PaymentDeclined(uint256 indexed purchaseId);
    event RefundIssued(uint256 indexed purchaseId);

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier validPurchaseId(uint256 _purchaseId) {
        require(_purchaseId < purchaseCounter, "Invalid purchase ID");
        _;
    }

    modifier onlyBuyer(uint256 _purchaseId) {
        require(msg.sender == purchases[_purchaseId].buyer, "Only buyer can call this function");
        _;
    }

    modifier onlyMerchant(uint256 _purchaseId) {
        require(msg.sender == purchases[_purchaseId].merchant, "Only merchant can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        purchaseCounter = 0;
    }

    // Function to create a new purchase
    function createPurchase(
        address _merchant,
        string memory _productId,
        uint256 _amount
    ) external payable returns (uint256) {
        require(_amount > 0, "Amount must be greater than 0");
        require(_merchant != address(0), "Invalid merchant address");
        require(msg.value == _amount, "Sent amount must match purchase amount");

        uint256 purchaseId = purchaseCounter++;
        
        Purchase storage newPurchase = purchases[purchaseId];
        newPurchase.purchaseId = purchaseId;
        newPurchase.buyer = msg.sender;
        newPurchase.merchant = _merchant;
        newPurchase.amount = _amount;
        newPurchase.status = PurchaseStatus.Created;
        newPurchase.timestamp = block.timestamp;
        newPurchase.productId = _productId;
        newPurchase.isRefunded = false;

        emit PurchaseCreated(purchaseId, msg.sender, _productId);
        return purchaseId;
    }

    // Function to submit payment
    function submitPayment(uint256 _purchaseId) 
        external 
        validPurchaseId(_purchaseId) 
        onlyBuyer(_purchaseId) 
    {
        Purchase storage purchase = purchases[_purchaseId];
        require(purchase.status == PurchaseStatus.Created, "Invalid purchase status");
        
        purchase.status = PurchaseStatus.PaymentSubmitted;
        emit PaymentSubmitted(_purchaseId);
    }

    // Function for payment approval (could be called by an oracle or authorized party)
    function approvePayment(uint256 _purchaseId) 
        external 
        onlyOwner 
        validPurchaseId(_purchaseId) 
    {
        Purchase storage purchase = purchases[_purchaseId];
        require(purchase.status == PurchaseStatus.PaymentSubmitted, "Invalid purchase status");
        
        purchase.status = PurchaseStatus.PaymentApproved;
        emit PaymentApproved(_purchaseId);
    }

    // Function for merchant confirmation
    function merchantConfirm(uint256 _purchaseId) 
        external 
        validPurchaseId(_purchaseId) 
        onlyMerchant(_purchaseId) 
    {
        Purchase storage purchase = purchases[_purchaseId];
        require(purchase.status == PurchaseStatus.PaymentApproved, "Invalid purchase status");
        
        purchase.status = PurchaseStatus.MerchantConfirmed;
        emit MerchantConfirmed(_purchaseId);
    }

    // Function to complete purchase
    function completePurchase(uint256 _purchaseId) 
        external 
        validPurchaseId(_purchaseId) 
        onlyOwner 
    {
        Purchase storage purchase = purchases[_purchaseId];
        require(purchase.status == PurchaseStatus.MerchantConfirmed, "Invalid purchase status");
        
        // Transfer funds to merchant
        bool success = payable(purchase.merchant).send(purchase.amount);
        require(success,"Failed to Transfer Payment to Merchant");
        //No Possibility For ReEntrancy Attack Because I used "Send" Instead of lowlevel call.
        purchase.status = PurchaseStatus.Completed;
        emit PurchaseCompleted(_purchaseId);
    }

    // Function to decline payment
    function declinePayment(uint256 _purchaseId) 
        external 
        onlyOwner 
        validPurchaseId(_purchaseId) 
    {
        Purchase storage purchase = purchases[_purchaseId];
        require(purchase.status == PurchaseStatus.PaymentSubmitted, "Invalid purchase status");
        
        purchase.status = PurchaseStatus.Declined;
        emit PaymentDeclined(_purchaseId);
        
        // Refund the buyer
        if (!purchase.isRefunded) {
            bool success = payable(purchase.buyer).send(purchase.amount);
            require(success,"Failed to Decline the Purchase");
            purchase.isRefunded = true;
            emit RefundIssued(_purchaseId);
        }
    }

    // Function to cancel purchase
    function cancelPurchase(uint256 _purchaseId) 
        external 
        validPurchaseId(_purchaseId) 
    {
        Purchase storage purchase = purchases[_purchaseId];
        //Only the Buyer or the Owner can cancel the Payment.
        require(msg.sender == purchase.buyer || msg.sender == owner, "Sorry Bro U can't do that");
        require(purchase.status != PurchaseStatus.Completed, "Purchase already completed");
        require(purchase.status != PurchaseStatus.Cancelled, "Purchase already cancelled");
        
        purchase.status = PurchaseStatus.Cancelled;
        emit PurchaseCancelled(_purchaseId);
        
        // Refund the buyer if payment was made and not yet refunded
        if (!purchase.isRefunded) {
            bool success = payable(purchase.buyer).send(purchase.amount);
            require(success,"Failed to Refund the Payment");
            //ReEntrancy Cant be done.
            purchase.isRefunded = true;
            emit RefundIssued(_purchaseId);
        }
    }

    // Function to get purchase details
    function getPurchaseDetails(uint256 _purchaseId) 
        external 
        view 
        validPurchaseId(_purchaseId) 
        returns (
            address buyer,
            address merchant,
            uint256 amount,
            PurchaseStatus status,
            uint256 timestamp,
            string memory productId,
            bool isRefunded
        ) 
    {
        Purchase storage purchase = purchases[_purchaseId];
        return (
            purchase.buyer,
            purchase.merchant,
            purchase.amount,
            purchase.status,
            purchase.timestamp,
            purchase.productId,
            purchase.isRefunded
        );
    }
}
