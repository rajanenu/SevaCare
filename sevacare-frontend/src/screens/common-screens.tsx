import { useEffect, useState } from 'react';
import * as DocumentPicker from 'expo-document-picker';
import { Image, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { sevacareApi } from '../api/client';
import { AppShell, BackButton, Card, DangerButton, InfoRow, PageHeader, PrimaryButton, SecondaryButton } from '../components/ui';
import { useAppStore } from '../store/app-store';
import { useTheme } from '../providers/theme-provider';
import { type TenantKey, roleLabels } from '../theme';
import { roleFirstScreen, type AppScreen, type BottomNavItem } from '../types/app';
import AuthService from '../services/authService';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

export function ProfileScreen({
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
}: {
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems?: BottomNavItem[];
  hospitalName: string;
}) {
  const theme = useTheme();
  const activeRole = useAppStore((s) => s.activeRole);
  const subjectPublicId = useAppStore((s) => s.subjectPublicId);
  const sessionTenantPublicId = useAppStore((s) => s.sessionTenantPublicId);
  const authToken = useAppStore((s) => s.authToken);
  const loginIdentifier = useAppStore((s) => s.loginIdentifier);
  const loginEmail = useAppStore((s) => s.loginEmail);
  const doctorProfilePhotoUri = useAppStore((s) => s.doctorProfilePhotoUri);
  const patientProfilePhotoUri = useAppStore((s) => s.patientProfilePhotoUri);
  const setDoctorProfilePhotoUri = useAppStore((s) => s.setDoctorProfilePhotoUri);
  const setPatientProfilePhotoUri = useAppStore((s) => s.setPatientProfilePhotoUri);
  const homeScreen = roleFirstScreen[activeRole];

  // Editable profile fields (patient only)
  const [profileName, setProfileName] = useState('');
  const [profileAge, setProfileAge] = useState('');
  const [profileAddress, setProfileAddress] = useState('');
  const [profileEmail, setProfileEmail] = useState(loginEmail || '');
  const [profileGender, setProfileGender] = useState('');
  const [doctorSpecialty, setDoctorSpecialty] = useState('');
  const [doctorAboutMe, setDoctorAboutMe] = useState('');
  const [doctorAvailability, setDoctorAvailability] = useState('Available');
  const [doctorFee, setDoctorFee] = useState('₹500');
  const [doctorActive, setDoctorActive] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState('');
  const [loaded, setLoaded] = useState(false);

  // Fetch existing patient profile on mount
  useEffect(() => {
    if (!authToken || !sessionTenantPublicId || !subjectPublicId) return;

    if (activeRole === 'patient') {
      sevacareApi.getPatientRecord(sessionTenantPublicId, subjectPublicId, authToken)
        .then((record) => {
          setProfileName(record.fullName || '');
          setProfileAge(record.age != null ? String(record.age) : '');
          setProfileAddress(record.address || '');
          setProfileEmail(record.email || loginEmail || '');
          setProfileGender(record.gender || '');
          setLoaded(true);
        })
        .catch(() => {
          setProfileName('');
          setProfileAge('');
          setProfileAddress('');
          setProfileEmail(loginEmail || '');
          setProfileGender('');
          setLoaded(true);
        });
      return;
    }

    if (activeRole === 'doctor') {
      sevacareApi.getDoctorRecord(sessionTenantPublicId, subjectPublicId, authToken)
        .then((record) => {
          setProfileName(record.fullName || '');
          setProfileAge(record.age != null ? String(record.age) : '');
          setProfileAddress(record.address || '');
          setDoctorSpecialty(record.specialty || '');
          setDoctorAboutMe(record.aboutMe || '');
          setDoctorAvailability(record.availability || 'Available');
          setDoctorFee(record.fee || '₹500');
          setDoctorActive(record.active ?? true);
          setLoaded(true);
        })
        .catch(() => {
          setProfileName('');
          setProfileAge('');
          setProfileAddress('');
          setDoctorSpecialty('');
          setDoctorAboutMe('');
          setDoctorAvailability('Available');
          setDoctorFee('₹500');
          setDoctorActive(true);
          setLoaded(true);
        });
    }
  }, [activeRole, authToken, sessionTenantPublicId, subjectPublicId, loginEmail]);

  const handleSaveProfile = () => {
    if (!authToken || !sessionTenantPublicId || !subjectPublicId) return;
    setSaving(true);
    setSaveMessage('');
    if (activeRole === 'patient') {
      sevacareApi.upsertPatientRecord(sessionTenantPublicId, subjectPublicId, authToken, {
        fullName: profileName || 'Patient',
        mobileNumber: loginIdentifier,
        status: 'active',
        email: profileEmail || undefined,
        gender: (profileGender as 'male' | 'female' | 'other') || undefined,
        age: profileAge ? Number.parseInt(profileAge, 10) : undefined,
        address: profileAddress || undefined,
      })
        .then(() => setSaveMessage('Profile saved'))
        .catch(() => setSaveMessage('Failed to save'))
        .finally(() => setSaving(false));
      return;
    }

    if (activeRole === 'doctor') {
      sevacareApi.upsertDoctorRecord(sessionTenantPublicId, subjectPublicId, authToken, {
        fullName: profileName || 'Doctor',
        specialty: doctorSpecialty || 'General Physician',
        availability: doctorAvailability || 'Available',
        fee: doctorFee || '₹500',
        active: doctorActive,
        age: profileAge ? Number.parseInt(profileAge, 10) : undefined,
        address: profileAddress || undefined,
        aboutMe: doctorAboutMe || undefined,
      })
        .then(() => setSaveMessage('Profile saved'))
        .catch(() => setSaveMessage('Failed to save'))
        .finally(() => setSaving(false));
    }
  };

  const uploadPhoto = async () => {
    const result = await DocumentPicker.getDocumentAsync({
      type: 'image/*',
      multiple: false,
      copyToCacheDirectory: true,
    });

    if (result.canceled || !result.assets[0]) {
      return;
    }

    if (activeRole === 'doctor') {
      setDoctorProfilePhotoUri(result.assets[0].uri);
      return;
    }

    setPatientProfilePhotoUri(result.assets[0].uri);
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate(homeScreen)} />
      </View>
      <PageHeader title="Profile" />
      <View style={styles.avatarWrap}>
        <View style={[styles.avatar, { backgroundColor: theme.surfaceMuted }]}>
          {activeRole === 'doctor' ? (
            doctorProfilePhotoUri ? (
              <Image source={{ uri: doctorProfilePhotoUri }} style={styles.avatarImage} resizeMode="cover" />
            ) : (
              <Text style={[styles.avatarText, { color: theme.primary }]}>🩺</Text>
            )
          ) : activeRole === 'patient' ? (
            patientProfilePhotoUri ? (
              <Image source={{ uri: patientProfilePhotoUri }} style={styles.avatarImage} resizeMode="cover" />
            ) : (
              <View style={styles.avatarDefaultBg}>
                <Text style={styles.avatarDefaultText}>{(profileName || 'P')[0].toUpperCase()}</Text>
              </View>
            )
          ) : (
            <Text style={[styles.avatarText, { color: theme.primary }]}> 
              {(subjectPublicId ?? 'U')[0].toUpperCase()}
            </Text>
          )}
        </View>
        <Text style={[styles.nameText, { color: theme.text }]}>{profileName || roleLabels[activeRole]}</Text>
        <Text style={[styles.idText, { color: theme.textMuted }]}>{subjectPublicId ?? 'Not logged in'}</Text>
      </View>
      {activeRole === 'doctor' || activeRole === 'patient' ? <SecondaryButton label="Upload Photo" onPress={() => { void uploadPhoto(); }} /> : null}

      {/* Auto-filled read-only info */}
      <Card>
        <InfoRow label="ID" value={subjectPublicId ?? '-'} />
        <View style={styles.divider} />
        <InfoRow label="Hospital" value={hospitalName} />
        <View style={styles.divider} />
        <InfoRow label="Tenant" value={sessionTenantPublicId ?? '-'} />
        <View style={styles.divider} />
        <InfoRow label="Mobile" value={loginIdentifier || '-'} />
        <View style={styles.divider} />
        <InfoRow label="Role" value={roleLabels[activeRole]} />
      </Card>

      {/* Editable profile fields (patient only) */}
      {activeRole === 'patient' && loaded ? (
        <Card>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>Personal details</Text>
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Name</Text>
          <TextInput
            style={[styles.textInput, { color: theme.text, borderColor: theme.border }]}
            value={profileName}
            onChangeText={setProfileName}
            placeholder="Enter your name"
            placeholderTextColor={theme.textMuted}
          />
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Age</Text>
          <TextInput
            style={[styles.textInput, { color: theme.text, borderColor: theme.border }]}
            value={profileAge}
            onChangeText={(v) => setProfileAge(v.replace(/[^0-9]/g, ''))}
            placeholder="Enter your age"
            placeholderTextColor={theme.textMuted}
            keyboardType="numeric"
          />
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Gender</Text>
          <View style={styles.genderRow}>
            {(['male', 'female', 'other'] as const).map((g) => (
              <Pressable
                key={g}
                onPress={() => setProfileGender(g)}
                style={[
                  styles.genderChip,
                  { borderColor: profileGender === g ? '#10B981' : theme.border, backgroundColor: profileGender === g ? '#D1FAE5' : 'transparent' },
                ]}
              >
                <Text style={[styles.genderChipText, { color: profileGender === g ? '#065F46' : theme.text }]}>
                  {g.charAt(0).toUpperCase() + g.slice(1)}
                </Text>
              </Pressable>
            ))}
          </View>
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Email</Text>
          <TextInput
            style={[styles.textInput, { color: theme.text, borderColor: theme.border }]}
            value={profileEmail}
            onChangeText={setProfileEmail}
            placeholder="Email address (optional)"
            placeholderTextColor={theme.textMuted}
            keyboardType="email-address"
            autoCapitalize="none"
          />
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Address</Text>
          <TextInput
            style={[styles.textInput, styles.textInputMultiline, { color: theme.text, borderColor: theme.border }]}
            value={profileAddress}
            onChangeText={setProfileAddress}
            placeholder="Enter your address"
            placeholderTextColor={theme.textMuted}
            multiline
          />
          <View style={styles.saveRow}>
            <PrimaryButton label={saving ? 'Saving...' : 'Save profile'} onPress={handleSaveProfile} />
            {saveMessage ? <Text style={[styles.saveMsg, { color: saveMessage === 'Profile saved' ? '#10B981' : '#EF4444' }]}>{saveMessage}</Text> : null}
          </View>
        </Card>
      ) : null}

      {activeRole === 'doctor' && loaded ? (
        <Card>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>Doctor details</Text>
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Name</Text>
          <TextInput
            style={[styles.textInput, { color: theme.text, borderColor: theme.border }]}
            value={profileName}
            onChangeText={setProfileName}
            placeholder="Enter your name"
            placeholderTextColor={theme.textMuted}
          />
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Age</Text>
          <TextInput
            style={[styles.textInput, { color: theme.text, borderColor: theme.border }]}
            value={profileAge}
            onChangeText={(v) => setProfileAge(v.replace(/[^0-9]/g, ''))}
            placeholder="Enter your age"
            placeholderTextColor={theme.textMuted}
            keyboardType="numeric"
          />
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Specialization</Text>
          <TextInput
            style={[styles.textInput, { color: theme.text, borderColor: theme.border }]}
            value={doctorSpecialty}
            onChangeText={setDoctorSpecialty}
            placeholder="Enter your specialization"
            placeholderTextColor={theme.textMuted}
          />
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>Address</Text>
          <TextInput
            style={[styles.textInput, styles.textInputMultiline, { color: theme.text, borderColor: theme.border }]}
            value={profileAddress}
            onChangeText={setProfileAddress}
            placeholder="Enter your address"
            placeholderTextColor={theme.textMuted}
            multiline
          />
          <Text style={[styles.fieldLabel, { color: theme.textMuted }]}>About me</Text>
          <TextInput
            style={[styles.textInput, styles.textInputMultiline, { color: theme.text, borderColor: theme.border }]}
            value={doctorAboutMe}
            onChangeText={setDoctorAboutMe}
            placeholder="Tell patients about your experience"
            placeholderTextColor={theme.textMuted}
            multiline
          />
          <View style={styles.saveRow}>
            <PrimaryButton label={saving ? 'Saving...' : 'Save profile'} onPress={handleSaveProfile} />
            {saveMessage ? <Text style={[styles.saveMsg, { color: saveMessage === 'Profile saved' ? '#10B981' : '#EF4444' }]}>{saveMessage}</Text> : null}
          </View>
        </Card>
      ) : null}

      <View style={styles.buttonRow}>
        <SecondaryButton label="Settings" onPress={() => onNavigate('settings')} />
        <SecondaryButton label="Contact us" onPress={() => onNavigate('contacts')} />
      </View>
      <DangerButton
        label="Sign Out"
        onPress={async () => {
          useAppStore.getState().clearAuthSession();
          await AuthService.clearSession();
          onNavigate('welcome');
        }}
        filled
      />
    </AppShell>
  );
}

