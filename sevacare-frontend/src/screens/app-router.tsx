import { useEffect, useMemo, useState } from 'react';
import { Camera } from 'expo-camera';
import * as Location from 'expo-location';
import { sevacareApi } from '../api/client';
import type { PatientHomeView } from '../api/types';
import AuthService from '../services/authService';
import {
  doctors,
  hospitals,
} from '../demo-data';
import { useTenantConfig } from '../providers/theme-provider';
import { useAppStore } from '../store/app-store';
import { roleFirstScreen, type AppScreen } from '../types/app';
import {
  WelcomeScreen,
  FeaturesScreen,
  OnboardingScreen,
  SearchResultsScreen,
  NearbyHospitalsScreen,
  ScannerScreen,
  SavedHospitalsScreen,
  TenantLoadingScreen,
} from './tenant-entry-screens';
import { LoginScreen } from './login-screen';
import {
  PatientHomeScreen,
  DoctorsScreen,
  BookingScreen,
  ConfirmationScreen,
  AppointmentsScreen,
  PrescriptionScreen,
} from './patient-screens';
import {
  PrescriptionListScreen,
  PrescriptionDetailScreen,
  MedicineUploadScreen,
  MedicalHistoryScreen,
} from './prescription-screens';
import { DoctorDashboardScreen, ConsultationScreen } from './doctor-screens';
import { AdminDashboardScreen, AdminReportsScreen, AdminUsersScreen, DoctorManagementScreen, PlatformAdminDashboardScreen } from './admin-screens';
import { ProfileScreen, SettingsScreen, ContactsScreen } from './common-screens';
import { ColorPaletteScreen } from './color-palette-screen';
import { type ColorPalette } from '../palettes';

