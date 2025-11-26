const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AaveFlashLoopPolygon - integration test (ethers v6)", function () {
  let owner, user;
  let weth, usdc, oracle, swapper, pool, flash;

  beforeEach(async () => {
    [owner, user] = await ethers.getSigners();

    // ---------------------------
    // Deploy Mock Tokens
    // ---------------------------
    const ERC20 = await ethers.getContractFactory("MockERC20");
    weth = await ERC20.deploy("Wrapped Ether", "WETH", 18);
    usdc = await ERC20.deploy("USD Coin", "USDC", 6);

    await weth.mint(owner.address, ethers.parseUnits("1000000", 18));
    await usdc.mint(owner.address, ethers.parseUnits("1000000", 6));

    // ---------------------------
    // Price Oracle
    // ---------------------------
    const Oracle = await ethers.getContractFactory("MockOracle");
    oracle = await Oracle.deploy(ethers.parseUnits("2000", 8));

    // ---------------------------
    // Swapper
    // ---------------------------
    const Swapper = await ethers.getContractFactory("MockSwapper");
    swapper = await Swapper.deploy();

    // price: WETH → USDC 2000
    await swapper.setPrice(
      weth.target,
      usdc.target,
      ethers.parseUnits("2000", 18)
    );

    // price: USDC → WETH 0.0005
    await swapper.setPrice(
      usdc.target,
      weth.target,
      ethers.parseUnits("0.0005", 18)
    );

    // liquidity
    await weth.mint(swapper.target, ethers.parseUnits("500000", 18));
    await usdc.mint(swapper.target, ethers.parseUnits("500000", 6));

    // ---------------------------
    // Mock Pool
    // ---------------------------
    const Pool = await ethers.getContractFactory("MockPool");
    pool = await Pool.deploy();
    await usdc.mint(pool.target, ethers.parseUnits("100000", 6));

    // ---------------------------
    // Deploy FlashLoop
    // ---------------------------
    const Flash = await ethers.getContractFactory("AaveFlashLoopPolygon");
    flash = await Flash.deploy(
      pool.target,
      oracle.target,
      swapper.target,
      weth.target,
      usdc.target
    );

    // small buffer
    await usdc.transfer(flash.target, ethers.parseUnits("10", 6));
  });

  it("should execute full flashloan loop and end with profit", async () => {
    const startBalance = await usdc.balanceOf(flash.target);

    // 🔥 usar valor mais alto evita borrowAmount = 0 no mock
    const flashAmount = ethers.parseUnits("100000", 6);

    await expect(flash.startLoop(flashAmount)).to.not.be.reverted;

    const endBalance = await usdc.balanceOf(flash.target);

    expect(endBalance).to.be.gt(startBalance);
  });
});
