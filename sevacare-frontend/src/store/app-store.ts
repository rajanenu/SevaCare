import { create } from 'zustand';
import { hospitals } from '../demo-data';
import { type AuthenticatedSession } from '../api/types';
import { type Role, type TenantKey } from '../theme';
import { roleFirstScreen, type AppScreen, type PermissionState } from '../types/app';
import { type ColorPalette, colorPalettes } from '../palettes';

type AppCache = {
  lastHospitalId: string | null;
  lastRole: Role;
  lastOtp: string;
  tenantHistory: string[];
};

type AppState = {
  screen: AppScreen;
  activeRole: Role;
  activeTenant: TenantKey;
  query: string;
  selectedHospitalId: string;
  selectedDoctorId: string;
  selectedDate: string;
  selectedSlot: string;
  appointmentTab: 'upcoming' | 'history';
  loginIdentifier: string;
  loginEmail: string;
  loginOtp: string;
  bookingName: string;
  bookingEmail: string;
  bookingGender: 'male' | 'female' | 'other';
  bookingAge: string;
  bookingMobile: string;
  bookingAddress: string;
  bookingSpecialty: string;
  slotIntervalMinutes: number;
  bookedSlots: string[];
  bookingAvailableDates: string[];
  bookingMorningSlots: string[];
  bookingEveningSlots: string[];
  locationAccess: PermissionState;
  cameraAccess: PermissionState;
  authToken: string | null;
  sessionTenantPublicId: string | null;
  subjectPublicId: string | null;
  doctorSelectedPatientId: string | null;
  doctorSelectedAppointmentId: string | null;
  doctorProfilePhotoUri: string | null;
  patientProfilePhotoUri: string | null;
  selectedColorPalette: ColorPalette | null;
  patientHomeRefreshKey: number;
  cache: AppCache;
  setScreen: (screen: AppScreen) => void;
  setActiveRole: (role: Role) => void;
  setQuery: (query: string) => void;
  setSelectedDate: (date: string) => void;
  setSelectedSlot: (slot: string) => void;
  setAppointmentTab: (tab: 'upcoming' | 'history') => void;
  setLoginIdentifier: (identifier: string) => void;
  setLoginEmail: (email: string) => void;
  setLoginOtp: (otp: string) => void;
  setBookingName: (value: string) => void;
  setBookingEmail: (value: string) => void;
  setBookingGender: (value: 'male' | 'female' | 'other') => void;
  setBookingAge: (value: string) => void;
  setBookingMobile: (value: string) => void;
  setBookingAddress: (value: string) => void;
  setBookingSpecialty: (value: string) => void;
  setSlotIntervalMinutes: (value: number) => void;
  setBookingSetup: (dates: string[], morning: string[], evening: string[]) => void;
  markBookedSlot: (slot: string) => void;
  setLocationAccess: (state: PermissionState) => void;
  setCameraAccess: (state: PermissionState) => void;
  selectHospital: (hospitalId: string) => void;
  setSelectedDoctorId: (doctorId: string) => void;
  selectDoctor: (doctorId: string) => void;
  continueAfterLogin: () => void;
  setAuthSession: (session: AuthenticatedSession) => void;
  clearAuthSession: () => void;
  setActiveTenant: (tenant: TenantKey) => void;
  setDoctorSelectionForRx: (patientPublicId: string | null, appointmentPublicId: string | null) => void;
  setDoctorProfilePhotoUri: (uri: string | null) => void;
  setPatientProfilePhotoUri: (uri: string | null) => void;
  setSelectedColorPalette: (palette: ColorPalette | null) => void;
  resetBookingForm: () => void;
  refreshPatientHomeData: () => void;
};

const STORAGE_KEY = 'sevacare-ui-cache';

type PersistedState = Pick<
  AppState,
  'activeRole' | 'activeTenant' | 'selectedHospitalId' | 'selectedDoctorId' | 'selectedDate' | 'selectedSlot' | 'appointmentTab' | 'loginIdentifier' | 'loginEmail' | 'loginOtp' | 'bookingName' | 'bookingEmail' | 'bookingGender' | 'bookingAge' | 'bookingMobile' | 'bookingAddress' | 'bookingSpecialty' | 'slotIntervalMinutes' | 'bookedSlots' | 'bookingAvailableDates' | 'bookingMorningSlots' | 'bookingEveningSlots' | 'authToken' | 'sessionTenantPublicId' | 'subjectPublicId' | 'doctorSelectedPatientId' | 'doctorSelectedAppointmentId' | 'doctorProfilePhotoUri' | 'patientProfilePhotoUri' | 'selectedColorPalette' | 'cache'
