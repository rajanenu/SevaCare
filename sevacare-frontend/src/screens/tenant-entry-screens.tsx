import { useState } from 'react';
import { ActivityIndicator, Image, Platform, Pressable, StyleSheet, Text, View, Modal, Alert } from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import { type Hospital } from '../demo-data';
import { useTenantConfig, useTheme } from '../providers/theme-provider';
import { AppShell, BackButton, Card, DropdownSelect, OptionCard, PageHeader, PrimaryButton, SearchField, SecondaryButton, DangerButton } from '../components/ui';
import { type TenantOnboardingUploadFile } from '../api/types';
import { type AppScreen, type PermissionState } from '../types/app';
import { type TenantKey, tenantThemes } from '../theme';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

const STATE_OPTIONS = ['Telangana', 'Andhra Pradesh', 'Karnataka', 'Tamil Nadu', 'Maharashtra'];
const CITY_OPTIONS: Record<string, string[]> = {
  Telangana: ['Hyderabad', 'Warangal', 'Karimnagar', 'Nizamabad', 'Khammam'],
  'Andhra Pradesh': ['Vijayawada', 'Visakhapatnam', 'Tirupati', 'Kurnool', 'Guntur'],
  Karnataka: ['Bengaluru', 'Mysuru', 'Mangaluru', 'Hubli', 'Belagavi'],
  'Tamil Nadu': ['Chennai', 'Coimbatore', 'Madurai', 'Salem', 'Trichy'],
  Maharashtra: ['Mumbai', 'Pune', 'Nagpur', 'Nashik', 'Aurangabad'],
};

export function WelcomeScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  onOpenSearch,
  onOpenNearby,
  onOpenScanner,
  onOpenSaved,
  onOpenOnboarding,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  onOpenSearch: () => void;
  onOpenNearby: () => void;
  onOpenScanner: () => void;
  onOpenSaved: () => void;
  onOpenOnboarding: () => void;
}) {
  const config = useTenantConfig();
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate}>
      <View style={[styles.heroBanner, { backgroundColor: theme.surfaceMuted, borderColor: theme.border }]}> 
        <View style={[styles.heroCanvas, { backgroundColor: '#FFFFFF', borderColor: theme.border }]}> 
          <Image source={require('../../assets/AI_Image_Landing_Screen.jpg')} style={styles.heroImage} resizeMode="cover" />
        </View>
      </View>

      <View style={styles.grid}>
        {config.featureFlags.entrySearch ? <OptionCard title="Search Hospitals" icon="🔍" iconColor="#2563EB" hoverHighlight onPress={onOpenSearch} /> : null}
        <OptionCard title="Onboard Your Hospital" icon="+" iconColor="#2563EB" hoverHighlight onPress={onOpenOnboarding} />
        {config.featureFlags.entryNearby ? <OptionCard title={config.copy.entryLabels.nearby} icon="⌖" disabled onPress={onOpenNearby} /> : null}
        {config.featureFlags.entryScanQr ? <OptionCard title={config.copy.entryLabels.scanQr} icon="▣" disabled onPress={onOpenScanner} /> : null}
        {config.featureFlags.entrySavedHospitals ? <OptionCard title={config.copy.entryLabels.saved} icon="★" disabled onPress={onOpenSaved} /> : null}
      </View>
    </AppShell>
  );
}

