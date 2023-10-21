const { network } = require("hardhat");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const rockPaperScissor = await deploy("RockPaperScissorCoin", {
    from: deployer,
    log: true,
    args: [],
    waitConfirmations: network.config.blockConfirmations || 1,
  });
  if (network.config.chainId == 11155111 && process.env.ETHERSCAN_API_KEY) {
    await verify(rockPaperScissor.address, []);
  }
  console.log(`Contract deployed at : ${rockPaperScissor.address}`);
};

module.exports.tags = ["token"];
