// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


contract RaffleNFT is ERC721, ERC721URIStorage, Ownable, IERC721Receiver{
    constructor() ERC721("Raffle", "RFL") {}

    function sendToRaffle(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        _safeMint(address(this), tokenId);
        _setTokenURI(tokenId, uri);
        IERC721(address(this)).safeTransferFrom(address(this), to, tokenId);
        
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