export function FeaturesScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  onOpenPlatformAdmin,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  onOpenPlatformAdmin: () => void;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('welcome')} />
      </View>
      <PageHeader title="SevaCare features" subtitle="A complete healthcare platform" />
      <Card>
        <Text style={[styles.cardTitle, { color: theme.text }]}>For patients</Text>
        <FeatureItem text="Search hospitals by city and specialty" theme={theme} />
        <FeatureItem text="Book appointments and track history" theme={theme} />
        <FeatureItem text="Digital prescriptions and follow-ups" theme={theme} />
      </Card>
      <Card>
        <Text style={[styles.cardTitle, { color: theme.text }]}>For hospitals</Text>
        <FeatureItem text="Multi-tenant for hospitals and clinics" theme={theme} />
        <FeatureItem text="Role-based doctor, admin, patient access" theme={theme} />
        <FeatureItem text="Slot-based operations to reduce wait" theme={theme} />
      </Card>
      <Card>
        <Text style={[styles.cardTitle, { color: theme.text }]}>Platform operations</Text>
        <Text style={[styles.cardBody, { color: theme.textMuted }]}>Open the platform console for tenant visibility, onboarding review, and system-wide administration.</Text>
        <PrimaryButton label="Platform admin sign in" onPress={onOpenPlatformAdmin} align="flex-start" />
      </Card>
    </AppShell>
  );
}

