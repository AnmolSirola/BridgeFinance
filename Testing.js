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

  it("should allow borrowing cross-chain", async function () {
    // Borrow request parameters
    const destChainId = "destinationChainId";
    const destinationContractAddress = "destinationContractAddress";
    const asset = "asset";
    const amount = 100;
