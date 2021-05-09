const axios = require("axios");

const SwapperV1 = artifacts.require("SwapperV1");
const SwapperV2 = artifacts.require("SwapperV2");
const IERC20 = artifacts.require("IERC20");

const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
const UNI_ADDRESS = "0x1f9840a85d5af5bf1d1762f925bdaddc4201f984";
const USDT_ADDRESS = "0xdac17f958d2ee523a2206206994597c13d831ec7";

const { expectEvent, time } = require("@openzeppelin/test-helpers");

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

const FEE = 1000; // 1%

contract("Swapper", ([user, feeRecipient]) => {
  let swapper, uniRouter, dai, link;

  before(async function () {
    dai = await IERC20.at(DAI_ADDRESS);
    link = await IERC20.at(LINK_ADDRESS);
  });

  it("Should deploy proxy with V1", async function () {
    const SwapperV1Factory = await ethers.getContractFactory("SwapperV1");

    const proxy = await upgrades.deployProxy(SwapperV1Factory, [
      feeRecipient,
      FEE,
    ]);
    swapper = await SwapperV1.at(proxy.address);
  });

  it("Should use swapper tool", async function () {
    const distribution = [3000, 7000]; // 30% and 70%
    const tokens = [DAI_ADDRESS, LINK_ADDRESS];
    const intialFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    const tx = await swapper.swap(tokens, distribution, { value: toWei(1) });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balanceDAI = await dai.balanceOf(user);
    const balanceLINK = await link.balanceOf(user);
    const contractBalance = await web3.eth.getBalance(swapper.address);
    const finalFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    assert.notEqual(balanceDAI, 0);
    assert.notEqual(balanceLINK, 0);
    assert.equal(contractBalance, 0);
    assert(
      fromWei(finalFeeRecipientBalance) > fromWei(intialFeeRecipientBalance)
    );
  });

  it("Should upgrade to V2", async function () {
    const SwapperV2Factory = await ethers.getContractFactory("SwapperV2");

    const proxy = await upgrades.upgradeProxy(
      swapper.address,
      SwapperV2Factory
    );
    swapper = await SwapperV2.at(proxy.address);
  });

  it("Should swap using best dex", async function () {
    const { data: data1 } = await axios.get(
      `https://api.1inch.exchange/v3.0/1/quote?fromTokenAddress=${WETH_ADDRESS}&toTokenAddress=${DAI_ADDRESS}&amount=${toWei(
        0.3
      )}&protocols=UNISWAP_V2,BALANCER`
    );
    console.log(`\tSwap WETH to DAI in ${data1.protocols[0][0][0].name}`);
    const protocol1 = data1.protocols[0][0][0].name === "UNISWAP_V2" ? 0 : 1;

    const { data: data2 } = await axios.get(
      `https://api.1inch.exchange/v3.0/1/quote?fromTokenAddress=${WETH_ADDRESS}&toTokenAddress=${LINK_ADDRESS}&amount=${toWei(
        0.7
      )}&protocols=UNISWAP_V2,BALANCER`
    );
    console.log(`\tSwap WETH to LINK in ${data2.protocols[0][0][0].name}`);
    const protocol2 = data2.protocols[0][0][0].name === "UNISWAP_V2" ? 0 : 1;

    const distribution = [3500, 6500]; // 35% and 65%
    const tokens = [DAI_ADDRESS, LINK_ADDRESS];
    const dexes = [protocol1, protocol2];

    const intialFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    const tx = await swapper.swap(tokens, distribution, dexes, {
      value: toWei(1),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balanceDAI = await dai.balanceOf(user);
    const balanceLINK = await link.balanceOf(user);
    const contractBalance = await web3.eth.getBalance(swapper.address);
    const finalFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    assert.notEqual(balanceDAI, 0);
    assert.notEqual(balanceLINK, 0);
    assert.equal(contractBalance, 0);
    assert(
      fromWei(finalFeeRecipientBalance) > fromWei(intialFeeRecipientBalance)
    );
  });
});