export function OnboardingScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  onSubmit,
  isLoading = false,
  successMessage,
  errorMessage,
  onSuccessClose,
  onErrorClose,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  onSubmit: (payload: {
    hospitalName: string;
    licenseNumber: string;
    address: string;
    city: string;
    state: string;
    country: string;
    contactName: string;
    contactMobile: string;
    contactEmail: string;
    supportingDocs: string;
    supportingFiles: TenantOnboardingUploadFile[];
    facilityType: 'hospital' | 'clinic';
  }) => void;
  isLoading?: boolean;
  successMessage?: { requestId: string };
  errorMessage?: string;
  onSuccessClose?: () => void;
  onErrorClose?: () => void;
}) {
  const theme = useTheme();
  const [hospitalName, setHospitalName] = useState('');
  const [licenseNumber, setLicenseNumber] = useState('');
  const [address, setAddress] = useState('');
  const [state, setState] = useState('Telangana');
  const [city, setCity] = useState('Hyderabad');
  const [pinCode, setPinCode] = useState('500001');
  const [country, setCountry] = useState('India');
  const [contactName, setContactName] = useState('');
  const [contactMobile, setContactMobile] = useState('');
  const [contactEmail, setContactEmail] = useState('');
  const [supportingFiles, setSupportingFiles] = useState<TenantOnboardingUploadFile[]>([]);
  const [validationError, setValidationError] = useState<string | null>(null);

  const supportingDocs = supportingFiles.map((file) => file.name).join(', ');

  const handlePickFiles = async () => {
    const result = await DocumentPicker.getDocumentAsync({
      multiple: true,
      copyToCacheDirectory: true,
    });

    if (result.canceled) {
      return;
    }

    setSupportingFiles((current) => {
      const next = [...current];
      for (const asset of result.assets) {
        next.push({
          uri: asset.uri,
          name: asset.name,
          mimeType: asset.mimeType ?? undefined,
          size: asset.size ?? undefined,
          file: asset.file as Blob | undefined,
        });
      }
      return next;
    });
  };

  const handleClearFiles = () => setSupportingFiles([]);

  const validateAndSubmit = () => {
    if (!hospitalName.trim()) { setValidationError('Hospital name is required'); return; }
    if (!licenseNumber.trim()) { setValidationError('License number is required'); return; }
    if (!address.trim()) { setValidationError('Address is required'); return; }
    if (!contactName.trim()) { setValidationError('Contact name is required'); return; }
    if (!contactMobile.trim()) { setValidationError('Contact mobile is required'); return; }
    if (!contactEmail.trim()) { setValidationError('Contact email is required'); return; }
    setValidationError(null);
    onSubmit({
      hospitalName,
      licenseNumber,
      address: `${address}, ${city}, ${state} - ${pinCode}`,
      city,
      state,
      country,
      contactName,
      contactMobile,
      contactEmail,
      supportingDocs,
      supportingFiles,
      facilityType: activeTenant === 'premium' ? 'hospital' : 'clinic',
    });
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('welcome')} />
      </View>
      <PageHeader title="Tenant onboarding" subtitle="Connect your hospital to SevaCare" />
      {validationError ? (
        <View style={[styles.errorBanner]}>
          <Text style={styles.errorText}>{'⚠ '}{validationError}</Text>
        </View>
      ) : null}
      <Card>
        <Text style={[styles.cardTitle, { color: theme.text }]}>Hospital details</Text>
        <SearchField value={hospitalName} onChangeText={setHospitalName} placeholder="Hospital name" showIcon={false} />
        <SearchField value={licenseNumber} onChangeText={setLicenseNumber} placeholder="License number" showIcon={false} />
        <SearchField value={address} onChangeText={setAddress} placeholder="Address" showIcon={false} />
        <DropdownSelect
          label="State"
          value={state}
          options={STATE_OPTIONS.map((item) => ({ label: item, value: item }))}
          onChange={(value) => {
            const nextState = String(value);
            setState(nextState);
            const nextCity = CITY_OPTIONS[nextState]?.[0] ?? '';
            setCity(nextCity);
          }}
        />
        <DropdownSelect
          label="City"
          value={city}
          options={(CITY_OPTIONS[state] ?? []).map((item) => ({ label: item, value: item }))}
          onChange={(value) => setCity(String(value))}
        />
        <SearchField value={pinCode} onChangeText={(value) => setPinCode(value.replace(/[^0-9]/g, '').slice(0, 6))} placeholder="Pin Code" showIcon={false} />
        <SearchField value={country} onChangeText={setCountry} placeholder="Country" showIcon={false} />
      </Card>
      <Card>
        <Text style={[styles.cardTitle, { color: theme.text }]}>Contact and docs</Text>
        <SearchField value={contactName} onChangeText={setContactName} placeholder="Contact name" showIcon={false} />
        <SearchField value={contactMobile} onChangeText={setContactMobile} placeholder="Contact mobile" showIcon={false} />
        <SearchField value={contactEmail} onChangeText={setContactEmail} placeholder="Contact email" showIcon={false} />
        <View style={styles.buttonRow}>
          <DangerButton label="⬆ Certificates To Upload" onPress={() => void handlePickFiles()} />
          <SecondaryButton label="Clear files" onPress={handleClearFiles} />
        </View>
        <Text style={[styles.cardBody, { color: theme.textMuted }]}>
          {supportingFiles.length > 0 ? `Selected: ${supportingDocs}` : 'No supporting files selected'}
        </Text>
      </Card>
      <View style={styles.onboardButtonWrap}>
        {isLoading ? (
          <View style={[styles.buttonContainer, { gap: 12 }]}>
            <ActivityIndicator size="large" color={theme.primary} />
            <Text style={[styles.loadingText, { color: theme.textMuted }]}>Submitting your onboarding request...</Text>
          </View>
        ) : (
          <PrimaryButton
            label="On Board"
            onPress={validateAndSubmit}
          />
        )}
      </View>

      {/* Success Modal */}
      <Modal
        visible={!!successMessage}
        transparent
        animationType="fade"
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
            <Text style={[styles.modalIcon, { fontSize: 48 }]}>✅</Text>
            <Text style={[styles.modalTitle, { color: theme.text }]}>Hospital Onboarded Successfully!</Text>
            <Text style={[styles.modalMessage, { color: theme.textMuted }]}>
              Your hospital onboarding request has been submitted successfully.
            </Text>
            <View style={styles.confirmationBox}>
              <Text style={[styles.confirmLabel, { color: theme.textMuted }]}>Request ID:</Text>
              <Text style={[styles.confirmValue, { color: theme.primary }]}>{successMessage?.requestId}</Text>
            </View>
            <Text style={[styles.modalSubtext, { color: theme.textMuted }]}>
              Our team will review your request and contact you shortly.
            </Text>
            <PrimaryButton
              label="Continue"
              onPress={onSuccessClose ?? (() => undefined)}
            />
          </View>
        </View>
      </Modal>

      {/* Error Modal */}
      <Modal
        visible={!!errorMessage}
        transparent
        animationType="fade"
      >
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { backgroundColor: theme.surface }]}>
            <Text style={[styles.modalIcon, { fontSize: 48 }]}>❌</Text>
            <Text style={[styles.modalTitle, { color: theme.text }]}>Onboarding Failed</Text>
            <Text style={[styles.modalMessage, { color: theme.danger }]}> 
              {errorMessage}
            </Text>
            <PrimaryButton
              label="Try Again"
              onPress={onErrorClose ?? (() => undefined)}
            />
          </View>
        </View>
      </Modal>
    </AppShell>
  );
}