export function SettingsScreen({
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
}: {
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems?: BottomNavItem[];
  hospitalName: string;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('profile')} />
      </View>
      <PageHeader title="Settings" />
      <Card>
        <SettingsRow label="Notifications" value="Enabled" theme={theme} />
        <View style={styles.divider} />
        <SettingsRow label="Language" value="English" theme={theme} />
        <View style={styles.divider} />
        <SettingsRow label="App version" value="1.0.0" theme={theme} />
        <View style={styles.divider} />
        <SettingsRow label="Data usage" value="Wi-Fi only" theme={theme} />
      </Card>
      <Card>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>Appearance</Text>
        <SecondaryButton label="🎨 Choose Button Colors" onPress={() => onNavigate('color-palette')} />
      </Card>
      <Card>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>Privacy</Text>
        <SettingsRow label="Share analytics" value="Off" theme={theme} />
        <View style={styles.divider} />
        <SettingsRow label="Location access" value="When in use" theme={theme} />
      </Card>
    </AppShell>
  );
}

export function ContactsScreen({
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
}: {
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems?: BottomNavItem[];
  hospitalName: string;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('profile')} />
      </View>
      <PageHeader title="Contact us" />
      <Card>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>Support</Text>
        <InfoRow label="Email" value="support@sevacare.in" />
        <View style={styles.divider} />
        <InfoRow label="Phone" value="+91 800 000 1234" />
        <View style={styles.divider} />
        <InfoRow label="Hours" value="Mon-Sat, 9 AM - 6 PM" />
      </Card>
      <Card>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>Hospital desk</Text>
        <Text style={[styles.bodyText, { color: theme.textMuted }]}>
          For appointment queries or billing issues, contact the hospital front desk directly.
        </Text>
        <InfoRow label="Hospital" value={hospitalName} />
      </Card>
      <Card>
        <Text style={[styles.sectionTitle, { color: theme.text }]}>About SevaCare</Text>
        <Text style={[styles.bodyText, { color: theme.textMuted }]}>
          SevaCare is a multi-tenant healthcare platform connecting patients, doctors, and hospital administrators on a single, easy-to-use system.
        </Text>
      </Card>
    </AppShell>
  );
}

