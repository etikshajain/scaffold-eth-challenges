// deploy/00_deploy_your_contract.js

const { ethers } = require("hardhat");

const localChainId = "31337";

// const sleep = (ms) =>
//   new Promise((r) =>
//     setTimeout(() => {
//       console.log(`waited for ${(ms / 1000).toFixed(3)} seconds`);
//       r();
//     }, ms)
//   );

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  await deploy("Balloons", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    // args: [ "Hello", ethers.utils.parseEther("1.5") ],
    log: true,
  });

  console.log("deployer: ", deployer)
  const balloons = await ethers.getContract("Balloons", deployer);

  await deploy("DEX", {
    // Learn more about args here: https://www.npmjs.com/package/hardhat-deploy#deploymentsdeploy
    from: deployer,
    args: [balloons.address],
    log: true,
    // waitConfirmations: 5,
  });

  const dex = await ethers.getContract("DEX", deployer);

  // paste in your front-end address here to get 10 balloons on deploy:
  // 10 balloons are transferred from msg.sender's account(=deployer) to front end address
  await balloons.transfer(
    "0x064A540B457801e0a3D40EDCe2BadA6EBe727B54",
    "" + 10 * 10 ** 18
  );

  // uncomment to init DEX on deploy:
  console.log(
    "Approving DEX (" + dex.address + ") to take Balloons from main account..."
  );
  // If you are going to the testnet make sure your deployer account has enough ETH
  // approving dex.address to transfer 100 balloons from msg.sender's account(=deployer) to any account
  await balloons.approve(dex.address, ethers.utils.parseEther("100"));
  console.log("INIT exchange...");

  // Dex init: msg.sender = ?
  await dex.init(ethers.utils.parseEther("5"), {
    value: ethers.utils.parseEther("5"),
    gasLimit: 200000,
  });
};
module.exports.tags = ["Balloons", "DEX"];
