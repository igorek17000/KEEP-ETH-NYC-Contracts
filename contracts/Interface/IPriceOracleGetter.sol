// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracleGetter {
  /**
   * @dev returns the asset price in ETH
   */
  function getAssetPrice(address asset) external view returns (uint256);

}
