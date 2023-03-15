const AngelBoost = artifacts.require("AngelBoost");
// const Azuki = artifacts.require("Azuki");
// const BetaKreativ = artifacts.require("BetaKreativ");

function classicDateToSolidityDate(date) {
  return Math.ceil(new Date(date).getTime() / 1000);
}

function solidityDateToClassicDate(date) {
  return new Date(Number(date) * 1000);
}

Date.prototype.addHours = function (h) {
  this.setTime(this.getTime() + h * 60 * 60 * 1000);
  return this;
};

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

    contract = await AngelBoost.new({
      from: accounts[0],
    });

    console.log("contract", contract.address);

    const launchFee = Number(await contract["launchFee"]());

    const start = new Date().addHours(-1);
    const end = new Date().addHours(24);

    console.log(
      (10 * 10 ** 18).toString(),
      classicDateToSolidityDate(start),
      classicDateToSolidityDate(end)
    );

    await contract.launch(
      (10 * 10 ** 18).toString(),
      classicDateToSolidityDate(start),
      classicDateToSolidityDate(end),
      {
        value: launchFee,
        from: accounts[1],
      }
    );

    const tx = await contract.pledge(0, {
      value: 20 * 10 ** 18,
    });
  });
});
