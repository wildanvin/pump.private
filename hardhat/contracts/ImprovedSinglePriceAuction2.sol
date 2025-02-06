// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import { ConfidentialERC20 } from "fhevm-contracts/contracts/token/ERC20/ConfidentialERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "fhevm/config/ZamaFHEVMConfig.sol";
import "fhevm/config/ZamaGatewayConfig.sol";
import "fhevm/gateway/GatewayCaller.sol";

/// @title Improved Single Price Auction with Enhanced Edge Case Handling
/// @notice Implements a single-price auction with handling for multiple edge cases
/// @dev Uses FHE for bid privacy and includes mechanisms for bid modification, time extension, and fair resolution
contract ImprovedSinglePriceAuction2 is 
    SepoliaZamaFHEVMConfig, 
    SepoliaZamaGatewayConfig, 
    GatewayCaller, 
    Ownable2Step 
{
    /// @notice Configuration parameters for auction behavior
    struct AuctionConfig {
        uint256 minDuration;          // Minimum auction duration
        uint256 maxDuration;          // Maximum auction duration
        bool allowBidModification;    // Whether bids can be modified
        uint256 maxModifications;     // Maximum number of bid modifications allowed
        uint256 extensionTime;        // Time to extend auction when threshold is met
        uint256 extensionThreshold;   // Time before end that triggers extension
        uint256 requiredDeposit;      // Required deposit for participation
        uint256 minBidValue;          // Minimum bid value allowed
    }

    /// @notice Structure for encrypted bids with additional metadata
    struct EncryptedBid {
        euint64 quantity;            // Quantity of tokens requested
        euint64 price;               // Price per token
        euint64 timestamp;           // Timestamp for tiebreaking
        uint256 deposit;             // Deposited amount
        bool initialized;            // Whether bid exists
        bool processed;              // Whether bid was processed
        uint256 modificationCount;   // Number of times bid was modified
    }

    /// @notice Structure to track bid validation state
    struct ValidationState {
        ebool isValid;
        bool validated;
    }

    /// @notice Structure to track sorting state
    struct SortingState {
        ebool shouldSwap;
        bool validated;
    }

    /// @notice Auction states
    enum AuctionState {
        Created,
        Active,
        Settling,
        Settled,
        Failed
    }

    // Auction state variables
    AuctionState public auctionState;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public immutable totalTokens;
    uint256 public immutable minParticipants;
    address public immutable beneficiary;
    bool public proceedsClaimed;
    AuctionConfig public config;

    // Token contracts
    ConfidentialERC20 public immutable tokenForSale;
    ConfidentialERC20 public immutable paymentToken;

    // Bid tracking
    mapping(address => EncryptedBid) public bids;
    address[] public bidders;
    mapping(address => euint64) private tokenAllocations;
    mapping(address => uint256) public deposits;
    mapping(address => ValidationState) private bidValidations;
    mapping(uint256 => SortingState) private sortingStates;
    uint256 private currentSortIndex;

    // Encrypted auction variables
    euint64 private highestBid;
    euint64 private settlementPrice;
    euint64 private totalAllocated;
    euint64 private totalProceeds;
    euint64 private lowestWinningBid;

    // Events
    event AuctionCreated(uint256 totalTokens, uint256 startTime, uint256 endTime);
    event BidPlaced(address indexed bidder, uint256 deposit);
    event BidModified(address indexed bidder);
    event AuctionExtended(uint256 newEndTime);
    event AuctionSettled(uint256 participantCount);
    event AuctionFailed();
    event TokensClaimed(address indexed bidder);
    event DepositReturned(address indexed bidder, uint256 amount);
    event ProceedsClaimed(address indexed beneficiary, euint64 amount);

    /// @notice Constructor with extensive configuration
    constructor(
        address _tokenForSale,
        address _paymentToken,
        address _beneficiary,
        uint256 _totalTokens,
        uint256 _minDuration,
        uint256 _maxDuration,
        uint256 _minParticipants,
        AuctionConfig memory _config
    ) Ownable(msg.sender) {
        require(_totalTokens > 0, "Invalid token amount");
        require(_minDuration <= _maxDuration, "Invalid duration range");
        require(_minParticipants > 0, "Invalid min participants");
        require(_beneficiary != address(0), "Invalid beneficiary");
        
        tokenForSale = ConfidentialERC20(_tokenForSale);
        paymentToken = ConfidentialERC20(_paymentToken);
        beneficiary = _beneficiary;
        totalTokens = _totalTokens;
        minParticipants = _minParticipants;
        config = _config;
        
        // Initialize encrypted values
        highestBid = TFHE.asEuint64(0);
        settlementPrice = TFHE.asEuint64(0);
        totalAllocated = TFHE.asEuint64(0);
        totalProceeds = TFHE.asEuint64(0);
        lowestWinningBid = TFHE.asEuint64(0);
        
        auctionState = AuctionState.Created;
        proceedsClaimed = false;
    }

    /// @notice Start the auction
    function startAuction() external onlyOwner {
        require(auctionState == AuctionState.Created, "Wrong state");
        
        startTime = block.timestamp;
        endTime = startTime + config.minDuration;
        auctionState = AuctionState.Active;
        
        emit AuctionCreated(totalTokens, startTime, endTime);
    }

    /// @notice Place a new bid with validation
    function placeBid(
        einput quantityInput,
        einput priceInput,
        bytes calldata inputProof
    ) external payable {
        require(auctionState == AuctionState.Active, "Not active");
        require(block.timestamp < endTime, "Auction ended");
        require(msg.value >= config.requiredDeposit, "Insufficient deposit");
        require(!bids[msg.sender].initialized || 
                (config.allowBidModification && 
                bids[msg.sender].modificationCount < config.maxModifications), 
                "Cannot place bid");

        // Convert and validate inputs
        euint64 quantity = TFHE.asEuint64(quantityInput, inputProof);
        euint64 price = TFHE.asEuint64(priceInput, inputProof);
        euint64 timestamp = TFHE.asEuint64(block.timestamp);

        // Validate bid size
        euint64 minValue = TFHE.asEuint64(config.minBidValue);
        euint64 bidValue = TFHE.mul(quantity, price);
        
        // Request validation
        _requestBidValidation(msg.sender, bidValue, minValue);
        
        // Wait for validation
        require(bidValidations[msg.sender].validated, "Validation pending");
        
        // Reset validation state
        delete bidValidations[msg.sender];

        // Handle bid modification
        if (bids[msg.sender].initialized) {
            _handleBidModification(msg.sender);
        }

        // Lock payment
        euint64 maxPayment = TFHE.mul(quantity, price);
        TFHE.allowTransient(maxPayment, address(paymentToken));
        paymentToken.transferFrom(msg.sender, address(this), maxPayment);

        // Record bid
        bids[msg.sender] = EncryptedBid({
            quantity: quantity,
            price: price,
            timestamp: timestamp,
            deposit: msg.value,
            initialized: true,
            processed: false,
            modificationCount: bids[msg.sender].modificationCount + 1
        });

        if (!bids[msg.sender].initialized) {
            bidders.push(msg.sender);
        }

        // Update state
        ebool isHigher = TFHE.gt(price, highestBid);
        highestBid = TFHE.select(isHigher, price, highestBid);

        // Check for time extension
        _checkAndExtendAuction();

        emit BidPlaced(msg.sender, msg.value);
    }

    /// @notice Internal helpers
    function _requestBidValidation(
        address bidder,
        euint64 bidValue,
        euint64 minValue
    ) internal {
        ebool validationResult = TFHE.ge(bidValue, minValue);
        bidValidations[bidder].isValid = validationResult;
        
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(validationResult);
        Gateway.requestDecryption(cts, this.validateBidCallback.selector, 0, block.timestamp + 100, false);
    }

    function _handleBidModification(address bidder) internal {
        euint64 oldPayment = TFHE.mul(bids[bidder].quantity, bids[bidder].price);
        paymentToken.transfer(bidder, oldPayment);
        emit BidModified(bidder);
    }

    function _checkAndExtendAuction() internal {
        if (block.timestamp >= endTime - config.extensionThreshold) {
            uint256 newEndTime = block.timestamp + config.extensionTime;
            if (newEndTime <= startTime + config.maxDuration) {
                endTime = newEndTime;
                emit AuctionExtended(newEndTime);
            }
        }
    }

    /// @notice Callback functions
    function validateBidCallback(uint256, bool decryptedValidation) public onlyGateway returns (bool) {
        bidValidations[msg.sender].validated = decryptedValidation;
        return decryptedValidation;
    }

    function sortingCallback(uint256 requestId, bool decryptedResult) public onlyGateway returns (bool) {
        sortingStates[currentSortIndex].validated = true;
        return decryptedResult;
    }

    /// @notice Settlement functions
    function settleAuction() external {
        require(block.timestamp >= endTime, "Not ended");
        require(auctionState == AuctionState.Active, "Wrong state");

        if (bidders.length < minParticipants) {
            auctionState = AuctionState.Failed;
            emit AuctionFailed();
            return;
        }

        auctionState = AuctionState.Settling;
        _processSettlement();

        auctionState = AuctionState.Settled;
        emit AuctionSettled(bidders.length);
    }

    function _sortBids() internal {
        for (uint256 i = 0; i < bidders.length; i++) {
            for (uint256 j = i + 1; j < bidders.length; j++) {
                ebool shouldSwap = TFHE.or(
                    TFHE.gt(bids[bidders[j]].price, bids[bidders[i]].price),
                    TFHE.and(
                        TFHE.eq(bids[bidders[j]].price, bids[bidders[i]].price),
                        TFHE.lt(bids[bidders[j]].timestamp, bids[bidders[i]].timestamp)
                    )
                );
                
                uint256[] memory cts = new uint256[](1);
                cts[0] = Gateway.toUint256(shouldSwap);
                
                currentSortIndex = i * bidders.length + j;
                sortingStates[currentSortIndex].shouldSwap = shouldSwap;
                
                Gateway.requestDecryption(cts, this.sortingCallback.selector, 0, block.timestamp + 100, false);
                
                require(sortingStates[currentSortIndex].validated, "Validation pending");
                
                if (sortingStates[currentSortIndex].validated) {
                    address temp = bidders[i];
                    bidders[i] = bidders[j];
                    bidders[j] = temp;
                }
                
                delete sortingStates[currentSortIndex];
            }
        }
    }

    /// @notice Process the auction settlement and allocate tokens
    function _processSettlement() internal {
        _sortBids();

        euint64 remainingTokens = TFHE.asEuint64(totalTokens);
        euint64 currentPrice = highestBid;

        for (uint256 i = 0; i < bidders.length; i++) {
            address bidder = bidders[i];
            EncryptedBid storage bid = bids[bidder];

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
            bid.processed = true;
        }

        // Calculate total proceeds
        totalProceeds = TFHE.mul(totalAllocated, settlementPrice);
    }

    /// @notice Allow beneficiary to claim auction proceeds
    function claimAuctionProceeds() external {
        require(msg.sender == beneficiary, "Not beneficiary");
        require(auctionState == AuctionState.Settled, "Not settled");
        require(!proceedsClaimed, "Already claimed");

        // Calculate final proceeds and transfer
        euint64 totalAmount = TFHE.mul(totalAllocated, settlementPrice);
        
        TFHE.allowTransient(totalAmount, address(paymentToken));
        paymentToken.transfer(beneficiary, totalAmount);

        proceedsClaimed = true;
        emit ProceedsClaimed(beneficiary, totalAmount);
    }

    /// @notice Claim tokens and receive refund if applicable
    function claimTokens() external {
        require(auctionState == AuctionState.Settled, "Not settled");
        euint64 allocation = tokenAllocations[msg.sender];

        euint64 zero = TFHE.asEuint64(0);
        euint64 validAllocation = TFHE.select(
            TFHE.gt(allocation, zero),
            allocation,
            zero
        );

        // Transfer allocated tokens
        TFHE.allowTransient(validAllocation, address(tokenForSale));
        tokenForSale.transfer(msg.sender, validAllocation);

        // Calculate and process refund if any
        euint64 finalPayment = TFHE.mul(validAllocation, settlementPrice);
        euint64 initialPayment = TFHE.mul(
            bids[msg.sender].quantity,
            bids[msg.sender].price
        );
        euint64 refund = TFHE.sub(initialPayment, finalPayment);

        // Process refund if applicable
        TFHE.allowTransient(refund, address(paymentToken));
        paymentToken.transfer(
            msg.sender,
            TFHE.select(TFHE.gt(refund, zero), refund, zero)
        );

        // Return deposit
        uint256 deposit = deposits[msg.sender];
        if (deposit > 0) {
            deposits[msg.sender] = 0;
            payable(msg.sender).transfer(deposit);
            emit DepositReturned(msg.sender, deposit);
        }

        // Clear state
        tokenAllocations[msg.sender] = TFHE.asEuint64(0);
        delete bids[msg.sender];

        emit TokensClaimed(msg.sender);
    }

    /// @notice Get refund for failed auction
    function getRefund() external {
        require(auctionState == AuctionState.Failed, "Not failed");
        require(bids[msg.sender].initialized, "No bid");

        // Refund bid payment
        euint64 refundAmount = TFHE.mul(
            bids[msg.sender].quantity,
            bids[msg.sender].price
        );
        TFHE.allowTransient(refundAmount, address(paymentToken));
        paymentToken.transfer(msg.sender, refundAmount);

        // Return deposit
        uint256 deposit = deposits[msg.sender];
        if (deposit > 0) {
            deposits[msg.sender] = 0;
            payable(msg.sender).transfer(deposit);
            emit DepositReturned(msg.sender, deposit);
        }

        delete bids[msg.sender];
    }

    // View functions
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

    function getBidDetails(
        address bidder
    ) external view returns (
        bool initialized,
        bool processed,
        uint256 modCount,
        uint256 deposit
    ) {
        EncryptedBid storage bid = bids[bidder];
        return (
            bid.initialized,
            bid.processed,
            bid.modificationCount,
            bid.deposit
        );
    }
}