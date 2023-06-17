// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";

contract CrossChainLending {
    address public owner;
    uint256 public currentRequestId;

    mapping(string => mapping(uint256 => uint256)) public borrowRequests;
    mapping(string => mapping(uint256 => uint256)) public repaymentRequests;
    mapping(uint256 => string) public borrowAcknowledgments;
    mapping(uint256 => string) public repaymentAcknowledgments;

    IGateway public gatewayContract;

    event BorrowRequest(uint256 indexed requestId, string chainId, uint256 amount);
    event BorrowSuccess(uint256 indexed requestId);
    event BorrowFailure(uint256 indexed requestId);
    event RepaymentRequest(uint256 indexed requestId, string chainId, uint256 amount);
    event RepaymentSuccess(uint256 indexed requestId);
    event RepaymentFailure(uint256 indexed requestId);

    error CustomError(string message);

    constructor(address payable gatewayAddress, string memory feePayerAddress) {
        owner = msg.sender;
        gatewayContract = IGateway(gatewayAddress);
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    function setDappMetadata(string memory feePayerAddress) external {
        require(msg.sender == owner, "Only owner");
        gatewayContract.setDappMetadata(feePayerAddress);
    }

    function setGateway(address gateway) external {
        require(msg.sender == owner, "Only owner");
        gatewayContract = IGateway(gateway);
    }

    function borrow(uint256 amount) external {
        currentRequestId++;
        borrowRequests[gatewayContract.chainId()][currentRequestId] = amount;
        emit BorrowRequest(currentRequestId, gatewayContract.chainId(), amount);
    }

    function repayment(uint256 requestId, uint256 amount) external {
        repaymentRequests[gatewayContract.chainId()][requestId] = amount;
        emit RepaymentRequest(requestId, gatewayContract.chainId(), amount);
    }

    function iReceive(string memory requestSender, bytes memory packet, string memory srcChainId) external returns (uint256, uint256) {
        require(msg.sender == address(gatewayContract), "Only gateway");

        (uint256 requestId, uint256 requestType, uint256 amount) = abi.decode(packet, (uint256, uint256, uint256));

        if (requestType == 0) {
            borrowRequests[srcChainId][requestId] = amount;
        } else if (requestType == 1) {
            repaymentRequests[srcChainId][requestId] = amount;
        } else {
            revert("Invalid request type");
        }

        return (requestId, amount);
    }
}    