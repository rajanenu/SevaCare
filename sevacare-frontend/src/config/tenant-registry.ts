import { type BottomNavItem } from '../types/app';
import { tenantThemes, type TenantKey, type ThemeTokens } from '../theme';

export type TenantFeatureFlags = {
  entrySearch: boolean;
  entryNearby: boolean;
  entryScanQr: boolean;
  entrySavedHospitals: boolean;
  digitalPrescription: boolean;
  adminReports: boolean;
  adminManageDoctors: boolean;
  adminManagePatients: boolean;
  doctorCanDisablePatient: boolean;
};

export type TenantModules = {
  patient: {
    quickActions: string[];
  };
  doctor: {
    tabs: { dashboard: string; consultation: string; schedule: string };
  };
  admin: {
    tabs: { dashboard: string; doctors: string; patients: string; slots: string; reports: string };
  };
};

export type TenantCopy = {
  landingBrand: string;
  landingSubline: string;
  footerPrefix: string;
  footerSuffix: string;
  localOtpHint: string;
  entryLabels: {
    search: string;
    nearby: string;
    scanQr: string;
    saved: string;
  };
};

export type TenantConfig = {
  key: TenantKey;
  theme: ThemeTokens;
  brandColor: string;
  copy: TenantCopy;
  featureFlags: TenantFeatureFlags;
  modules: TenantModules;
  navigation: {
    patientBottom: BottomNavItem[];
    doctorBottom: BottomNavItem[];
    adminBottom: BottomNavItem[];
  };
};

const commonCopy: TenantCopy = {
  landingBrand: 'SevaCare',
  landingSubline: 'A complete healthcare platform',
  footerPrefix: 'Managed by',
  footerSuffix: 'companies',
  localOtpHint: 'Local OTP for testing: 0000',
  entryLabels: {
    search: 'Search Hospitals',
    nearby: 'Nearby Hospitals',
    scanQr: 'Scan QR',
    saved: 'Saved Hospitals',
  },
};

export const tenantRegistry: Record<TenantKey, TenantConfig> = {
  premium: {
    key: 'premium',
    theme: tenantThemes.premium,
    brandColor: '#2563EB',
    copy: commonCopy,
    featureFlags: {
      entrySearch: true,
      entryNearby: false,
      entryScanQr: false,
      entrySavedHospitals: false,
      digitalPrescription: true,
      adminReports: true,
      adminManageDoctors: true,
      adminManagePatients: true,
      doctorCanDisablePatient: true,
    },
    modules: {
      patient: {
        quickActions: ['Book appointment', 'Digital prescription', 'Lab reports', 'Insurance help'],
      },
      doctor: {
        tabs: { dashboard: 'Yesterday', consultation: 'Today', schedule: 'Tomorrow' },
      },
      admin: {
        tabs: { dashboard: 'Overview', doctors: 'Doctors', patients: 'Patients', slots: 'Slots', reports: 'Reports' },
      },
    },
    navigation: {
      patientBottom: [
        { label: 'Home', target: 'patientHome' },
        { label: 'Doctors', target: 'doctors' },
        { label: 'Appointments', target: 'appointments' },
        { label: 'Rx', target: 'prescription' },
        { label: 'Profile', target: 'profile' },
      ],
      doctorBottom: [
        { label: 'Dashboard', target: 'doctorDashboard' },
        { label: 'Consult', target: 'consultation' },
        { label: 'Rx', target: 'prescription-upload' },
      ],
      adminBottom: [
        { label: 'Dashboard', target: 'adminDashboard' },
        { label: 'Admins', target: 'adminUsers' },
        { label: 'Doctors', target: 'doctorManagement' },
        { label: 'Reports', target: 'reports' },
        { label: 'Profile', target: 'profile' },
      ],
    },
  },
  clinic: {
    key: 'clinic',
    theme: tenantThemes.clinic,
    brandColor: '#2563EB',
    copy: commonCopy,
    featureFlags: {
      entrySearch: true,
      entryNearby: false,
      entryScanQr: false,
      entrySavedHospitals: false,
      digitalPrescription: true,
      adminReports: false,
      adminManageDoctors: true,
      adminManagePatients: true,
      doctorCanDisablePatient: true,
    },
    modules: {
      patient: {
        quickActions: ['Book appointment', 'Digital prescription', 'Lab reports'],
      },
      doctor: {
        tabs: { dashboard: 'Yesterday', consultation: 'Today', schedule: 'Tomorrow' },
      },
      admin: {
        tabs: { dashboard: 'Overview', doctors: 'Doctors', patients: 'Patients', slots: 'Slots', reports: 'Reports' },
      },
    },
    navigation: {
      patientBottom: [
        { label: 'Home', target: 'patientHome' },
        { label: 'Doctors', target: 'doctors' },
        { label: 'Appointments', target: 'appointments' },
        { label: 'Rx', target: 'prescription' },
        { label: 'Profile', target: 'profile' },
      ],
      doctorBottom: [
        { label: 'Dashboard', target: 'doctorDashboard' },
        { label: 'Consult', target: 'consultation' },
        { label: 'Rx', target: 'prescription-upload' },
      ],
      adminBottom: [
        { label: 'Dashboard', target: 'adminDashboard' },
        { label: 'Admins', target: 'adminUsers' },
        { label: 'Doctors', target: 'doctorManagement' },
        { label: 'Reports', target: 'reports' },
        { label: 'Profile', target: 'profile' },
      ],
    },
  },
};