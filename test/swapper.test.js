const IUniswapV2Router = artifacts.require("IUniswapV2Router");
const Swapper = artifacts.require("Swapper");
const IERC20 = artifacts.require("IERC20");

const UNI_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
const DAI_ADDRESS = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const LINK_ADDRESS = "0x514910771AF9Ca656af840dff83E8264EcF986CA";

const { expectEvent, time } = require("@openzeppelin/test-helpers");

// HELPERS
const toWei = (value) => web3.utils.toWei(String(value));
const fromWei = (value) => Number(web3.utils.fromWei(String(value)));

// Traditional Truffle test
contract("Router", ([user]) => {
  let swapper, uniRouter, dai, link;

  before(async function () {
    uniRouter = await IUniswapV2Router.at(UNI_ROUTER);
    dai = await IERC20.at(DAI_ADDRESS);
    link = await IERC20.at(LINK_ADDRESS);

    swapper = await Swapper.new();
  });

  it("Should use swapper tool", async function () {
    const distribution = [3000, 7000]; // 30% and 70%
    const tokens = [DAI_ADDRESS, LINK_ADDRESS];

    const tx = await swapper.swap(tokens, distribution, { value: toWei(1) });

    console.log("Gas Used:", tx.receipt.gasUsed);

    const balanceDAI = await dai.balanceOf(user);
    const balanceLINK = await link.balanceOf(user);
    const contractBalance = await web3.eth.getBalance(swapper.address);

    assert.notEqual(balanceDAI, 0);
    assert.notEqual(balanceLINK, 0);
    assert.equal(contractBalance, 0);
  });

  it("Should use swapper tool with direct swap", async function () {
    const distribution = [3000, 7000]; // 30% and 70%
    const tokens = [DAI_ADDRESS, LINK_ADDRESS];

    const tx = await swapper.swap2(tokens, distribution, { value: toWei(1) });

    console.log("Gas Used:", tx.receipt.gasUsed);

    const balanceDAI = await dai.balanceOf(user);
    const balanceLINK = await link.balanceOf(user);
    const contractBalance = await web3.eth.getBalance(swapper.address);

    assert.notEqual(balanceDAI, 0);
    assert.notEqual(balanceLINK, 0);
    assert.equal(contractBalance, 0);
  });
});
