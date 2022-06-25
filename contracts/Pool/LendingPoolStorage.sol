// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import {ReserveLogic} from '../libraries/logic/ReserveLogic.sol';
import {ILendingPoolAddressesProvider} from '../Interface/ILendingPoolAddressesProvider.sol';
import {DataTypes} from '../Library/Type/DataTypes.sol';
import {ReserveLogic} from '../Library/Logic/ReserveLogic.sol';
import {ReserveLogic} from '../Library/Logic/ReserveLogic.sol';

contract LendingPoolStorage {
// using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
// using UserConfiguration for DataTypes.UserConfigurationMap;

  ILendingPoolAddressesProvider internal _addressesProvider;

  // reserves, mapped by asset address
  mapping(address => DataTypes.ReserveData) internal _reserves;
  // user configs, mapped by user address
  mapping(address => DataTypes.UserConfigurationMap) internal _usersConfig;

  // list of positions, structured as a mapping for gas savings
  mapping(uint256 => DataTypes.UserPosition) internal _positionsList;
  // the number of historical positions
  uint256 internal _positionsCount;

  // the list of the available reserves, structured as a mapping for gas savings reasons
  mapping(uint256 => address) internal _reservesList;
  // the number of initialized reserves
  uint256 internal _reservesCount;
  // the list of users who have supplied TODO: automatically remove stale users
  mapping(uint256 => address) internal _usersList;
  // if user has encountered before
  mapping(address => bool) internal _userActive;
  // the number of users
  uint256 internal _usersCount;
  // if lending pool is paused or not
  bool internal _paused;
  // the maximum number of reserves
  uint256 internal _maxNumberOfReserves;
  // whether or not the 
  bool internal _isMainPool;
}
