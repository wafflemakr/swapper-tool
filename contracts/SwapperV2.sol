//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Exchange.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IBalancerRegistry.sol";
import "./interfaces/IBalancerPool.sol";

contract SwapperV2 is Initializable {
  using SafeMath for uint256;
  using UniswapV2ExchangeLib for IUniswapV2Exchange;

  // ======== STATE V1 STARTS ======== //

  IUniswapV2Factory internal constant factory =
    IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

  IWETH internal constant WETH =
    IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  address public feeRecipient;

  uint256 public fee;

  // ======== STATE V1 ENDS ======== //

  // ======== STATE V2 STARTS ======== //

  IBalancerRegistry internal constant balancerRegistry =
    IBalancerRegistry(0x65e67cbc342712DF67494ACEfc06fe951EE93982);

  enum Dex { UNISWAP, BALANCER }

  // ======== STATE V2 ENDS ======== //

  function initialize(address _feeRecipient, uint256 _fee)
    external
    initializer
  {
    feeRecipient = _feeRecipient;
    fee = _fee;
  }

  function getAddressETH() public pure returns (address eth) {
    eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }

  function _setApproval(
    address to,
    address erc20,
    uint256 srcAmt
  ) internal {
    if (srcAmt > IERC20(erc20).allowance(address(this), to)) {
      IERC20(erc20).approve(to, type(uint256).max);
    }
  }

  function _swapUniswap(
    IERC20 fromToken,
    IERC20 destToken,
    uint256 amount
  ) internal returns (uint256 returnAmount) {
    require(fromToken != destToken, "SAME_TOKEN");
    require(amount > 0, "ZERO-AMOUNT");

    IUniswapV2Exchange exchange = factory.getPair(fromToken, destToken);
    returnAmount = exchange.getReturn(fromToken, destToken, amount);

    fromToken.transfer(address(exchange), amount);
    if (
      uint256(uint160(address(fromToken))) <
      uint256(uint160(address(destToken)))
    ) {
      exchange.swap(0, returnAmount, msg.sender, "");
    } else {
      exchange.swap(returnAmount, 0, msg.sender, "");
    }
  }

  function _swapBalancer(
    address fromToken,
    address destToken,
    uint256 amount,
    uint256 poolIndex
  ) internal {
    address[] memory pools =
      balancerRegistry.getBestPoolsWithLimit(
        fromToken,
        destToken,
        poolIndex + 1
      );

    _setApproval(pools[poolIndex], fromToken, amount);

    IBalancerPool(pools[poolIndex]).swapExactAmountIn(
      fromToken,
      amount,
      destToken,
      0,
      type(uint256).max
    );
  }

  /**
    @notice swap ETH for multiple tokens according to distribution % and a dex
    @dev tokens length should be equal to distribution length
    @dev msg.value will be completely converted to tokens
    @param tokens array of tokens to swap to
    @param distribution array of % amount to convert eth from (3054 = 30.54%)
    @param dexes array of % amount to convert eth from (3054 = 30.54%)
   */
  function swap(
    address[] memory tokens,
    uint256[] memory distribution,
    Dex[] memory dexes
  ) external payable {
    require(msg.value > 0);
    require(
      tokens.length == distribution.length && tokens.length == dexes.length
    );
    uint256 afterFee = msg.value.sub(msg.value.mul(fee).div(10000));

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 ethAmt = afterFee.mul(distribution[i]).div(10000);

      WETH.deposit{ value: ethAmt }();

      if (dexes[i] == Dex.UNISWAP)
        _swapUniswap(WETH, IERC20(tokens[i]), ethAmt);
      else if (dexes[i] == Dex.BALANCER)
        _swapBalancer(address(WETH), tokens[i], ethAmt, 0);
      else revert("DEX NOT SUPPORTED");
    }

    // Send remaining ETH to fee recipient
    payable(feeRecipient).transfer(address(this).balance);
  }
}
