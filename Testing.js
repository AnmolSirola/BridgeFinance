const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CrossChainLending", function () {
  let crossChainLending;
  let gatewayContract;
  let owner;
  let borrower;
  let collateralToken;
  let collateralAmount;

  beforeEach(async function () {
    // Deploy the CrossChainLending contract
    const CrossChainLending = await ethers.getContractFactory("CrossChainLending");
    crossChainLending = await CrossChainLending.deploy();
    await crossChainLending.deployed();

    // Deploy a mock gateway contract
    const MockGateway = await ethers.getContractFactory("MockGateway");
    gatewayContract = await MockGateway.deploy();
    await gatewayContract.deployed();

    // Set the gateway contract address in CrossChainLending
    await crossChainLending.setGateway(gatewayContract.address);

    // Get the owner and borrower addresses
    [owner, borrower] = await ethers.getSigners();
  });

 // Borrow cross-chain
    const borrowTx = await crossChainLending.borrowCrossChain(
      destChainId,
      destinationContractAddress,
      asset,
      amount
    );
  // Assert the event is emitted correctly
    expect(borrowTx)
      .to.emit(crossChainLending, "BorrowCrossChain")
      .withArgs(1, destChainId, asset, amount);

    // Check the borrow request details
    const borrowRequest = await crossChainLending.borrowRequests(1);
    expect(borrowRequest.borrower).to.equal(owner.address);
    expect(borrowRequest.amount).to.equal(amount);
    expect(borrowRequest.status).to.equal(0); // BorrowRequestStatus.Active
  });

  it("should allow borrowing cross-chain", async function () {
    // Borrow request parameters
    const destChainId = "destinationChainId";
    const destinationContractAddress = "destinationContractAddress";
    const asset = "asset";
    const amount = 100;
  });
