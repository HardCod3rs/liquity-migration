import NETWORKS from 'networks.json';
import MakerNetwork from 'networks/maker.json';
import DSProxy_ABI from 'abis/DSProxy.json';
import { ethers } from 'ethers';
import { UseWallet } from 'contexts/wallet';
import { useNotifications } from 'contexts/notifications';
import { Button } from '@material-ui/core';
import { Big } from 'utils/big-number';
import React from 'react';
const axios = require('axios');

export async function DoMigration({ vault }) {
  const { tx } = useNotifications();
  const {
    VaultMigrationContract,
    DSSProxyActionsContract,
    address,
    signer,
    network,
  } = UseWallet();
  const makerNetwork = MakerNetwork[network];

  const migratetoLiquity = async () => {
    try {
      await tx('Applying...', 'Applied!', async () => {
        console.log({
          owner: address,
          manager: makerNetwork.CDP_MANAGER,
          gemToken:
            vault.collateralType.id == 'ETH-A' ||
            vault.collateralType.id == 'ETH-B'
              ? makerNetwork.ETH
              : makerNetwork[vault.collateralType.id],
          gemjoin:
            makerNetwork[
              'MCD_JOIN_' + vault.collateralType.id.replace('-', '_')
            ],
          daiJoin: makerNetwork['MCD_JOIN_DAI'],
          cdpID: vault.cdpId,
          debtAmount: ethers.utils.parseEther(
            (vault.debt * vault.collateralType.rate).toString()
          ),
          collateralAmount: ethers.utils.parseEther(
            vault.collateral.toString()
          ),
          maxSlippage: 90,
        });
        await VaultMigrationContract.migratetoLiquity({
          owner: address,
          manager: makerNetwork.CDP_MANAGER,
          gemToken:
            vault.collateralType.id == 'ETH-A' ||
            vault.collateralType.id == 'ETH-B'
              ? makerNetwork.ETH
              : makerNetwork[vault.collateralType.id],
          gemjoin:
            makerNetwork[
              'MCD_JOIN_' + vault.collateralType.id.replace('-', '_')
            ],
          daiJoin: makerNetwork['MCD_JOIN_DAI'],
          cdpID: vault.cdpId,
          debtAmount: ethers.utils.parseEther(
            (vault.debt * vault.collateralType.rate).toString()
          ),
          collateralAmount: ethers.utils.parseEther(
            vault.collateral.toString()
          ),
          maxSlippage: 90,
        });
      });
    } finally {
    }
  };

  var vaultProxyContract = new ethers.Contract(
    vault.vaultProxy,
    DSProxy_ABI,
    signer
  );

  if (
    !(await DSSProxyActionsContract.cdpCan(
      makerNetwork.CDP_MANAGER,
      vault.cdpId,
      VaultMigrationContract.address
    ))
  )
    return (
      <Button
        style={{ position: 'relative', top: 20 }}
        color="secondary"
        variant="outlined"
        disabled={false}
        onClick={async () =>
          await vaultProxyContract.execute(
            DSSProxyActionsContract.address,
            DSSProxyActionsContract.interface.encodeFunctionData('cdpAllow', [
              makerNetwork.CDP_MANAGER,
              vault.cdpId,
              VaultMigrationContract.address,
              1,
            ])
          )
        }
      >
        Unlock the CDP
      </Button>
    );
  else
    return (
      <Button
        style={{ position: 'relative', top: 20 }}
        color="secondary"
        variant="outlined"
        disabled={false}
        onClick={() => migratetoLiquity()}
      >
        Migrate to Liquity
      </Button>
    );
}
