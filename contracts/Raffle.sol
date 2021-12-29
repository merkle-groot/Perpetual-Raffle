// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/**
* @dev Raffle Contract
* @author merkle-groot
*/
contract Raffle is AccessControl, VRFConsumerBase, Pausable, IERC721Receiver{
    // ============ Immutable storage ============

    // Chainlink keyHash
    bytes32 internal immutable keyHash;
    // Chainlink fee
    uint256 internal immutable fee;
    // Price (in Ether) per raffle slot
    uint256 public slotPrice;
    // Number of total available raffle slots
    uint256 public numSlotsAvailable;
    // Address of NFT contract
    address public nftContract;
    // Treasury Role 
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    // Treasury address which manages the locked funds
    address public treasury;
    // No of Raffle Rounds
    uint256 public noOfRounds = 0;
    // Current Phase of a Round
    int256 public currentPhase = -1;
    // Used for time delay
    uint256 public countDown;
    // Stores if Raffle is Stopped by the operator
    uint256 public isStopped = 0;
     // NFT ID
    uint256 public nftID;

    // ============ Mutable storage ============

    // struct to store info about addresses that own/owned a slot
    struct slotOwner{
        uint256 noOfSlots;        
        uint256 noOfSlotsBought;
        uint256 enteredRound;
    }
    // Result from Chainlink VRF
    uint256 public randomResult = 0;
    // Toggled when contract requests result from Chainlink VRF
    bool public randomResultRequested = false;
    // Number of filled raffle slots
    uint256 public numSlotsFilled = 0;
    // Array of slot owners
    address[] public slotOwners;
    // Array of deleted slots to be filled while buying slots
    uint256[] public deletedSlots;
    // Mapping of slot owners to number of slots owned
    mapping(address => slotOwner) public addressToSlotsOwner;
    // Toggled when contract holds NFT to raffle
    bool public nftOwned = false;

    // ============ Events ============

    // Address of slot claimee and number of slots claimed
    event SlotsClaimed(address indexed claimee, uint256 numClaimed);
    // Address of slot refunder and number of slots refunded
    event SlotsRefunded(address indexed refunder, uint256 numRefunded);
    // Address of raffle winner
    event RaffleWon(address indexed winner);

    // ============ Constructor ============


    event TreasuryAddressChanged(
        address
    );

    constructor(
        address _treasuryOwner,
        address _treasuryAddress,
        address _nftAddress,
        uint256 _slotPrice,
        bytes32 _keyhash,
        address _vrfCoordinator, 
        address _linkToken, 
        uint256 _fee,
        uint256 _numSlotsAvailable
    )  VRFConsumerBase(
        _vrfCoordinator, // VRF Coordinator
        _linkToken
    ){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(TREASURY_ROLE, _treasuryOwner);
        treasury = _treasuryAddress;
        keyHash = _keyhash;
        nftContract = _nftAddress;
        fee = _fee; 
        slotPrice = _slotPrice;
        numSlotsAvailable = _numSlotsAvailable;
    }
      // ============ Functions ============

    /**
    * @dev Function used to buy slots or get free slots
    * @param _numSlots No of slots
    * @param _method 0 if buying, 1 if getting it for free
    * @notice For getting free slots, the number must be calculated at front-end
    */
    function purchaseSlot(uint256 _numSlots, uint256 _method) payable external whenNotPaused(){
        // method 0 -> buy slots
        // method 1 -> get free slots

        // Require the currentPhase to be the Raffle phase
        require(currentPhase == 0, "Cannot buy during this round");
        // Require purchasing at least 1 slot
        require(_numSlots > 0, "Raffle: Cannot purchase 0 slots.");
        // Require the raffle contract to own the NFT to raffle
        require(nftOwned == true, "Raffle: Contract does not own raffleable NFT.");
        // Require there to be available raffle slots
        require(numSlotsFilled < numSlotsAvailable, "Raffle: All raffle slots are filled.");
        // Prevent claiming after winner selection
        require(randomResultRequested == false, "Raffle: Cannot purchase slot after winner has been chosen.");
        // Require appropriate payment for number of slots to purchase if the method is 0
        require(msg.value >= _numSlots * slotPrice || _method == 1, "Raffle: Insufficient ETH provided to purchase slots.");
        // Require the caller to have participated in the last round if the method is 1
        require((addressToSlotsOwner[msg.sender].enteredRound < noOfRounds && _numSlots <= (addressToSlotsOwner[msg.sender].noOfSlotsBought/10 + 1)) || _method == 0, "Raffle: Cannot increment slots in this round");
        // Require number of slots to purchase to be <= number of available slots
        require(_numSlots <= numSlotsAvailable - numSlotsFilled, "Raffle: Requesting to purchase too many slots.");

        uint256 idx = 0;

        // Try to allot the deleted slots if available
        while (deletedSlots.length != 0){
            slotOwners[deletedSlots[deletedSlots.length - 1]] = msg.sender;
            deletedSlots.pop();
            idx++;
        }

        // Allot new slots
        if(idx < _numSlots){
            // For each _numSlots
            for (uint256 i = 0; i < _numSlots - idx; i++) {
                // Add address to slot owners array
                slotOwners.push(msg.sender);
            }
        }

        // Increment filled slots
        numSlotsFilled = numSlotsFilled + _numSlots;
        // Increment slots owned by address
        addressToSlotsOwner[msg.sender].noOfSlots += _numSlots;
        addressToSlotsOwner[msg.sender].enteredRound = noOfRounds;

        // Increment the slots bought count if method is 0
        if(_method == 0){
            addressToSlotsOwner[msg.sender].noOfSlotsBought += _numSlots;
        }
        // Emit claim event
        emit SlotsClaimed(msg.sender, _numSlots);
    }

    /**
    * @dev Function to get refund from the raffle
    * @param deleteIndices Pass the array of indices to be deleted
    * @notice Only bought slots can be refunded
    */
    function refundSlot(uint[] calldata deleteIndices) external whenNotPaused(){
        //Require the currentPhase to be the raffle Round
        require(currentPhase == 0 || isStopped == 1, "Raffle: Cannot refund during this round.");
        // Require the raffle contract to own the NFT to raffle
        require(nftOwned == true || isStopped == 1, "Raffle: Contract does not own raffleable NFT.");
        // Require number of slots owned by address to be >= _numSlots requested for refund
        require(addressToSlotsOwner[msg.sender].noOfSlotsBought >= deleteIndices.length, "Raffle: Address did not buy these slots.");

        uint256 idx = 0;
        uint256 deletedCount = 0;

        // Loop through all entries 
        while (idx < deleteIndices.length) {
            if(deleteIndices[idx] < slotOwners.length){
                if (slotOwners[deleteIndices[idx]] == msg.sender) {
                    slotOwners[deleteIndices[idx]] = address(0);
                    deletedSlots.push(deleteIndices[idx]);
                    deletedCount += 1;
                }
            }
            idx++;
        }

        // Repay raffle participant
        payable(msg.sender).transfer(deletedCount * slotPrice);
        // Decrement filled slots
        numSlotsFilled = numSlotsFilled - deletedCount;
        // Decrement slots owned by address
        addressToSlotsOwner[msg.sender].noOfSlots -= deletedCount;
        addressToSlotsOwner[msg.sender].noOfSlotsBought -= deletedCount;

        // Emit refund event
        emit SlotsRefunded(msg.sender, deletedCount);
    }

    /**
    * @dev Internal Function called by exitLockPeriod
    * @notice Calls the Chainlink Oracle
    */
    function collectRandomWinner() internal returns (bytes32 requestId) {
        // Require at least 1 raffle slot to be filled
        require(numSlotsFilled > 0, "Raffle: No slots are filled");
        // Require NFT to be owned by raffle contract
        require(nftOwned == true, "Raffle: Contract does not own raffleable NFT.");
        // Require this to be the first time that randomness is requested
        require(randomResultRequested == false, "Raffle: Cannot collect winner twice.");

        // Toggle randomness requested
        randomResultRequested = true;

        // Call for random number
        return getRandomNumber();
    }

    function stopTheRaffle() external onlyRole(DEFAULT_ADMIN_ROLE){
        isStopped = 1;

        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, nftID);
        nftOwned = false;
    }

    /**
    * Disburses NFT to winner and raised raffle pool to owner
    */
    function disburseWinner() external {
        // Require that the contract holds the NFT
        require(nftOwned == true, "Raffle: Cannot disurbse NFT to winner without holding NFT.");
        // Require that a winner has been collected already
        require(randomResultRequested == true, "Raffle: Cannot disburse to winner without having collected one.");
        // Require that the random result is not 0
        require(randomResult != 0, "Raffle: Please wait for Chainlink VRF to update the winner first.");

        uint256 randomNumber = randomResult;
        while(slotOwners[randomNumber % slotOwners.length] == address(0)){
            randomNumber = (randomNumber + 1) % slotOwners.length;
        }
        // Find winner of NFT
        address winner = slotOwners[randomNumber % numSlotsFilled];

        // Transfer NFT to winner
        IERC721(nftContract).safeTransferFrom(address(this), winner, nftID);

        // Toggle nftOwned
        nftOwned = false;

        // Toggle randomness requested to false
        randomResultRequested = false;

        // Reset result
        randomResult = 0;

        // Emit raffle winner
        emit RaffleWon(winner);
    }

    /**
    * @dev Function to lock the funds and enter phase 1
    * @notice Can only be called by admin role
    */
    function enterLockPeriod() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(currentPhase == 0, "Can only call this after raffle round");
        require(countDown > block.timestamp, "Contract is still in raffle round");
        
        currentPhase = 1;
        countDown = block.timestamp + 30 days;
        _pause();
    }

    /**
    * @dev Function to return -1 phase and call the chainlink oracle
    * @notice Can only be called by the admin role   
    */
    function exitLockPeriod() external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused() returns (bytes32 requestId){
        require(currentPhase == 1, "Can only call this after lock period");
        require(countDown > block.timestamp, "Contract is still in lock period");


        _unpause();
        currentPhase = -1;
        return collectRandomWinner();
    }


    /**
    * @dev Called by the NFT contract
    */
    function onERC721Received(
        address operator,
        address from, 
        uint256 tokenId,
        bytes calldata data
    ) external virtual override returns (bytes4) {
        // Require NFT from correct contract
        require(from == nftContract, "Raffle: Raffle not initiated with this NFT contract.");
        require(currentPhase == -1 && nftOwned == false, "Cannot receive NFT at this phase");
        
        nftID = tokenId;

        currentPhase = 0;
        noOfRounds++;
        countDown = block.timestamp + 7 days;
        // Toggle contract NFT ownership
        nftOwned = true;

        // Return required successful interface bytes
        return this.onERC721Received.selector;
    }

    /** 
     * Requests randomness 
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }


    /**
    * @dev Function that allows changing the treasury address
    * @notice Can only be called by the owner of the contract
    * @param newTreasuryAddress The new address to which the collected fees will be spent
     */
    function changeTreasuryAddress(address newTreasuryAddress) public onlyRole(TREASURY_ROLE){
        require(newTreasuryAddress != address(0), "Non zero address required");
        treasury = newTreasuryAddress;
        emit TreasuryAddressChanged(newTreasuryAddress);
    }

    function getSlotOwners()public view returns(address [] memory){
        return slotOwners;
    }
}
