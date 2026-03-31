import { type ReactNode, useEffect, useRef, useState } from 'react';
import {
  Animated,
  Image,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useTenantConfig, useTheme } from '../providers/theme-provider';
import { type AppScreen, type BottomNavItem } from '../types/app';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

const shadow = (theme: ReturnType<typeof useTheme>): ViewStyle => ({
  shadowColor: theme.shadowColor,
  shadowOffset: { width: 0, height: 8 },
  shadowOpacity: 0.12,
  shadowRadius: 16,
  elevation: 4,
});

export function AppShell({
  children,
  compact = false,
  currentScreen,
  bottomItems = [],
  onNavigate,
  hospitalName,
}: {
  children: ReactNode;
  compact?: boolean;
  currentScreen: AppScreen;
  bottomItems?: BottomNavItem[];
  onNavigate: (screen: AppScreen) => void;
  hospitalName?: string;
}) {
  const theme = useTheme();
  const config = useTenantConfig();
  const showLandingBrand = currentScreen === 'welcome';

  return (
    <View style={[styles.screen, { backgroundColor: theme.screenGradient[0] }]}>
      <SafeAreaView style={styles.safeArea}>
        <ScrollView contentContainerStyle={[styles.content, compact && styles.contentCompact]} showsVerticalScrollIndicator={false}>
          <View style={[styles.topBar, shadow(theme), { backgroundColor: theme.headerSurface, borderColor: theme.border, borderRadius: theme.radius + 8 }]}> 
            <View style={styles.brandBlock}>
              <View style={styles.brandRow}>
                <Image source={require('../../assets/icon.png')} style={styles.topBarLogo} resizeMode="contain" />
                <Text style={[styles.brandText, { color: theme.primary }]}>{config.copy.landingBrand}</Text>
              </View>
              <Text style={[styles.brandSubline, { color: theme.primaryStrong }]}> 
                {showLandingBrand ? config.copy.landingSubline : hospitalName ?? config.copy.landingSubline}
              </Text>
            </View>
            {currentScreen === 'welcome' || currentScreen === 'search' ? (
              <Pressable onPress={() => onNavigate('features')} style={[styles.featuresAction, { backgroundColor: theme.secondaryAccent, borderRadius: 999, borderColor: theme.primaryStrong }]}> 
                <Text style={[styles.featuresActionText, { color: theme.buttonText }]}>✦ Features</Text>
              </Pressable>
            ) : null}
          </View>
          {children}
          {showLandingBrand ? (
            <View style={[styles.footerWrap, { backgroundColor: theme.footerSurface, borderColor: theme.border, borderRadius: theme.radius + 8 }]}>
              <Text style={[styles.footerText, { color: theme.primaryStrong }]}> 
                {'🛡 '}Managed by <Text style={[styles.footerBrand, { color: theme.primary }]}>{config.copy.landingBrand}</Text> companies an org.
              </Text>
            </View>
          ) : null}
        </ScrollView>
        {bottomItems.length > 0 ? <BottomNav items={bottomItems} currentScreen={currentScreen} onNavigate={onNavigate} /> : null}
      </SafeAreaView>
    </View>
  );
}

export function PageHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  const theme = useTheme();

  return (
    <View style={styles.headerBlock}>
      <Text style={[styles.title, { color: theme.primary }]}>{title}</Text>
      {subtitle ? <Text style={[styles.subtitle, { color: theme.primaryStrong }]}>{subtitle}</Text> : null}
    </View>
  );
}

export function BackButton({ onPress }: { onPress: () => void }) {
  const theme = useTheme();

  return (
    <Pressable onPress={onPress} accessibilityLabel="Back" style={({ pressed }) => [styles.backButton, { opacity: pressed ? 0.7 : 1, borderColor: theme.border, backgroundColor: theme.surfaceMuted }]}> 
      <Text style={[styles.backButtonIcon, { color: theme.primary }]}>{'←'}</Text>
    </Pressable>
  );
}

