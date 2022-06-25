// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {Errors} from '../Helper/Errors.sol';
import {IReserveInterestRateStrategy} from '../../Interface/IReserveInterestRateStrategy.sol';
import {IERC20} from '../../Dependency/openzeppelin/IERC20.sol';
import {SafeMath} from '../../Dependency/openzeppelin/SafeMath.sol';
import {SafeERC20} from '../../Dependency/openzeppelin/SafeERC20.sol';
import {ReserveLogic} from './ReserveLogic.sol';
import {GenericLogic} from './GenericLogic.sol';
import {WadRayMath} from '../Math/WadRayMath.sol';
import {PercentageMath} from '../Math/PercentageMath.sol';
import {IPriceOracleGetter} from '../../Interface/IPriceOracleGetter.sol';
import {DataTypes} from '../Type/DataTypes.sol';

/**
 * @title ReserveLogic library
 * @author Aave
 * @notice Implements functions to validate the different actions of the protocol
 */
library ValidationLogic {
  using ReserveLogic for DataTypes.ReserveData;
  using SafeMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeERC20 for IERC20;

  uint256 public constant REBALANCE_UP_LIQUIDITY_RATE_THRESHOLD = 4000;
  uint256 public constant REBALANCE_UP_USAGE_RATIO_THRESHOLD = 0.95 * 1e27; //usage ratio of 95%

  /**
   * @dev Validates a deposit action
   * @param reserve The reserve object on which the user is depositing
   * @param amount The amount to be deposited
   */
  function validateDeposit(DataTypes.ReserveData storage reserve, uint256 amount) external view {
    bool isActive = reserve.configuration.active;
    bool isFrozen = reserve.configuration.frozen;

    require(amount != 0, Errors.GetError(Errors.Error.VL_INVALID_AMOUNT));
    require(isActive, Errors.GetError(Errors.Error.VL_NO_ACTIVE_RESERVE));
    require(!isFrozen, Errors.GetError(Errors.Error.VL_RESERVE_FROZEN));
  }

  /**
   * @dev Validates a withdraw action
   * @param reserveAddress The address of the reserve
   * @param amount The amount to be withdrawn
   * @param userBalance The balance of the user
   * @param reservesData The reserves state
   * @param userConfig The user configuration
   * @param reserves The addresses of the reserves
   * @param reservesCount The number of reserves
   * @param oracle The price oracle
   */
  function validateWithdraw(
    address reserveAddress,
    uint256 amount,
    uint256 userBalance,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    DataTypes.UserConfigurationMap storage userConfig,
    mapping(uint256 => address) storage reserves,
    uint256 reservesCount,
    address oracle
  ) external view {
    require(amount != 0, Errors.GetError(Errors.Error.VL_INVALID_AMOUNT));
    require(amount <= userBalance, Errors.GetError(Errors.Error.VL_NOT_ENOUGH_AVAILABLE_USER_BALANCE));

    bool isActive = reservesData[reserveAddress].configuration.active;
    require(isActive, Errors.GetError(Errors.Error.VL_NO_ACTIVE_RESERVE));

    require(
      GenericLogic.balanceDecreaseAllowed(
        reserveAddress,
        msg.sender,
        amount,
        reservesData,
        userConfig,
        reserves,
        reservesCount,
        oracle
      ),
      Errors.GetError(Errors.Error.VL_TRANSFER_NOT_ALLOWED)
    );
  }

  struct ValidateBorrowLocalVars {
    uint256 currentLtv;
    uint256 currentLiquidationThreshold;
    uint256 amountOfCollateralNeededETH;
    uint256 userCollateralBalanceETH;
    uint256 userBorrowBalanceETH;
    uint256 availableLiquidity;
    uint256 healthFactor;
    bool isActive;
    bool isFrozen;
    bool borrowingEnabled;
  }

  /**
   * @dev Validates a borrow action
   * @param asset The address of the asset to borrow
   * @param reserve The reserve state from which the user is borrowing
   * @param userAddress The address of the user
   * @param amount The amount to be borrowed
   * @param amountInETH The amount to be borrowed, in ETH
   * @param interestRateMode The interest rate mode at which the user is borrowing
   * @param reservesData The state of all the reserves
   * @param userConfig The state of the user for the specific reserve
   * @param reserves The addresses of all the active reserves
   * @param oracle The price oracle
   */

  function validateBorrow(
    address asset,
    DataTypes.ReserveData storage reserve,
    address userAddress,
    uint256 amount,
    uint256 amountInETH,
    uint256 interestRateMode,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    DataTypes.UserConfigurationMap storage userConfig,
    mapping(uint256 => address) storage reserves,
    uint256 reservesCount,
    address oracle
  ) external view {
    ValidateBorrowLocalVars memory vars;

    vars.isActive = reserve.configuration.active;
    vars.isFrozen = reserve.configuration.frozen;
    vars.borrowingEnabled = reserve.configuration.borrowingEnabled;

    require(vars.isActive, Errors.GetError(Errors.Error.VL_NO_ACTIVE_RESERVE));
    require(!vars.isFrozen, Errors.GetError(Errors.Error.VL_RESERVE_FROZEN));
    require(amount != 0, Errors.GetError(Errors.Error.VL_INVALID_AMOUNT));

    require(vars.borrowingEnabled, Errors.GetError(Errors.Error.VL_BORROWING_NOT_ENABLED));

    //validate interest rate mode
    require(
      uint256(DataTypes.InterestRateMode.VARIABLE) == interestRateMode,
      Errors.GetError(Errors.Error.VL_INVALID_INTEREST_RATE_MODE_SELECTED)
    );

    (
      vars.userCollateralBalanceETH,
      vars.userBorrowBalanceETH,
      vars.currentLtv,
      vars.currentLiquidationThreshold,
      vars.healthFactor
    ) = GenericLogic.calculateUserAccountData(
      userAddress,
      reservesData,
      userConfig,
      reserves,
      reservesCount,
      oracle
    );

    require(vars.userCollateralBalanceETH > 0, Errors.GetError(Errors.Error.VL_COLLATERAL_BALANCE_IS_0));

    require(
      vars.healthFactor > GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.GetError(Errors.Error.VL_HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD)
    );

    //add the current already borrowed amount to the amount requested to calculate the total collateral needed.
    vars.amountOfCollateralNeededETH = vars.userBorrowBalanceETH.add(amountInETH).percentDiv(
      vars.currentLtv
    ); //LTV is calculated in percentage

    require(
      vars.amountOfCollateralNeededETH <= vars.userCollateralBalanceETH,
      Errors.GetError(Errors.Error.VL_COLLATERAL_CANNOT_COVER_NEW_BORROW)
    );
  }

  /**
   * @dev Validates a repay action
   * @param reserve The reserve state from which the user is repaying
   * @param amountSent The amount sent for the repayment. Can be an actual value or uint(-1)
   * @param onBehalfOf The address of the user msg.sender is repaying for
   * @param variableDebt The borrow balance of the user
   */
  function validateRepay(
    DataTypes.ReserveData storage reserve,
    uint256 amountSent,
    DataTypes.InterestRateMode rateMode,
    address onBehalfOf,
    uint256 variableDebt
  ) external view {
    bool isActive = reserve.configuration.active;

    require(isActive, Errors.GetError(Errors.Error.VL_NO_ACTIVE_RESERVE));

    require(amountSent > 0, Errors.GetError(Errors.Error.VL_INVALID_AMOUNT));

    require(
      variableDebt > 0 && DataTypes.InterestRateMode(rateMode) == DataTypes.InterestRateMode.VARIABLE,
      Errors.GetError(Errors.Error.VL_NO_DEBT_OF_SELECTED_TYPE)
    );

    require(
      (amountSent != type(uint256).max) || (msg.sender == onBehalfOf),
      Errors.GetError(Errors.Error.VL_NO_EXPLICIT_AMOUNT_TO_REPAY_ON_BEHALF)
    );
  }

  /**
   * @dev Validates the action of setting an asset as collateral
   * @param reserve The state of the reserve that the user is enabling or disabling as collateral
   * @param reserveAddress The address of the reserve
   * @param reservesData The data of all the reserves
   * @param userConfig The state of the user for the specific reserve
   * @param reserves The addresses of all the active reserves
   * @param oracle The price oracle
   */
  function validateSetUseReserveAsCollateral(
    DataTypes.ReserveData storage reserve,
    address reserveAddress,
    bool useAsCollateral,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    DataTypes.UserConfigurationMap storage userConfig,
    mapping(uint256 => address) storage reserves,
    uint256 reservesCount,
    address oracle
  ) external view {
    uint256 underlyingBalance = IERC20(reserve.kTokenAddress).balanceOf(msg.sender);

    require(underlyingBalance > 0, Errors.GetError(Errors.Error.VL_UNDERLYING_BALANCE_NOT_GREATER_THAN_0));

    require(
      useAsCollateral ||
        GenericLogic.balanceDecreaseAllowed(
          reserveAddress,
          msg.sender,
          underlyingBalance,
          reservesData,
          userConfig,
          reserves,
          reservesCount,
          oracle
        ),
      Errors.GetError(Errors.Error.VL_DEPOSIT_ALREADY_IN_USE)
    );
  }

  /**
   * @dev Validates the liquidation action
   * @param collateralReserve The reserve data of the collateral
   * @param principalReserve The reserve data of the principal
   * @param userConfig The user configuration
   * @param userHealthFactor The user's health factor
   * @param userVariableDebt Total variable debt balance of the user
   **/
  function validateLiquidationCall(
    DataTypes.ReserveData storage collateralReserve,
    DataTypes.ReserveData storage principalReserve,
    DataTypes.UserConfigurationMap storage userConfig,
    uint256 userHealthFactor,
    uint256 userVariableDebt
  ) internal view returns (uint256, string memory) {
    if (
      !collateralReserve.configuration.active || !principalReserve.configuration.active
    ) {
      return (
        uint256(Errors.Error.CM_NO_ACTIVE_RESERVE),
        Errors.GetError(Errors.Error.VL_NO_ACTIVE_RESERVE)
      );
    }

    if (userHealthFactor >= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
      return (
        uint256(Errors.Error.CM_HEALTH_FACTOR_ABOVE_THRESHOLD),
        Errors.GetError(Errors.Error.LPCM_HEALTH_FACTOR_NOT_BELOW_THRESHOLD)
      );
    }

    bool isCollateralEnabled =
      collateralReserve.configuration.liquidationThreshold > 0 &&
        userConfig.isUsingAsCollateral[collateralReserve.id];

    //if collateral isn't enabled as collateral by user, it cannot be liquidated
    if (!isCollateralEnabled) {
      return (
        uint256(Errors.Error.CM_COLLATERAL_CANNOT_BE_LIQUIDATED),
        Errors.GetError(Errors.Error.LPCM_COLLATERAL_CANNOT_BE_LIQUIDATED)
      );
    }

    if (userVariableDebt == 0) {
      return (
        uint256(Errors.Error.CM_CURRRENCY_NOT_BORROWED),
        Errors.GetError(Errors.Error.LPCM_SPECIFIED_CURRENCY_NOT_BORROWED_BY_USER)
      );
    }

    return (uint256(Errors.Error.CM_NO_ERROR), Errors.GetError(Errors.Error.LPCM_NO_ERRORS));
  }

  /**
   * @dev Validates an aToken transfer
   * @param from The user from which the aTokens are being transferred
   * @param reservesData The state of all the reserves
   * @param userConfig The state of the user for the specific reserve
   * @param reserves The addresses of all the active reserves
   * @param oracle The price oracle
   */
  function validateTransfer(
    address from,
    mapping(address => DataTypes.ReserveData) storage reservesData,
    DataTypes.UserConfigurationMap storage userConfig,
    mapping(uint256 => address) storage reserves,
    uint256 reservesCount,
    address oracle
  ) internal view {
    (, , , , uint256 healthFactor) =
      GenericLogic.calculateUserAccountData(
        from,
        reservesData,
        userConfig,
        reserves,
        reservesCount,
        oracle
      );

    require(
      healthFactor >= GenericLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      Errors.GetError(Errors.Error.VL_TRANSFER_NOT_ALLOWED)
    );
  }
}
