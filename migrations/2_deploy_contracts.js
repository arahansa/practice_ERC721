const SimpleStorage = artifacts.require("SimpleStorage");
const DeedToken = artifacts.require("DeedToken");
const ComplexStorage = artifacts.require("ComplexStorage");

module.exports = function(deployer) {
  deployer.deploy(SimpleStorage);
  deployer.deploy(DeedToken);
  deployer.deploy(ComplexStorage);
};
