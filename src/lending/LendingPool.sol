// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "../token/ERC20.sol";
import {SpotOracle} from "../oracle/SpotOracle.sol";
import {IFlashBorrower} from "./IFlashBorrower.sol";

/// @notice Lenders supply USDH; borrowers post HBR as collateral and borrow USDH up to 75% of
/// its value. Positions above an 80% debt-to-value ratio can be liquidated at a 5% bonus. The
/// pool also offers flash loans of its idle USDH; fees go to the fee vault.
contract LendingPool {
    event Supplied(address indexed lender, uint256 amount);
    event SupplyWithdrawn(address indexed lender, uint256 amount);
    event CollateralDeposited(address indexed account, uint256 amount);
    event CollateralWithdrawn(address indexed account, uint256 amount);
    event Borrowed(address indexed account, uint256 amount);
    event Repaid(address indexed payer, address indexed account, uint256 amount);
    event Liquidated(address indexed liquidator, address indexed account, uint256 repaid, uint256 seized);
    event FlashLoan(address indexed initiator, address indexed receiver, uint256 amount, uint256 fee);

    bytes32 public constant CALLBACK_SUCCESS = keccak256("IFlashBorrower.onFlashLoan");
    uint256 public constant BPS = 10_000;
    uint256 public constant LTV_BPS = 7_500;
    uint256 public constant LIQUIDATION_THRESHOLD_BPS = 8_000;
    uint256 public constant LIQUIDATION_BONUS_BPS = 500;
    uint256 public constant FLASH_FEE_BPS = 9;

    ERC20 public immutable collateralToken;
    ERC20 public immutable debtToken;
    SpotOracle public immutable oracle;
    address public immutable feeVault;

    uint256 public totalSupplied;
    uint256 public totalBorrowed;
    mapping(address => uint256) public supplied;
    mapping(address => uint256) public collateralOf;
    mapping(address => uint256) public debtOf;

    constructor(ERC20 collateralToken_, ERC20 debtToken_, SpotOracle oracle_, address feeVault_) {
        collateralToken = collateralToken_;
        debtToken = debtToken_;
        oracle = oracle_;
        feeVault = feeVault_;
    }

    // ---- lenders ----

    function supply(uint256 amount) external {
        require(amount > 0, "LendingPool: zero amount");
        supplied[msg.sender] += amount;
        totalSupplied += amount;
        require(debtToken.transferFrom(msg.sender, address(this), amount), "LendingPool: transfer failed");
        emit Supplied(msg.sender, amount);
    }

    function withdrawSupply(uint256 amount) external {
        require(supplied[msg.sender] >= amount, "LendingPool: exceeds supplied");
        require(availableLiquidity() >= amount, "LendingPool: insufficient liquidity");
        supplied[msg.sender] -= amount;
        totalSupplied -= amount;
        require(debtToken.transfer(msg.sender, amount), "LendingPool: transfer failed");
        emit SupplyWithdrawn(msg.sender, amount);
    }

    // ---- borrowers ----

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "LendingPool: zero amount");
        collateralOf[msg.sender] += amount;
        require(
            collateralToken.transferFrom(msg.sender, address(this), amount), "LendingPool: transfer failed"
        );
        emit CollateralDeposited(msg.sender, amount);
    }

    function withdrawCollateral(uint256 amount) external {
        require(collateralOf[msg.sender] >= amount, "LendingPool: exceeds collateral");
        collateralOf[msg.sender] -= amount;
        require(collateralToken.transfer(msg.sender, amount), "LendingPool: transfer failed");
        emit CollateralWithdrawn(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        require(amount > 0, "LendingPool: zero amount");
        require(availableLiquidity() >= amount, "LendingPool: insufficient liquidity");
        debtOf[msg.sender] += amount;
        totalBorrowed += amount;
        require(debtOf[msg.sender] <= maxBorrow(msg.sender), "LendingPool: exceeds borrow limit");
        require(debtToken.transfer(msg.sender, amount), "LendingPool: transfer failed");
        emit Borrowed(msg.sender, amount);
    }

    function repay(address account, uint256 amount) external {
        require(amount > 0 && amount <= debtOf[account], "LendingPool: bad amount");
        debtOf[account] -= amount;
        totalBorrowed -= amount;
        require(debtToken.transferFrom(msg.sender, address(this), amount), "LendingPool: transfer failed");
        emit Repaid(msg.sender, account, amount);
    }

    function liquidate(address account, uint256 repayAmount) external returns (uint256 seized) {
        require(isLiquidatable(account), "LendingPool: position healthy");
        require(repayAmount > 0 && repayAmount <= debtOf[account], "LendingPool: bad amount");

        seized = (repayAmount * 1e18 / oracle.price()) * (BPS + LIQUIDATION_BONUS_BPS) / BPS;
        if (seized > collateralOf[account]) seized = collateralOf[account];

        debtOf[account] -= repayAmount;
        totalBorrowed -= repayAmount;
        collateralOf[account] -= seized;

        require(debtToken.transferFrom(msg.sender, address(this), repayAmount), "LendingPool: transfer failed");
        require(collateralToken.transfer(msg.sender, seized), "LendingPool: transfer failed");
        emit Liquidated(msg.sender, account, repayAmount, seized);
    }

    // ---- flash loans ----

    function flashFee(uint256 amount) public pure returns (uint256) {
        return (amount * FLASH_FEE_BPS) / BPS;
    }

    function flashLoan(IFlashBorrower receiver, uint256 amount, bytes calldata data) external {
        require(amount <= availableLiquidity(), "LendingPool: insufficient liquidity");
        uint256 fee = flashFee(amount);
        require(debtToken.transfer(address(receiver), amount), "LendingPool: transfer failed");
        require(
            receiver.onFlashLoan(msg.sender, address(debtToken), amount, fee, data) == CALLBACK_SUCCESS,
            "LendingPool: callback failed"
        );
        require(debtToken.transferFrom(address(receiver), address(this), amount), "LendingPool: repay failed");
        require(debtToken.transferFrom(address(receiver), feeVault, fee), "LendingPool: fee failed");
        emit FlashLoan(msg.sender, address(receiver), amount, fee);
    }

    // ---- views ----

    function availableLiquidity() public view returns (uint256) {
        return totalSupplied - totalBorrowed;
    }

    function collateralValue(address account) public view returns (uint256) {
        return (collateralOf[account] * oracle.price()) / 1e18;
    }

    function maxBorrow(address account) public view returns (uint256) {
        return (collateralValue(account) * LTV_BPS) / BPS;
    }

    function isLiquidatable(address account) public view returns (bool) {
        return debtOf[account] > (collateralValue(account) * LIQUIDATION_THRESHOLD_BPS) / BPS;
    }
}
