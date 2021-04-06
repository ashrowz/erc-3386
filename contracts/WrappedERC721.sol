pragma solidity ^0.8.0;

import "./IWrapper.sol";
import "./Wrapped.sol";
import "./StructuredLinkedList.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Implementation of IWrapper
 */
contract WrappedERC721 is
    IWrapper,
    Wrapped,
    IERC721Receiver
{
    using Address for address;
    using StructuredLinkedList for StructuredLinkedList.List;

    // Address of the ERC721 underlying token.
    address public _baseAddress;
    uint256 private _rate;
    StructuredLinkedList.List private _poolIds;

    constructor (
        string memory name,
        string memory symbol,
        uint256 cap,
        address baseAddress_,
        uint256 rate_
    ) public ERC20(name, symbol) ERC20Capped(cap) {
        require(rate_ > 0, "WrappedERC721: positive rate needed");
        _baseAddress = baseAddress_;
        _rate = rate_;
    }

    // Static exchange rate
    function rate() public view returns (uint256) {
        return _rate;
    }

    function value(uint256 _id, uint256 _amount) public view returns (uint256) {
        return rate() * _amount;
    }

    function batchValue(uint256[] calldata _ids, uint256[] calldata _amounts) public view returns (uint256) {
        uint256 _value = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            _value += value(_ids[i], _amounts[i]);
        }
        return _value;
    }

    function hasId(uint256 _id) public view returns (bool) {
        return _poolIds.nodeExists(_id + 1);
    }

    /**
     * @dev Returns the head token id to be used by {burn}
     */
    function headId() internal view returns (uint256) {
        require(_poolIds.listExists(), "WrappedERC721: pool is empty");
        (bool exists, uint256 node) = _poolIds.getHead();

        return node - 1;
    }

    function _removeId(uint256 _id) internal returns (uint256) {
        return _poolIds.remove(_id + 1) - 1;
    }

    function _nextId(uint256 _id) internal view returns (bool, uint256) {
        (bool exists, uint256 node) = _poolIds.getNextNode(_id + 1);

        return (exists, node - 1);
    }

    function _addId(uint256 _id) internal returns (bool) {
        return _poolIds.pushFront(_id + 1);
    }

    /**
     * @dev Transfer the ERC721 token before mint
     */
    function _beforeMint(uint256 id) internal {
        IERC721(_baseAddress).safeTransferFrom(msg.sender, address(this), id);
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _amount
    ) external override {
        require(_amount == 1, "WrappedERC721: ERC721 mints can only be with 1");
        _beforeMint(_id);

        uint256 _value = value(_id, _amount);
        _mint(_to, _value);

        emit MintSingle(msg.sender, _to, _id, _amount, _value);
    }

    /**
     * @dev Mints multiple ERC721 tokens.
     * `amount` is not needed since each ERC721 id corresponds to
     * exactly 1 token.
     */
    function batchMint(
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external override {
        require(_ids.length > 0, "WrappedERC721: need a non-empty list of ids");
        require(_amounts.length == _ids.length, "WrappedERC721: amounts need to be the same as ids");

        for (uint256 i = 0; i < _ids.length; i++) {
            _beforeMint(_ids[i]);
        }

        uint256 _value = batchValue(_ids, _amounts);

        _mint(_to, _value);
        emit MintBatch(msg.sender, _to, _ids, _amounts, _value);
    }

    function _transferBase(address _account, uint256 _id, uint256 _amount) internal {
        IERC721(_baseAddress).safeTransferFrom(address(this), _account, _id);
    }

    function _afterBurn(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        uint256 _value
    ) internal {
        _transferBase(_to, _id, _amount);
        _removeId(_id);
        emit BurnSingle(_from, _to, _id, _amount, _value);
    }

    function burn(
        address _from,
        address _to,
        uint256 _amount
    ) external override {
        require(_amount > 0, "WrappedERC721: need a positive amount");
        uint256 _id = headId();
        uint256 _value = value(_id, _amount);
        burnFrom(_from, _value);
        _afterBurn(_from, _to, _id, _amount, _value);
    }

    function batchBurn(
        address _from,
        address _to,
        uint256[] calldata _amounts
    ) external override {
        require(_amounts.length > 0, "WrappedERC721: need a non-empty _amounts");
        require(_amounts.length <= _poolIds.sizeOf(), "WrappedERC721: amounts are greater than pool size");
        uint256 _value = 0;
        uint256[] memory _ids = new uint256[](_amounts.length);
        uint256 _id = headId();

        _value += value(_id, _amounts[0]);
        _ids[0] = _id;
        bool exists;

        for (uint256 i = 1; i < _amounts.length; i++) {
            (exists, _id) = _nextId(_id);

            _value += value(_id, _amounts[i]);
            _ids[i] = _id;
        }

        burnFrom(_from, _value);

        for (uint256 i = 0;  i < _ids.length; i++) {
            uint256 _id = _ids[i];
            _transferBase(_to, _id, _amounts[i]);
            _removeId(_id);
        }
        emit BurnBatch(_from, _to, _ids, _amounts, _value);
    }

    function idBurn(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount
    ) external override {
        require(hasId(_id), "WrappedERC721: id not found");
        uint256 _value = value(_id, _amount);

        burnFrom(_from, _value);
        _afterBurn(_from, _to, _id, _amount, _value);
    }

    function batchIdBurn(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _amounts
    ) external override {
        require(_ids.length > 0, "WrappedERC721: need a non-empty list of ids");
        require(_amounts.length == _ids.length, "WrappedERC721: amounts need to be the same as ids");

        uint256 _value = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            uint256 _id = _ids[i];
            require(hasId(_id), "WrappedERC721: id not found");
            _value += value(_id, _amounts[i]);
        }

        burnFrom(_from, _value);

        for (uint256 i=0; i < _amounts.length; i++) {
            uint256 _id = _ids[i];
            _transferBase(_to, _id, _amounts[i]);
            _removeId(_id);
        }
        emit BurnBatch(_from, _to, _ids, _amounts, _value);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        require(_addId(tokenId), "WrappedERC721: could not add id");
        return this.onERC721Received.selector;
    }
}