export function SearchField({
  value,
  onChangeText,
  placeholder,
  showIcon = true,
}: {
  value: string;
  onChangeText: (value: string) => void;
  placeholder: string;
  showIcon?: boolean;
}) {
  const theme = useTheme();

  return (
    <View
      style={[
        styles.inputWrap,
        {
          backgroundColor: theme.surface,
          borderColor: theme.border,
          borderRadius: theme.radius,
        },
      ]}
    >
      {showIcon ? <Text style={[styles.searchIcon, { color: theme.primary }]}>🔍</Text> : null}
      <TextInput
        value={value}
        onChangeText={onChangeText}
        placeholder={placeholder}
        placeholderTextColor={theme.textMuted}
        style={[
          styles.input,
          {
            color: theme.text,
          },
        ]}
      />
    </View>
  );
}

export function PrimaryButton({
  label,
  onPress,
  wide = false,
  align = 'center' as const,
}: {
  label: string;
  onPress: () => void;
  wide?: boolean;
  align?: 'flex-start' | 'center' | 'flex-end';
}) {
  const theme = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        { opacity: pressed ? 0.92 : 1 },
        wide ? styles.fullWidth : { alignSelf: align },
      ]}
    >
      <View
        style={[
          styles.primaryButton,
          {
            backgroundColor: theme.primary,
            borderRadius: 999,
            borderColor: theme.primaryStrong,
            shadowColor: theme.primaryStrong,
            shadowOffset: { width: 0, height: 8 },
            shadowOpacity: 0.28,
            shadowRadius: 14,
            elevation: 6,
          },
        ]}
      >
        <View style={styles.primaryButtonGloss}>
          <View style={[styles.primaryButtonGlossBand, { backgroundColor: 'rgba(255,255,255,0.33)' }]} />
        </View>
        <Text style={[styles.primaryButtonText, { color: theme.buttonText }]}>{label}</Text>
      </View>
    </Pressable>
  );
}

export function SecondaryButton({
  label,
  onPress,
  wide = false,
  align = 'center' as const,
}: {
  label: string;
  onPress: () => void;
  wide?: boolean;
  align?: 'flex-start' | 'center' | 'flex-end';
}) {
  const theme = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        wide ? styles.fullWidth : { alignSelf: align },
        {
          backgroundColor: theme.primary,
          borderColor: theme.primaryStrong,
          borderRadius: 999,
          opacity: pressed ? 0.92 : 1,
          shadowColor: theme.primaryStrong,
          shadowOffset: { width: 0, height: 8 },
          shadowOpacity: 0.24,
          shadowRadius: 12,
          elevation: 5,
        },
      ]}
    >
      <View style={styles.secondaryButton}>
        <View style={styles.primaryButtonGloss}>
          <View style={[styles.primaryButtonGlossBand, { backgroundColor: 'rgba(255,255,255,0.3)' }]} />
        </View>
        <Text style={[styles.secondaryButtonText, { color: theme.buttonText }]}>{label}</Text>
      </View>
    </Pressable>
  );
}

export function Card({ children }: { children: ReactNode }) {
  const theme = useTheme();

  return <View style={[styles.card, shadow(theme), { backgroundColor: theme.card, borderColor: theme.border, borderRadius: theme.radius }]}>{children}</View>;
}

export function OptionCard({ title, icon, onPress, disabled = false, highlighted = false, hoverHighlight = false, iconColor }: { title: string; icon: string; onPress: () => void; disabled?: boolean; highlighted?: boolean; hoverHighlight?: boolean; iconColor?: string }) {
  const theme = useTheme();
  const [hovered, setHovered] = useState(false);
  const activeHighlight = highlighted || (hoverHighlight && hovered);

  return (
    <Pressable
      onPress={disabled ? undefined : onPress}
      onHoverIn={() => setHovered(true)}
      onHoverOut={() => setHovered(false)}
      style={({ pressed }) => [
        styles.optionCard,
        shadow(theme),
        {
          backgroundColor: activeHighlight ? theme.footerSurface : theme.card,
          borderColor: activeHighlight ? theme.secondaryAccent : theme.border,
          borderRadius: theme.radius,
          opacity: disabled ? 0.65 : pressed ? 0.97 : 1,
        },
      ]}
    >
      <Text style={[styles.optionIcon, { color: iconColor ?? theme.secondaryAccent }]}>{icon}</Text>
      <Text style={[styles.optionTitle, { color: theme.text }]}>{title}</Text>
      {disabled ? <Text style={[styles.optionHint, { color: theme.textMuted }]}>Read only</Text> : null}
    </Pressable>
  );
}

