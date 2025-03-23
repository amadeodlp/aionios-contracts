// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title TimeCapsule
 * @dev Store messages and assets to be revealed in the future
 */
contract TimeCapsule is ReentrancyGuard {
    using Address for address payable;
    
    enum CapsuleStatus { Draft, Pending, Sealed, ReadyToOpen, Opened, Failed }
    enum ConditionType { Time, MultiSig, Oracle, Compound }
    enum AssetTransferType { Immediate, Conditional }
    
    struct Capsule {
        string title;
        string contentHash;
        address creator;
        address recipient;
        uint256 creationTime;
        uint256 openTime;
        CapsuleStatus status;
        ConditionType conditionType;
        mapping(address => bool) signers;
        uint256 requiredSignatures;
        mapping(address => bool) hasApproved;
        uint256 approvalCount;
        uint256 ethBalance; // ETH stored in the capsule
    }
    
    struct CapsuleInfo {
        string title;
        string contentHash;
        address creator;
        address recipient;
        uint256 creationTime;
        uint256 openTime;
        CapsuleStatus status;
        ConditionType conditionType;
        uint256 ethBalance;
    }
    
    struct Asset {
        address tokenAddress;
        uint256 tokenId;
        uint256 amount;
        bool isNFT;
        bool isApproved;
        AssetTransferType transferType;
    }
    
    uint256 private capsuleCount;
    mapping(uint256 => Capsule) private capsules;
    mapping(uint256 => Asset[]) private capsuleAssets;
    
    event CapsuleCreated(uint256 indexed capsuleId, address indexed creator, address indexed recipient);
    event CapsuleOpened(uint256 indexed capsuleId, address indexed opener);
    event CapsuleStatusChanged(uint256 indexed capsuleId, CapsuleStatus status);
    event AssetAdded(uint256 indexed capsuleId, address tokenAddress, uint256 tokenId, uint256 amount, bool isNFT, AssetTransferType transferType);
    event AssetTransferred(uint256 indexed capsuleId, address indexed recipient, address tokenAddress, uint256 amount);
    event EthDeposited(uint256 indexed capsuleId, address indexed sender, uint256 amount);
    
    /**
     * @dev Create a new time capsule
     * @param _title Title of the capsule
     * @param _contentHash IPFS hash of the content
     * @param _recipient The recipient who can open the capsule
     * @param _openTime The timestamp when the capsule can be opened (for time-based capsules)
     * @return capsuleId The ID of the created capsule
     */
    function createTimeCapsule(
        string memory _title, 
        string memory _contentHash, 
        address _recipient, 
        uint256 _openTime
    ) external returns (uint256) {
        require(_recipient != address(0), "Invalid recipient address");
        require(_openTime > block.timestamp, "Open time must be in the future");
        
        uint256 capsuleId = capsuleCount++;
        Capsule storage capsule = capsules[capsuleId];
        
        capsule.title = _title;
        capsule.contentHash = _contentHash;
        capsule.creator = msg.sender;
        capsule.recipient = _recipient;
        capsule.creationTime = block.timestamp;
        capsule.openTime = _openTime;
        capsule.status = CapsuleStatus.Sealed;
        capsule.conditionType = ConditionType.Time;
        capsule.ethBalance = 0;
        
        emit CapsuleCreated(capsuleId, msg.sender, _recipient);
        
        return capsuleId;
    }
    
    /**
     * @dev Create a multi-signature time capsule
     * @param _title Title of the capsule
     * @param _contentHash IPFS hash of the content
     * @param _recipient The recipient who can open the capsule
     * @param _signers Array of addresses that must approve opening
     * @param _requiredSignatures Number of required signatures to open
     * @return capsuleId The ID of the created capsule
     */
    function createMultiSigCapsule(
        string memory _title, 
        string memory _contentHash, 
        address _recipient, 
        address[] memory _signers,
        uint256 _requiredSignatures
    ) external returns (uint256) {
        require(_recipient != address(0), "Invalid recipient address");
        require(_signers.length > 0, "Must have at least one signer");
        require(_requiredSignatures > 0 && _requiredSignatures <= _signers.length, "Invalid signature requirement");
        
        uint256 capsuleId = capsuleCount++;
        Capsule storage capsule = capsules[capsuleId];
        
        capsule.title = _title;
        capsule.contentHash = _contentHash;
        capsule.creator = msg.sender;
        capsule.recipient = _recipient;
        capsule.creationTime = block.timestamp;
        capsule.status = CapsuleStatus.Sealed;
        capsule.conditionType = ConditionType.MultiSig;
        capsule.requiredSignatures = _requiredSignatures;
        capsule.ethBalance = 0;
        
        for (uint i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "Invalid signer address");
            capsule.signers[_signers[i]] = true;
        }
        
        emit CapsuleCreated(capsuleId, msg.sender, _recipient);
        
        return capsuleId;
    }
    
    /**
     * @dev Deposit ETH to a capsule (can only be done by the creator)
     * @param _capsuleId The ID of the capsule
     */
    function depositEth(uint256 _capsuleId) external payable {
        require(_capsuleId < capsuleCount, "Invalid capsule ID");
        Capsule storage capsule = capsules[_capsuleId];
        
        require(capsule.creator == msg.sender, "Only creator can deposit ETH");
        require(capsule.status == CapsuleStatus.Draft || capsule.status == CapsuleStatus.Pending || capsule.status == CapsuleStatus.Sealed, 
            "Cannot deposit to opened capsule");
        require(msg.value > 0, "Must send ETH");
        
        capsule.ethBalance += msg.value;
        
        emit EthDeposited(_capsuleId, msg.sender, msg.value);
    }
    
    /**
     * @dev Add an asset to a capsule
     * @param _capsuleId The ID of the capsule
     * @param _tokenAddress The address of the token contract
     * @param _tokenId The ID of the token (for NFTs)
     * @param _amount The amount of tokens
     * @param _isNFT Whether the token is an NFT
     * @param _transferType Whether to transfer now or when the capsule is opened
     */
    function addAsset(
        uint256 _capsuleId, 
        address _tokenAddress, 
        uint256 _tokenId, 
        uint256 _amount, 
        bool _isNFT,
        AssetTransferType _transferType
    ) external nonReentrant {
        require(_capsuleId < capsuleCount, "Invalid capsule ID");
        Capsule storage capsule = capsules[_capsuleId];
        
        require(capsule.creator == msg.sender, "Only creator can add assets");
        require(capsule.status == CapsuleStatus.Draft || capsule.status == CapsuleStatus.Pending || 
                capsule.status == CapsuleStatus.Sealed, "Cannot add assets to opened capsule");
        
        Asset memory asset = Asset({
            tokenAddress: _tokenAddress,
            tokenId: _tokenId,
            amount: _amount,
            isNFT: _isNFT,
            isApproved: false,
            transferType: _transferType
        });
        
        // If immediate transfer, transfer assets immediately
        if (_transferType == AssetTransferType.Immediate) {
            // Handle the asset transfer based on its type
            if (_isNFT) {
                // For NFTs
                IERC721 nft = IERC721(_tokenAddress);
                nft.transferFrom(msg.sender, address(this), _tokenId);
                asset.isApproved = true;
            } else {
                // For ERC20 tokens
                IERC20 token = IERC20(_tokenAddress);
                uint256 beforeBalance = token.balanceOf(address(this));
                token.transferFrom(msg.sender, address(this), _amount);
                uint256 afterBalance = token.balanceOf(address(this));
                
                // Verify the transfer was successful
                require(afterBalance - beforeBalance == _amount, "Token transfer failed");
                asset.isApproved = true;
            }
        }
        
        // Add asset to the capsule's asset list
        capsuleAssets[_capsuleId].push(asset);
        
        emit AssetAdded(_capsuleId, _tokenAddress, _tokenId, _amount, _isNFT, _transferType);
    }
    
    /**
     * @dev Approve opening a multi-signature capsule
     * @param _capsuleId The ID of the capsule
     */
    function approveCapsuleOpening(uint256 _capsuleId) external {
        require(_capsuleId < capsuleCount, "Invalid capsule ID");
        Capsule storage capsule = capsules[_capsuleId];
        
        require(capsule.conditionType == ConditionType.MultiSig, "Not a multi-sig capsule");
        require(capsule.status == CapsuleStatus.Sealed, "Capsule is not sealed");
        require(capsule.signers[msg.sender], "Not authorized to approve");
        require(!capsule.hasApproved[msg.sender], "Already approved");
        
        capsule.hasApproved[msg.sender] = true;
        capsule.approvalCount++;
        
        if (capsule.approvalCount >= capsule.requiredSignatures) {
            capsule.status = CapsuleStatus.ReadyToOpen;
            emit CapsuleStatusChanged(_capsuleId, CapsuleStatus.ReadyToOpen);
        }
    }
    
    /**
     * @dev Check if a time-based capsule is ready to be opened
     * @param _capsuleId The ID of the capsule
     * @return bool Whether the capsule is ready to be opened
     */
    function isReadyToOpen(uint256 _capsuleId) public view returns (bool) {
        require(_capsuleId < capsuleCount, "Invalid capsule ID");
        Capsule storage capsule = capsules[_capsuleId];
        
        if (capsule.status != CapsuleStatus.Sealed) {
            return false;
        }
        
        if (capsule.conditionType == ConditionType.Time) {
            return block.timestamp >= capsule.openTime;
        } else if (capsule.conditionType == ConditionType.MultiSig) {
            return capsule.approvalCount >= capsule.requiredSignatures;
        }
        
        // For other condition types, implement specific logic
        return false;
    }
    
    /**
     * @dev Open a capsule if conditions are met
     * @param _capsuleId The ID of the capsule
     * @return bool Whether the capsule was successfully opened
     */
    function openCapsule(uint256 _capsuleId) external nonReentrant returns (bool) {
        require(_capsuleId < capsuleCount, "Invalid capsule ID");
        Capsule storage capsule = capsules[_capsuleId];
        
        require(msg.sender == capsule.recipient, "Only recipient can open");
        require(capsule.status == CapsuleStatus.Sealed || capsule.status == CapsuleStatus.ReadyToOpen, 
            "Capsule cannot be opened");
        
        if (capsule.status != CapsuleStatus.ReadyToOpen) {
            // Check if conditions are met
            bool ready = isReadyToOpen(_capsuleId);
            require(ready, "Conditions not met to open capsule");
        }
        
        // Update status
        capsule.status = CapsuleStatus.Opened;
        emit CapsuleStatusChanged(_capsuleId, CapsuleStatus.Opened);
        emit CapsuleOpened(_capsuleId, msg.sender);
        
        // Transfer conditional assets to recipient
        Asset[] storage assets = capsuleAssets[_capsuleId];
        for (uint i = 0; i < assets.length; i++) {
            if (assets[i].transferType == AssetTransferType.Conditional) {
                if (assets[i].isNFT) {
                    // For NFTs
                    IERC721(assets[i].tokenAddress).transferFrom(address(this), capsule.recipient, assets[i].tokenId);
                } else {
                    // For ERC20 tokens
                    IERC20(assets[i].tokenAddress).transfer(capsule.recipient, assets[i].amount);
                }
                
                emit AssetTransferred(_capsuleId, capsule.recipient, assets[i].tokenAddress, assets[i].amount);
            }
        }
        
        // Transfer any ETH balance
        if (capsule.ethBalance > 0) {
            uint256 amount = capsule.ethBalance;
            capsule.ethBalance = 0;
            payable(capsule.recipient).sendValue(amount);
            emit AssetTransferred(_capsuleId, capsule.recipient, address(0), amount);
        }
        
        return true;
    }
    
    /**
     * @dev Get information about a capsule
     * @param _capsuleId The ID of the capsule
     * @return CapsuleInfo The capsule information
     */
    function getCapsuleInfo(uint256 _capsuleId) external view returns (CapsuleInfo memory) {
        require(_capsuleId < capsuleCount, "Invalid capsule ID");
        Capsule storage capsule = capsules[_capsuleId];
        
        return CapsuleInfo({
            title: capsule.title,
            contentHash: capsule.contentHash,
            creator: capsule.creator,
            recipient: capsule.recipient,
            creationTime: capsule.creationTime,
            openTime: capsule.openTime,
            status: capsule.status,
            conditionType: capsule.conditionType,
            ethBalance: capsule.ethBalance
        });
    }
    
    /**
     * @dev Get the number of capsules created
     * @return uint256 The total number of capsules
     */
    function getCapsuleCount() external view returns (uint256) {
        return capsuleCount;
    }
    
    /**
     * @dev Get the assets associated with a capsule
     * @param _capsuleId The ID of the capsule
     * @return Asset[] Array of assets
     */
    function getCapsuleAssets(uint256 _capsuleId) external view returns (Asset[] memory) {
        require(_capsuleId < capsuleCount, "Invalid capsule ID");
        return capsuleAssets[_capsuleId];
    }
    
    /**
     * @dev Allows the contract to receive ETH
     */
    receive() external payable {
        // Do nothing, ETH can be received
    }
}