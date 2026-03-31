import { StatusBar } from 'expo-status-bar';
import { StyleSheet } from 'react-native';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { ThemeProvider, useTheme } from './src/providers/theme-provider';
import { AppRouter } from './src/screens/app-router';
import { useAppStore } from './src/store/app-store';

function AppStatusBar() {
  const theme = useTheme();

  return <StatusBar style="dark" />;
}

export default function App() {
  const activeTenant = useAppStore((state) => state.activeTenant);

  return (
    <SafeAreaProvider>
      <ThemeProvider tenantKey={activeTenant}>
        <AppStatusBar />
        <AppRouter />
      </ThemeProvider>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  loader: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#f2f8f6',
  },
});
