//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Exchange.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWETH.sol";
import "hardhat/console.sol";

contract Swapper {
  using SafeMath for uint256;
  using UniswapV2ExchangeLib for IUniswapV2Exchange;

  IUniswapV2Router router =
    IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

  IUniswapV2Factory internal constant factory =
    IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

  IWETH internal constant WETH =
    IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

  function getAddressETH() public pure returns (address eth) {
    eth = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  }

  function _swapDirect(
    IERC20 fromToken,
    IERC20 destToken,
    uint256 amount
  ) internal returns (uint256 returnAmount) {
    require(fromToken != destToken, "SAME_TOKEN");
    require(amount > 0, "ZERO-AMOUNT");

    if (address(fromToken) == getAddressETH()) {
      WETH.deposit{ value: amount }();
    }

    IERC20 fromTokenReal =
      address(fromToken) == getAddressETH() ? WETH : fromToken;
    IERC20 toTokenReal =
      address(destToken) == getAddressETH() ? WETH : destToken;
    IUniswapV2Exchange exchange = factory.getPair(fromTokenReal, toTokenReal);
    returnAmount = exchange.getReturn(fromTokenReal, toTokenReal, amount);

    fromTokenReal.transfer(address(exchange), amount);
    if (
      uint256(uint160(address(fromTokenReal))) <
      uint256(uint160(address(toTokenReal)))
    ) {
      exchange.swap(0, returnAmount, msg.sender, "");
    } else {
      exchange.swap(returnAmount, 0, msg.sender, "");
    }

    if (address(destToken) == getAddressETH()) {
      WETH.withdraw(WETH.balanceOf(address(this)));
    }
  }

  function swap(address[] memory tokens, uint256[] memory distribution)
    external
    payable
  {
    address[] memory path = new address[](2);
    path[0] = router.WETH();

    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 ethAmt =
        i == tokens.length - 1
          ? address(this).balance
          : msg.value.mul(distribution[i]).div(10000); // 3054 = 30.54%

      path[1] = tokens[i];

      router.swapExactETHForTokens{ value: ethAmt }(
        1,
        path,
        msg.sender,
        block.timestamp + 100
      );
    }
  }

  function swap2(address[] memory tokens, uint256[] memory distribution)
    external
    payable
  {
    for (uint256 i = 0; i < tokens.length; i++) {
      uint256 ethAmt =
        i == tokens.length - 1
          ? address(this).balance
          : msg.value.mul(distribution[i]).div(10000); // 3054 = 30.54%

      _swapDirect(IERC20(getAddressETH()), IERC20(tokens[i]), ethAmt);
    }
  }
}
