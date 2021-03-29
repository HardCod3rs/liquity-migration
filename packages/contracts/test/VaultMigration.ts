import hre from "hardhat";
import { Artifact } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import { Signers } from "../types";
import { shouldBehaveLikeVaultMigration } from "./VaultMigration.behavior";

import { deployThem } from "../scripts/deploy";
import { VaultMigration } from "../typechain/VaultMigration";
import { DsProxy } from "../typechain";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await hre.ethers.getSigners();
    this.signers.admin = signers[0];
  });

  //TODO: Complete the Tests

  describe("Greeter", function () {
    beforeEach(async function () {
      // Maker
      this.vaultMigration = <VaultMigration>await deployThem();
    });

    shouldBehaveLikeVaultMigration();
  });
});