export function AppRouter() {
  const config = useTenantConfig();
  const screen = useAppStore((state) => state.screen);
  const activeRole = useAppStore((state) => state.activeRole);
  const activeTenant = useAppStore((state) => state.activeTenant);
  const query = useAppStore((state) => state.query);
  const selectedHospitalId = useAppStore((state) => state.selectedHospitalId);
  const selectedDoctorId = useAppStore((state) => state.selectedDoctorId);
  const selectedDate = useAppStore((state) => state.selectedDate);
  const selectedSlot = useAppStore((state) => state.selectedSlot);
  const appointmentTab = useAppStore((state) => state.appointmentTab);
  const [selectedPrescriptionId, setSelectedPrescriptionId] = useState<string | null>(null);
  const loginIdentifier = useAppStore((state) => state.loginIdentifier);
  const loginEmail = useAppStore((state) => state.loginEmail);
  const loginOtp = useAppStore((state) => state.loginOtp);
  const bookingName = useAppStore((state) => state.bookingName);
  const bookingGender = useAppStore((state) => state.bookingGender);
  const bookingAge = useAppStore((state) => state.bookingAge);
  const bookingMobile = useAppStore((state) => state.bookingMobile);
  const bookingEmail = useAppStore((state) => state.bookingEmail);
  const bookingAddress = useAppStore((state) => state.bookingAddress);
  const bookingSpecialty = useAppStore((state) => state.bookingSpecialty);
  const slotIntervalMinutes = useAppStore((state) => state.slotIntervalMinutes);
  const bookedSlots = useAppStore((state) => state.bookedSlots);
  const locationAccess = useAppStore((state) => state.locationAccess);
  const cameraAccess = useAppStore((state) => state.cameraAccess);
  const setScreen = useAppStore((state) => state.setScreen);
  const setActiveRole = useAppStore((state) => state.setActiveRole);
  const setQuery = useAppStore((state) => state.setQuery);
  const setSelectedDate = useAppStore((state) => state.setSelectedDate);
  const setSelectedSlot = useAppStore((state) => state.setSelectedSlot);
  const setAppointmentTab = useAppStore((state) => state.setAppointmentTab);
  const setLoginIdentifier = useAppStore((state) => state.setLoginIdentifier);
  const setLoginEmail = useAppStore((state) => state.setLoginEmail);
  const setLoginOtp = useAppStore((state) => state.setLoginOtp);
  const setBookingName = useAppStore((state) => state.setBookingName);
  const setBookingGender = useAppStore((state) => state.setBookingGender);
  const setBookingAge = useAppStore((state) => state.setBookingAge);
  const setBookingMobile = useAppStore((state) => state.setBookingMobile);
  const setBookingEmail = useAppStore((state) => state.setBookingEmail);
  const setBookingAddress = useAppStore((state) => state.setBookingAddress);
  const setBookingSpecialty = useAppStore((state) => state.setBookingSpecialty);
  const setSlotIntervalMinutes = useAppStore((state) => state.setSlotIntervalMinutes);
  const markBookedSlot = useAppStore((state) => state.markBookedSlot);
  const setLocationAccess = useAppStore((state) => state.setLocationAccess);
  const setCameraAccess = useAppStore((state) => state.setCameraAccess);
  const authToken = useAppStore((state) => state.authToken);
  const sessionTenantPublicId = useAppStore((state) => state.sessionTenantPublicId);
  const subjectPublicId = useAppStore((state) => state.subjectPublicId);
  const doctorSelectedPatientId = useAppStore((state) => state.doctorSelectedPatientId);
  const doctorSelectedAppointmentId = useAppStore((state) => state.doctorSelectedAppointmentId);
  const setAuthSession = useAppStore((state) => state.setAuthSession);
  const selectHospital = useAppStore((state) => state.selectHospital);
  const setSelectedDoctorId = useAppStore((state) => state.setSelectedDoctorId);
  const selectDoctor = useAppStore((state) => state.selectDoctor);
  const continueAfterLogin = useAppStore((state) => state.continueAfterLogin);
  const setSelectedColorPalette = useAppStore((state) => state.setSelectedColorPalette);
  const resetBookingForm = useAppStore((state) => state.resetBookingForm);
  const refreshPatientHomeData = useAppStore((state) => state.refreshPatientHomeData);
  const patientHomeRefreshKey = useAppStore((state) => state.patientHomeRefreshKey);

  const setBookingSetup = useAppStore((state) => state.setBookingSetup);
  const bookingAvailableDates = useAppStore((state) => state.bookingAvailableDates);
  const bookingMorningSlots = useAppStore((state) => state.bookingMorningSlots);
  const bookingEveningSlots = useAppStore((state) => state.bookingEveningSlots);

  const [remoteTenants, setRemoteTenants] = useState(hospitals);
  const [remoteDoctors, setRemoteDoctors] = useState<typeof doctors>([]);
  const [lookupSpecializations, setLookupSpecializations] = useState<string[]>([]);
  const [remotePatientHome, setRemotePatientHome] = useState<PatientHomeView | null>(null);
  
  // Onboarding state
  const [onboardingLoading, setOnboardingLoading] = useState(false);
  const [onboardingSuccess, setOnboardingSuccess] = useState<{ requestId: string } | null>(null);
  const [onboardingError, setOnboardingError] = useState<string | null>(null);

  // Restore session on app startup
  useEffect(() => {
    let cancelled = false;
    const restoreSession = async () => {
      try {
        const session = await AuthService.loadSession();
        if (!cancelled && session) {
          setAuthSession(session);
          // Navigate to appropriate screen based on role
          const firstScreen = roleFirstScreen[session.role];
          setScreen(firstScreen);
        }
      } catch (error) {
        console.warn('Failed to restore session:', error);
      }
    };
    void restoreSession();
    return () => {
      cancelled = true;
    };
  }, [setAuthSession, setScreen]);

  const filteredHospitals = remoteTenants.filter((hospital) => {
    const haystack = `${hospital.name} ${hospital.city} ${hospital.specialty}`.toLowerCase();
    return haystack.includes(query.trim().toLowerCase());
  });
  const savedHospitals = remoteTenants.filter((hospital) => hospital.saved);
  const sortedHospitals = [...remoteTenants].sort((left, right) => left.distance.localeCompare(right.distance));
  const selectedHospital = remoteTenants.find((hospital) => hospital.id === selectedHospitalId) ?? remoteTenants[0] ?? hospitals[0];
  const doctorsForHospital = remoteDoctors.filter((doctor) => doctor.hospitalId === selectedHospital.id);
  const appointmentsForHospital = useMemo(
    () => remotePatientHome
      ? remotePatientHome.appointments.map((item): import('../demo-data').Appointment => ({
          id: item.appointmentPublicId,
          hospitalId: selectedHospital.id,
          patientId: subjectPublicId ?? 'unknown',
          doctor: remoteDoctors.find((doctor) => doctor.publicId === item.doctorPublicId)?.name ?? item.doctorName,
          hospital: selectedHospital.name,
          slot: item.slot,
          status: item.status === 'past' ? 'completed' : 'upcoming',
          note: item.note,
        }))
      : [],
    [remotePatientHome, remoteDoctors, selectedHospital.id, selectedHospital.name, subjectPublicId],
  );
  const selectedDoctor = remoteDoctors.find((doctor) => doctor.id === selectedDoctorId) ?? doctorsForHospital[0];
  const patientBottomItems = config.navigation.patientBottom.filter((item) => (item.target === 'prescription' ? config.featureFlags.digitalPrescription : true));
  const doctorBottomItems = config.navigation.doctorBottom.filter((item) => (item.target === 'prescription-upload' ? config.featureFlags.digitalPrescription : true));
  const adminBottomItems = config.navigation.adminBottom;
  const roleBottomItems = activeRole === 'platform_admin' ? [] : activeRole === 'doctor' ? doctorBottomItems : activeRole === 'admin' ? adminBottomItems : patientBottomItems;

  useEffect(() => {
    let cancelled = false;
    sevacareApi.listTenants()
      .then((payload) => {
        if (cancelled) {
          return;
        }
        const mapped = payload.tenants.map((tenant, index) => ({
          id: tenant.hospitalName.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
          publicId: tenant.tenantPublicId,
          name: tenant.hospitalName,
          city: tenant.city,
          distance: `${index + 1}.0 km`,
          specialty: tenant.specialty,
          theme: tenant.themeKey,
          saved: index < 2,
        }));
        setRemoteTenants(mapped.length > 0 ? mapped : hospitals);
      })
      .catch(() => setRemoteTenants(hospitals));

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    sevacareApi.getLookups()
      .then((payload) => {
        if (cancelled) {
          return;
        }
        setLookupSpecializations(payload.specializations ?? []);
      })
      .catch(() => setLookupSpecializations([]));

    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    if (!selectedHospital?.publicId) {
      return;
    }
    let cancelled = false;
    sevacareApi.listDoctors(selectedHospital.publicId)
      .then((payload) => {
        if (cancelled) {
          return;
        }
        const mapped = payload.doctors.map((doctor) => ({
          id: doctor.doctorPublicId.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
          publicId: doctor.doctorPublicId,
          name: doctor.name,
          specialty: doctor.specialty,
          hospitalId: selectedHospital.id,
          availability: doctor.availability,
          rating: '4.8',
          fee: doctor.fee,
          experience: doctor.experience ?? '5Y+ Exp',
        }));
        setRemoteDoctors(mapped);
      })
      .catch(() => setRemoteDoctors([]));

    return () => {
      cancelled = true;
    };
  }, [selectedHospital?.id, selectedHospital?.publicId]);

  useEffect(() => {
    if (!authToken || !sessionTenantPublicId || !subjectPublicId || activeRole !== 'patient') {
      setRemotePatientHome(null);
      return;
    }

    sevacareApi.getPatientHome(sessionTenantPublicId, subjectPublicId, authToken)
      .then(setRemotePatientHome)
      .catch(() => setRemotePatientHome(null));
  }, [activeRole, authToken, sessionTenantPublicId, subjectPublicId, patientHomeRefreshKey]);

  useEffect(() => {
    if (doctorsForHospital.length === 0) {
      return;
    }
    const hasActiveSpecialty = doctorsForHospital.some((doctor) => doctor.specialty === bookingSpecialty);
    if (!hasActiveSpecialty) {
      setBookingSpecialty(doctorsForHospital[0].specialty);
      setSelectedDoctorId(doctorsForHospital[0].id);
    }
  }, [doctorsForHospital, bookingSpecialty, setBookingSpecialty, setSelectedDoctorId]);

  useEffect(() => {
    if (!authToken || !sessionTenantPublicId || !subjectPublicId || activeRole !== 'patient') {
      return;
    }

    sevacareApi.getBookingSetup(sessionTenantPublicId, subjectPublicId, authToken)
      .then((setup) => {
        setSlotIntervalMinutes(setup.slotIntervalMinutes);
        if (setup.specialties.length > 0) {
          const preferred = setup.specialties.find((s) => s === 'General Physician') ?? setup.specialties[0];
          setBookingSpecialty(preferred);
        }
        setBookingSetup(
          setup.availableDates ?? [],
          setup.morningSlots ?? [],
          setup.eveningSlots ?? [],
        );
        // Auto-select first available date
        if (setup.availableDates?.length > 0 && !selectedDate) {
          setSelectedDate(setup.availableDates[0]);
        }
      })
      .catch(() => undefined);
  }, [activeRole, authToken, sessionTenantPublicId, subjectPublicId, setBookingSpecialty, setSlotIntervalMinutes, setBookingSetup, selectedDate, setSelectedDate]);

  useEffect(() => {
    if (screen !== 'loading') {
      return undefined;
    }

    const timeoutId = setTimeout(() => {
      setScreen('login');
    }, 900);

    return () => clearTimeout(timeoutId);
  }, [screen, setScreen]);

  useEffect(() => {
    if (screen === 'prescription' && !config.featureFlags.digitalPrescription) {
      setScreen('patientHome');
    }
  }, [screen, setScreen, config.featureFlags.digitalPrescription]);

  const navigate = (nextScreen: AppScreen) => {
    if (nextScreen === 'prescription' && !config.featureFlags.digitalPrescription) {
      setScreen('patientHome');
      return;
    }
    if (nextScreen === 'booking' && screen !== 'booking' && screen !== 'confirmation') {
      resetBookingForm();
    }
    setScreen(nextScreen);
  };

  const requestLocation = async () => {
    const permission = await Location.requestForegroundPermissionsAsync();
    setLocationAccess(permission.status === 'granted' ? 'granted' : 'denied');
    setScreen('nearby');
  };

  const requestCamera = async () => {
    const permission = await Camera.requestCameraPermissionsAsync();
    setCameraAccess(permission.status === 'granted' ? 'granted' : 'denied');
    setScreen('scanner');
  };

  switch (screen) {
    case 'welcome':
      return (
        <WelcomeScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          onOpenSearch={() => navigate('search')}
          onOpenNearby={requestLocation}
          onOpenScanner={requestCamera}
          onOpenSaved={() => navigate('saved')}
          onOpenOnboarding={() => navigate('onboarding')}
        />
      );
    case 'features':
      return (
        <FeaturesScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          onOpenPlatformAdmin={() => {
            setActiveRole('platform_admin');
            setScreen('login');
          }}
        />
      );
    case 'onboarding': {
      return (
        <OnboardingScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          isLoading={onboardingLoading}
          successMessage={onboardingSuccess ?? undefined}
          errorMessage={onboardingError ?? undefined}
          onSuccessClose={() => {
            setOnboardingSuccess(null);
            setOnboardingError(null);
            setOnboardingLoading(false);
            navigate('welcome');
            // Refresh tenants list to show the new hospital
            void sevacareApi.listTenants()
              .then((payload) => {
                const mapped = payload.tenants.map((tenant, index) => ({
                  id: tenant.hospitalName.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
                  publicId: tenant.tenantPublicId,
                  name: tenant.hospitalName,
                  city: tenant.city,
                  distance: `${index + 1}.0 km`,
                  specialty: tenant.specialty,
                  theme: tenant.themeKey,
                  saved: index < 2,
                }));
                setRemoteTenants(mapped.length > 0 ? mapped : hospitals);
              })
              .catch(() => setRemoteTenants(hospitals));
          }}
          onErrorClose={() => {
            setOnboardingError(null);
            setOnboardingLoading(false);
          }}
          onSubmit={(payload) => {
            setOnboardingLoading(true);
            setOnboardingError(null);
            setOnboardingSuccess(null);

            const requestBody = {
              hospitalName: payload.hospitalName,
              licenseNumber: payload.licenseNumber,
              address: payload.address,
              city: payload.city,
              state: payload.state,
              country: payload.country,
              contactName: payload.contactName,
              contactMobile: payload.contactMobile,
              contactEmail: payload.contactEmail,
              supportingDocs: payload.supportingDocs,
              facilityType: payload.facilityType,
            };

            const handleSuccess = (response: any) => {
              setOnboardingLoading(false);
              setOnboardingSuccess({ requestId: response.requestPublicId });
            };

            const handleError = (error: any) => {
              setOnboardingLoading(false);
              const errorMsg = typeof error?.message === 'string' 
                ? error.message 
                : 'Failed to submit onboarding request. Please try again.';
              setOnboardingError(errorMsg);
            };

            if (payload.supportingFiles.length > 0) {
              void sevacareApi.requestTenantOnboardingMultipart(requestBody, payload.supportingFiles)
                .then(handleSuccess)
                .catch(handleError);
              return;
            }

            void sevacareApi.requestTenantOnboarding(requestBody)
              .then(handleSuccess)
              .catch(handleError);
          }}
        />
      );
    }
    case 'search':
      return (
        <SearchResultsScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          query={query}
          onQueryChange={setQuery}
          hospitals={query ? filteredHospitals : remoteTenants}
          onSelectHospital={selectHospital}
        />
      );
    case 'nearby':
      return (
        <NearbyHospitalsScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          locationAccess={locationAccess}
          hospitals={sortedHospitals}
          onSelectHospital={selectHospital}
        />
      );
    case 'scanner':
      return (
        <ScannerScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          cameraAccess={cameraAccess}
          onSimulateSuccess={() => selectHospital('aurora')}
        />
      );
    case 'saved':
      return (
        <SavedHospitalsScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          hospitals={savedHospitals}
          onSelectHospital={selectHospital}
        />
      );
    case 'loading':
      return (
        <TenantLoadingScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          hospitalName={selectedHospital.name}
        />
      );
    case 'login':
      return (
        <LoginScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          activeRole={activeRole}
          onRoleChange={setActiveRole}
          hospitalName={selectedHospital.name}
          identifier={loginIdentifier}
          email={loginEmail}
          otp={loginOtp}
          onIdentifierChange={setLoginIdentifier}
          onEmailChange={setLoginEmail}
          onOtpChange={setLoginOtp}
          isPlatformEntry={activeRole === 'platform_admin'}
          onSendOtp={async () => {
            const tenantPublicId = activeRole === 'platform_admin' ? 'platform' : selectedHospital.publicId ?? remoteTenants[0]?.publicId ?? 'T-1001';
            await sevacareApi.requestOtp({ tenantPublicId, role: activeRole, mobileNumber: loginIdentifier });
          }}
          onContinue={async () => {
            const tenantPublicId = activeRole === 'platform_admin' ? 'platform' : selectedHospital.publicId ?? remoteTenants[0]?.publicId ?? 'T-1001';
            const session = await sevacareApi.verifyOtp({ tenantPublicId, role: activeRole, mobileNumber: loginIdentifier, otp: loginOtp });
            setAuthSession(session);
            // Save session to secure storage
            await AuthService.saveSession(session);
            continueAfterLogin();
          }}
        />
      );
    case 'patientHome':
      return <PatientHomeScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} patientHome={remotePatientHome} doctors={doctorsForHospital} />;
    case 'doctors':
      return (
        <DoctorsScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          hospitalName={selectedHospital.name}
          doctors={doctorsForHospital}
          onSelectDoctor={selectDoctor}
        />
      );
    case 'booking':
      return (
        <BookingScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          doctors={doctorsForHospital}
          bookingName={bookingName}
          onBookingNameChange={setBookingName}
          bookingGender={bookingGender}
          onBookingGenderChange={setBookingGender}
          bookingAge={bookingAge}
          onBookingAgeChange={setBookingAge}
          bookingMobile={bookingMobile}
          onBookingMobileChange={setBookingMobile}
          bookingEmail={bookingEmail}
          onBookingEmailChange={setBookingEmail}
          bookingAddress={bookingAddress}
          onBookingAddressChange={setBookingAddress}
          bookingSpecialty={bookingSpecialty}
          specializationOptions={lookupSpecializations}
          onBookingSpecialtyChange={setBookingSpecialty}
          selectedDoctorId={selectedDoctorId}
          onSelectDoctor={selectDoctor}
          hospitalName={selectedHospital.name}
          slotIntervalMinutes={slotIntervalMinutes}
          bookedSlots={bookedSlots}
          selectedDate={selectedDate}
          onSelectDate={setSelectedDate}
          selectedSlot={selectedSlot}
          onSelectSlot={setSelectedSlot}
          onConfirmBooking={() => {
            if (!authToken || !sessionTenantPublicId || !subjectPublicId) {
              markBookedSlot(selectedSlot);
              return;
            }

            const slotDateTime = selectedDate && selectedSlot ? `${selectedDate} ${selectedSlot}` : selectedSlot;
            void sevacareApi.bookAppointment(sessionTenantPublicId, subjectPublicId, authToken, {
              tenantPublicId: sessionTenantPublicId,
              patientPublicId: subjectPublicId,
              patientName: bookingName || 'Patient',
              gender: bookingGender,
              age: Number.parseInt(bookingAge || '0', 10),
              mobileNumber: bookingMobile || loginIdentifier,
              address: bookingAddress || 'Address not provided',
              specialty: bookingSpecialty,
              doctorPublicId: selectedDoctor?.publicId ?? selectedDoctor?.id ?? '',
              slot: slotDateTime,
            }).then(() => {
              refreshPatientHomeData();
            }).finally(() => markBookedSlot(selectedSlot));
          }}
          availableDates={bookingAvailableDates}
          availableSlots={[...bookingMorningSlots, ...bookingEveningSlots]}
          morningSlots={bookingMorningSlots}
          eveningSlots={bookingEveningSlots}
        />
      );
    case 'confirmation':
      return (
        <ConfirmationScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          doctorName={selectedDoctor?.name ?? 'Doctor'}
          selectedDate={selectedDate}
          selectedSlot={selectedSlot}
        />
      );
    case 'appointments':
      return (
        <AppointmentsScreen
          activeTenant={activeTenant}
          onTenantChange={() => undefined}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          appointments={appointmentsForHospital}
          selectedTab={appointmentTab}
          onTabChange={setAppointmentTab}
          onAppointmentCancelled={refreshPatientHomeData}
        />
      );
    case 'prescription':
      return (
        <PrescriptionListScreen
          activeTenant={activeTenant}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          hospitalName={selectedHospital.name}
          onSelectPrescription={(id) => {
            setSelectedPrescriptionId(id);
            navigate('prescription-detail');
          }}
        />
      );
    case 'prescription-detail':
      return (
        <PrescriptionDetailScreen
          prescriptionId={selectedPrescriptionId ?? ''}
          activeTenant={activeTenant}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          hospitalName={selectedHospital.name}
        />
      );
    case 'prescription-upload':
      return (
        <MedicineUploadScreen
          patientPublicId={doctorSelectedPatientId ?? ''}
          appointmentId={doctorSelectedAppointmentId ?? undefined}
          activeTenant={activeTenant}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          hospitalName={selectedHospital.name}
          onUploadSuccess={() => navigate('prescription')}
        />
      );
    case 'medical-history':
      return (
        <MedicalHistoryScreen
          activeTenant={activeTenant}
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          hospitalName={selectedHospital.name}
        />
      );
    case 'doctorDashboard':
      return <DoctorDashboardScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'consultation':
      return <ConsultationScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'adminDashboard':
      return <AdminDashboardScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'platformAdminDashboard':
      return <PlatformAdminDashboardScreen currentScreen={screen} onNavigate={navigate} />;
    case 'adminUsers':
      return <AdminUsersScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'doctorManagement':
      return <DoctorManagementScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'slotConfig':
      return <AdminDashboardScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'reports':
      return <AdminReportsScreen activeTenant={activeTenant} onTenantChange={() => undefined} currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'profile':
      return <ProfileScreen currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'settings':
      return <SettingsScreen currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'contacts':
      return <ContactsScreen currentScreen={screen} onNavigate={navigate} bottomItems={roleBottomItems} hospitalName={selectedHospital.name} />;
    case 'color-palette':
      return (
        <ColorPaletteScreen
          currentScreen={screen}
          onNavigate={navigate}
          bottomItems={roleBottomItems}
          hospitalName={selectedHospital.name}
          onPaletteSelect={(palette: ColorPalette) => setSelectedColorPalette(palette)}
        />
      );
  }
}