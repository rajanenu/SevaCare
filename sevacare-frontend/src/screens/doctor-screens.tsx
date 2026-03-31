import { useEffect, useMemo, useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { sevacareApi } from '../api/client';
import type { DoctorQueueDayView } from '../api/types';
import { AppShell, Avatar, BackButton, Card, EmptyState, MetricTile, PageHeader, PrimaryButton, SecondaryButton, SectionHeader, SegmentedControl, StatusBadge } from '../components/ui';
import { useTheme } from '../providers/theme-provider';
import { useAppStore } from '../store/app-store';
import { type AppScreen, type BottomNavItem } from '../types/app';
import { type TenantKey } from '../theme';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

type QueueTabValue = 'yesterday' | 'today' | 'tomorrow';

function QueueTimelineTabs({ selected, onChange }: { selected: QueueTabValue; onChange: (value: QueueTabValue) => void }) {
  return (
    <SegmentedControl
      items={[
        { label: 'Yesterday', value: 'yesterday' },
        { label: 'Today', value: 'today' },
        { label: 'Tomorrow', value: 'tomorrow' },
      ]}
      selected={selected}
      onChange={onChange}
    />
  );
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function addDays(date: Date, days: number): Date {
  const result = new Date(date);
  result.setDate(result.getDate() + days);
  return startOfDay(result);
}

function toIsoDate(date: Date): string {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

function formatDateLabel(date: Date): string {
  const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return `${DAYS[date.getDay()]} ${date.getDate()} ${MONTHS[date.getMonth()]}`;
}

export function DoctorDashboardScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems?: BottomNavItem[];
  hospitalName: string;
}) {
  const theme = useTheme();
  const authToken = useAppStore((state) => state.authToken);
  const sessionTenantPublicId = useAppStore((state) => state.sessionTenantPublicId);
  const subjectPublicId = useAppStore((state) => state.subjectPublicId);
  const doctorProfilePhotoUri = useAppStore((state) => state.doctorProfilePhotoUri);
  const setDoctorSelectionForRx = useAppStore((state) => state.setDoctorSelectionForRx);

  const [selectedTab, setSelectedTab] = useState<QueueTabValue>('today');
  const [selectedDate, setSelectedDate] = useState<Date>(() => startOfDay(new Date()));
  const [queueDay, setQueueDay] = useState<DoctorQueueDayView | null>(null);
  const [selectedFacetId, setSelectedFacetId] = useState<string | null>(null);
  const [loadingQueue, setLoadingQueue] = useState(false);

  useEffect(() => {
    const today = startOfDay(new Date());
    const offset = selectedTab === 'yesterday' ? -1 : selectedTab === 'tomorrow' ? 1 : 0;
    setSelectedDate(addDays(today, offset));
  }, [selectedTab]);

  useEffect(() => {
    if (!authToken || !sessionTenantPublicId || !subjectPublicId) {
      return;
    }

    const date = toIsoDate(selectedDate);
    setLoadingQueue(true);
    sevacareApi.getDoctorQueueByDate(sessionTenantPublicId, subjectPublicId, date, authToken)
      .then((response) => {
        setQueueDay(response);
        setSelectedFacetId((current) => current ?? response.facets[0]?.appointmentPublicId ?? null);
      })
      .catch(() => {
        setQueueDay({
          tenantPublicId: sessionTenantPublicId,
          doctorPublicId: subjectPublicId,
          date,
          totalAppointments: 0,
          pendingNotes: 0,
          avgConsultMinutes: 0,
          facets: [],
        });
        setSelectedFacetId(null);
      })
      .finally(() => setLoadingQueue(false));
  }, [authToken, selectedDate, sessionTenantPublicId, subjectPublicId]);

  const selectedFacet = useMemo(() => {
    const facets = queueDay?.facets ?? [];
    if (facets.length === 0) {
      return null;
    }
    return facets.find((facet) => facet.appointmentPublicId === selectedFacetId) ?? facets[0];
  }, [queueDay?.facets, selectedFacetId]);

  const today = startOfDay(new Date());
  const minBrowseDate = addDays(today, -365);
  const maxBrowseDate = addDays(today, 365);

  const changeDate = (delta: number) => {
    const nextDate = addDays(selectedDate, delta);
    if (nextDate.getTime() < minBrowseDate.getTime() || nextDate.getTime() > maxBrowseDate.getTime()) {
      return;
    }

    setSelectedDate(nextDate);
    const yesterday = addDays(today, -1);
    const tomorrow = addDays(today, 1);
    if (toIsoDate(nextDate) === toIsoDate(yesterday)) {
      setSelectedTab('yesterday');
    } else if (toIsoDate(nextDate) === toIsoDate(today)) {
      setSelectedTab('today');
    } else if (toIsoDate(nextDate) === toIsoDate(tomorrow)) {
      setSelectedTab('tomorrow');
    }
  };
  const rangeLabel = `Timeline: ${formatDateLabel(selectedDate)}`;

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Doctor Overview" subtitle="Your daily overview" />

      <View style={styles.headerRow}>
        <View>
          <Text style={[styles.titleText, { color: theme.text }]}>{hospitalName}</Text>
        </View>
        <Pressable onPress={() => onNavigate('profile')} style={styles.profileButton}>
          <Avatar name="Doctor" imageUri={doctorProfilePhotoUri} size={50} />
        </Pressable>
      </View>

      <QueueTimelineTabs
        selected={selectedTab}
        onChange={setSelectedTab}
      />

      <View style={styles.dayNavigatorRow}>
        <Pressable onPress={() => changeDate(-1)} style={[styles.dayArrow, { borderColor: theme.border, backgroundColor: theme.card }]}>
          <Text style={[styles.dayArrowText, { color: theme.text }]}>Previous</Text>
        </Pressable>
        <Text style={[styles.dayLabel, { color: theme.text }]}>{rangeLabel}</Text>
        <Pressable onPress={() => changeDate(1)} style={[styles.dayArrow, { borderColor: theme.border, backgroundColor: theme.card }]}>
          <Text style={[styles.dayArrowText, { color: theme.text }]}>Next</Text>
        </Pressable>
      </View>

      <View style={styles.metricsRow}>
        <MetricTile interactive value={String(queueDay?.totalAppointments ?? 0)} label="Appointments" />
        <MetricTile interactive value={String(queueDay?.pendingNotes ?? 0)} label="Pending notes" />
        <MetricTile interactive value={`${queueDay?.avgConsultMinutes ?? 0} min`} label="Avg consult" />
      </View>

      <SectionHeader title="Patient Queue" />
      <Card>
        <Text style={[styles.sectionSubtitle, { color: theme.textMuted }]}>Swipe facets to review past, current, and future visits.</Text>

        {loadingQueue ? (
          <Text style={[styles.loadingText, { color: theme.textMuted }]}>Loading queue...</Text>
        ) : (queueDay?.facets ?? []).length === 0 ? (
          <EmptyState icon="No queue" title="No appointments for selected day" subtitle="Move left for history or right for future bookings" />
        ) : (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.facetRow}>
            {(queueDay?.facets ?? []).map((facet) => {
              const active = selectedFacet?.appointmentPublicId === facet.appointmentPublicId;
              return (
                <Pressable
                  key={facet.appointmentPublicId}
                  onPress={() => setSelectedFacetId(facet.appointmentPublicId)}
                  style={[
                    styles.facetCard,
                    {
                      borderColor: active ? theme.primaryStrong : theme.border,
                      backgroundColor: active ? theme.footerSurface : theme.card,
                    },
                  ]}
                >
                  <Text style={[styles.facetTitle, { color: theme.text }]}>{facet.patientName}</Text>
                  <Text style={[styles.facetMeta, { color: theme.textMuted }]}>{facet.patientPublicId} • {facet.slot}</Text>
                  <View style={styles.facetFooter}>
                    <StatusBadge status={facet.status} />
                    {facet.followUp ? <Text style={[styles.followUpChip, { color: theme.primaryStrong }]}>Follow-up</Text> : null}
                  </View>
                </Pressable>
              );
            })}
          </ScrollView>
        )}
      </Card>

      {selectedFacet ? (
        <Card>
          <View style={styles.detailHeader}>
            <View>
              <Text style={[styles.sectionTitle, { color: theme.text }]}>{selectedFacet.patientName}</Text>
              <Text style={[styles.sectionSubtitle, { color: theme.textMuted }]}>{selectedFacet.patientPublicId} • {selectedFacet.slot}</Text>
            </View>
            <StatusBadge status={selectedFacet.status} />
          </View>

          <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Symptoms</Text>
          <Text style={[styles.detailValue, { color: theme.text }]}>{selectedFacet.symptoms || 'Symptoms pending'}</Text>

          <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Diagnosis</Text>
          <Text style={[styles.detailValue, { color: theme.text }]}>{selectedFacet.diagnosis || 'Diagnosis not added yet'}</Text>

          <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Medicines</Text>
          {selectedFacet.medicines.length === 0 ? (
            <Text style={[styles.detailValue, { color: theme.textMuted }]}>No medicines prescribed yet</Text>
          ) : (
            <View style={styles.medicineList}>
              {selectedFacet.medicines.map((medicine, index) => (
                <Text key={`${selectedFacet.appointmentPublicId}-${index}`} style={[styles.detailValue, { color: theme.text }]}>- {medicine.name} {medicine.strength} • {medicine.frequency} • {medicine.duration}</Text>
              ))}
            </View>
          )}

          <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Rx Notes</Text>
          <Text style={[styles.detailValue, { color: theme.text }]}>{selectedFacet.rxNotes || 'No Rx notes available'}</Text>

          <View style={styles.actionRow}>
            <PrimaryButton label="Open consultation" onPress={() => onNavigate('consultation')} />
            <SecondaryButton
              label="Issue Rx"
              onPress={() => {
                setDoctorSelectionForRx(selectedFacet.patientPublicId, selectedFacet.appointmentPublicId);
                onNavigate('prescription-upload');
              }}
            />
          </View>
        </Card>
      ) : null}
    </AppShell>
  );
}

