// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title KosiumPioneer (KPR) ERC721 Token
 *
 * @notice Kosium Pioneers are the foundation of the Kosium Economy.
 *      They represent a stake in all future Kosium related products.
 *
 * @dev Summary:
 *      - Symbol: KPR
 *      - Name: Kosium Pioneer
 *      - Max Supply: 9,999
 *      - Reserve Limit: 1000 initially. Can decrease but cannot increase
 *        - Intended for DAO treasury, team, and marketing 
 *      - Presale Limit: 2000 initially
 *      - Price: 0.06 ETH. Unchangeable
 *
 * @author Brett Cleary
 */
contract KosiumPioneer is ERC721, Ownable {
    using SafeMath for uint256;
    
    string public baseURI;

    bool public saleIsActive = false;
    bool public presaleIsActive = false;

    uint256 public maxPioneerPurchase = 5;
    uint256 public maxPioneerPurchasePresale = 2;
    uint256 public constant pioneerPrice = 0;

    uint256 public MAX_PIONEERS;
    uint256 public MAX_PRESALE_PIONEERS = 2000;
    uint256 public PIONEERS_RESERVED = 1000;

    uint256 public numReserved = 0;
    uint256 public numMinted = 0;

    mapping(address => bool) public whitelistedPresaleAddresses;
    mapping(address => uint256) public presaleBoughtCounts;

    /**
    * @dev Initialize the Kosium Pioneer contract.
    * @param maxNftSupply is the unchangeable max supply of NFT's this contract can mint.
    */
    constructor(
            uint256 maxNftSupply
        )
        ERC721("Kosium Pioneer", "KPR")
    {
        MAX_PIONEERS = maxNftSupply;
    }

    modifier userOnly{
        require(tx.origin==msg.sender,"Only a user may call this function");
        _;
    }

    /**
    * @dev Withdraw funds to contract owner.
    */
    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /**
    * @dev Returns base uri for token metadata.
    */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
    * @dev Changes base uri for token metadata.
    * @param newBaseURI is the new base uri for the token metadata.
    */
    function setBaseTokenURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    /**
    * @dev Mints NFT's to an address. Using numMinted instead of totalSupply() saves gas.
    * @param _to is the address that will own the newly minted tokens.
    * @param numToMint is the number of NFT's to mint to _to.
    */
    function mintTo(address _to, uint numToMint) internal {
        require(numMinted + numToMint <= MAX_PIONEERS, "Reserving would exceed max number of Pioneers to reserve");
        
        for (uint i = 0; i < numToMint; i++) {
            _safeMint(_to, numMinted);
            ++numMinted;
        }
    }

    /**
    * @dev Mints Pioneers to an address of the contract owner's choosing.
    * @param _to is the address that will own the newly minted tokens.
    * @param numberToReserve is the number of NFT's to mint to _to.
    */
    function reservePioneers(address _to, uint numberToReserve) external onlyOwner { 
        require(numReserved + numberToReserve <= PIONEERS_RESERVED, "Reserving would exceed max number of Pioneers to reserve");

        mintTo(_to, numberToReserve);
        numReserved += numberToReserve;
    }

    /**
    * @dev Pause sale if active, make sale active if paused.
    */
    function flipSaleState() external onlyOwner {
        saleIsActive = !saleIsActive;
    }

    /**
    * @dev Pause presale if active, make presale active if paused.
    */
    function flipPresaleState() external onlyOwner {
        presaleIsActive = !presaleIsActive;
    }
    
    /**
    * @notice Mints Pioneers in open sale.
    * @param numberOfTokens is the number of NFT's to mint to caller.
    */
    function mintPioneer(uint numberOfTokens) external payable userOnly {
        require(saleIsActive, "Sale must be active to mint Pioneer");
        require(numberOfTokens <= maxPioneerPurchase, "Can't mint that many tokens at a time");
        require(numMinted + numberOfTokens <= MAX_PIONEERS - PIONEERS_RESERVED + numReserved, "Purchase would exceed max supply of Pioneers");
        require(pioneerPrice.mul(numberOfTokens) <= msg.value, "Ether value sent is not correct");
        
        mintTo(msg.sender, numberOfTokens);
    }

    /**
    * @notice Mints Kosium Pioneers in presale.
    * @param numberOfTokens is the number of NFT's to mint to caller.
    */
    function mintPresalePioneer(uint numberOfTokens) external payable userOnly {
        require(presaleIsActive, "Presale must be active to mint Pioneer");
        require(whitelistedPresaleAddresses[msg.sender], "Sender address must be whitelisted for presale minting");
        require(numberOfTokens + presaleBoughtCounts[msg.sender] <= maxPioneerPurchasePresale, "This whitelisted address cannot mint this many Pioneers in the presale.");
        uint newSupplyTotal = numMinted + numberOfTokens;
        require(newSupplyTotal <= MAX_PRESALE_PIONEERS + numReserved, "Purchase would exceed max supply of Presale Pioneers");
        require(newSupplyTotal <= MAX_PIONEERS - PIONEERS_RESERVED + numReserved, "Purchase would exceed max supply of Pioneers");
        require(pioneerPrice.mul(numberOfTokens) <= msg.value, "Provided ETH is below the required price");
        
        mintTo(msg.sender, numberOfTokens);
        presaleBoughtCounts[msg.sender] += numberOfTokens;
    }

    /**
    * @dev Adds users to the whitelist for the presale.
    * @param earlyAdopterAddresses is an array of addresses to whitelist.
    */
    function whitelistAddressForPresale(address[] calldata earlyAdopterAddresses) external onlyOwner{
        for (uint i = 0; i < earlyAdopterAddresses.length; i++){
            whitelistedPresaleAddresses[earlyAdopterAddresses[i]] = true;
        }
    }

    /**
    * @dev Remove users from the whitelist for the presale.
    * @param earlyAdopterAddresses is an array of addresses to remove from the whitelist.
    */
    function removeFromWhitelist(address[] calldata earlyAdopterAddresses) external onlyOwner{
        for (uint i = 0; i < earlyAdopterAddresses.length; i++){
            whitelistedPresaleAddresses[earlyAdopterAddresses[i]] = false;
        }
    }

    /**
    * @dev Change the max presale limit.
    * @param maxToPresale is the new presale mint limit for the entire presale.
    */
    function setPresaleLimit(uint maxToPresale) public onlyOwner{
        require(maxToPresale <= MAX_PIONEERS, "Presale limit cannot be greater than the max supply of Pioneers.");
        MAX_PRESALE_PIONEERS = maxToPresale;
    }

    /**
    * @dev Change the reserved number of Pioneers. The reserve limit is strictly non-increasing.
    * @param reservedLimit is the new total Pioneers that are reserved.
    *      This cannot be higher than the current reserve limit at execution time.
    */
    function setReserveLimit(uint reservedLimit) public onlyOwner{
        require(reservedLimit <= MAX_PIONEERS, "Reserve supply cannot be greater than the max supply of Pioneers.");
        require(numReserved <= reservedLimit, "Reserve supply cannot be less than the number of Pioneers already reserved.");
        require(reservedLimit < PIONEERS_RESERVED, "Can only reduce the number of Pioneers reserved.");
        PIONEERS_RESERVED = reservedLimit;
    }

    /**
    * @dev Change the max number of Pioneers each account can purchase in one call in the open sale.
    * @param purchaseLimit is the new open sale purchase limit.
    */
    function setPurchaseLimit(uint purchaseLimit) public onlyOwner{
        require(purchaseLimit <= MAX_PIONEERS, "The max number of pioneers to purchase for each account cannot be greater than the maximum number of Pioneers.");
        maxPioneerPurchase = purchaseLimit;
    }

    /**
    * @dev Change the max number of Pioneers each account can purchase in one call in the presale.
    * @param purchaseLimit is the new presale purchase limit.
    */
    function setPurchaseLimitPresale(uint purchaseLimit) public onlyOwner{
        require(purchaseLimit <= MAX_PIONEERS, "The max number of pioneers to purchase for each account cannot be greater than the maximum number of Pioneers.");
        maxPioneerPurchasePresale = purchaseLimit;
    }
}