import { createMuiTheme } from '@material-ui/core/styles';
import { BORDER_RADIUS, SECONDARY_COLOR } from 'config';

export default createMuiTheme({
  typography: {
    fontFamily: ['Work Sans', 'Arial', 'sans-serif'].join(','),
  },
  palette: {
    type: 'dark',
    isDark: true,
    background: {
      default: 'rgb(43 45 60)',
      paper: '#383d52',
    },
    primary: {
      main: '#ffffff',
    },
    secondary: {
      main: SECONDARY_COLOR,
    },
  },
  overrides: {
    MuiButton: {
      root: {
        borderRadius: BORDER_RADIUS,
      },
    },
    MuiPaper: {
      rounded: {
        borderRadius: BORDER_RADIUS,
      },
    },
    MuiDialog: {
      paper: {
        borderRadius: BORDER_RADIUS,
      },
    },
  },
});