function SettingsRow({ label, value, theme }: { label: string; value: string; theme: ReturnType<typeof useTheme> }) {
  return (
    <Pressable style={styles.settingsRow}>
      <Text style={[styles.settingsLabel, { color: theme.text }]}>{label}</Text>
      <Text style={[styles.settingsValue, { color: theme.textMuted }]}>{value}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  backRow: {
    flexDirection: 'row',
  },
  avatarWrap: {
    alignItems: 'center',
    gap: 8,
    paddingVertical: 8,
  },
  avatar: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  avatarImage: {
    width: 72,
    height: 72,
  },
  avatarText: {
    fontFamily: FONT,
    fontSize: 28,
    fontWeight: '700',
  },
  avatarDefaultBg: {
    width: 72,
    height: 72,
    borderRadius: 36,
    backgroundColor: '#2563EB',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarDefaultText: {
    fontFamily: FONT,
    fontSize: 30,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  nameText: {
    fontFamily: FONT,
    fontSize: 16,
    fontWeight: '700',
  },
  idText: {
    fontFamily: FONT,
    fontSize: 12,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
  },
  divider: {
    height: 1,
    backgroundColor: '#F1F5F9',
  },
  sectionTitle: {
    fontFamily: FONT,
    fontSize: 14,
    fontWeight: '700',
  },
  bodyText: {
    fontFamily: FONT,
    fontSize: 12,
    lineHeight: 18,
  },
  settingsRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 10,
  },
  settingsLabel: {
    fontFamily: FONT,
    fontSize: 13,
    fontWeight: '500',
  },
  settingsValue: {
    fontFamily: FONT,
    fontSize: 12,
  },
  fieldLabel: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '500',
    marginTop: 10,
    marginBottom: 4,
  },
  textInput: {
    fontFamily: FONT,
    fontSize: 14,
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  textInputMultiline: {
    minHeight: 60,
    textAlignVertical: 'top',
  },
  genderRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 2,
  },
  genderChip: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 6,
  },
  genderChipText: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '500',
  },
  saveRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginTop: 12,
  },
  saveMsg: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '500',
  },
});
