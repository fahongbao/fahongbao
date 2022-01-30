// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./IRedEnvelope.sol";

contract RedEnvelope is IRedEnvelope, Context, EIP712 {
    using SafeERC20 for IERC20;

    struct Data {
        bytes32 id;
        address token;
        address creator;
        uint256 createAt;
        uint256 amount;
        uint256 count;
        bool random;
        bool dispatched;
        uint256 dispatchedAmount;
        uint256 dispatchedCount;
        bool refunded;
    }

    address private constant NATIVE_TOKEN = address(0);
    uint256 private constant DURATION = 86400;
    bytes32 private immutable DISPATCH_TYPEHASH =
        keccak256("Dispatch(bytes32 id,bytes32 hash)");

    address private _governance;

    mapping(bytes32 => Data) private _datas;
    mapping(bytes32 => bool) private _exists;
    mapping(address => bool) private _isWhitelisted;
    address[] private _whitelist;
    bool private _whitelistCanceled;

    event Received(address sender, uint256 amount);

    modifier onlyExists(bytes32 id) {
        require(_exists[id], "RedEnvelope: id error");
        _;
    }

    modifier onlyWhitelisted(address token) {
        require(
            _whitelistCanceled || _isWhitelisted[token],
            "RedEnvelope: token error"
        );
        _;
    }

    modifier onlyGovernance() {
        require(_msgSender() == _governance, "RedEnvelope: not governance");
        _;
    }

    constructor(address governance_) EIP712("RedEnvelope", "1") {
        _governance = governance_;
        emit SetGovernance(governance_);

        _isWhitelisted[NATIVE_TOKEN] = true;
        _whitelist.push(NATIVE_TOKEN);
        emit AddToWhitelist(NATIVE_TOKEN);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    function create(
        bytes32 id,
        address token,
        uint256 amount,
        uint256 count,
        bool random
    ) external payable override onlyWhitelisted(token) {
        require(!_exists[id], "RedEnvelope: id error");
        require(amount > 0, "RedEnvelope: amount error");
        require(count > 0, "RedEnvelope: count error");

        address account = _msgSender();
        address self = address(this);
        uint256 input;

        if (_isNative(token)) {
            require(amount == msg.value, "RedEnvelope: value error");
            _sendETH(self, amount);
            input = amount;
        } else {
            uint256 oldBalance = IERC20(token).balanceOf(self);
            IERC20(token).safeTransferFrom(account, self, amount);
            input = IERC20(token).balanceOf(self) - oldBalance;
            require(input == amount, "RedEnvelope: transfer error");
        }

        Data storage data = _datas[id];
        data.id = id;
        data.token = token;
        data.amount = amount;
        data.count = count;
        data.creator = account;
        data.createAt = _getTimestamp();
        data.random = random;

        _exists[id] = true;

        emit Created(id, token, amount, count, account);
    }

    function dispatch(
        bytes32 id,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external override onlyExists(id) {
        require(
            _datas[id].creator == _msgSender(),
            "RedEnvelope: not the creator"
        );

        _dispatch(id, recipients, amounts);
    }

    function dispatchBySig(
        bytes32 id,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override onlyExists(id) {
        bytes32 structHash = keccak256(
            abi.encode(
                DISPATCH_TYPEHASH,
                id,
                keccak256(abi.encode(recipients, amounts))
            )
        );
        address signer = ECDSA.recover(_hashTypedDataV4(structHash), v, r, s);
        require(signer == _governance, "RedEnvelope: signature error");
        require(
            _datas[id].count == recipients.length || _isExpired(id),
            "RedEnvelope: not yet"
        );

        _dispatch(id, recipients, amounts);
    }

    function refund(bytes32 id) external override onlyExists(id) {
        require(_isExpired(id), "RedEnvelope: not yet");

        Data storage data = _datas[id];
        require(!data.dispatched, "RedEnvelope: dispatched");
        require(!data.refunded, "RedEnvelope: refunded");
        require(data.creator == _msgSender(), "RedEnvelope: not the creator");

        data.refunded = true;

        if (_isNative(data.token)) {
            _sendETH(data.creator, data.amount);
        } else {
            IERC20(data.token).safeTransfer(data.creator, data.amount);
        }

        emit Refund(id, data.token, data.amount, data.creator);
    }

    function addToWhitelist(address token) external override onlyGovernance {
        require(!_isWhitelisted[token], "RedEnvelope: added");

        _whitelist.push(token);
        _isWhitelisted[token] = true;

        emit AddToWhitelist(token);
    }

    function cancelWhitelist() external override onlyGovernance {
        require(!_whitelistCanceled, "RedEnvelope: canceled");

        _whitelistCanceled = true;
    }

    function setGovernance(address governance_)
        external
        override
        onlyGovernance
    {
        require(governance_ != address(0), "RedEnvelope: address error");

        _governance = governance_;

        emit SetGovernance(governance_);
    }

    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view override returns (bytes32) {
        return _domainSeparatorV4();
    }

    function nativeToken() external pure override returns (address) {
        return NATIVE_TOKEN;
    }

    function governance() external view override returns (address) {
        return _governance;
    }

    function duration() external pure override returns (uint256) {
        return DURATION;
    }

    function whitelist() external view override returns (address[] memory) {
        return _whitelist;
    }

    function isWhitelisted(address token)
        external
        view
        override
        returns (bool)
    {
        return _isWhitelisted[token];
    }

    function isWhitelistCanceled() external view override returns (bool) {
        return _whitelistCanceled;
    }

    function getData(bytes32 id)
        external
        view
        override
        onlyExists(id)
        returns (
            address token,
            address creator,
            uint256 createAt,
            uint256 amount,
            uint256 count,
            bool random,
            bool dispatched,
            uint256 dispatchedAmount,
            uint256 dispatchedCount,
            bool refunded
        )
    {
        Data storage data = _datas[id];

        token = data.token;
        creator = data.creator;
        createAt = data.createAt;
        amount = data.amount;
        count = data.count;
        random = data.random;
        dispatched = data.dispatched;
        dispatchedAmount = data.dispatchedAmount;
        dispatchedCount = data.dispatchedCount;
        refunded = data.refunded;
    }

    function _dispatch(
        bytes32 id,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) private {
        Data storage d = _datas[id];

        require(!d.dispatched, "RedEnvelope: dispatched");
        require(!d.refunded, "RedEnvelope: refunded");
        require(
            recipients.length == amounts.length,
            "RedEnvelope: length error"
        );

        uint256 count = recipients.length;
        require(d.count >= count && count > 0, "RedEnvelope: count error");

        uint256 amount;
        uint256 i;
        for (i = 0; i < count; i++) {
            amount += amounts[i];
        }

        require(d.amount >= amount && amount > 0, "RedEnvelope: amount error");

        d.dispatched = true;
        d.dispatchedAmount = amount;
        d.dispatchedCount = count;

        uint256 remain = d.amount - amount;

        if (_isNative(d.token)) {
            for (i = 0; i < count; i++) {
                _sendETH(recipients[i], amounts[i]);
            }

            if (remain > 0) {
                _sendETH(d.creator, remain);
            }
        } else {
            IERC20 token = IERC20(d.token);
            for (i = 0; i < count; i++) {
                token.transfer(recipients[i], amounts[i]);
            }

            if (remain > 0) {
                token.transfer(d.creator, remain);
            }
        }

        emit Dispatched(id, d.token, amount, count);
    }

    function _sendETH(address to, uint256 value) private {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, "RedEnvelope: ether transfer fail");
    }

    function _isExpired(bytes32 id) private view returns (bool) {
        return _datas[id].createAt + DURATION < _getTimestamp();
    }

    function _isNative(address token) private pure returns (bool) {
        return token == NATIVE_TOKEN;
    }

    function _getTimestamp() private view returns (uint256) {
        return block.timestamp;
    }
}