export function SearchResultsScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  query,
  onQueryChange,
  hospitals,
  onSelectHospital,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  query: string;
  onQueryChange: (value: string) => void;
  hospitals: Hospital[];
  onSelectHospital: (hospitalId: string) => void;
}) {
  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('welcome')} />
      </View>
      <PageHeader title="Search Hospitals" />
      <SearchField value={query} onChangeText={onQueryChange} placeholder="Type hospital, city, specialty" />
      <View style={styles.stackGap}>
        {hospitals.map((hospital) => (
          <View key={hospital.id} style={styles.floatingCardWrap}>
            <HospitalCard hospital={hospital} onSelectHospital={onSelectHospital} />
          </View>
        ))}
      </View>
    </AppShell>
  );
}

export function NearbyHospitalsScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  locationAccess,
  hospitals,
  onSelectHospital,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  locationAccess: PermissionState;
  hospitals: Hospital[];
  onSelectHospital: (hospitalId: string) => void;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('welcome')} />
      </View>
      <PageHeader title="Nearby hospitals" subtitle={`Location access: ${locationAccess}`} />
      <View style={styles.stackGap}>
        {hospitals.map((hospital) => (
          <HospitalCard key={hospital.id} hospital={hospital} onSelectHospital={onSelectHospital} />
        ))}
      </View>
    </AppShell>
  );
}

export function ScannerScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  cameraAccess,
  onSimulateSuccess,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  cameraAccess: PermissionState;
  onSimulateSuccess: () => void;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} compact>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('welcome')} />
      </View>
      <PageHeader title="Scan QR" subtitle={`Camera access: ${cameraAccess}`} />
      <Card>
        <View style={[styles.scannerFrame, { borderColor: theme.primary }]} />
      </Card>
      <View style={styles.buttonRow}>
        <SecondaryButton label="Simulate QR success" onPress={onSimulateSuccess} />
      </View>
    </AppShell>
  );
}

export function SavedHospitalsScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  hospitals,
  onSelectHospital,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  hospitals: Hospital[];
  onSelectHospital: (hospitalId: string) => void;
}) {
  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('welcome')} />
      </View>
      <PageHeader title="Saved hospitals" />
      <View style={styles.stackGap}>
        {hospitals.map((hospital) => (
          <HospitalCard key={hospital.id} hospital={hospital} onSelectHospital={onSelectHospital} />
        ))}
      </View>
    </AppShell>
  );
}

export function TenantLoadingScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  hospitalName,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  hospitalName: string;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} compact hospitalName={hospitalName}>
      <View style={styles.loadingWrap}>
        <ActivityIndicator size="large" color={theme.primary} />
        <Text style={[styles.loadingText, { color: theme.text }]}>{`Loading ${hospitalName}`}</Text>
      </View>
    </AppShell>
  );
}

function FeatureItem({ text, theme }: { text: string; theme: ReturnType<typeof useTheme> }) {
  return (
    <View style={styles.featureRow}>
      <Text style={{ color: theme.primary, fontSize: 12 }}>{'\u2713'}</Text>
      <Text style={[styles.cardBody, { color: theme.textMuted }]}>{text}</Text>
    </View>
  );
}

