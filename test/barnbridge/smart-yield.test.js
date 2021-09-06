const { expect } = require("chai");
const hre = require("hardhat");
const abis = require("../../scripts/constant/abis");
const addresses = require("../../scripts/constant/addresses");
const deployAndEnableConnector = require("../../scripts/deployAndEnableConnector");
const getMasterSigner = require("../../scripts/getMasterSigner");
const buildDSAv2 = require("../../scripts/buildDSAv2");
const ERC20 = require("../../scripts/constant/abi/basics/erc20.json");
const ConnectV2SmartYield = require("../../artifacts/contracts/mainnet/connectors/barnbridge/smart-yield/main.sol//ConnectV2BarnBridgeSmartYield.json");
const SmartYieldMapping = require("../../artifacts/contracts/mainnet/mapping/barnbridge.sol/InstaBarnBridgeSmartYieldMapping.json");
const { parseEther } = require("@ethersproject/units");
const encodeSpells = require("../../scripts/encodeSpells");
const tokens = require("../../scripts/constant/tokens");
const constants = require("../../scripts/constant/constant");
const { ethers } = hre;

describe("BarnBridge SmartYield", function() {
  const connectorName = "BarnBridgeSmartYield-TEST-A";
  const smartYield = {
    aave: { dai: { address: "0x6c9DaE2C40b1e5883847bF5129764e76Cb69Fc57" } },
  };
  let wallet0, wallet1;
  let dsaWallet0;
  let instaConnectorsV2;
  let connector;
  let masterSigner;
  let token;
  let mapping;

  before(async () => {
    [wallet0, wallet1] = await ethers.getSigners();
    masterSigner = await getMasterSigner();
    instaConnectorsV2 = await ethers.getContractAt(
      abis.core.connectorsV2,
      addresses.core.connectorsV2
    );
    token = await ethers.getContractAt(ERC20, tokens.dai.address);
    connector = await deployAndEnableConnector({
      connectorName,
      contractArtifact: ConnectV2SmartYield,
      signer: masterSigner,
      connectors: instaConnectorsV2,
    });
    console.log("Connector address", connector.address);
  });

  it("should have contracts deployed", async () => {
    expect(!!instaConnectorsV2.address).to.be.true;
    expect(!!connector.address).to.be.true;
    expect(!!masterSigner.address).to.be.true;
  });

  describe("DSA wallet setup", function() {
    it("Should build DSA v2", async function() {
      dsaWallet0 = await buildDSAv2(wallet0.address);
      expect(!!dsaWallet0.address).to.be.true;
    });

    it("Deposit ETH into DSA wallet", async function() {
      await wallet0.sendTransaction({
        to: dsaWallet0.address,
        value: parseEther("10"),
      });
      expect(await ethers.provider.getBalance(dsaWallet0.address)).to.be.gte(
        parseEther("10")
      );
    });
  });

  describe("Main", function() {
    beforeEach(async () => {
      const account = "0x47ac0fb4f2d84898e4d9e7b4dab3c24507a6d503";
      await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [account],
      });
      const signer = await ethers.getSigner(account);
      await token
        .connect(signer)
        .transfer(dsaWallet0.address, parseEther("10"));
    });
    afterEach(async () => {
      await hre.network.provider.request({
        method: "hardhat_reset",
        params: [
          {
            forking: {
              jsonRpcUrl: hre.config.networks.hardhat.forking.url,
              blockNumber: hre.config.networks.hardhat.forking.blockNumber,
            },
          },
        ],
      });
    });
    it(`should buy juniorTokens with DAI in ${connectorName}`, async function() {
      const amt = parseEther("1");
      const spells = [
        {
          connector: connectorName,
          method: "buyJuniorTokensRaw",
          args: [
            tokens.dai.address,
            smartYield.aave.dai.address,
            amt,
            0,
            ethers.BigNumber.from(Date.now() + 3600 * 1000).div(1000),
            0,
            0,
          ],
        },
      ];
      const tx = await dsaWallet0
        .connect(wallet0)
        .cast(...encodeSpells(spells), wallet1.address);

      await tx.wait();

      expect(await token.balanceOf(dsaWallet0.address)).to.eq(
        parseEther("10").sub(amt)
      );
    });

    it(`should buy juniorTokens with all DAI in ${connectorName}`, async function() {
      console.log(
        "await token.balanceOf(dsaWallet0.address) :>> ",
        (await token.balanceOf(dsaWallet0.address))
          .div(parseEther("1"))
          .toString()
      );
      const spells = [
        {
          connector: connectorName,
          method: "buyJuniorTokensRaw",
          args: [
            tokens.dai.address,
            smartYield.aave.dai.address,
            constants.max_value,
            0,
            ethers.BigNumber.from(Date.now() + 3600 * 1000).div(1000),
            0,
            0,
          ],
        },
      ];

      const tx = await dsaWallet0
        .connect(wallet0)
        .cast(...encodeSpells(spells), wallet1.address);
      await tx.wait();

      expect(await token.balanceOf(dsaWallet0.address)).to.eq(0);
    });

    it(`should sell all juniorTokens for DAI in ${connectorName}`, async function() {
      const amt = parseEther("1");
      let spells = [
        {
          connector: connectorName,
          method: "buyJuniorTokensRaw",
          args: [
            tokens.dai.address,
            smartYield.aave.dai.address,
            amt,
            0,
            ethers.BigNumber.from(Date.now() + 3600 * 1000).div(1000),
            0,
            0,
          ],
        },
      ];

      let tx = await dsaWallet0
        .connect(wallet0)
        .cast(...encodeSpells(spells), wallet1.address);

      await tx.wait();

      spells = [
        {
          connector: connectorName,
          method: "sellJuniorTokensRaw",
          args: [
            tokens.dai.address,
            smartYield.aave.dai.address,
            constants.max_value,
            parseEther("0.9"),
            ethers.BigNumber.from(Date.now() + 3600 * 1000).div(1000),
            0,
            0,
          ],
        },
      ];

      tx = await dsaWallet0
        .connect(wallet0)
        .cast(...encodeSpells(spells), wallet1.address);

      await tx.wait();

      expect(await token.balanceOf(dsaWallet0.address)).to.gt(
        parseEther("9.9")
      );
    });

    it(`should buy seniorBond with DAI in ${connectorName}`, async function() {
      const amt = parseEther("1");
      const spells = [
        {
          connector: connectorName,
          method: "buySeniorBond",
          args: [
            tokens.dai.address,
            smartYield.aave.dai.address,
            amt,
            parseEther("0"),
            ethers.BigNumber.from(Date.now() + 3600 * 1000).div(1000),
            100,
            0,
            0,
          ],
        },
      ];

      const tx = await dsaWallet0
        .connect(wallet0)
        .cast(...encodeSpells(spells), wallet1.address);

      await tx.wait();

      expect(await token.balanceOf(dsaWallet0.address)).to.lt(parseEther("10"));
    });
  });
});
