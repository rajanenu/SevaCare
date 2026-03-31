import { useState } from 'react';
import { Platform, StyleSheet, Text, View } from 'react-native';
import { roleDescriptions } from '../demo-data';
import { AppShell, Card, PageHeader, PrimaryButton, SearchField, SecondaryButton, SegmentedControl } from '../components/ui';
import { useTenantConfig, useTheme } from '../providers/theme-provider';
import { type Role, roleLabels, type TenantKey } from '../theme';
import { type AppScreen } from '../types/app';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

export function LoginScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  activeRole,
  onRoleChange,
  hospitalName,
  identifier,
  email,
  otp,
  onIdentifierChange,
  onEmailChange,
  onOtpChange,
  onSendOtp,
  onContinue,
  isPlatformEntry = false,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  activeRole: Role;
  onRoleChange: (role: Role) => void;
  hospitalName: string;
  identifier: string;
  email: string;
  otp: string;
  onIdentifierChange: (value: string) => void;
  onEmailChange: (value: string) => void;
  onOtpChange: (value: string) => void;
  onSendOtp: () => void | Promise<void>;
  onContinue: () => void | Promise<void>;
  isPlatformEntry?: boolean;
}) {
  const theme = useTheme();
  const [otpSent, setOtpSent] = useState(false);
  const [sending, setSending] = useState(false);
  const loginTitle = isPlatformEntry ? 'SevaCare Platform' : hospitalName;
  const loginSubtitle = isPlatformEntry ? 'Platform Admin Login' : 'Login';
  const roleItems = isPlatformEntry
    ? [{ label: 'Platform Admin', value: 'platform_admin' as const }]
    : [
        { label: 'Patient', value: 'patient' as const },
        { label: 'Doctor', value: 'doctor' as const },
        { label: 'Hospital Admin', value: 'admin' as const },
      ];

  const handleSendOtp = async () => {
    setSending(true);
    try {
      await onSendOtp();
      setOtpSent(true);
    } finally {
      setSending(false);
    }
  };

  // Reset OTP sent state when role changes
  const handleRoleChange = (role: Role) => {
    setOtpSent(false);
    onRoleChange(role);
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} hospitalName={hospitalName}>
      <PageHeader title={loginTitle} subtitle={loginSubtitle} />
      <SegmentedControl
        items={roleItems}
        selected={activeRole}
        onChange={handleRoleChange}
      />
      <Card>
        <Text style={[styles.cardTitle, { color: theme.text }]}>{roleLabels[activeRole]} access</Text>
        <Text style={[styles.cardBody, { color: theme.textMuted }]}>{roleDescriptions[activeRole]}</Text>

        {/* Identifier: mobile / employee ID */}
        <SearchField
          value={identifier}
          onChangeText={onIdentifierChange}
          placeholder={activeRole === 'patient' ? 'Mobile number' : activeRole === 'platform_admin' ? 'Platform admin mobile number' : 'Mobile number or employee ID'}
          showIcon={false}
        />

        {/* Email field (all roles) */}
        <SearchField
          value={email}
          onChangeText={onEmailChange}
          placeholder="Email address (optional)"
          showIcon={false}
        />

        {/* OTP sent success banner */}
        {otpSent ? (
          <View style={[styles.otpBanner, { backgroundColor: theme.surfaceMuted, borderColor: theme.primary }]}>
            <Text style={[styles.otpBannerIcon, { color: theme.primary }]}>{'✓'}</Text>
            <Text style={[styles.otpBannerText, { color: theme.primary }]}>
              {activeRole === 'patient' ? 'OTP has been sent to your mobile number' : activeRole === 'platform_admin' ? 'Secure OTP sent for platform access' : 'Secure PIN sent — check your registered number'}
            </Text>
          </View>
        ) : null}

        {/* OTP / PIN input — only shown after OTP is sent */}
        {otpSent ? (
          <SearchField
            value={otp}
            onChangeText={onOtpChange}
            placeholder={activeRole === 'patient' ? 'Enter OTP' : activeRole === 'platform_admin' ? 'Enter platform OTP' : 'Enter secure PIN'}
            showIcon={false}
          />
        ) : null}

        {/* Primary action button */}
        {!otpSent ? (
          <PrimaryButton
            label={sending ? 'Sending…' : 'Send OTP'}
            onPress={() => { void handleSendOtp(); }}
            align="center"
          />
        ) : (
          <PrimaryButton
            label="Continue"
            onPress={onContinue}
            align="center"
          />
        )}

        {/* Allow re-sending */}
        {otpSent ? (
          <SecondaryButton
            label="Resend OTP"
            onPress={() => { setOtpSent(false); }}
            align="center"
          />
        ) : null}
      </Card>
      {isPlatformEntry ? (
        <SecondaryButton label="Back to Features" onPress={() => onNavigate('features')} align="center" />
      ) : (
        <SecondaryButton label="Choose Different Hospital" onPress={() => onNavigate('welcome')} align="center" />
      )}
    </AppShell>
  );
}

const styles = StyleSheet.create({
  cardTitle: {
    fontFamily: FONT,
    fontSize: 16,
    fontWeight: '600',
  },
  cardBody: {
    fontFamily: FONT,
    fontSize: 13,
    lineHeight: 21,
  },
  otpBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    borderWidth: 1.5,
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
  },
  otpBannerIcon: {
    fontSize: 18,
    fontWeight: '700',
  },
  otpBannerText: {
    fontFamily: FONT,
    fontSize: 13,
    fontWeight: '600',
    flex: 1,
  },
});