const { run } = require("hardhat");
const verify = async (contractAddress, args) => {
  console.log("Verifying contracts...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
      // contract: "contracts/RockPaperScissor.sol:RockPaperScissorCoin",
    });
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("Already Verified");
    } else {
      console.log(e);
    }
  }
};
module.exports = { verify };
