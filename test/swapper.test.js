const axios = require("axios");

const SwapperV1 = artifacts.require("SwapperV1");
const SwapperV2 = artifacts.require("SwapperV2");
const IBalancerRegistry = artifacts.require("IBalancerRegistry");
const IUniswapV2Factory = artifacts.require("IUniswapV2Factory");
const IERC20 = artifacts.require("IERC20");

const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
const USDT_ADDRESS = "0xdac17f958d2ee523a2206206994597c13d831ec7";

const BALANCER_REGISTRY = "0x65e67cbc342712DF67494ACEfc06fe951EE93982";
const UNI_FACTORY = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f";

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

const FEE = 100; // 0.1%

contract("Swapper", ([user, feeRecipient]) => {
  let swapper, uniRouter, dai, link;

  before(async function () {
    dai = await IERC20.at(DAI_ADDRESS);
    link = await IERC20.at(LINK_ADDRESS);
    usdt = await IERC20.at(USDT_ADDRESS);
    balancer = await IBalancerRegistry.at(BALANCER_REGISTRY);
    factory = await IUniswapV2Factory.at(UNI_FACTORY);
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

  it("Should swap 2 tokens using best dex", async function () {
    const TOKENS = [DAI_ADDRESS, LINK_ADDRESS];
    const AMOUNT = [0.3, 0.7];
    const DISTRIBUTIONS = [3000, 7000];

    const swaps = [];

    for (let i = 0; i < TOKENS.length; i++) {
      const token = TOKENS[i];
      const amount = AMOUNT[i];
      const distribution = DISTRIBUTIONS[i];

      const { data } = await axios.get(
        `https://api.1inch.exchange/v3.0/1/quote?fromTokenAddress=${WETH_ADDRESS}&toTokenAddress=${token}&amount=${toWei(
          amount
        )}&protocols=UNISWAP_V2,BALANCER`
      );
      console.log(`\tSwap WETH to ${token} in ${data.protocols[0][0][0].name}`);

      let swapData;

      if (data.protocols[0][0][0].name === "UNISWAP_V2") {
        const pool = await factory.getPair(WETH_ADDRESS, token);
        swapData = { token, pool, distribution, dex: 0 };
      } else {
        const pools = await balancer.getBestPoolsWithLimit(
          WETH_ADDRESS,
          token,
          1
        );
        swapData = { token, pool: pools[0], distribution, dex: 1 };
      }

      swaps.push(swapData);
    }

    const intialFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    const tx = await swapper.swapMultiple(swaps, {
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

  it("Should swap 3 tokens using best dex", async function () {
    const TOKENS = [DAI_ADDRESS, LINK_ADDRESS, USDT_ADDRESS];
    const AMOUNT = [0.3, 0.3, 0.4];
    const DISTRIBUTIONS = [3000, 3000, 4000];

    const swaps = [];

    for (let i = 0; i < TOKENS.length; i++) {
      const token = TOKENS[i];
      const amount = AMOUNT[i];
      const distribution = DISTRIBUTIONS[i];

      const { data } = await axios.get(
        `https://api.1inch.exchange/v3.0/1/quote?fromTokenAddress=${WETH_ADDRESS}&toTokenAddress=${token}&amount=${toWei(
          amount
        )}&protocols=UNISWAP_V2,BALANCER`
      );
      console.log(`\tSwap WETH to ${token} in ${data.protocols[0][0][0].name}`);

      let swapData;

      if (data.protocols[0][0][0].name === "UNISWAP_V2") {
        const pool = await factory.getPair(WETH_ADDRESS, token);
        swapData = { token, pool, distribution, dex: 0 };
      } else {
        const pools = await balancer.getBestPoolsWithLimit(
          WETH_ADDRESS,
          token,
          1
        );
        swapData = { token, pool: pools[0], distribution, dex: 1 };
      }

      swaps.push(swapData);
    }

    const intialFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    const tx = await swapper.swapMultiple(swaps, {
      value: toWei(1),
    });

    console.log("\tGas Used:", tx.receipt.gasUsed);

    const balanceDAI = await dai.balanceOf(user);
    const balanceLINK = await link.balanceOf(user);
    const balanceUSDT = await usdt.balanceOf(user);
    const contractBalance = await web3.eth.getBalance(swapper.address);
    const finalFeeRecipientBalance = await web3.eth.getBalance(feeRecipient);

    assert.notEqual(balanceDAI, 0);
    assert.notEqual(balanceLINK, 0);
    assert.notEqual(balanceUSDT, 0);
    assert.equal(contractBalance, 0);
    assert(
      fromWei(finalFeeRecipientBalance) > fromWei(intialFeeRecipientBalance)
    );
  });
});
