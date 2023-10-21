const { network } = require("hardhat");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const args = ["0x7d0Bf29d442974D66a6F31CDD6e24908763D0eA8"];
  const rockPaperScissors = await deploy("RockPaperScissors", {
    from: deployer,
    log: true,
    args: args,
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  if (network.config.chainId == 11155111 && process.env.ETHERSCAN_API_KEY) {
    await verify(rockPaperScissors.address, args);
  }
  console.log(`Contract deployed at : ${rockPaperScissors.address}`);
};
module.exports.tags = ["game"];
