// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { parseUnits } = require("ethers/lib/utils");
const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  // 1. Get deployer
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deployer address: ", deployer.address);

  // 2. deploy mock tokens: usdc, eth, matic
  const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
  let USDC = await MockERC20.deploy("USDC", "USDC", 6);
  await USDC.deployed();
  let ETH = await MockERC20.deploy("ETH", "ETH", 18);
  await ETH.deployed();
  let MATIC = await MockERC20.deploy("MATIC", "MATIC", 18);
  await MATIC.deployed();
  console.log("USDC address: ", USDC.address);
  console.log("ETH address: ", ETH.address);
  console.log("MATIC address: ", MATIC.address);

  // 3. deploy mock rate oracle
  const MockOracle = await hre.ethers.getContractFactory("MockPriceOracleGetter");
  let oracle = await MockOracle.deploy();
  await oracle.deployed();
  // add rate (TODO)
  oracle.setAssetPrice(USDC.address, parseUnits("1", 25));
  oracle.setAssetPrice(ETH.address, parseUnits("1", 25));
  oracle.setAssetPrice(MATIC.address, parseUnits("1", 25));
  console.log("Oracle address: ", oracle.address);

  // 4. deploy address provider
  const LendingPoolAddressProvider = await hre.ethers.getContractFactory("LendingPoolAddressProvider");
  let address_provider = await LendingPoolAddressProvider
    .deploy(deployer.address, deployer.address, oracle.address);
  await address_provider.deployed();
  console.log("Address provider address: ", address_provider.address);

  // 5. deploy 2 lending pools: main and eth-usdc
  const LendingPool = await hre.ethers.getContractFactory("LendingPool");
  let main_pool = await LendingPool.deploy(address_provider.address);
  let eth_usdc_pool = await LendingPool.deploy(address_provider.address);
  await main_pool.deployed();
  await eth_usdc_pool.deployed();
  console.log("Main Pool Address: ", main_pool.address);
  console.log("ETH-USDC Pool Address: ", eth_usdc_pool.address);

  // 6. deploy rate strategies
  const DefaultReserveIntersetRateStrategy = await hre.ethers.getContractFactory("DefaultReserveIntersetRateStrategy");
  let optimal_rate = parseUnits("0.9", 27);
  let base_rate = parseUnits("0.01", 27);
  let slope_1 = parseUnits("0.1", 27);
  let slope_2 = parseUnits("1", 27);
  let usdc_rate_strategy = await DefaultReserveIntersetRateStrategy.deploy(
    address_provider.address,
    optimal_rate,
    base_rate,
    slope_1,
    slope_2
  );
  let eth_rate_strategy = await DefaultReserveIntersetRateStrategy.deploy(
    address_provider.address,
    optimal_rate,
    base_rate,
    slope_1,
    slope_2
  );
  let matic_rate_strategy = await DefaultReserveIntersetRateStrategy.deploy(
    address_provider.address,
    optimal_rate,
    base_rate,
    slope_1,
    slope_2
  );
  await usdc_rate_strategy.deployed();
  await eth_rate_strategy.deployed();
  await matic_rate_strategy.deployed();
  console.log("USDC strategy address: ", usdc_rate_strategy.address);
  console.log("ETH strategy address: ", eth_rate_strategy.address);
  console.log("MATIC strategy address: ", matic_rate_strategy.address);

  // 7. deploy configurator
  const LendingPoolConfigurator = await hre.ethers.getContractFactory("LendingPoolConfigurator");
  let main_pool_configurator = await LendingPoolConfigurator.deploy(address_provider.address, main_pool.address);
  let eth_usdc_pool_configurator = await LendingPoolConfigurator.deploy(address_provider.address, eth_usdc_pool.address);
  await main_pool_configurator.deployed();
  await eth_usdc_pool_configurator.deployed();
  console.log("Main pool configurator address: ", main_pool_configurator.address);
  console.log("ETH-USDC pool configurator address: ", eth_usdc_pool_configurator.address);

  // 8. deploy collateral manager
  const LendingPoolCollateralManager = await hre.ethers.getContractFactory("LendingPoolCollateralManager");
  let main_pool_cm = await LendingPoolCollateralManager.deploy();
  let eth_usdc_pool_cm = await LendingPoolCollateralManager.deploy();
  await main_pool_cm.deployed();
  await eth_usdc_pool_cm.deployed();
  console.log("Main pool cm address: ", main_pool_cm.address);
  console.log("ETH-USDC pool cm address: ", eth_usdc_pool_cm.address);

  // 9. add 2 pools to address provider
  await address_provider.addPool(
    main_pool.address,
    main_pool_configurator.address,
    main_pool_cm.address
  );
  await address_provider.addPool(
    eth_usdc_pool.address,
    eth_usdc_pool_configurator.address,
    eth_usdc_pool_cm.address
  );

  // 10. init ETH, USDC, MATIC on main pool
  let eth_init_reserve_input = [
    "18",
    eth_rate_strategy.address,
    ETH.address,
    deployer.address,
    "kETH",
    "kETH",
    "18",
    "dETH",
    "dETH",
    "18"
  ];
  let usdc_init_reserve_input = [
    "6",
    usdc_rate_strategy.address,
    USDC.address,
    deployer.address,
    "kUSDC",
    "kUSDC",
    "6",
    "dUSDC",
    "dUSDC",
    "6"
  ];
  let matic_init_reserve_input = [
    "18",
    matic_rate_strategy.address,
    MATIC.address,
    deployer.address,
    "kMATIC",
    "kMATIC",
    "18",
    "dMATIC",
    "dMATIC",
    "18"
  ];
  await main_pool_configurator.initReserve(
    eth_init_reserve_input
  );
  await main_pool_configurator.initReserve(
    usdc_init_reserve_input
  );
  await main_pool_configurator.initReserve(
    matic_init_reserve_input
  );
  await main_pool_configurator.configureReserveAsCollateral(
    ETH.address,
    60, // ltv
    65, // liquidation threshold
    105 // bonus
  );
  await main_pool_configurator.configureReserveAsCollateral(
    USDC.address,
    80, // ltv
    90, // liquidation threshold
    105 // bonus
  );
  await main_pool_configurator.configureReserveAsCollateral(
    MATIC.address,
    60, // ltv
    65, // liquidation threshold
    105 // bonus
  );

  // 11. init ETH, USDC on ETH-USDC pool
  await eth_usdc_pool_configurator.initReserve(
    eth_init_reserve_input
  );
  await eth_usdc_pool_configurator.initReserve(
    usdc_init_reserve_input
  );
  await eth_usdc_pool_configurator.configureReserveAsCollateral(
    ETH.address,
    80, // ltv
    90, // liquidation threshold
    110 // bonus
  );
  await eth_usdc_pool_configurator.configureReserveAsCollateral(
    USDC.address,
    90, // ltv
    95, // liquidation threshold
    110 // bonus
  );

  // TEST ONLY
  await USDC.approve(main_pool.address, parseUnits("1", 50));
  await ETH.approve(main_pool.address, parseUnits("1", 50));
  await MATIC.approve(main_pool.address, parseUnits("1", 50));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
