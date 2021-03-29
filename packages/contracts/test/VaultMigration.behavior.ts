import { expect } from "chai";

export function shouldBehaveLikeVaultMigration(): void {
  it("should return the new greeting once it's changed", async function () {
    this.timeout(0);
    console.log("test");
    //expect(await this.greeter.connect(this.signers.admin).greet()).to.equal("Hello, world!");
    console.log(
      await this.vaultMigration.connect(this.signers.admin).newMakerVault({
        owner: "0xe13aaef97bd752794c9121c2ce98e51e4f7dd257",
        _CollateralAmount: "1000000000000000000",
        _DAIReceiver: "0xe13aaef97bd752794c9121c2ce98e51e4f7dd257",
        _manager: "0x1476483dD8C35F25e568113C5f70249D3976ba21",
        _jug: "0xcbB7718c9F39d05aEEDE1c472ca8Bf804b2f1EaD",
        _ethJoin: "0x775787933e92b709f2a3C70aa87999696e74A9F8",
        _daiJoin: "0x5AA71a3ae1C0bd6ac27A1f28e1415fFFB6F15B8c",
        _ilk: "0x4554482d41000000000000000000000000000000000000000000000000000000",
      }),
    );
    //await this.greeter.setGreeting("Hola, mundo!");
    //expect(await this.greeter.connect(this.signers.admin).greet()).to.equal("Hola, mundo!");
  });
}