export function Chip({ label, active = false, onPress }: { label: string; active?: boolean; onPress?: () => void }) {
  const theme = useTheme();
  const content = (
    <Text
      style={[
        styles.chipText,
        {
          backgroundColor: active ? theme.primary : theme.footerSurface,
          borderColor: active ? theme.primary : theme.footerSurface,
          color: active ? theme.buttonText : theme.text,
          borderRadius: 999,
        },
      ]}
    >
      {label}
    </Text>
  );

  if (!onPress) {
    return content;
  }

  return <Pressable onPress={onPress}>{content}</Pressable>;
}

export function SegmentedControl<T extends string>({
  items,
  selected,
  onChange,
}: {
  items: { label: string; value: T }[];
  selected: T;
  onChange: (value: T) => void;
}) {
  const theme = useTheme();

  return (
    <View style={[styles.segmented, { backgroundColor: theme.surface, borderColor: theme.border, borderRadius: theme.radius }]}> 
      {items.map((item) => {
        const active = item.value === selected;
        return (
          <Pressable
            key={item.value}
            onPress={() => onChange(item.value)}
            style={[
              styles.segment,
              {
                backgroundColor: active ? theme.primary : 'transparent',
                borderRadius: 999,
              },
            ]}
          >
            <Text style={[styles.segmentText, { color: active ? theme.buttonText : theme.textMuted }]}>{item.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

export function MetricTile({ value, label, trend, interactive = false }: { value: string; label: string; trend?: string; interactive?: boolean }) {
  const theme = useTheme();
  const [hovered, setHovered] = useState(false);

  return (
    <Pressable
      onHoverIn={() => setHovered(true)}
      onHoverOut={() => setHovered(false)}
      style={[
        styles.metricTile,
        shadow(theme),
        {
          backgroundColor: interactive && hovered ? theme.footerSurface : theme.card,
          borderColor: interactive && hovered ? theme.primaryStrong : theme.border,
          borderRadius: theme.radius,
          transform: [{ scale: interactive && hovered ? 1.03 : 1 }],
        },
      ]}
    >
      <Text style={[styles.metricValue, { color: interactive && hovered ? theme.primaryStrong : theme.text }]}>{value}</Text>
      <Text style={[styles.metricLabel, { color: interactive && hovered ? theme.text : theme.textMuted }]}>{label}</Text>
      {trend ? <Text style={[styles.trendText, { color: theme.primaryStrong }]}>{trend}</Text> : null}
    </Pressable>
  );
}

export function DropdownSelect({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: { label: string; value: string }[];
  onChange: (value: string) => void;
}) {
  const theme = useTheme();
  const [open, setOpen] = useState(false);
  const selected = options.find((o) => o.value === value);

  return (
    <View style={styles.dropdownWrap}>
      <Text style={[styles.dropdownLabel, { color: theme.text }]}>{label}</Text>
      <Pressable
        testID={`dropdown-${label}`}
        onPress={() => setOpen(!open)}
        style={[styles.dropdownTrigger, { borderColor: theme.border, backgroundColor: theme.surface, borderRadius: theme.radius }]}
      >
        <Text style={[styles.dropdownTriggerText, { color: selected ? theme.text : theme.textMuted }]}>
          {selected?.label ?? 'Select...'}
        </Text>
        <Text style={{ color: theme.textMuted, fontSize: 10 }}>{open ? '\u25B2' : '\u25BC'}</Text>
      </Pressable>
      {open ? (
        <View style={[styles.dropdownMenu, shadow(theme), { borderColor: theme.border, backgroundColor: theme.card, borderRadius: theme.radius }]}>
          <ScrollView style={styles.dropdownScroll} nestedScrollEnabled>
            {options.map((option) => (
              <Pressable
                key={option.value}
                onPress={() => { onChange(option.value); setOpen(false); }}
                style={[styles.dropdownItem, option.value === value && { backgroundColor: theme.surfaceMuted }]}
              >
                <Text style={[styles.dropdownItemText, { color: theme.text }]}>{option.label}</Text>
                {option.value === value ? <Text style={{ color: theme.primary }}>{'✓'}</Text> : null}
              </Pressable>
            ))}
          </ScrollView>
        </View>
      ) : null}
    </View>
  );
}

export function DangerButton({
  label,
  onPress,
  wide = false,
  filled = false,
  align = 'center' as const,
}: {
  label: string;
  onPress: () => void;
  wide?: boolean;
  filled?: boolean;
  align?: 'flex-start' | 'center' | 'flex-end';
}) {
  const theme = useTheme();

  return (
    <Pressable
      onPress={onPress}
      style={[
        wide ? styles.fullWidth : { alignSelf: align },
        {
          borderColor: filled ? '#DC2626' : theme.primaryStrong,
          backgroundColor: filled ? '#DC2626' : theme.primary,
          borderRadius: 999,
          shadowColor: filled ? '#DC2626' : theme.primaryStrong,
          shadowOffset: { width: 0, height: 8 },
          shadowOpacity: 0.22,
          shadowRadius: 12,
          elevation: 5,
        },
      ]}
    >
      <View style={styles.dangerButton}>
        <Text style={[styles.dangerButtonText, { color: theme.buttonText }]}>{label}</Text>
      </View>
    </Pressable>
  );
}

export function InfoRow({ label, value }: { label: string; value: string }) {
  const theme = useTheme();

  return (
    <View style={styles.infoRow}>
      <Text style={[styles.infoLabel, { color: theme.textMuted }]}>{label}</Text>
      <Text style={[styles.infoValue, { color: theme.text }]}>{value}</Text>
    </View>
  );
}

export function ButtonContainer({
  children,
  align = 'flex-start' as const,
  gap = 12,
  horizontal = false,
  wrap = false,
}: {
  children: ReactNode;
  align?: 'flex-start' | 'center' | 'flex-end' | 'space-between';
  gap?: number;
  horizontal?: boolean;
  wrap?: boolean;
}) {
  const isSpaceBetween = align === 'space-between';
  const alignItems = isSpaceBetween ? ('center' as const) : align;
  const justifyContent = isSpaceBetween ? ('space-between' as const) : undefined;

  return (
    <View
      style={[
        styles.buttonContainer,
        {
          flexDirection: horizontal ? 'row' : 'column',
          gap,
          alignItems,
          justifyContent,
          flexWrap: wrap ? 'wrap' : 'nowrap',
        },
      ]}
    >
      {children}
    </View>
  );
}

// --- New Components ---

export function Avatar({ name, size = 48, imageUri }: { name: string; size?: number; imageUri?: string | null }) {
  const theme = useTheme();
  const initials = name
    .split(' ')
    .map((w) => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: size / 2,
        backgroundColor: theme.primary + '20',
        alignItems: 'center',
        justifyContent: 'center',
        overflow: 'hidden',
      }}
    >
      {imageUri ? (
        <Image source={{ uri: imageUri }} style={{ width: size, height: size }} resizeMode="cover" />
      ) : (
        <Text style={{ fontFamily: FONT, fontWeight: '700', fontSize: size * 0.38, color: theme.primary }}>{initials}</Text>
      )}
    </View>
  );
}

const STATUS_COLORS: Record<string, { bg: string; text: string }> = {
  upcoming: { bg: '#DBEAFE', text: '#1E40AF' },
  confirmed: { bg: '#D1FAE5', text: '#065F46' },
  completed: { bg: '#FEE2E2', text: '#B91C1C' },
  cancelled: { bg: '#FEE2E2', text: '#991B1B' },
  active: { bg: '#D1FAE5', text: '#065F46' },
  inactive: { bg: '#F3F4F6', text: '#6B7280' },
  pending: { bg: '#FEF3C7', text: '#92400E' },
};

export function StatusBadge({ status }: { status: string }) {
  const colors = STATUS_COLORS[status.toLowerCase()] ?? { bg: '#F3F4F6', text: '#6B7280' };

  return (
    <View style={[styles.statusBadge, { backgroundColor: colors.bg }]}>
      <Text style={[styles.statusBadgeText, { color: colors.text }]}>{status}</Text>
    </View>
  );
}

export function EmptyState({ icon, title, subtitle }: { icon: string; title: string; subtitle?: string }) {
  const theme = useTheme();

  return (
    <View style={styles.emptyState}>
      <Text style={styles.emptyStateIcon}>{icon}</Text>
      <Text style={[styles.emptyStateTitle, { color: theme.text }]}>{title}</Text>
      {subtitle ? <Text style={[styles.emptyStateSubtitle, { color: theme.textMuted }]}>{subtitle}</Text> : null}
    </View>
  );
}

type ToastType = 'success' | 'error' | 'info';
const TOAST_COLORS: Record<ToastType, { bg: string; text: string }> = {
  success: { bg: '#D1FAE5', text: '#065F46' },
  error: { bg: '#FEE2E2', text: '#991B1B' },
  info: { bg: '#DBEAFE', text: '#1E40AF' },
};

export function Toast({ message, type = 'info', visible, onDismiss }: { message: string; type?: ToastType; visible: boolean; onDismiss: () => void }) {
  const fadeAnim = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (visible) {
      Animated.timing(fadeAnim, { toValue: 1, duration: 250, useNativeDriver: true }).start();
      const timer = setTimeout(() => {
        Animated.timing(fadeAnim, { toValue: 0, duration: 250, useNativeDriver: true }).start(() => onDismiss());
      }, 3000);
      return () => clearTimeout(timer);
    }
    return undefined;
  }, [visible, fadeAnim, onDismiss]);

  if (!visible) return null;

  const colors = TOAST_COLORS[type];
  return (
    <Animated.View style={[styles.toast, { backgroundColor: colors.bg, opacity: fadeAnim }]}>
      <Text style={[styles.toastText, { color: colors.text }]}>{message}</Text>
    </Animated.View>
  );
}

export function LoadingSkeleton({ width = '100%' as const, height = 16 }: { width?: `${number}%` | number; height?: number }) {
  const pulseAnim = useRef(new Animated.Value(0.3)).current;

  useEffect(() => {
    const animation = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, { toValue: 1, duration: 800, useNativeDriver: true }),
        Animated.timing(pulseAnim, { toValue: 0.3, duration: 800, useNativeDriver: true }),
      ]),
    );
    animation.start();
    return () => animation.stop();
  }, [pulseAnim]);

  return (
    <Animated.View
      style={{
        width,
        height,
        borderRadius: 8,
        backgroundColor: '#E2E8F0',
        opacity: pulseAnim,
      }}
    />
  );
}