export function ConsultationScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems?: BottomNavItem[];
  hospitalName: string;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('doctorDashboard')} />
      </View>
      <PageHeader title="Consultation" subtitle="Review selected appointment notes and continue care" />
      <Card>
        <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Symptoms</Text>
        <Text style={[styles.detailValue, { color: theme.text }]}>Use the queue facet in Doctor Overview to review appointment-specific symptoms.</Text>
      </Card>
      <Card>
        <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Diagnosis</Text>
        <Text style={[styles.detailValue, { color: theme.text }]}>Diagnosis and medicines are now linked to queue facets for quick timeline review.</Text>
      </Card>
      <Card>
        <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Rx</Text>
        <Text style={[styles.detailValue, { color: theme.text }]}>Use Issue Rx from the selected facet to create or update medication details.</Text>
      </Card>
    </AppShell>
  );
}

const styles = StyleSheet.create({
  backRow: {
    flexDirection: 'row',
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  profileButton: {
    width: 50,
    height: 50,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
  profileIcon: {
    fontSize: 24,
  },
  greetingText: {
    fontFamily: FONT,
    fontSize: 13,
  },
  titleText: {
    fontFamily: FONT,
    fontSize: 22,
    fontWeight: '700',
  },
  dayNavigatorRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 10,
  },
  dayArrow: {
    borderWidth: 1,
    borderRadius: 999,
    paddingVertical: 8,
    paddingHorizontal: 14,
  },
  dayArrowText: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
    lineHeight: 16,
    includeFontPadding: false,
  },
  dayLabel: {
    fontFamily: FONT,
    fontSize: 13,
    fontWeight: '600',
    flex: 1,
    textAlign: 'center',
  },
  metricsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  sectionTitle: {
    fontFamily: FONT,
    fontSize: 16,
    fontWeight: '700',
  },
  sectionSubtitle: {
    fontFamily: FONT,
    fontSize: 12,
    marginTop: 2,
  },
  loadingText: {
    fontFamily: FONT,
    fontSize: 12,
    marginTop: 12,
  },
  facetRow: {
    gap: 10,
    paddingTop: 12,
    paddingBottom: 4,
  },
  facetCard: {
    width: 220,
    borderWidth: 1,
    borderRadius: 12,
    padding: 12,
    gap: 6,
  },
  facetTitle: {
    fontFamily: FONT,
    fontSize: 14,
    fontWeight: '700',
  },
  facetMeta: {
    fontFamily: FONT,
    fontSize: 12,
  },
  facetFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 6,
  },
  followUpChip: {
    fontFamily: FONT,
    fontSize: 11,
    fontWeight: '700',
  },
  detailHeader: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: 8,
    gap: 8,
  },
  detailLabel: {
    fontFamily: FONT,
    fontSize: 11,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    marginTop: 10,
  },
  detailValue: {
    fontFamily: FONT,
    fontSize: 13,
    lineHeight: 20,
    marginTop: 2,
  },
  medicineList: {
    marginTop: 2,
    gap: 4,
  },
  actionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 14,
  },
});
