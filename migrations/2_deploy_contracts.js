var PiggyBank = artifacts.require("./PiggyBank.sol");

module.exports = function (deployer) {
    deployer.deploy(PiggyBank);
};
