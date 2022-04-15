// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IBookNFT is IERC1155 {
    function totalSupply(uint256 _id) external view returns (uint256);

    function setURI(string memory _newURI) external;

    function setCustomURI(uint256 _tokenId, string memory _newURI) external;

    function contractURI() external pure returns (string memory);

    function create(
        address _initialOwner,
        uint256 _id,
        uint256 _initialSupply,
        string memory _uri,
        bytes memory _data
    ) external returns (uint256);

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) external;

    function mintBatch(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) external;

    function burn(
        address from,
        uint256 id,
        uint256 value
    ) external;

    function burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory values
    ) external;

    function setCreator(address _to, uint256[] memory _ids) external;
    function setRoyalty(address _recipient, uint96 value) external;

    function creatorOf(uint256 _id) external view returns (address);
}
