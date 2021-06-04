import Web3 from "web3";
import DeedToken from "./contracts/DeedToken.json";

const options = {
  web3: {
    block: false,
    customProvider: new Web3("ws://localhost:8545"),
  },
  contracts: [DeedToken],
  events: {
    DeedToken: ["Transfer", "Approval", "ApprovalForAll"],
  },
};

export default options;
