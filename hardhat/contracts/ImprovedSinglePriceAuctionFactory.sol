// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "./ImprovedSinglePriceAuction2.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @title Factory for creating Improved Single Price Auctions
/// @notice Allows creation and tracking of multiple auctions with advanced configuration
contract ImprovedSinglePriceAuctionFactory is Ownable2Step {
    /// @notice Mapping of all auctions created by this factory
    mapping(address => bool) public isAuctionCreatedHere;
    
    /// @notice Array to keep track of all created auctions
    address[] public auctions;
    
    /// @notice Default configuration parameters
    struct DefaultConfig {
        uint256 minDuration;
        uint256 maxDuration;
        uint256 minParticipants;
        uint256 extensionTime;
        uint256 extensionThreshold;
        uint256 requiredDeposit;
        uint256 minBidValue;
        uint256 maxModifications;
    }
    
    /// @notice Default configuration values
    DefaultConfig public defaultConfig;
    
    /// @notice Events
    event AuctionCreated(
        address indexed auctionAddress, 
        address indexed creator,
        address indexed beneficiary,
        address tokenForSale,
        address paymentToken,
        uint256 totalTokens
    );
    event DefaultConfigUpdated(DefaultConfig newConfig);
    
    constructor() Ownable(msg.sender) {
        // Set sensible default values
        defaultConfig = DefaultConfig({
            minDuration: 1 days,
            maxDuration: 7 days,
            minParticipants: 2,
            extensionTime: 1 hours,
            extensionThreshold: 30 minutes,
            requiredDeposit: 0.1 ether,
            minBidValue: 0,
            maxModifications: 3
        });
    }
    
    /// @notice Create a new auction with default configuration
    /// @param beneficiary Address to receive auction proceeds
    /// @param tokenForSale Address of token being sold
    /// @param paymentToken Address of token used for payment (0x0 for ETH)
    /// @param totalTokens Number of tokens to sell
    /// @param duration Auction duration in seconds
    /// @param allowBidModification Whether bids can be modified
    function createAuction(
        address beneficiary,
        address tokenForSale,
        address paymentToken,
        uint256 totalTokens,
        uint256 duration,
        bool allowBidModification
    ) external returns (address) {
        // Create auction config from defaults
        ImprovedSinglePriceAuction2.AuctionConfig memory config = ImprovedSinglePriceAuction2.AuctionConfig({
            minDuration: defaultConfig.minDuration,
            maxDuration: duration > defaultConfig.maxDuration ? defaultConfig.maxDuration : duration,
            allowBidModification: allowBidModification,
            maxModifications: defaultConfig.maxModifications,
            extensionTime: defaultConfig.extensionTime,
            extensionThreshold: defaultConfig.extensionThreshold,
            requiredDeposit: defaultConfig.requiredDeposit,
            minBidValue: defaultConfig.minBidValue
        });
        
        return _createAuction(
            beneficiary,
            tokenForSale,
            paymentToken,
            totalTokens,
            defaultConfig.minDuration,
            config.maxDuration,
            defaultConfig.minParticipants,
            config
        );
    }
    
    /// @notice Create a new auction with custom configuration
    /// @param beneficiary Address to receive auction proceeds
    /// @param tokenForSale Address of token being sold
    /// @param paymentToken Address of token used for payment
    /// @param totalTokens Number of tokens to sell
    /// @param minDuration Minimum auction duration
    /// @param maxDuration Maximum auction duration
    /// @param minParticipants Minimum number of participants
    /// @param config Custom auction configuration
    function createAuctionWithConfig(
        address beneficiary,
        address tokenForSale,
        address paymentToken,
        uint256 totalTokens,
        uint256 minDuration,
        uint256 maxDuration,
        uint256 minParticipants,
        ImprovedSinglePriceAuction2.AuctionConfig memory config
    ) external returns (address) {
        return _createAuction(
            beneficiary,
            tokenForSale,
            paymentToken,
            totalTokens,
            minDuration,
            maxDuration,
            minParticipants,
            config
        );
    }
    
    /// @notice Internal function to create auction
    function _createAuction(
        address beneficiary,
        address tokenForSale,
        address paymentToken,
        uint256 totalTokens,
        uint256 minDuration,
        uint256 maxDuration,
        uint256 minParticipants,
        ImprovedSinglePriceAuction2.AuctionConfig memory config
    ) internal returns (address) {
        ImprovedSinglePriceAuction2 auction = new ImprovedSinglePriceAuction2(
            tokenForSale,
            paymentToken,
            beneficiary,
            totalTokens,
            minDuration,
            maxDuration,
            minParticipants,
            config
        );
        
        address auctionAddress = address(auction);
        isAuctionCreatedHere[auctionAddress] = true;
        auctions.push(auctionAddress);
        
        emit AuctionCreated(
            auctionAddress,
            msg.sender,
            beneficiary,
            tokenForSale,
            paymentToken,
            totalTokens
        );
        
        return auctionAddress;
    }
    
    /// @notice Update default configuration
    /// @param newConfig New default configuration values
    function updateDefaultConfig(DefaultConfig memory newConfig) external onlyOwner {
        defaultConfig = newConfig;
        emit DefaultConfigUpdated(newConfig);
    }
    
    /// @notice Get all auctions created by this factory
    function getAllAuctions() external view returns (address[] memory) {
        return auctions;
    }
    
    /// @notice Get auction count
    function getAuctionCount() external view returns (uint256) {
        return auctions.length;
    }
    
    /// @notice Get auction at index
    function getAuctionAtIndex(uint256 index) external view returns (address) {
        require(index < auctions.length, "Index out of bounds");
        return auctions[index];
    }
    
    /// @notice Check if an address is a valid auction
    function isValidAuction(address auction) external view returns (bool) {
        return isAuctionCreatedHere[auction];
    }
}