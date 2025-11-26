// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IERC20Minimal {
    function balanceOf(address) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface IPoolLike {
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes calldata params, uint16 referralCode) external;
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IPriceOracleLike {
    // returns price of `asset` in USD with 8 decimals (exemplo: Chainlink style)
    function getAssetPrice(address asset) external view returns (uint256);
}

interface ISwapper {
    // swap exact source amount; returns amount received
    function swapExactInput(address srcToken, address dstToken, uint256 amountIn, uint256 minOut) external returns (uint256);
}

abstract contract FlashLoanReceiverBaseMock {
    IPoolLike public POOL;
    constructor(address pool) {
        POOL = IPoolLike(pool);
    }
}

contract AaveFlashLoopPolygon is FlashLoanReceiverBaseMock {
    address payable public owner;
    IPriceOracleLike public priceOracle;
    ISwapper public swapper;

    // tokens
    address public WETH;
    address public USDC;

    // params
    uint256 public constant LTV_BP = 8000; // 80% in basis points (10000 = 100%)
    uint256 public constant BP_DIV = 10000;

    event StartLoop(uint256 usdcAmount);
    event Swap(address indexed src, address indexed dst, uint256 inAmount, uint256 outAmount);
    event Supply(address indexed asset, uint256 amount);
    event Borrow(address indexed asset, uint256 amount);
    event Repay(address indexed asset, uint256 amount);
    event Withdraw(address indexed asset, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(
        address pool,
        address _priceOracle,
        address _swapper,
        address _weth,
        address _usdc
    ) FlashLoanReceiverBaseMock(pool) {
        owner = payable(msg.sender);
        priceOracle = IPriceOracleLike(_priceOracle);
        swapper = ISwapper(_swapper);
        WETH = _weth;
        USDC = _usdc;
    }

    // Chame essa função para iniciar o flashloan (tudo dentro de uma tx)
    function startLoop(uint256 usdcAmount) external onlyOwner {
        require(usdcAmount > 0, "zero amount");
        bytes memory data = abi.encode(uint8(0)); // placeholder
        emit StartLoop(usdcAmount);
        POOL.flashLoanSimple(address(this), USDC, usdcAmount, data, 0);
    }

    // A função que o Pool chama como receiver do flashloan
    // Nota: o "POOL" externo deve chamar esta função. Aqui simulamos a assinatura.
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(POOL), "Only pool can call");
        require(asset == USDC, "Flash asset must be USDC");

        // 1) Swap todo USDC flash -> WETH
        _approveIfNeeded(USDC, address(swapper), amount);
        uint256 wethReceived = swapper.swapExactInput(USDC, WETH, amount, 1);
        emit Swap(USDC, WETH, amount, wethReceived);

        uint256 totalBorrowedUSDC = 0;
        uint256 iterations = 4; // fixado para exemplo; você pode parametrizar

        // Loop: supply WETH -> borrow USDC -> swap USDC->WETH (incremental alavancagem)
        for (uint256 i = 0; i < iterations; i++) {
            uint256 wethBal = IERC20Minimal(WETH).balanceOf(address(this));
            require(wethBal > 0, "no weth");

            // Supply WETH as collateral
            _approveIfNeeded(WETH, address(POOL), wethBal);
            POOL.supply(WETH, wethBal, address(this), 0);
            emit Supply(WETH, wethBal);

            // Get WETH price in USD (oracle returns price with 8 decimals)
            uint256 priceWeth = priceOracle.getAssetPrice(WETH); // e.g. 2000 * 1e8
            // Convert wethBal (18) * priceWeth (8) -> usd with 6 decimals (USDC)
            // usdAmount = wethBal * priceWeth / 1e(18) -> gives USD with 8 decimals
            // To convert to USDC units (6 decimals): usdAmount_in_usdc = (wethBal * priceWeth) / 1e20 (because 18+? see below)
            // Let's compute safely with full factors:

            // wethBal (18) * priceWeth (8) => 26 decimals. To get to USDC 6 decimals, divide by 1e20.
            uint256 wethValueInUSDC = (wethBal * priceWeth) / 1e20; // result in USDC units (6 decimals)
            // borrow amount = wethValueInUSDC * LTV
            uint256 borrowAmount = (wethValueInUSDC * LTV_BP) / BP_DIV;
            require(borrowAmount > 0, "borrow zero");

            // Borrow USDC (variable rate)
            POOL.borrow(USDC, borrowAmount, 2, 0, address(this));
            emit Borrow(USDC, borrowAmount);
            totalBorrowedUSDC += borrowAmount;

            // Swap borrowed USDC -> more WETH
            _approveIfNeeded(USDC, address(swapper), borrowAmount);
            uint256 wethFromBorrow = swapper.swapExactInput(USDC, WETH, borrowAmount, 1);
            emit Swap(USDC, WETH, borrowAmount, wethFromBorrow);
        }

        // UNWIND: convert collateral (WETH) back to USDC to repay borrows and the flashloan
        // 1) Withdraw all WETH collateral
        uint256 aWethBalance = IERC20Minimal(WETH).balanceOf(address(this));
        // In this mock design, after supply the pool isn't minting aTokens to us; but the mock POOL will allow withdraw of the full collateral
        uint256 withdrawn = POOL.withdraw(WETH, type(uint256).max, address(this));
        emit Withdraw(WETH, withdrawn);

        // 2) Swap WETH -> USDC
        uint256 wethBalFinal = IERC20Minimal(WETH).balanceOf(address(this));
        if (wethBalFinal > 0) {
            _approveIfNeeded(WETH, address(swapper), wethBalFinal);
            uint256 usdcFromSwap = swapper.swapExactInput(WETH, USDC, wethBalFinal, 0);
            emit Swap(WETH, USDC, wethBalFinal, usdcFromSwap);
        }

        // 3) Repay all borrows
        if (totalBorrowedUSDC > 0) {
            _approveIfNeeded(USDC, address(POOL), totalBorrowedUSDC);
            uint256 repayed = POOL.repay(USDC, totalBorrowedUSDC, 2, address(this));
            emit Repay(USDC, repayed);
        }

        // 4) Repay flashloan
        uint256 totalDebt = amount + premium;
        uint256 usdcBal = IERC20Minimal(USDC).balanceOf(address(this));
        require(usdcBal >= totalDebt, "insufficient USDC to repay flashloan");
        _approveIfNeeded(USDC, address(POOL), totalDebt);
        POOL.repay(USDC, totalDebt, 2, address(this));

        // Any leftover tokens belong to owner; withdrawAll can be called later
        return true;
    }

    function withdrawAll() external onlyOwner {
        uint256 wethBal = IERC20Minimal(WETH).balanceOf(address(this));
        if (wethBal > 0) {
            IERC20Minimal(WETH).transfer(owner, wethBal);
        }
        uint256 usdcBal = IERC20Minimal(USDC).balanceOf(address(this));
        if (usdcBal > 0) {
            IERC20Minimal(USDC).transfer(owner, usdcBal);
        }
        (bool sent,) = owner.call{value: address(this).balance}('');
        sent;
    }

    function _approveIfNeeded(address token, address spender, uint256 amount) internal {
        // try to approve without reading allowance (mock simplicity)
        IERC20Minimal(token).approve(spender, amount);
    }

    receive() external payable {}
}

