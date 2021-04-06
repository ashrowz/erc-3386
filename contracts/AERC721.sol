pragma solidity >=0.6.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract AERC721 is ERC721 {
    constructor (string memory name_, string memory symbol_) public ERC721(name_, symbol_) {}

    function safeMint(address to, uint256 tokenId, bytes memory _data) external {
        _safeMint(to, tokenId, _data);
    }
}

