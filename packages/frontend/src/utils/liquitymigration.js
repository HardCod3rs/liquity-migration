import NETWORKS from 'networks.json';
import MakerNetwork from 'networks/maker.json';
import DSProxy_ABI from 'abis/DSProxy.json';
import { ethers } from 'ethers';
import { UseWallet } from 'contexts/wallet';
import { useNotifications } from 'contexts/notifications';
import { Button } from '@material-ui/core';
import React from 'react';
const axios = require('axios');

export async function DoMigration({ vault }) {
  const { tx } = useNotifications();
  const { VaultMigrationContract, address, signer, network } = UseWallet();
  const makerNetwork = MakerNetwork[network];

  const vaultDebt = (vault.debt * vault.collateralType.rate).toFixed(2);

  var vaultProxyContract = new ethers.Contract(
    vault.vaultProxy,
    DSProxy_ABI,
    signer
  );

  const migratetoLiquity = async () => {
    try {
      await tx('Applying...', 'Applied!', async () => {
        await VaultMigrationContract.migratetoLiquity(
          vaultProxyContract.address,
          {
            manager: makerNetwork.CDP_MANAGER,
            gemToken:
              vault.collateralType.id == 'ETH-A' ||
              vault.collateralType.id == 'ETH-B'
                ? makerNetwork.ETH
                : makerNetwork[vault.collateralType.id.slice(0, -2)],
            gemjoin:
              makerNetwork[
                'MCD_JOIN_' + vault.collateralType.id.replace(/-/g, '_')
              ],
            daiJoin: makerNetwork['MCD_JOIN_DAI'],
            cdpID: vault.cdpId,
            debtAmount: ethers.utils.parseEther(vaultDebt.toString()),
            collateralAmount: ethers.utils.parseEther(
              vault.collateral.toString()
            ),
            minCollateralPercentage: 90,
          }
          //{ gasLimit: 9500000 }
        );
      });
    } finally {
    }
  };

  /*if (vaultDebt < 2000)
    return (
      <Button color="secondary" variant="outlined" disabled={true}>
        You need at least 2000 DAI Debt
      </Button>
    );
  else*/ if (
    !(
      (await VaultMigrationContract.ProxyGuardAddress()) ==
      (await vaultProxyContract.authority())
    )
  )
    return (
      <Button
        color="secondary"
        variant="outlined"
        disabled={false}
        onClick={async () =>
          await vaultProxyContract.setAuthority(
            await VaultMigrationContract.ProxyGuardAddress()
          )
        }
      >
        Unlock the Proxy
      </Button>
    );
  else
    return (
      <Button
        color="secondary"
        variant="outlined"
        disabled={false}
        onClick={() => migratetoLiquity()}
      >
        Migrate to Liquity
      </Button>
    );
}
