import React from 'react';
import clsx from 'clsx';
import * as ethers from 'ethers';
import { makeStyles } from '@material-ui/core/styles';
import {
  Box,
  Button,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  Slider,
} from '@material-ui/core';
import { formatUnits, isZero } from 'utils/big-number';
import { DoMigration } from 'utils/liquitymigration';
import { UseWallet } from 'contexts/wallet';
import { useNotifications } from 'contexts/notifications';
import { SUCCESS_COLOR, DANGER_COLOR } from 'config';
import sleep from 'utils/sleep';
import Loader from 'components/Loader';
import ERC20_ABI from 'abis/ERC20.json';
import networks from 'networks.json';

const useStyles = makeStyles(theme => ({
  container: {
    '& th, td': {
      borderColor: 'rgba(16, 161, 204, 0.2)',
    },
  },
  error: {
    color: DANGER_COLOR,
  },
  success: {
    color: SUCCESS_COLOR,
  },
  grid: {
    display: 'grid',
    gridTemplateColumns: '1fr 1fr',
    columnGap: '10px',
  },
}));

export default function() {
  const classes = useStyles();
  const {
    connect,
    isLoaded: walletIsLoaded,
    signer,
    subgraph,
    network,
    VaultMigrationContract,
  } = UseWallet();
  const { address } = UseWallet();
  const [isLoaded, setIsLoaded] = React.useState(false);
  const [Vaults, setVaults] = React.useState([]);

  React.useEffect(() => {
    if (!walletIsLoaded) return;
    if (!(signer && address && VaultMigrationContract)) return;
    const Vaults = [];

    let isMounted = true;
    const unsubs = [() => (isMounted = false)];

    const load = async () => {
      const { users } = await subgraph(
        networks[network].MakerSubGraph,
        `query ($address: String) {
          users(where: {id: $address}) {
            id
            proxies {
              id
            }
            vaults(where: {cdpId_not: null, collateral_gt: 0}) {
              cdpId
              collateralType {
                id
                rate
              }
              collateral
              debt
            }
          }
         }`,
        {
          address: address.toLowerCase(),
        }
      );

      users.forEach(({ vaults }) => {
        vaults.forEach(vault => {
          if (!isZero(vault.collateral)) {
            Vaults.push({
              ...vault,
              vaultProxy: users[0].proxies[0].id,
            });
          }
        });
      });

      if (isMounted) {
        setVaults(Vaults);
        setIsLoaded(true);
      }
    };

    load();
    return () => {
      unsubs.forEach(unsub => unsub());
    };
  }, [signer, walletIsLoaded, address, VaultMigrationContract]);

  return (
    <Box className={clsx(classes.container, 'text-center')}>
      {!walletIsLoaded ? null : !address ? (
        <Box py={4}>
          <h2>Maker to Liquity Migration</h2>
          <Button
            color="secondary"
            variant="outlined"
            onClick={() => connect()}
          >
            Connect Wallet
          </Button>
        </Box>
      ) : !isLoaded ? (
        <Loader />
      ) : (
        <Box>
          <Box className={classes.grid}>
            <Box style={{ position: 'relative', left: 200 }}>
              <h2>Your Maker Vaults</h2>
              {!Vaults.length ? (
                <Box>You have no Vaults.</Box>
              ) : (
                <Table className={classes.table} aria-label="deposit">
                  <TableHead>
                    <TableRow>
                      <TableCell>CDP ID</TableCell>
                      <TableCell>Collateral Type</TableCell>
                      <TableCell>Collateral</TableCell>
                      <TableCell>Debt</TableCell>
                      <TableCell>Migration</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {Vaults.map(vault => (
                      <Vault key={vault.cdpId} {...{ vault }} />
                    ))}
                  </TableBody>
                </Table>
              )}
            </Box>
          </Box>
        </Box>
      )}
    </Box>
  );
}

function Vault({ vault }) {
  // const classes = useStyles();
  const [DoMigrateButton, setDoMigrateButton] = React.useState('Loading...');

  DoMigration({ vault }).then(res => setDoMigrateButton(res));

  return (
    <TableRow>
      <TableCell component="th" scope="row">
        {vault.cdpId}
      </TableCell>
      <TableCell>{vault.collateralType.id}</TableCell>
      <TableCell>{vault.collateral}</TableCell>
      <TableCell>
        {(vault.debt * vault.collateralType.rate).toFixed(2)}
      </TableCell>
      <TableCell>{DoMigrateButton}</TableCell>
    </TableRow>
  );
}
