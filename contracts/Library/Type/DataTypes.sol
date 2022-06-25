// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library DataTypes {
  struct ReserveData {
    ReserveConfiguration configuration;
    // the liquidity index. Expressed in ray
    uint128 liquidityIndex;
    // (variable) borrow index. Expressed in ray
    uint128 borrowIndex;
    // the current supply rate. Expressed in ray
    uint128 currentLiquidityRate;
    // the current borrow rate. Expressed in ray
    uint128 currentBorrowRate;
    // the timestamp 
    uint40 lastUpdateTimestamp;
    // interest token address
    address kTokenAddress;
    // debt token address
    address dTokenAddress;
    // address of the interest rate strategy
    address interestRateStrategyAddress;
    // the id of the reserve
    uint256 id;
  }

  struct ReserveConfiguration {
    // loan-to-value
    uint256 ltv;
    // the liquidation threshold
    uint256 liquidationThreshold;
    // the liquidation bonus
    uint256 liquidationBonus;
    // the decimals
    uint8 decimals;
    // reserve is active
    bool active;
    // reserve is frozen
    bool frozen;
    // borrowing is enabled
    bool borrowingEnabled;
    // reserve factor
    uint256 reserveFactor;
  }

  struct UserConfigurationMap {
    // uint256 data;
    mapping(uint256 => bool) isUsingAsCollateral;
    mapping(uint256 => bool) isBorrowing;
  }

  struct UserPosition {
    // the trader
    address traderAddress;
    // the asset as margin
    address marginAsset;
    // the asset to borrow
    address borrowedAsset;
    // the amount of provided margin
    uint256 marginAmount;
    // the actual amount of borrowed asset
    uint256 borrowedAmount;
    // the liquidationThreshold at trade
    uint256 liquidationThreshold;
    // the id of position
    uint256 id;
  }

  enum InterestRateMode {NONE, VARIABLE}
}