function HospitalCard({ hospital, onSelectHospital }: { hospital: Hospital; onSelectHospital: (hospitalId: string) => void }) {
  const theme = useTheme();

  return (
    <Pressable onPress={() => onSelectHospital(hospital.id)}>
      <Card>
        <View style={styles.rowBetween}>
          <View style={styles.flexOne}>
            <Text style={[styles.cardTitle, { color: theme.text }]}>{hospital.name}</Text>
            <Text style={[styles.cardBody, { color: theme.textMuted }]}>{hospital.city} {'\u00B7'} {hospital.specialty}</Text>
          </View>
          <View style={[styles.distBadge, { backgroundColor: theme.surfaceMuted }]}>
            <Text style={[styles.distText, { color: theme.primary }]}>{hospital.distance}</Text>
          </View>
        </View>
      </Card>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  stackGap: {
    gap: 12,
  },
  floatingCardWrap: {
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.12,
    shadowRadius: 12,
    elevation: 6,
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
  },
  buttonRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  backRow: {
    flexDirection: 'row',
    marginBottom: 4,
  },
  onboardButtonWrap: {
    alignItems: 'center',
    marginTop: 8,
  },
  errorBanner: {
    backgroundColor: '#FEF2F2',
    borderLeftWidth: 4,
    borderLeftColor: '#DC2626',
    borderRadius: 8,
    padding: 12,
  },
  errorText: {
    fontFamily: FONT,
    fontSize: 13,
    color: '#DC2626',
    fontWeight: '600',
  },
  heroBanner: {
    borderRadius: 14,
    borderWidth: 1,
    padding: 20,
    alignItems: 'center',
    overflow: 'hidden',
  },
  heroCanvas: {
    width: '100%',
    borderWidth: 1,
    borderRadius: 18,
    padding: 18,
    gap: 0,
  },
  heroImage: {
    width: '100%',
    height: 260,
    borderRadius: 14,
  },
  scannerFrame: {
    width: 200,
    height: 200,
    borderWidth: 2,
    borderRadius: 20,
    borderStyle: 'dashed',
    alignSelf: 'center',
  },
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 10,
  },
  flexOne: {
    flex: 1,
  },
  cardTitle: {
    fontFamily: FONT,
    fontSize: 14,
    fontWeight: '600',
  },
  cardBody: {
    fontFamily: FONT,
    fontSize: 12,
    lineHeight: 18,
  },
  distBadge: {
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  distText: {
    fontFamily: FONT,
    fontSize: 11,
    fontWeight: '600',
  },
  loadingWrap: {
    alignItems: 'center',
    gap: 16,
    paddingVertical: 40,
  },
  loadingText: {
    fontFamily: FONT,
    fontSize: 14,
    fontWeight: '600',
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
    paddingVertical: 2,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 16,
  },
  modalContent: {
    borderRadius: 16,
    padding: 28,
    maxWidth: 400,
    alignItems: 'center',
    gap: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.2,
    shadowRadius: 16,
    elevation: 8,
  },
  modalIcon: {
    marginBottom: 8,
  },
  modalTitle: {
    fontFamily: FONT,
    fontSize: 18,
    fontWeight: '700',
    textAlign: 'center',
  },
  modalMessage: {
    fontFamily: FONT,
    fontSize: 14,
    lineHeight: 20,
    textAlign: 'center',
  },
  confirmationBox: {
    backgroundColor: 'rgba(0, 0, 0, 0.02)',
    borderRadius: 12,
    padding: 14,
    width: '100%',
    gap: 6,
    marginVertical: 8,
  },
  confirmLabel: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
  },
  confirmValue: {
    fontFamily: FONT,
    fontSize: 14,
    fontWeight: '700',
    textAlign: 'center',
  },
  modalSubtext: {
    fontFamily: FONT,
    fontSize: 12,
    lineHeight: 18,
    textAlign: 'center',
  },
  buttonContainer: {
    alignItems: 'center',
  },
});
