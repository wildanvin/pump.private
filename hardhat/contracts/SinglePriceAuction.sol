// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { ConfidentialERC20 } from "fhevm-contracts/contracts/token/ERC20/ConfidentialERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "fhevm/config/ZamaFHEVMConfig.sol";
import "fhevm/config/ZamaGatewayConfig.sol";
import "fhevm/gateway/GatewayCaller.sol";

/// @title Single Price Auction with FHE for Sepolia
/// @notice Implements a single-price auction where bids are encrypted
/// @dev Uses TFHE library for fully homomorphic encryption operations
contract SinglePriceAuction is SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller, Ownable2Step {
    /// @notice Structure to store encrypted bids
    /// @dev Uses euint64 for encrypted values and boolean flags for state management
    struct EncryptedBid {
        euint64 quantity;     // Requested token quantity
        euint64 price;        // Price per token
        bool initialized;     // Whether the bid exists
        bool processed;       // Whether the bid was processed in settlement
    }

    /// @notice Auction states
    /// @dev Used to track the auction's lifecycle
    enum AuctionState {
        Active,     // Accepting bids
        Settling,   // Processing bids
        Settled,    // Successfully finished
        Failed      // Failed to meet conditions
    }

    /// @notice Current auction state
    AuctionState public auctionState;

    /// @notice Immutable auction parameters
    /// @dev These values cannot be changed after deployment
    uint256 public immutable totalTokens;        // Total tokens for sale
    uint256 public immutable minParticipants;    // Minimum required participants
    uint256 public immutable endTime;            // End time timestamp

    /// @notice Token contracts
    /// @dev References to the involved ERC20 tokens
    ConfidentialERC20 public immutable tokenForSale;  // Token being sold
    ConfidentialERC20 public immutable paymentToken;  // Token used for payment

    /// @notice Mappings for bids and allocations
    /// @dev Primary data structures for bid management
    mapping(address => EncryptedBid) public bids;
    address[] public bidders;
    mapping(address => euint64) private tokenAllocations;

    /// @notice Encrypted process variables
    /// @dev Used during auction operations
    euint64 private highestBid;          // Current highest bid
    euint64 private settlementPrice;     // Final settlement price
    euint64 private totalAllocated;      // Total allocated tokens

    /// @notice Events
    event AuctionCreated(uint256 totalTokens, uint256 endTime);
    event BidPlaced(address indexed bidder);
    event AuctionSettled();
    event AuctionFailed();
    event TokensClaimed(address indexed bidder);

    /// @notice Constructor to initialize the auction
    /// @param _tokenForSale Address of token being sold
    /// @param _paymentToken Address of token used for payment
    /// @param _totalTokens Total number of tokens for sale
    /// @param _duration Auction duration in seconds
    /// @param _minParticipants Minimum number of participants required
    constructor(
        address _tokenForSale,
        address _paymentToken,
        uint256 _totalTokens,
        uint256 _duration,
        uint256 _minParticipants
    ) Ownable(msg.sender) {
        require(_totalTokens > 0, "Total tokens must be > 0");
        require(_duration > 0, "Duration must be > 0");
        require(_minParticipants > 0, "Min participants must be > 0");

        tokenForSale = ConfidentialERC20(_tokenForSale);
        paymentToken = ConfidentialERC20(_paymentToken);
        totalTokens = _totalTokens;
        endTime = block.timestamp + _duration;
        minParticipants = _minParticipants;
        
        // Initialize encrypted values
        highestBid = TFHE.asEuint64(0);
        settlementPrice = TFHE.asEuint64(0);
        totalAllocated = TFHE.asEuint64(0);
        
        auctionState = AuctionState.Active;
        emit AuctionCreated(_totalTokens, endTime);
    }

    /// @notice Place a bid in the auction
    /// @dev Handles input validation and payment locking
    /// @param quantityInput Encrypted quantity of tokens requested
    /// @param priceInput Encrypted price per token
    /// @param quantityProof Proof for quantity input
    /// @param priceProof Proof for price input
    function placeBid(
        einput quantityInput,
        einput priceInput,
        bytes calldata quantityProof,
        bytes calldata priceProof
    ) external {
        require(block.timestamp < endTime, "Auction ended");
        require(auctionState == AuctionState.Active, "Not active");
        require(!bids[msg.sender].initialized, "Already bid");

        // Convert and verify inputs
        euint64 quantity = TFHE.asEuint64(quantityInput, quantityProof);
        euint64 price = TFHE.asEuint64(priceInput, priceProof);

        // Avoid require() and handle quantity == 0
        euint64 zero = TFHE.asEuint64(0);
        euint64 validQuantity = TFHE.select(TFHE.gt(quantity, zero), quantity, zero);

        // Skip bid if validQuantity is 0
        ebool isValidBid = TFHE.gt(validQuantity, zero);
        highestBid = TFHE.select(isValidBid, highestBid, highestBid);

        // Calculate and lock maximum payment
        euint64 maxPayment = TFHE.mul(validQuantity, price);
        TFHE.allowTransient(maxPayment, address(paymentToken));
        paymentToken.transferFrom(msg.sender, address(this), maxPayment);

        // Record bid
        bids[msg.sender] = EncryptedBid({
            quantity: validQuantity,
            price: price,
            initialized: true,
            processed: false
        });
        bidders.push(msg.sender);

        // Update highest bid if applicable
        ebool isHigher = TFHE.gt(price, highestBid);
        highestBid = TFHE.select(isHigher, price, highestBid);

        emit BidPlaced(msg.sender);
    }

    /// @notice Start the settlement process
    /// @dev Checks conditions and initiates settlement
    function settleAuction() external {
        require(block.timestamp >= endTime, "Auction not ended");
        require(auctionState == AuctionState.Active, "Not active");
        
        if (bidders.length < minParticipants) {
            auctionState = AuctionState.Failed;
            emit AuctionFailed();
            return;
        }

        auctionState = AuctionState.Settling;
        _processSettlement();
    }

    /// @notice Process the auction settlement
    /// @dev Implements the single-price auction mechanism
    function _processSettlement() internal {
        euint64 remainingTokens = TFHE.asEuint64(totalTokens);
        euint64 currentPrice = highestBid;

        for (uint256 i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            EncryptedBid storage bid = bids[bidder];

            // Use TFHE.select() instead of if (TFHE.decrypt(...))
            euint64 allocation = TFHE.select(
                TFHE.gt(remainingTokens, TFHE.asEuint64(0)),
                TFHE.min(bid.quantity, remainingTokens),
                TFHE.asEuint64(0)
            );

            tokenAllocations[bidder] = allocation;
            remainingTokens = TFHE.sub(remainingTokens, allocation);
            totalAllocated = TFHE.add(totalAllocated, allocation);
            
            ebool updatePrice = TFHE.and(
                TFHE.eq(remainingTokens, TFHE.asEuint64(0)),
                TFHE.gt(allocation, TFHE.asEuint64(0))
            );
            settlementPrice = TFHE.select(updatePrice, bid.price, settlementPrice);
        }

        auctionState = AuctionState.Settled;
        emit AuctionSettled();
    }

    /// @notice Claim allocated tokens
    /// @dev Handles token distribution and refunds
    function claimTokens() external {
        require(auctionState == AuctionState.Settled, "Not settled");
        euint64 allocation = tokenAllocations[msg.sender];

        euint64 zero = TFHE.asEuint64(0);
        euint64 validAllocation = TFHE.select(TFHE.gt(allocation, zero), allocation, zero);
        ebool hasAllocation = TFHE.gt(validAllocation, zero);

        // Dummy operation for consistency
        highestBid = TFHE.select(hasAllocation, highestBid, highestBid);

        // Calculate and process final payment
        euint64 finalPayment = TFHE.mul(validAllocation, settlementPrice);
        TFHE.allowTransient(finalPayment, address(tokenForSale));
        tokenForSale.transfer(msg.sender, validAllocation);

        // Process refund if applicable
        euint64 initialPayment = TFHE.mul(bids[msg.sender].quantity, bids[msg.sender].price);
        euint64 refund = TFHE.sub(initialPayment, finalPayment);
        ebool hasRefund = TFHE.gt(refund, zero);
        paymentToken.transfer(msg.sender, TFHE.select(hasRefund, refund, zero));

        // Reset state
        tokenAllocations[msg.sender] = TFHE.asEuint64(0);
        delete bids[msg.sender];

        emit TokensClaimed(msg.sender);
    }

    /// @notice Get refund for failed auction
    /// @dev Returns locked payments if auction fails
    function getRefund() external {
        require(auctionState == AuctionState.Failed, "Not failed");
        EncryptedBid storage bid = bids[msg.sender];
        require(bid.initialized, "No bid to refund");

        euint64 refundAmount = TFHE.mul(bid.quantity, bid.price);
        TFHE.allowTransient(refundAmount, address(paymentToken));
        paymentToken.transfer(msg.sender, refundAmount);

        delete bids[msg.sender];
    }

    /// @notice View functions
    /// @dev Public getters for auction state
    function getAuctionState() external view returns (AuctionState) {
        return auctionState;
    }

    function getBidderCount() external view returns (uint256) {
        return bidders.length;
    }

    function getRemainingTime() external view returns (uint256) {
        if (block.timestamp >= endTime) return 0;
        return endTime - block.timestamp;
    }
}