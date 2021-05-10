//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IUniswapV2Exchange.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IWETH.sol";
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

    enum Dex {UNISWAP, BALANCER}

    struct Swaps {
        address token;
        address pool;
        uint256 distribution;
        Dex dex;
    }

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
        address pool,
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount
    ) internal {
        require(fromToken != destToken, "SAME_TOKEN");
        require(amount > 0, "ZERO-AMOUNT");

        uint256 returnAmount =
            IUniswapV2Exchange(pool).getReturn(fromToken, destToken, amount);

        fromToken.transfer(pool, amount);
        if (
            uint256(uint160(address(fromToken))) <
            uint256(uint160(address(destToken)))
        ) {
            IUniswapV2Exchange(pool).swap(0, returnAmount, msg.sender, "");
        } else {
            IUniswapV2Exchange(pool).swap(returnAmount, 0, msg.sender, "");
        }
    }

    function _swapBalancer(
        address pool,
        address fromToken,
        address destToken,
        uint256 amount
    ) internal {
        _setApproval(pool, fromToken, amount);

        IBalancerPool(pool).swapExactAmountIn(
            fromToken,
            amount,
            destToken,
            1,
            type(uint256).max
        );
    }

    /**
    @notice swap ETH for multiple tokens according to distribution % and a dex
    @dev tokens length should be equal to distribution length
    @dev msg.value will be completely converted to tokens
    @param swaps array of swap struct containing details about the swap to perform
   */
    function swap(Swaps[] memory swaps) external payable {
        require(msg.value > 0);
        require(swaps.length < 10);

        uint256 afterFee = msg.value.sub(msg.value.mul(fee).div(10000));
        WETH.deposit{value: afterFee}();

        uint256 ethAmt;

        for (uint256 i = 0; i < swaps.length; i++) {
            ethAmt = afterFee.mul(swaps[i].distribution).div(10000);

            if (swaps[i].dex == Dex.UNISWAP)
                _swapUniswap(
                    swaps[i].pool,
                    WETH,
                    IERC20(swaps[i].token),
                    ethAmt
                );
            else if (swaps[i].dex == Dex.BALANCER)
                _swapBalancer(
                    swaps[i].pool,
                    address(WETH),
                    swaps[i].token,
                    ethAmt
                );
            else revert("DEX NOT SUPPORTED");
        }

        // Send remaining ETH to fee recipient
        payable(feeRecipient).transfer(address(this).balance);
    }
}
