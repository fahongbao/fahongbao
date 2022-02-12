// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IRedEnvelope {
    event Created(
        bytes32 id,
        address token,
        uint256 amount,
        uint256 count,
        address creator
    );
    event Dispatched(bytes32 id, address token, uint256 amount, uint256 count);
    event Refund(bytes32 id, address token, uint256 amount, address recipient);
    event AddToWhitelist(address token);
    event RevokeFromWhitelist(address token);
    event SetGovernance(address governance_);

    function create(
        bytes32 id,
        address token,
        uint256 amount,
        uint256 count,
        bool random
    ) external payable;

    function dispatch(
        bytes32 id,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external;

    function dispatchBySig(
        bytes32 id,
        address[] calldata recipients,
        uint256[] calldata amounts,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function refund(bytes32 id) external;

    function addToWhitelist(address token) external;

    function revokeFromWhitelist(address token) external;

    function cancelWhitelist() external;

    function setGovernance(address governance_) external;

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function nativeToken() external view returns (address);

    function governance() external view returns (address);

    function duration() external view returns (uint256);

    function whitelist() external view returns (address[] memory);

    function isWhitelisted(address token) external view returns (bool);

    function isWhitelistCanceled() external view returns (bool);

    function getData(bytes32 id)
        external
        view
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
        );
}
