export type TenantKey = 'premium' | 'clinic';
export type Role = 'patient' | 'doctor' | 'admin' | 'platform_admin';

export type ThemeTokens = {
  id: TenantKey;
  name: string;
  brandLine: string;
  radius: number;
  background: string;
  backgroundGlow: string;
  headerSurface: string;
  footerSurface: string;
  surface: string;
  surfaceMuted: string;
  card: string;
  border: string;
  text: string;
  textMuted: string;
  primary: string;
  primaryStrong: string;
  accent: string;
  secondaryAccent: string;
  success: string;
  warning: string;
  danger: string;
  overlay: string;
  screenGradient: [string, string, string];
  heroGradient: [string, string];
  buttonGradient: [string, string];
  buttonText: string;
  shadowColor: string;
};

export const tenantThemes: Record<TenantKey, ThemeTokens> = {
  premium: {
    id: 'premium',
    name: 'Premium Hospital',
    brandLine: 'World-class care in a concierge experience',
    radius: 14,
    background: '#EAF8EC',
    backgroundGlow: '#CDEDD2',
    headerSurface: '#F8FBFF',
    footerSurface: '#F8FBFF',
    surface: '#F4FBF4',
    surfaceMuted: '#E3F4E6',
    card: '#FFFFFF',
    border: '#C8E6CD',
    text: '#0F172A',
    textMuted: '#475569',
    primary: '#60A5FA',
    primaryStrong: '#3B82F6',
    accent: '#60A5FA',
    secondaryAccent: '#60A5FA',
    success: '#10B981',
    warning: '#F59E0B',
    danger: '#EF4444',
    overlay: 'rgba(74, 222, 128, 0.12)',
    screenGradient: ['#EAF8EC', '#F4FBF4', '#EAF8EC'],
    heroGradient: ['#60A5FA', '#BAE6FD'],
    buttonGradient: ['#93C5FD', '#60A5FA'],
    buttonText: '#FFFFFF',
    shadowColor: '#60A5FA',
  },
  clinic: {
    id: 'clinic',
    name: 'Community Clinic',
    brandLine: 'Accessible care for every neighborhood',
    radius: 12,
    background: '#EAF8EC',
    backgroundGlow: '#CDEDD2',
    headerSurface: '#F8FBFF',
    footerSurface: '#F8FBFF',
    surface: '#F4FBF4',
    surfaceMuted: '#E3F4E6',
    card: '#FFFFFF',
    border: '#C8E6CD',
    text: '#0F172A',
    textMuted: '#475569',
    primary: '#60A5FA',
    primaryStrong: '#3B82F6',
    accent: '#60A5FA',
    secondaryAccent: '#60A5FA',
    success: '#10B981',
    warning: '#F59E0B',
    danger: '#EF4444',
    overlay: 'rgba(74, 222, 128, 0.12)',
    screenGradient: ['#EAF8EC', '#F4FBF4', '#EAF8EC'],
    heroGradient: ['#60A5FA', '#BAE6FD'],
    buttonGradient: ['#93C5FD', '#60A5FA'],
    buttonText: '#FFFFFF',
    shadowColor: '#60A5FA',
  },
};

export const roleLabels: Record<Role, string> = {
  patient: 'Patient',
  doctor: 'Doctor',
  admin: 'Hospital Admin',
  platform_admin: 'Platform Admin',
};