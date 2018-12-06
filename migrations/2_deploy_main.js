var Integration = artifacts.require("./Integration.sol");

module.exports = async function(deployer) {
  await deployer.deploy(Integration);
};
