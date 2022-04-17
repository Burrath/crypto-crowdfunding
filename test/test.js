const CryptoCrowdfunding = artifacts.require("CryptoCrowdfunding");
// const Azuki = artifacts.require("Azuki");
// const BetaKreativ = artifacts.require("BetaKreativ");

contract("test", async (accounts) => {
  printAccounts = {};
  accounts.forEach((a) => {
    printAccounts[accounts.indexOf(a)] = a;
  });
  console.log(printAccounts);

  it("should deploy", async () => {
    // nft = await Azuki.new({
    //   from: accounts[1],
    // });

    // token = await BetaKreativ.new({
    //   from: accounts[2],
    // });

    contract = await CryptoCrowdfunding.new({
      from: accounts[0],
    });

    console.log("contract", contract.address);
  });
});