>;

const defaultPersistedState: PersistedState = {
  activeRole: 'patient',
  activeTenant: 'premium',
  selectedHospitalId: 'aurora',
  selectedDoctorId: 'dr-meera',
  selectedDate: '',
  selectedSlot: '',
  appointmentTab: 'upcoming',
  loginIdentifier: '9000000000',
  loginEmail: '',
  loginOtp: '0000',
  bookingName: '',
  bookingEmail: '',
  bookingGender: 'male',
  bookingAge: '',
  bookingMobile: '',
  bookingAddress: '',
  bookingSpecialty: 'General Physician',
  slotIntervalMinutes: 15,
  bookedSlots: [],
  bookingAvailableDates: [],
  bookingMorningSlots: [],
  bookingEveningSlots: [],
  authToken: null,
  sessionTenantPublicId: null,
  subjectPublicId: null,
  doctorSelectedPatientId: null,
  doctorSelectedAppointmentId: null,
  doctorProfilePhotoUri: null,
  patientProfilePhotoUri: null,
  selectedColorPalette: colorPalettes.find((p) => p.id === 'vivid-purple') ?? null,
  cache: {
    lastHospitalId: null,
    lastRole: 'patient',
    lastOtp: '0000',
    tenantHistory: [],
  },
};

const loadPersistedState = (): PersistedState => {
  if (typeof window === 'undefined' || !window.localStorage) {
    return defaultPersistedState;
  }

  const rawValue = window.localStorage.getItem(STORAGE_KEY);
  if (!rawValue) {
    return defaultPersistedState;
  }

  try {
    return { ...defaultPersistedState, ...JSON.parse(rawValue) } as PersistedState;
  } catch {
    return defaultPersistedState;
  }
};

const persistState = (state: PersistedState) => {
  if (typeof window === 'undefined' || !window.localStorage) {
    return;
  }

  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
};

const initialPersistedState = loadPersistedState();

