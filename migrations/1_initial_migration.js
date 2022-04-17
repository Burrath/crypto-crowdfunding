const CryptoCrowdfunding = artifacts.require("CryptoCrowdfunding");

module.exports = function (deployer) {
  deployer.deploy(CryptoCrowdfunding);
};
