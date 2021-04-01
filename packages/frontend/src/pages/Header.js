import React from 'react';
import { makeStyles } from '@material-ui/core/styles';
import clsx from 'clsx';
import { AppBar, Typography, Toolbar, Button, Box } from '@material-ui/core';
import { APP_TITLE } from 'config';
import { UseWallet } from 'contexts/wallet';

const useStyles = makeStyles(theme => ({
  container: {
    background: theme.palette.background.paper,
    boxShadow: 'none',
  },
  account: {
    marginRight: 10,
    [theme.breakpoints.down('sm')]: {
      display: 'none',
    },
  },
}));

export default function Component() {
  const classes = useStyles();
  const { address, connect, disconnect, network } = UseWallet();

  const shortAddress =
    address && `${address.slice(0, 6)}....${address.slice(-4)}`;

  return (
    <AppBar position="fixed" color="inherit" className={classes.container}>
      <Toolbar color="inherit">
        <Typography variant="h6" className={'flex flex-grow'}>
          <Box className={clsx('flex flex-col')}>
            <div>
              <img
                src="https://uploads-ssl.webflow.com/5fd883457ba5da4c3822b02c/5fd9eedfd3365a22c65c5c78_Group%2061.svg"
                height="50"
                width="50"
              />
              <span
                className={classes.account}
                style={{ position: 'absolute', top: 10, left: 90 }}
              >
                Migration
              </span>
            </div>
          </Box>
        </Typography>

        {address ? (
          <>
            &nbsp;
            <div className={classes.account}>
              {shortAddress} ({network.toUpperCase()})
            </div>
            <Button color="secondary" variant="outlined" onClick={disconnect}>
              Disconnect
            </Button>
          </>
        ) : (
          <Button
            color="secondary"
            variant="outlined"
            onClick={() => connect()}
          >
            Connect Wallet
          </Button>
        )}
      </Toolbar>
    </AppBar>
  );
}