export const useAppStore = create<AppState>((set, get) => {
  const commit = (updater: Partial<AppState> | ((state: AppState) => Partial<AppState>)) => {
    set((state) => {
      const patch = typeof updater === 'function' ? updater(state) : updater;
      const nextState = { ...state, ...patch } as AppState;
      persistState({
        activeRole: nextState.activeRole,
        activeTenant: nextState.activeTenant,
        selectedHospitalId: nextState.selectedHospitalId,
        selectedDoctorId: nextState.selectedDoctorId,
        selectedDate: nextState.selectedDate,
        selectedSlot: nextState.selectedSlot,
        appointmentTab: nextState.appointmentTab,
        loginIdentifier: nextState.loginIdentifier,
        loginEmail: nextState.loginEmail,
        loginOtp: nextState.loginOtp,
        bookingName: nextState.bookingName,
        bookingEmail: nextState.bookingEmail,
        bookingGender: nextState.bookingGender,
        bookingAge: nextState.bookingAge,
        bookingMobile: nextState.bookingMobile,
        bookingAddress: nextState.bookingAddress,
        bookingSpecialty: nextState.bookingSpecialty,
        slotIntervalMinutes: nextState.slotIntervalMinutes,
        bookedSlots: nextState.bookedSlots,
        bookingAvailableDates: nextState.bookingAvailableDates,
        bookingMorningSlots: nextState.bookingMorningSlots,
        bookingEveningSlots: nextState.bookingEveningSlots,
        authToken: nextState.authToken,
        sessionTenantPublicId: nextState.sessionTenantPublicId,
        subjectPublicId: nextState.subjectPublicId,
        doctorSelectedPatientId: nextState.doctorSelectedPatientId,
        doctorSelectedAppointmentId: nextState.doctorSelectedAppointmentId,
        doctorProfilePhotoUri: nextState.doctorProfilePhotoUri,
        patientProfilePhotoUri: nextState.patientProfilePhotoUri,
        selectedColorPalette: nextState.selectedColorPalette,
        cache: nextState.cache,
      });
      return patch;
    });
  };

  return {
    screen: 'welcome',
    query: '',
    locationAccess: 'unknown',
    cameraAccess: 'unknown',
    patientHomeRefreshKey: 0,
    ...initialPersistedState,
    setScreen: (screen) => commit({ screen }),
    setActiveRole: (activeRole) => commit((state) => ({ activeRole, cache: { ...state.cache, lastRole: activeRole } })),
    setQuery: (query) => commit({ query }),
    setSelectedDate: (selectedDate) => commit({ selectedDate }),
    setSelectedSlot: (selectedSlot) => commit({ selectedSlot }),
    setLoginIdentifier: (loginIdentifier) => commit({ loginIdentifier }),
    setLoginEmail: (loginEmail) => commit({ loginEmail }),
    setLoginOtp: (loginOtp) => commit({ loginOtp }),
    setBookingName: (bookingName) => commit({ bookingName }),
    setBookingEmail: (bookingEmail) => commit({ bookingEmail }),
    setBookingGender: (bookingGender) => commit({ bookingGender }),
    setBookingAge: (bookingAge) => commit({ bookingAge }),
    setBookingMobile: (bookingMobile) => commit({ bookingMobile }),
    setBookingAddress: (bookingAddress) => commit({ bookingAddress }),
    setBookingSpecialty: (bookingSpecialty) => commit({ bookingSpecialty }),
    setSlotIntervalMinutes: (slotIntervalMinutes) => commit({ slotIntervalMinutes }),
    setBookingSetup: (bookingAvailableDates, bookingMorningSlots, bookingEveningSlots) => commit({ bookingAvailableDates, bookingMorningSlots, bookingEveningSlots }),
    markBookedSlot: (slot) => commit((state) => ({ bookedSlots: Array.from(new Set([...state.bookedSlots, slot])) })),
    setAppointmentTab: (appointmentTab) => commit({ appointmentTab }),
    setLocationAccess: (locationAccess) => commit({ locationAccess }),
    setCameraAccess: (cameraAccess) => commit({ cameraAccess }),
    setActiveTenant: (activeTenant) => commit({ activeTenant }),
    selectHospital: (hospitalId) => {
      const hospital = hospitals.find((item) => item.id === hospitalId) ?? hospitals[0];
      commit((state) => ({
        selectedHospitalId: hospital.id,
        activeTenant: hospital.theme,
        screen: 'loading',
        cache: {
          ...state.cache,
          lastHospitalId: hospital.id,
          tenantHistory: Array.from(new Set([hospital.publicId, ...state.cache.tenantHistory])).slice(0, 5),
        },
      }));
    },
    setSelectedDoctorId: (selectedDoctorId) => commit({ selectedDoctorId }),
    selectDoctor: (selectedDoctorId) => commit({ selectedDoctorId, screen: 'booking' }),
    continueAfterLogin: () => {
      const { activeRole } = get();
      commit((state) => ({
        screen: roleFirstScreen[activeRole],
        bookingMobile: state.loginIdentifier,
        cache: {
          ...state.cache,
          lastOtp: state.loginOtp,
        },
      }));
    },
    setAuthSession: (session) => commit({
      authToken: session.token,
      sessionTenantPublicId: session.tenantPublicId,
      subjectPublicId: session.subjectPublicId,
    }),
    clearAuthSession: () => commit({
      authToken: null,
      sessionTenantPublicId: null,
      subjectPublicId: null,
    }),
    setDoctorSelectionForRx: (patientPublicId, appointmentPublicId) => commit({
      doctorSelectedPatientId: patientPublicId,
      doctorSelectedAppointmentId: appointmentPublicId,
    }),
    setDoctorProfilePhotoUri: (uri) => commit({
      doctorProfilePhotoUri: uri,
    }),
    setPatientProfilePhotoUri: (uri) => commit({
      patientProfilePhotoUri: uri,
    }),
    setSelectedColorPalette: (palette) => commit({
      selectedColorPalette: palette,
    }),
    resetBookingForm: () => commit({
      bookingName: '',
      bookingEmail: '',
      bookingGender: 'male' as const,
      bookingAge: '',
      bookingMobile: '',
      bookingAddress: '',
      selectedDate: '',
      selectedSlot: '',
      bookedSlots: [],
    }),
    refreshPatientHomeData: () => set((state) => ({ patientHomeRefreshKey: state.patientHomeRefreshKey + 1 })),
  };
});