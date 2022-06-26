// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "../Interface/ILendingPool.sol";
import "../Interface/IDataProvider.sol";

contract NomadicKeeper is KeeperCompatibleInterface {


    ILendingPool public LendingPool;
    IDataProvider public DataProvider; // LendingPool address here
    address public collateralToken;
    uint256 public poolId;
    address public owner;

    constructor(
        address lendingPool_,
        address dataProvider_,
        address collateralToken_,
        uint256 poolId_
    ) {
        LendingPool = ILendingPool(lendingPool_);
        DataProvider = IDataProvider(dataProvider_);
        poolId = poolId_;
        collateralToken = collateralToken_;
        owner = msg.sender;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bool runCheck = _shouldRun();
        upkeepNeeded = (runCheck);
        performData = checkData;
    }

    function performUpkeep(bytes calldata performData) external override {
        address[] memory listToCheck = LendingPool.getUsersList();

        for (uint i = 0; i < listToCheck.length; i++) {
            address userToCheck = listToCheck[i];
            bool needsCheck = checkUnique(userToCheck);
            if (needsCheck) {
                performUnique(userToCheck);
                return;
            }
        }
    }

    function performUnique(address userToCheck) internal {

        IDataProvider.TokenData[] memory listOfReserves = DataProvider.getAllReservesTokens(0);
        uint256 reservesLen = listOfReserves.length;

        for (uint256 i = 0; i < reservesLen; i++) {
            address assetToCheck = (listOfReserves[i]).tokenAddress;
            performUniqueForAsset(userToCheck, assetToCheck);
        }
    }

    function performUniqueForAsset(address user, address asset) internal {
        uint256 debtToCover = type(uint256).max;
        LendingPool.liquidationCall(collateralToken, asset, user, debtToCover, false);
    }

    function _shouldRun() internal view returns (bool runCheck) {
        address[] memory listToCheck = LendingPool.getUsersList();
        for (uint i = 0; i < listToCheck.length; i++) {
            address userToCheck = listToCheck[i];
            bool needsCheck = checkUnique(userToCheck);
            if (needsCheck) {
                runCheck = true;
            }
        }
    }

    function checkUnique(address userToCheck)
        internal
        view
        returns (bool runCheck)
    {
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = LendingPool.getUserAccountData(userToCheck);

        if (healthFactor < 1) {
            runCheck = true;
        }
    }
}
