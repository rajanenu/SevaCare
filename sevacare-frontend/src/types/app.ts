import { Role } from '../theme';

export type AppScreen =
  | 'welcome'
  | 'features'
  | 'onboarding'
  | 'search'
  | 'nearby'
  | 'scanner'
  | 'saved'
  | 'loading'
  | 'login'
  | 'patientHome'
  | 'doctors'
  | 'booking'
  | 'confirmation'
  | 'appointments'
  | 'prescription'
  | 'prescription-detail'
  | 'prescription-upload'
  | 'medical-history'
  | 'color-palette'
  | 'doctorDashboard'
  | 'consultation'
  | 'adminDashboard'
  | 'platformAdminDashboard'
  | 'adminUsers'
  | 'doctorManagement'
  | 'slotConfig'
  | 'reports'
  | 'profile'
  | 'settings'
  | 'contacts';

export type PermissionState = 'unknown' | 'granted' | 'denied';

export type BottomNavItem = {
  label: string;
  target: AppScreen;
};

export const roleFirstScreen: Record<Role, AppScreen> = {
  patient: 'patientHome',
  doctor: 'doctorDashboard',
  admin: 'adminDashboard',
  platform_admin: 'platformAdminDashboard',
};

export const patientBottomScreens: AppScreen[] = [
  'patientHome',
  'doctors',
  'appointments',
  'prescription',
  'booking',
  'confirmation',
];