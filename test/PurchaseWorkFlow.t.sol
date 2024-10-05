// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "../src/PurchaseWorkflow.sol";

contract PurchaseWorkflowTest is Test {
    PurchaseWorkflow public purchaseWorkflow;
    address public owner;
    address public buyer;
    address public merchant;
    uint256 public constant PURCHASE_AMOUNT = 1 ether;

    function setUp() public {
        purchaseWorkflow = new PurchaseWorkflow();
        owner = address(this);
        buyer = address(0x1234);
        merchant = address(0x5678);
        vm.deal(buyer, 10 ether);
        vm.deal(merchant, 10 ether);
    }

    function testCreatePurchase() public {
        vm.prank(buyer);
        uint256 purchaseId = purchaseWorkflow.createPurchase{value: PURCHASE_AMOUNT}(merchant, "PROD001", PURCHASE_AMOUNT);
        
        (address _buyer, address _merchant, uint256 _amount, PurchaseWorkflow.PurchaseStatus _status, , string memory _productId, bool _isRefunded) = purchaseWorkflow.getPurchaseDetails(purchaseId);
        
        assertEq(_buyer, buyer);
        assertEq(_merchant, merchant);
        assertEq(_amount, PURCHASE_AMOUNT);
        assertEq(uint(_status), uint(PurchaseWorkflow.PurchaseStatus.Created));
        assertEq(_productId, "PROD001");
        assertEq(_isRefunded, false);
    }

    function testSubmitPayment() public {
        uint256 purchaseId = createTestPurchase();
        
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
        
        (, , , PurchaseWorkflow.PurchaseStatus _status, , , ) = purchaseWorkflow.getPurchaseDetails(purchaseId);
        assertEq(uint(_status), uint(PurchaseWorkflow.PurchaseStatus.PaymentSubmitted));
    }

    function testApprovePayment() public {
        uint256 purchaseId = createTestPurchase();
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
        
        purchaseWorkflow.approvePayment(purchaseId);
        
        (, , , PurchaseWorkflow.PurchaseStatus _status, , , ) = purchaseWorkflow.getPurchaseDetails(purchaseId);
        assertEq(uint(_status), uint(PurchaseWorkflow.PurchaseStatus.PaymentApproved));
    }

    function testMerchantConfirm() public {
        uint256 purchaseId = createTestPurchase();
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
        purchaseWorkflow.approvePayment(purchaseId);
        
        vm.prank(merchant);
        purchaseWorkflow.merchantConfirm(purchaseId);
        
        (, , , PurchaseWorkflow.PurchaseStatus _status, , , ) = purchaseWorkflow.getPurchaseDetails(purchaseId);
        assertEq(uint(_status), uint(PurchaseWorkflow.PurchaseStatus.MerchantConfirmed));
    }

    function testCompletePurchase() public {
        uint256 purchaseId = createTestPurchase();
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
        purchaseWorkflow.approvePayment(purchaseId);
        vm.prank(merchant);
        purchaseWorkflow.merchantConfirm(purchaseId);
        
        uint256 merchantBalanceBefore = merchant.balance;
        purchaseWorkflow.completePurchase(purchaseId);
        
        (, , , PurchaseWorkflow.PurchaseStatus _status, , , ) = purchaseWorkflow.getPurchaseDetails(purchaseId);
        assertEq(uint(_status), uint(PurchaseWorkflow.PurchaseStatus.Completed));
        assertEq(merchant.balance, merchantBalanceBefore + PURCHASE_AMOUNT);
    }
    //Failed
    function testDeclinePayment() public {
        uint256 purchaseId = createTestPurchase();
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
        
        uint256 buyerBalanceBefore = buyer.balance;
        purchaseWorkflow.declinePayment(purchaseId);
        
        (, , , PurchaseWorkflow.PurchaseStatus _status, , , bool _isRefunded) = purchaseWorkflow.getPurchaseDetails(purchaseId);
        assertEq(uint(_status), uint(PurchaseWorkflow.PurchaseStatus.Declined));
        assertEq(_isRefunded, true);
        assertEq(buyer.balance, buyerBalanceBefore + PURCHASE_AMOUNT);
    }
    //Failed
    function testCancelPurchase() public {
        uint256 purchaseId = createTestPurchase();
        
        uint256 buyerBalanceBefore = buyer.balance;
        vm.prank(buyer);
        purchaseWorkflow.cancelPurchase(purchaseId);
        
        (, , , PurchaseWorkflow.PurchaseStatus _status, , , bool _isRefunded) = purchaseWorkflow.getPurchaseDetails(purchaseId);
        assertEq(uint(_status), uint(PurchaseWorkflow.PurchaseStatus.Cancelled));
        assertEq(_isRefunded, true);
        assertEq(buyer.balance, buyerBalanceBefore + PURCHASE_AMOUNT);
    }

    function testFailCreatePurchaseInvalidAmount() public {
        vm.prank(buyer);
        purchaseWorkflow.createPurchase{value: 0}(merchant, "PROD001", PURCHASE_AMOUNT);
    }

    function testFailSubmitPaymentInvalidStatus() public {
        uint256 purchaseId = createTestPurchase();
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
        
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
    }

    function testFailApprovePaymentInvalidStatus() public {
        uint256 purchaseId = createTestPurchase();
        purchaseWorkflow.approvePayment(purchaseId);
    }

    function testFailMerchantConfirmInvalidStatus() public {
        uint256 purchaseId = createTestPurchase();
        vm.prank(merchant);
        purchaseWorkflow.merchantConfirm(purchaseId);
    }

    function testFailCompletePurchaseInvalidStatus() public {
        uint256 purchaseId = createTestPurchase();
        purchaseWorkflow.completePurchase(purchaseId);
    }

    function testFailDeclinePaymentInvalidStatus() public {
        uint256 purchaseId = createTestPurchase();
        purchaseWorkflow.declinePayment(purchaseId);
    }

    function testFailCancelCompletedPurchase() public {
        uint256 purchaseId = createTestPurchase();
        vm.prank(buyer);
        purchaseWorkflow.submitPayment(purchaseId);
        purchaseWorkflow.approvePayment(purchaseId);
        vm.prank(merchant);
        purchaseWorkflow.merchantConfirm(purchaseId);
        purchaseWorkflow.completePurchase(purchaseId);
        
        vm.prank(buyer);
        purchaseWorkflow.cancelPurchase(purchaseId);
    }

    function createTestPurchase() internal returns (uint256) {
        vm.prank(buyer);
        return purchaseWorkflow.createPurchase{value: PURCHASE_AMOUNT}(merchant, "PROD001", PURCHASE_AMOUNT);
    }
}
