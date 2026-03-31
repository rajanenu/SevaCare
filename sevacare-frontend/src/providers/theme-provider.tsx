import { createContext, useContext, useMemo, type ReactNode } from 'react';
import { tenantRegistry, type TenantConfig } from '../config/tenant-registry';
import { type TenantKey, type ThemeTokens } from '../theme';
import { useAppStore } from '../store/app-store';

const ThemeContext = createContext<ThemeTokens | null>(null);
const TenantConfigContext = createContext<TenantConfig | null>(null);

export function ThemeProvider({ tenantKey, children }: { tenantKey: TenantKey; children: ReactNode }) {
  const config = tenantRegistry[tenantKey];
  const selectedColorPalette = useAppStore((state) => state.selectedColorPalette);

  const themeWithPalette = useMemo(() => {
    const baseTheme = config.theme;
    if (!selectedColorPalette) {
      return baseTheme;
    }
    // Apply the selected color palette to the theme
    return {
      ...baseTheme,
      primary: selectedColorPalette.primary,
      primaryStrong: selectedColorPalette.primaryStrong,
      shadowColor: selectedColorPalette.shadowColor,
      buttonGradient: selectedColorPalette.buttonGradient,
    } as ThemeTokens;
  }, [config.theme, selectedColorPalette]);

  return (
    <TenantConfigContext.Provider value={config}>
      <ThemeContext.Provider value={themeWithPalette}>{children}</ThemeContext.Provider>
    </TenantConfigContext.Provider>
  );
}

export function useTheme() {
  const value = useContext(ThemeContext);
  if (!value) {
    throw new Error('useTheme must be used within ThemeProvider');
  }
  return value;
}

export function useTenantConfig() {
  const value = useContext(TenantConfigContext);
  if (!value) {
    throw new Error('useTenantConfig must be used within ThemeProvider');
  }
  return value;
}