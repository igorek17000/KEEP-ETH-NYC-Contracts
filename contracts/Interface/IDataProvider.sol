// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {ILendingPoolAddressesProvider} from './ILendingPoolAddressesProvider.sol';

interface IDataProvider {
  struct TokenData {
    string symbol;
    address tokenAddress;
  }

  struct AggregatedReserveData {
    address underlyingAsset;
    string name;
    string symbol;
    uint256 decimals;
    uint256 baseLTVasCollateral;
    uint256 reserveLiquidationThreshold;
    uint256 reserveLiquidationBonus;
    uint256 reserveFactor;
    bool usageAsCollateralEnabled;
    bool borrowingEnabled;
    bool isActive;
    bool isFrozen;
    // base data
    uint128 liquidityIndex;
    uint128 borrowIndex;
    uint128 liquidityRate;
    uint128 borrowRate;
    uint40 lastUpdateTimestamp;
    address kTokenAddress;
    address dTokenAddress;
    address interestRateStrategyAddress;
    //
    uint256 availableLiquidity;
    uint256 totalPrincipalStableDebt;
    uint256 totalScaledDebt;
    uint256 priceInMarketReferenceCurrency;
    uint256 variableRateSlope1;
    uint256 variableRateSlope2;
  }

  struct UserReserveData {
    address underlyingAsset;
    uint256 scaledKTokenBalance;
    bool usageAsCollateralEnabledOnUser;
    uint256 scaledDebt;
  }

  struct BaseCurrencyInfo {
    uint256 marketReferenceCurrencyUnit;
    int256 marketReferenceCurrencyPriceInUsd;
    int256 networkBaseTokenPriceInUsd;
    uint8 networkBaseTokenPriceDecimals;
  }

  function getReservesList(ILendingPoolAddressesProvider provider)
    external
    view
    returns (address[] memory);

  function getReservesData(ILendingPoolAddressesProvider provider)
    external
    view
    returns (
      AggregatedReserveData[] memory,
      BaseCurrencyInfo memory
    );

  function getUserReservesData(ILendingPoolAddressesProvider provider, address user)
    external
    view
    returns (
      UserReserveData[] memory
    );
}