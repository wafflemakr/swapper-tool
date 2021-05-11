//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./interfaces/IUniswapV2Exchange.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IBalancerRegistry.sol";
import "./interfaces/IBalancerPool.sol";

/**
    @title Multi Swap Tool a.k.a. Swapper
    @author wafflemakr
*/
contract SwapperV1 is Initializable {
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

  function initialize(address _feeRecipient, uint256 _fee)
    external
    initializer
  {
    require(_feeRecipient != address(0));
    require(_fee > 0);
    feeRecipient = _feeRecipient;
    fee = _fee;
  }

  function getAddressETH() public pure returns (address eth) {
    eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }

  /**
    @notice make a swap using uniswap
   */
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

  /**
    @notice swap ETH for multiple tokens according to distribution %
    @dev tokens length should be equal to distribution length
    @dev msg.value will be completely converted to tokens
    @param tokens array of tokens to swap to
    @param distribution array of % amount to convert eth from (3054 = 30.54%)
   */
  function swap(address[] memory tokens, uint256[] memory distribution)
    external
    payable
  {
    require(msg.value > 0);
    require(tokens.length == distribution.length);
    uint256 afterFee = msg.value.sub(msg.value.mul(fee).div(100000));

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 ethAmt = afterFee.mul(distribution[i]).div(10000);

      WETH.deposit{ value: ethAmt }();

      _swapUniswap(WETH, IERC20(tokens[i]), ethAmt);
    }

    // Send remaining ETH to fee recipient
    payable(feeRecipient).transfer(address(this).balance);
  }
}