export function SectionHeader({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  const theme = useTheme();

  return (
    <View style={styles.sectionHeaderRow}>
      <Text style={[styles.sectionHeaderText, { color: theme.primary }]}>{title}</Text>
      {action && onAction ? (
        <Pressable onPress={onAction}>
          <Text style={[styles.sectionHeaderAction, { color: theme.primary }]}>{action}</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

const NAV_ICONS: Record<string, string> = {
  Home: '🏠',
  Admins: '🛡️',
  Doctors: '👨‍⚕️',
  Appointments: '📅',
  Rx: '💊',
  Profile: '👤',
  Dashboard: '📊',
  Consult: '🩺',
  Schedule: '🗓️',
  Reports: '📈',
};

function BottomNav({ items, currentScreen, onNavigate }: { items: BottomNavItem[]; currentScreen: AppScreen; onNavigate: (screen: AppScreen) => void }) {
  const theme = useTheme();

  return (
    <View style={[styles.bottomNav, shadow(theme), { backgroundColor: theme.card, borderColor: theme.border, borderRadius: theme.radius + 8 }]}>
      {items.map((item) => {
        const active = currentScreen === item.target;
        const icon = NAV_ICONS[item.label] ?? '📋';
        return (
          <Pressable
            key={item.target}
            onPress={() => onNavigate(item.target)}
            style={[
              styles.bottomItem,
              active && { backgroundColor: theme.primary + '15', borderRadius: 12, paddingHorizontal: 14, paddingVertical: 6 },
            ]}
          >
            <Text style={{ fontSize: 18 }}>{icon}</Text>
            <Text style={[styles.bottomLabel, { color: active ? theme.primary : theme.textMuted, fontWeight: active ? '700' : '500' }]}>{item.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
  },
  safeArea: {
    flex: 1,
  },
  content: {
    paddingHorizontal: 20,
    paddingTop: 8,
    paddingBottom: 120,
    gap: 20,
    flexGrow: 1,
    justifyContent: 'space-between',
  },
  contentCompact: {
    justifyContent: 'center',
    flexGrow: 1,
  },
  topBar: {
    minHeight: 44,
    justifyContent: 'space-between',
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    paddingHorizontal: 16,
    paddingVertical: 14,
  },
  featuresAction: {
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  featuresActionText: {
    fontFamily: FONT, fontWeight: '700' as const,
    fontSize: 13,
  },
  brandBlock: {
    gap: 2,
  },
  brandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  topBarLogo: {
    width: 28,
    height: 28,
  },
  brandText: {
    fontFamily: FONT, fontWeight: '700' as const,
    fontSize: 26,
  },
  brandSubline: {
    fontFamily: FONT, fontWeight: '500' as const,
    fontSize: 13,
  },
  contextText: {
    fontFamily: FONT, fontWeight: '600' as const,
    fontSize: 16,
  },
  headerBlock: {
    gap: 8,
  },
  backButton: {
    width: 42,
    height: 42,
    borderRadius: 999,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  backButtonIcon: {
    fontSize: 20,
    fontWeight: '700',
  },
  title: {
    fontFamily: FONT, fontWeight: '700' as const,
    fontSize: 26,
    lineHeight: 34,
  },
  subtitle: {
    fontFamily: FONT,
    fontSize: 14,
    lineHeight: 22,
  },
  inputWrap: {
    borderWidth: 1.5,
    paddingHorizontal: 12,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  searchIcon: {
    fontFamily: FONT, fontWeight: '600' as const,
    fontSize: 16,
  },
  input: {
    flex: 1,
    paddingVertical: 16,
    fontFamily: FONT, fontWeight: '500' as const,
    fontSize: 14,
  },
  primaryButton: {
    position: 'relative',
    overflow: 'hidden',
    borderWidth: 1,
    minHeight: 42,
    paddingHorizontal: 16,
    paddingVertical: 12,
    alignItems: 'center',
    justifyContent: 'center',
    flex: 0,
  },
  primaryButtonGloss: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '52%',
    overflow: 'hidden',
  },
  primaryButtonGlossBand: {
    height: '100%',
    borderBottomLeftRadius: 18,
    borderBottomRightRadius: 18,
  },
  primaryButtonText: {
    fontFamily: FONT, fontWeight: '700' as const,
    fontSize: 12,
    lineHeight: 18,
    textAlign: 'center',
    includeFontPadding: false,
  },
  secondaryButton: {
    minHeight: 42,
    paddingHorizontal: 16,
    paddingVertical: 12,
    alignItems: 'center',
    justifyContent: 'center',
    flex: 0,
  },
  secondaryButtonText: {
    fontFamily: FONT, fontWeight: '600' as const,
    fontSize: 12,
    lineHeight: 18,
    textAlign: 'center',
    includeFontPadding: false,
  },
  fullWidth: {
    width: '100%',
  },
  card: {
    borderWidth: 1.5,
    padding: 18,
    gap: 14,
  },
  optionCard: {
    width: '47%',
    minHeight: 132,
    borderWidth: 1.5,
    padding: 18,
    gap: 14,
    justifyContent: 'center',
  },
  optionIcon: {
    fontFamily: FONT, fontWeight: '700' as const,
    fontSize: 24,
  },
  optionTitle: {
    fontFamily: FONT, fontWeight: '600' as const,
    fontSize: 15,
  },
  optionHint: {
    fontFamily: FONT,
    fontSize: 11,
    textAlign: 'center',
  },
  chipText: {
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 8,
    overflow: 'hidden',
    fontFamily: FONT, fontWeight: '500' as const,
    fontSize: 12,
  },
  segmented: {
    borderWidth: 1.5,
    flexDirection: 'row',
    padding: 4,
    gap: 4,
  },
  segment: {
    flex: 1,
    paddingVertical: 12,
    alignItems: 'center',
  },
  segmentText: {
    fontFamily: FONT, fontWeight: '600' as const,
    fontSize: 12,
  },
  metricTile: {
    width: '30.5%',
    minHeight: 118,
    borderWidth: 1.5,
    padding: 16,
    justifyContent: 'space-between',
  },
  metricValue: {
    fontFamily: FONT, fontWeight: '700' as const,
    fontSize: 20,
  },
  metricLabel: {
    fontFamily: FONT,
    fontSize: 12,
    lineHeight: 18,
  },
  trendText: {
    fontFamily: FONT, fontWeight: '600' as const,
    fontSize: 12,
  },
  footerWrap: {
    paddingHorizontal: 16,
    paddingVertical: 14,
    borderWidth: 1.5,
  },
  footerText: {
    fontFamily: FONT,
    fontSize: 12,
    lineHeight: 20,
    textAlign: 'center',
  },
  footerBrand: {
    fontFamily: FONT, fontWeight: '600' as const,
    fontSize: 12,
  },
  bottomNav: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    flexDirection: 'row',
    justifyContent: 'space-around',
    borderWidth: 1.5,
    borderTopWidth: 1,
    paddingVertical: 12,
    paddingBottom: 28,
  },
  bottomItem: {
    alignItems: 'center',
    justifyContent: 'center',
    gap: 4,
  },
  bottomLabel: {
    fontFamily: FONT,
    fontWeight: '600' as const,
    fontSize: 11,
  },
  dropdownWrap: {
    gap: 4,
    zIndex: 10,
  },
  dropdownLabel: {
    fontFamily: FONT,
    fontWeight: '500' as const,
    fontSize: 13,
  },
  dropdownTrigger: {
    borderWidth: 1.5,
    paddingHorizontal: 14,
    paddingVertical: 14,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dropdownTriggerText: {
    fontFamily: FONT,
    fontSize: 14,
  },
  dropdownMenu: {
    borderWidth: 1.5,
    marginTop: 4,
  },
  dropdownScroll: {
    maxHeight: 200,
  },
  dropdownItem: {
    paddingHorizontal: 14,
    paddingVertical: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  dropdownItemText: {
    fontFamily: FONT,
    fontSize: 14,
  },
  dangerButton: {
    minHeight: 42,
    paddingHorizontal: 16,
    paddingVertical: 12,
    alignItems: 'center',
    justifyContent: 'center',
    flex: 0,
  },
  dangerButtonText: {
    fontFamily: FONT,
    fontWeight: '600' as const,
    fontSize: 13,
    lineHeight: 18,
    textAlign: 'center',
    includeFontPadding: false,
    color: '#FFFFFF',
  },
  dangerButtonTextFilled: {
    color: '#FFFFFF',
  },
  infoRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
  },
  infoLabel: {
    fontFamily: FONT,
    fontSize: 13,
  },
  infoValue: {
    fontFamily: FONT,
    fontWeight: '600' as const,
    fontSize: 13,
  },
  buttonContainer: {
    flex: 0,
  },
  statusBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 999,
    alignSelf: 'flex-start',
  },
  statusBadgeText: {
    fontFamily: FONT,
    fontWeight: '600' as const,
    fontSize: 11,
    textTransform: 'capitalize',
  },
  emptyState: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 40,
    gap: 8,
  },
  emptyStateIcon: {
    fontSize: 40,
  },
  emptyStateTitle: {
    fontFamily: FONT,
    fontWeight: '600' as const,
    fontSize: 16,
  },
  emptyStateSubtitle: {
    fontFamily: FONT,
    fontSize: 13,
    textAlign: 'center',
    maxWidth: 280,
  },
  toast: {
    position: 'absolute',
    top: 60,
    left: 20,
    right: 20,
    paddingHorizontal: 20,
    paddingVertical: 14,
    borderRadius: 12,
    zIndex: 999,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 8,
    elevation: 6,
  },
  toastText: {
    fontFamily: FONT,
    fontWeight: '600' as const,
    fontSize: 14,
    textAlign: 'center',
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  sectionHeaderText: {
    fontFamily: FONT,
    fontWeight: '700' as const,
    fontSize: 18,
  },
  sectionHeaderAction: {
    fontFamily: FONT,
    fontWeight: '600' as const,
    fontSize: 13,
  },
});