// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@routerprotocol/evm-gateway-contracts/contracts/IGateway.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CrossChainLending {
    using SafeMath for uint256;

    enum BorrowRequestStatus { Active, Repaid, Liquidated }

    struct BorrowRequest {
        address borrower;
        uint256 amount;
        uint256 interestRate;
        address collateralToken;
        BorrowRequestStatus status;
        uint256 expiryTimestamp;
    }

    uint64 public currentRequestId;
    mapping(uint64 => BorrowRequest) public borrowRequests;
    mapping(address => uint256) public lendingBalances;
    mapping(address => uint256) public collateralBalances;
    address public owner;

    IGateway public gatewayContract;

    event BorrowCrossChain(uint64 indexed requestId, string destChainId, string asset, uint256 amount);
    event BorrowCrossChainHandled(address indexed requestSender, string srcChainId, uint64 indexed requestId, string asset, uint256 amount);
    event LendingRequestAcknowledgment(uint256 indexed requestIdentifier, bool execFlag, uint64 indexed requestId, string asset, uint256 amount);
    event RepaymentRequestInitiated(uint64 indexed requestId, uint256 amount);
    event RepaymentRequestReceived(string srcChainId, uint64 indexed requestId, uint256 amount);
    event LiquidationRequestInitiated(uint64 indexed requestId);
    event LiquidationRequestReceived(string srcChainId, uint64 indexed requestId);
    event LoanRepaid(uint64 indexed requestId, address indexed borrower, uint256 amount);
    event CollateralLiquidated(uint64 indexed requestId, address indexed borrower, address indexed liquidator, uint256 collateralAmount);

    constructor(address payable gatewayAddress) {
        gatewayContract = IGateway(gatewayAddress);
        owner = msg.sender;
    }

    function setGateway(address gateway) external {
        require(msg.sender == owner, "Only the owner can call this function");
        gatewayContract = IGateway(gateway);
    }

    function borrowCrossChain(
        string calldata destChainId,
        string calldata destinationContractAddress,
        string calldata asset,
        uint256 amount,
        bytes calldata requestMetadata
    ) external payable {
        currentRequestId++;

        bytes memory packet = abi.encode(currentRequestId, asset, amount);
        bytes memory requestPacket = abi.encode(destinationContractAddress, packet);

        gatewayContract.iSend{value: msg.value}(
            1, // Acknowledgment type: No acknowledgment
            0, // Destination gas limit: 0 for unlimited
            "", // Destination contract method signature: empty string for fallback
            destChainId, // Destination chain ID
            requestMetadata, // Request metadata
            requestPacket // Encoded request packet
        );

        emit BorrowCrossChain(currentRequestId, destChainId, asset, amount);
    }

    function handleBorrowCrossChain(
        address requestSender,
        bytes calldata packet,
        string calldata srcChainId
    ) external returns (uint64, string memory, uint256) {
        require(msg.sender == address(gatewayContract), "Only the gateway can call this function");

        (uint64 requestId, string memory asset, uint256 amount) = abi.decode(packet, (uint64, string, uint256));

        emit BorrowCrossChainHandled(requestSender, srcChainId, requestId, asset, amount);

        return (requestId, asset, amount);
    }

    function handleLendingRequestAcknowledgment(
        uint256 requestIdentifier,
        bool
        execFlag,
        uint64 requestId,
        string calldata asset,
        uint256 amount
        ) external {
        require(msg.sender == address(gatewayContract), "Only the gateway can call this function");
            BorrowRequest storage request = borrowRequests[requestId];
    require(request.status == BorrowRequestStatus.Active, "Invalid request status");

    if (execFlag) {
        // Update lending balances
        lendingBalances[msg.sender] = lendingBalances[msg.sender].add(amount);

        // Update request status
        request.status = BorrowRequestStatus.Repaid;

        emit LendingRequestAcknowledgment(requestIdentifier, execFlag, requestId, asset, amount);
    } else {
        // Trigger liquidation if acknowledgment is rejected
        initiateLiquidation(requestId);
    }
}

function initiateRepayment(uint64 requestId, uint256 amount) external {
    require(borrowRequests[requestId].borrower == msg.sender, "Only the borrower can initiate repayment");

    require(borrowRequests[requestId].status == BorrowRequestStatus.Active, "Invalid request status");

    IERC20 collateralToken = IERC20(borrowRequests[requestId].collateralToken);

    // Transfer repayment amount from the borrower to this contract
    require(collateralToken.transferFrom(msg.sender, address(this), amount), "Repayment transfer failed");

    emit RepaymentRequestInitiated(requestId, amount);
}

function handleRepaymentRequest(
    string calldata srcChainId,
    uint64 requestId,
    uint256 amount
) external {
    require(msg.sender == address(gatewayContract), "Only the gateway can call this function");

    BorrowRequest storage request = borrowRequests[requestId];
    require(request.status == BorrowRequestStatus.Active, "Invalid request status");

    // Update lending balances
    lendingBalances[request.borrower] = lendingBalances[request.borrower].sub(amount);

    // Update collateral balances
    collateralBalances[request.collateralToken] = collateralBalances[request.collateralToken].sub(amount);

    // Update request status
    request.status = BorrowRequestStatus.Repaid;

    emit RepaymentRequestReceived(srcChainId, requestId, amount);
    emit LoanRepaid(requestId, request.borrower, amount);
}

function initiateLiquidation(uint64 requestId) public {
    require(borrowRequests[requestId].status == BorrowRequestStatus.Active, "Invalid request status");

    BorrowRequest storage request = borrowRequests[requestId];
    IERC20 collateralToken = IERC20(request.collateralToken);

    // Calculate the collateral amount to be liquidated (50% of the borrowed amount)
    uint256 collateralAmount = request.amount.div(2);

    // Update collateral balances
    collateralBalances[request.collateralToken] = collateralBalances[request.collateralToken].sub(collateralAmount);

    // Transfer collateral to the liquidator
    require(collateralToken.transfer(msg.sender, collateralAmount), "Collateral transfer failed");

    // Update request status
    request.status = BorrowRequestStatus.Liquidated;

    emit LiquidationRequestInitiated(requestId);
    emit CollateralLiquidated(requestId, request.borrower, msg.sender, collateralAmount);
    }
}         
