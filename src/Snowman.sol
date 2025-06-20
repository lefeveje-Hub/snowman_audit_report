// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * ░▒▓███████▓▒░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓██████████████▓▒░ ░▒▓██████▓▒░░▒▓███████▓▒░
 * ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 *  ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░
 *        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 *        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓█████████████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░
 */
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract Snowman is ERC721, Ownable {
    // >>> ERROR
    error ERC721Metadata__URI_QueryFor_NonExistentToken();
    error SM__NotAllowed();

    // >>> VARIABLES
    uint256 private s_TokenCounter;
    string private s_SnowmanSvgUri;

    // >>> EVENTS
    event SnowmanMinted(address indexed receiver, uint256 indexed numberOfSnowman);

    // >>> CONSTRUCTOR
    // @audit no validation that _SnowmanSvgUri is not empty, this could break all tokenURI() calls.
    constructor(string memory _SnowmanSvgUri) ERC721("Snowman Airdrop", "SNOWMAN") Ownable(msg.sender) {
        s_TokenCounter = 0;
        s_SnowmanSvgUri = _SnowmanSvgUri;
    }

    // >>> EXTERNAL FUNCTIONS
    // @audit not access control on mintSnowman, anyone can mint snowman
    // @audit reentancy attack possible with ER721 _safeMint hook 
    // @audit potential DoS attack with mintSnowman with large amount, there is an unbounded loop
    // @audit inccorrect event emission, it should be emitted for each minted snowman amount
    function mintSnowman(address receiver, uint256 amount) external {
        for (uint256 i = 0; i < amount; i++) {
            _safeMint(receiver, s_TokenCounter);

            emit SnowmanMinted(receiver, s_TokenCounter);

            s_TokenCounter++;
        }
    }

    // >>> PUBLIC FUNCTIONS
    // @audit redundant check with ERC721: invalid token ID, can be removed or replaced with _exists(tokenID)
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (ownerOf(tokenId) == address(0)) {
            revert ERC721Metadata__URI_QueryFor_NonExistentToken();
        }
        string memory imageURI = s_SnowmanSvgUri;

        return string(
            abi.encodePacked(
                _baseURI(),
                Base64.encode(
                    abi.encodePacked(
                        '{"name":"',
                        name(),
                        '", "description":"Snowman for everyone!!!", ',
                        '"attributes": [{"trait_type": "freezing", "value": 100}], "image":"',
                        imageURI,
                        '"}'
                    )
                )
            )
        );
    }

    // >>> INTERNAL FUNCTIONS
    function _baseURI() internal pure override returns (string memory) {
        return "data:application/json;base64,";
    }

    // >>> GETTER FUNCTIONS
    function getTokenCounter() external view returns (uint256) {
        return s_TokenCounter;
    }
}
