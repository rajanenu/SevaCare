import { useEffect, useMemo, useState } from 'react';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { type Appointment, type Doctor } from '../demo-data';
import { sevacareApi } from '../api/client';
import type { PatientHomeView, PrescriptionView } from '../api/types';
import { useAppStore } from '../store/app-store';
import { AppShell, Avatar, BackButton, Card, Chip, DangerButton, DropdownSelect, EmptyState, MetricTile, PageHeader, PrimaryButton, SearchField, SecondaryButton, SectionHeader, SegmentedControl, StatusBadge } from '../components/ui';
import { useTheme } from '../providers/theme-provider';
import { type TenantKey } from '../theme';
import { type AppScreen, type BottomNavItem } from '../types/app';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

type QueueTabValue = 'yesterday' | 'today' | 'tomorrow';

type PatientFacet = {
  appointmentPublicId: string;
  doctorPublicId: string;
  doctorName: string;
  slot: string;
  timeLabel: string;
  status: string;
  note: string;
  prescription: PrescriptionView | null;
};

function PatientTimelineTabs({ selected, onChange }: { selected: QueueTabValue; onChange: (value: QueueTabValue) => void }) {
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

function legacyDatePrefix(date: Date): string {
  return `${date.getDate()} ${date.toLocaleDateString(undefined, { month: 'short' })}`;
}

function resolveSlotDay(slot: string, selectedDate: Date): boolean {
  const normalized = slot.toLowerCase();
  const today = startOfDay(new Date());
  const yesterday = addDays(today, -1);
  const tomorrow = addDays(today, 1);
  const selectedIso = toIsoDate(selectedDate);

  if (selectedIso === toIsoDate(today) && normalized.includes('today')) {
    return true;
  }
  if (selectedIso === toIsoDate(yesterday) && normalized.includes('yesterday')) {
    return true;
  }
  if (selectedIso === toIsoDate(tomorrow) && normalized.includes('tomorrow')) {
    return true;
  }

  const isoMatch = slot.match(/^(\d{4}-\d{2}-\d{2})/);
  if (isoMatch) {
    return isoMatch[1] === selectedIso;
  }

  return slot.startsWith(legacyDatePrefix(selectedDate));
}

function slotTime(slot: string): string {
  if (slot.includes('·')) {
    return slot.split('·')[1]?.trim() ?? slot;
  }
  const isoTime = slot.match(/(\d{2}:\d{2})$/);
  return isoTime?.[1] ?? slot;
}

export function PatientHomeScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
  patientHome,
  doctors,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  patientHome: PatientHomeView | null;
  doctors: Doctor[];
}) {
  const theme = useTheme();
  const patientProfilePhotoUri = useAppStore((state) => state.patientProfilePhotoUri);
  const [selectedTab, setSelectedTab] = useState<QueueTabValue>('today');
  const [selectedDate, setSelectedDate] = useState<Date>(() => startOfDay(new Date()));
  const [selectedFacetId, setSelectedFacetId] = useState<string | null>(null);
  useEffect(() => {
    const today = startOfDay(new Date());
    const offset = selectedTab === 'yesterday' ? -1 : selectedTab === 'tomorrow' ? 1 : 0;
    setSelectedDate(addDays(today, offset));
  }, [selectedTab]);

  const dayFacets = useMemo(() => {
    const prescriptions = patientHome?.prescriptions ?? [];

    return (patientHome?.appointments ?? [])
      .filter((appointment) => resolveSlotDay(appointment.slot, selectedDate))
      .map((appointment) => {
        const normalizedStatus = appointment.status === 'past' ? 'completed' : appointment.status;
        const prescription = normalizedStatus === 'completed'
          ? prescriptions.find((item) => item.doctorPublicId === appointment.doctorPublicId) ?? null
          : null;
        const doctorName = doctors.find((doctor) => doctor.publicId === appointment.doctorPublicId)?.name ?? appointment.doctorName;
        return {
          appointmentPublicId: appointment.appointmentPublicId,
          doctorPublicId: appointment.doctorPublicId,
          doctorName,
          slot: appointment.slot,
          timeLabel: slotTime(appointment.slot),
          status: normalizedStatus,
          note: appointment.note,
          prescription,
        } satisfies PatientFacet;
      });
  }, [doctors, patientHome?.appointments, patientHome?.prescriptions, selectedDate]);

  useEffect(() => {
    setSelectedFacetId((current) => {
      if (dayFacets.length === 0) {
        return null;
      }
      return dayFacets.some((facet) => facet.appointmentPublicId === current) ? current : dayFacets[0].appointmentPublicId;
    });
  }, [dayFacets]);

  const selectedFacet = useMemo(
    () => dayFacets.find((facet) => facet.appointmentPublicId === selectedFacetId) ?? dayFacets[0] ?? null,
    [dayFacets, selectedFacetId],
  );

  const completedCount = dayFacets.filter((facet) => facet.status === 'completed').length;
  const prescriptionCount = dayFacets.filter((facet) => facet.prescription).length;
  const today = startOfDay(new Date());
  const minBrowseDate = addDays(today, -365);
  const maxBrowseDate = addDays(today, 365);

  const changeDate = (delta: number) => {
    const candidate = addDays(selectedDate, delta);
    if (candidate.getTime() < minBrowseDate.getTime() || candidate.getTime() > maxBrowseDate.getTime()) {
      return;
    }

    setSelectedDate(candidate);
    const yesterday = addDays(today, -1);
    const tomorrow = addDays(today, 1);
    if (toIsoDate(candidate) === toIsoDate(yesterday)) {
      setSelectedTab('yesterday');
    } else if (toIsoDate(candidate) === toIsoDate(today)) {
      setSelectedTab('today');
    } else if (toIsoDate(candidate) === toIsoDate(tomorrow)) {
      setSelectedTab('tomorrow');
    }
  };

  const rangeLabel = `Timeline: ${formatDateLabel(selectedDate)}`;

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Patient Overview" />
      <SectionHeader title="Patient actions" />
      <View style={{ marginBottom: 2 }}>
        <Text style={[styles.greetingName, { color: theme.text }]}>{hospitalName}</Text>
      </View>

      <View style={styles.patientActionRow}>
        <Pressable style={[styles.patientActionCard, { backgroundColor: '#DBEAFE' }]} onPress={() => onNavigate('booking')}>
          <Text style={styles.quickActionIcon}>📅</Text>
          <Text style={[styles.quickActionLabel, { color: '#1E40AF' }]}>Book Appointments</Text>
        </Pressable>
        <Pressable style={[styles.patientActionCard, { backgroundColor: '#E0E7FF' }]} onPress={() => onNavigate('appointments')}>
          <Text style={styles.quickActionIcon}>🏥</Text>
          <Text style={[styles.quickActionLabel, { color: '#3730A3' }]}>View Appointments</Text>
        </Pressable>
        <Pressable style={[styles.patientActionCard, { backgroundColor: '#D1FAE5' }]} onPress={() => onNavigate('prescription')}>
          <Text style={styles.quickActionIcon}>👨‍⚕️</Text>
          <Text style={[styles.quickActionLabel, { color: '#065F46' }]}>View Prescriptions</Text>
        </Pressable>
        <Pressable style={[styles.patientActionCard, { backgroundColor: '#DBF4FF' }]} onPress={() => onNavigate('medical-history')}>
          <Text style={styles.quickActionIcon}>📖</Text>
          <Text style={[styles.quickActionLabel, { color: '#1D4ED8' }]}>Medical History</Text>
        </Pressable>
      </View>

      <PatientTimelineTabs
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
        <MetricTile interactive value={String(dayFacets.length)} label="Appointments" />
        <MetricTile interactive value={String(completedCount)} label="Completed" />
        <MetricTile interactive value={String(prescriptionCount)} label="Prescriptions" />
      </View>

      <Card>
        <Text style={[styles.sectionSubtitle, { color: theme.textMuted }]}>Review yesterday, today, and tomorrow appointments in one place.</Text>
        {dayFacets.length === 0 ? (
          <EmptyState icon="📅" title="No appointments for selected day" subtitle="Create a booking to see it appear here." />
        ) : (
          <View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.facetRow}>
              {dayFacets.map((facet) => {
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
                    <Text style={[styles.facetTitle, { color: theme.text }]}>{facet.doctorName}</Text>
                    <Text style={[styles.facetMeta, { color: theme.textMuted }]}>{facet.timeLabel}</Text>
                    <View style={styles.facetFooter}>
                      <StatusBadge status={facet.status} />
                    </View>
                  </Pressable>
                );
              })}
            </ScrollView>
          </View>
        )}
      </Card>

      {selectedFacet ? (
        <Card>
          <View style={styles.detailHeader}>
            <View>
              <Text style={[styles.sectionTitle, { color: theme.text }]}>{selectedFacet.doctorName}</Text>
              <Text style={[styles.sectionSubtitle, { color: theme.textMuted }]}>{selectedFacet.slot}</Text>
            </View>
            <StatusBadge status={selectedFacet.status} />
          </View>

          <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Visit Details</Text>
          <Text style={[styles.detailValue, { color: theme.text }]}>{selectedFacet.note || 'No appointment notes available yet.'}</Text>

          <Text style={[styles.detailLabel, { color: theme.textMuted }]}>Prescription</Text>
          {selectedFacet.prescription ? (
            <View style={styles.medicineList}>
              {selectedFacet.prescription.lines.map((line, index) => (
                <Text key={`${selectedFacet.prescription?.prescriptionPublicId}-${index}`} style={[styles.detailValue, { color: theme.text }]}>{line}</Text>
              ))}
            </View>
          ) : (
            <Text style={[styles.detailValue, { color: theme.textMuted }]}>
              {selectedFacet.status === 'completed' ? 'Prescription is not uploaded yet for this completed visit.' : 'Prescription will appear here once the doctor completes this appointment.'}
            </Text>
          )}
        </Card>
      ) : null}

    </AppShell>
  );
}

export function DoctorsScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
  doctors,
  onSelectDoctor,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  doctors: Doctor[];
  onSelectDoctor: (doctorId: string) => void;
}) {
  const theme = useTheme();
  const [searchQuery, setSearchQuery] = useState('');
  const [filterSpecialty, setFilterSpecialty] = useState('');
  const [sortBy, setSortBy] = useState<'name' | 'fee' | 'rating'>('name');

  const specialties = useMemo(() => Array.from(new Set(doctors.map((d) => d.specialty))), [doctors]);

  const filteredDoctors = useMemo(() => {
    let result = doctors;
    if (searchQuery.trim()) {
      const q = searchQuery.trim().toLowerCase();
      result = result.filter((d) => d.name.toLowerCase().includes(q) || d.specialty.toLowerCase().includes(q));
    }
    if (filterSpecialty) {
      result = result.filter((d) => d.specialty === filterSpecialty);
    }
    result = [...result].sort((a, b) => {
      if (sortBy === 'name') return a.name.localeCompare(b.name);
      if (sortBy === 'rating') return (b.rating ?? '0').localeCompare(a.rating ?? '0');
      return a.fee.localeCompare(b.fee);
    });
    return result;
  }, [doctors, searchQuery, filterSpecialty, sortBy]);

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('patientHome')} />
      </View>
      <PageHeader title="Doctor listing" subtitle={hospitalName} />
      <SearchField value={searchQuery} onChangeText={setSearchQuery} placeholder="Search doctors by name or specialty..." />
      <View style={styles.filterRow}>
        <View style={{ flex: 1 }}>
          <DropdownSelect
            label=""
            value={filterSpecialty}
            options={[{ label: 'All Specialties', value: '' }, ...specialties.map((s) => ({ label: s, value: s }))]}
            onChange={(v) => setFilterSpecialty(String(v))}
          />
        </View>
        <View style={{ flex: 1 }}>
          <DropdownSelect
            label=""
            value={sortBy}
            options={[
              { label: 'Sort: Name', value: 'name' },
              { label: 'Sort: Rating', value: 'rating' },
              { label: 'Sort: Fee', value: 'fee' },
            ]}
            onChange={(v) => setSortBy(v as 'name' | 'fee' | 'rating')}
          />
        </View>
      </View>
      {filteredDoctors.length === 0 ? (
        <EmptyState icon="👨‍⚕️" title="No doctors found" subtitle={searchQuery ? 'Try a different search' : 'Please check back later'} />
      ) : (
        <View style={styles.stackGap}>
          {filteredDoctors.map((doctor) => (
            <Pressable
              key={doctor.id}
              onPress={() => onSelectDoctor(doctor.id)}
              style={({ pressed }) => [{ opacity: pressed ? 0.96 : 1 }]}
            >
              <Card>
                <View style={styles.doctorCardRow}>
                  <Avatar name={doctor.name} size={44} />
                  <View style={{ flex: 1 }}>
                    <View style={styles.rowBetween}>
                      <Text style={[styles.cardTitle, { color: theme.text }]}>{doctor.name}</Text>
                      <Chip label={`${doctor.rating} ★`} />
                    </View>
                    <Text style={[styles.cardBody, { color: theme.textMuted }]}>{doctor.specialty} · {doctor.experience}</Text>
                  </View>
                </View>
                <View style={styles.metaRowWrap}>
                  <Chip label={doctor.availability} />
                  <Chip label={doctor.fee} />
                </View>
              </Card>
            </Pressable>
          ))}
        </View>
      )}
    </AppShell>
  );
}

export function BookingScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
  doctors,
  bookingName,
  onBookingNameChange,
  bookingGender,
  onBookingGenderChange,
  bookingAge,
  onBookingAgeChange,
  bookingMobile,
  onBookingMobileChange,
  bookingEmail,
  onBookingEmailChange,
  bookingAddress,
  onBookingAddressChange,
  bookingSpecialty,
  specializationOptions,
  onBookingSpecialtyChange,
  hospitalName,
  selectedDoctorId,
  onSelectDoctor,
  slotIntervalMinutes,
  bookedSlots,
  selectedDate,
  onSelectDate,
  selectedSlot,
  onSelectSlot,
  onConfirmBooking,
  availableDates,
  availableSlots,
  morningSlots = [],
  eveningSlots = [],
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  doctors: Doctor[];
  bookingName: string;
  onBookingNameChange: (value: string) => void;
  bookingGender: 'male' | 'female' | 'other';
  onBookingGenderChange: (value: 'male' | 'female' | 'other') => void;
  bookingAge: string;
  onBookingAgeChange: (value: string) => void;
  bookingMobile: string;
  onBookingMobileChange: (value: string) => void;
  bookingEmail: string;
  onBookingEmailChange: (value: string) => void;
  bookingAddress: string;
  onBookingAddressChange: (value: string) => void;
  bookingSpecialty: string;
  specializationOptions: string[];
  onBookingSpecialtyChange: (value: string) => void;
  hospitalName: string;
  selectedDoctorId: string;
  onSelectDoctor: (doctorId: string) => void;
  slotIntervalMinutes: number;
  bookedSlots: string[];
  selectedDate: string;
  onSelectDate: (date: string) => void;
  selectedSlot: string;
  onSelectSlot: (slot: string) => void;
  onConfirmBooking: () => void;
  availableDates: string[];
  availableSlots: string[];
  morningSlots?: string[];
  eveningSlots?: string[];
}) {
  const theme = useTheme();
  const specialties = specializationOptions.length > 0 ? specializationOptions : Array.from(new Set(doctors.map((doctor) => doctor.specialty))).slice(0, 5);
  const doctorsForSpecialty = doctors.filter((doctor) => doctor.specialty === bookingSpecialty);
  const selectedDoctor = doctorsForSpecialty.find((doctor) => doctor.id === selectedDoctorId) ?? doctorsForSpecialty[0];

  // Check if a time slot has passed for the selected date
  const isSlotPast = (slot: string): boolean => {
    const todayStr = new Date().toISOString().slice(0, 10);
    if (selectedDate !== todayStr) return false;
    const now = new Date();
    const [hours, minutes] = slot.split(':').map(Number);
    return hours < now.getHours() || (hours === now.getHours() && minutes <= now.getMinutes());
  };

  // Calendar state
  const todayDate = new Date();
  todayDate.setHours(0, 0, 0, 0);
  const todayStr = todayDate.toISOString().slice(0, 10);
  const initialMonth = selectedDate ? new Date(selectedDate + 'T00:00:00') : todayDate;
  const [calendarMonth, setCalendarMonth] = useState(initialMonth.getMonth());
  const [calendarYear, setCalendarYear] = useState(initialMonth.getFullYear());

  const availableDateSet = useMemo(() => new Set(availableDates), [availableDates]);

  const calendarDays = useMemo(() => {
    const firstDay = new Date(calendarYear, calendarMonth, 1);
    const startDow = firstDay.getDay(); // 0=Sun
    const daysInMonth = new Date(calendarYear, calendarMonth + 1, 0).getDate();
    const cells: Array<{ date: string; day: number; available: boolean; past: boolean } | null> = [];
    for (let i = 0; i < startDow; i++) cells.push(null); // leading blanks
    for (let d = 1; d <= daysInMonth; d++) {
      const iso = `${calendarYear}-${String(calendarMonth + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const dateObj = new Date(iso + 'T00:00:00');
      const isPast = dateObj < todayDate;
      cells.push({ date: iso, day: d, available: availableDateSet.has(iso), past: isPast });
    }
    return cells;
  }, [calendarYear, calendarMonth, availableDateSet, todayDate]);

  const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  const DOW_HEADERS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  const goToPrevMonth = () => {
    if (calendarMonth === 0) { setCalendarMonth(11); setCalendarYear(calendarYear - 1); }
    else setCalendarMonth(calendarMonth - 1);
  };
  const goToNextMonth = () => {
    if (calendarMonth === 11) { setCalendarMonth(0); setCalendarYear(calendarYear + 1); }
    else setCalendarMonth(calendarMonth + 1);
  };

  const renderSlotSection = (label: string, slots: string[]) => {
    // Filter out past slots for today instead of just disabling them
    const visibleSlots = slots.filter((slot) => !isSlotPast(slot));
    if (visibleSlots.length === 0) return null;
    return (
      <>
        <Text style={[styles.slotSectionLabel, { color: theme.textMuted }]}>{label}</Text>
        <View style={styles.metaRowWrap}>
          {visibleSlots.map((slot) => {
            const isUnavailable = bookedSlots.includes(slot);
            const isActive = selectedSlot === slot;

            return (
              <Pressable
                key={slot}
                onPress={() => {
                  if (!isUnavailable) {
                    onSelectSlot(slot);
                  }
                }}
                style={[
                  styles.slotPill,
                  {
                    backgroundColor: isUnavailable ? '#E5E7EB' : isActive ? '#86EFAC' : '#DCFCE7',
                    borderColor: isUnavailable ? '#9CA3AF' : '#10B981',
                    opacity: isUnavailable ? 0.5 : 1,
                  },
                ]}
              >
                <Text style={[styles.slotPillText, { color: isUnavailable ? '#6B7280' : '#065F46' }]}>{slot}</Text>
              </Pressable>
            );
          })}
        </View>
      </>
    );
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('patientHome')} />
      </View>
      <PageHeader title="Appointment booking" />
      <Card>
        <SearchField value={bookingName} onChangeText={onBookingNameChange} placeholder="Patient name" showIcon={false} />
        <DropdownSelect
          label="Gender"
          value={bookingGender}
          options={[
            { label: 'Male', value: 'male' },
            { label: 'Female', value: 'female' },
            { label: 'Other', value: 'other' },
          ]}
          onChange={(value) => onBookingGenderChange(value as 'male' | 'female' | 'other')}
        />
        <SearchField value={bookingAge} onChangeText={(val) => { const cleaned = val.replace(/[^0-9]/g, ''); onBookingAgeChange(cleaned); }} placeholder="Age" showIcon={false} />
        <SearchField value={bookingMobile} onChangeText={onBookingMobileChange} placeholder="Mobile number" showIcon={false} />
        <SearchField value={bookingEmail} onChangeText={onBookingEmailChange} placeholder="Email address (optional)" showIcon={false} />
        <SearchField value={bookingAddress} onChangeText={onBookingAddressChange} placeholder="Address" showIcon={false} />
      </Card>
      <Text style={[styles.sectionTitle, { color: theme.text }]}>Select specialty</Text>
      <Card>
        <DropdownSelect
          label="Specialization"
          value={bookingSpecialty || 'General Physician'}
          options={specialties.map((s) => ({ label: s, value: s }))}
          onChange={(value) => onBookingSpecialtyChange(String(value))}
        />
      </Card>
      {bookingSpecialty ? (
        <>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>Select doctor</Text>
          <View style={styles.stackGap}>
            {doctorsForSpecialty.length > 0 ? doctorsForSpecialty.map((doctor) => (
              <Pressable key={doctor.id} onPress={() => onSelectDoctor(doctor.id)}>
                <Card>
                  <View style={styles.rowBetween}>
                    <Text style={[styles.cardTitle, { color: theme.text }]}>{doctor.name}</Text>
                    <Chip label={doctor.fee} active={selectedDoctor?.id === doctor.id} />
                  </View>
                  <Text style={[styles.cardBody, { color: theme.textMuted }]}>{doctor.specialty} · {doctor.availability}</Text>
                </Card>
              </Pressable>
            )) : (
              <Card>
                <Text style={[styles.cardBody, { color: theme.textMuted }]}>No doctors available for this specialization.</Text>
              </Card>
            )}
          </View>
        </>
      ) : null}
      <Text style={[styles.sectionTitle, { color: theme.text }]}>Choose a date</Text>
      <Card>
        <View style={styles.calendarWrap}>
          <View style={styles.calendarHeader}>
            <Pressable onPress={goToPrevMonth} style={styles.calendarArrow}>
              <Text style={[styles.calendarArrowText, { color: theme.text }]}>‹</Text>
            </Pressable>
            <Text style={[styles.calendarMonthLabel, { color: theme.text }]}>{MONTHS[calendarMonth]} {calendarYear}</Text>
            <Pressable onPress={goToNextMonth} style={styles.calendarArrow}>
              <Text style={[styles.calendarArrowText, { color: theme.text }]}>›</Text>
            </Pressable>
          </View>
          <View style={styles.calendarGrid}>
            {DOW_HEADERS.map((dow) => (
              <View key={dow} style={styles.calendarCell}>
                <Text style={[styles.calendarDowText, { color: theme.textMuted }]}>{dow}</Text>
              </View>
            ))}
            {calendarDays.map((cell, i) => {
              if (!cell) return <View key={`blank-${i}`} style={styles.calendarCell} />;
              const isSelected = selectedDate === cell.date;
              const isToday = cell.date === todayStr;
              const disabled = cell.past || !cell.available;
              return (
                <Pressable
                  key={cell.date}
                  onPress={() => { if (!disabled) onSelectDate(cell.date); }}
                  style={[
                    styles.calendarCell,
                    isSelected && { backgroundColor: '#10B981', borderRadius: 6 },
                    isToday && !isSelected && { borderWidth: 1, borderColor: '#10B981', borderRadius: 6 },
                  ]}
                >
                  <Text style={[
                    styles.calendarDayText,
                    { color: disabled ? '#D1D5DB' : isSelected ? '#FFF' : theme.text },
                  ]}>{cell.day}</Text>
                </Pressable>
              );
            })}
          </View>
          {selectedDate ? (
            <Text style={[styles.calendarSelectedLabel, { color: theme.primary }]}>Selected: {selectedDate}</Text>
          ) : (
            <Text style={[styles.calendarSelectedLabel, { color: theme.textMuted }]}>Tap an available date to continue</Text>
          )}
        </View>
      </Card>
      {selectedDate ? (
        <>
          <Text style={[styles.sectionTitle, { color: theme.text }]}>{`Choose a slot (${slotIntervalMinutes}-minute intervals)`}</Text>
          {renderSlotSection('🌅 Morning (9:00 AM – 2:00 PM)', morningSlots.length > 0 ? morningSlots : availableSlots)}
          {renderSlotSection('🌆 Evening (5:00 PM – 9:00 PM)', eveningSlots)}
        </>
      ) : null}
      {selectedDate && selectedSlot ? (
        <View style={styles.centeredAction}>
          <PrimaryButton
            label="Confirm booking"
            onPress={() => {
              onConfirmBooking();
              onNavigate('confirmation');
            }}
          />
        </View>
      ) : null}
    </AppShell>
  );
}

export function ConfirmationScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
  doctorName,
  selectedDate,
  selectedSlot,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  doctorName: string;
  selectedDate: string;
  selectedSlot: string;
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} compact>
      <PageHeader title="Appointment confirmed" />
      <Card>
        <Text style={[styles.cardTitle, { color: theme.text }]}>Your visit is confirmed</Text>
        <Text style={[styles.cardBody, { color: theme.textMuted }]}>{doctorName} · {selectedDate} · {selectedSlot}</Text>
        <Chip label="Token #A-28" />
      </Card>
      <View style={styles.buttonRow}>
        <PrimaryButton label="Go to appointments" onPress={() => onNavigate('appointments')} />
        <SecondaryButton label="Back to home" onPress={() => onNavigate('patientHome')} />
      </View>
    </AppShell>
  );
}

export function AppointmentsScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
  appointments,
  selectedTab,
  onTabChange,
  onAppointmentCancelled,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  appointments: Appointment[];
  selectedTab: 'upcoming' | 'history';
  onTabChange: (value: 'upcoming' | 'history') => void;
  onAppointmentCancelled?: () => void;
}) {
  const theme = useTheme();
  const authToken = useAppStore((state) => state.authToken);
  const sessionTenantPublicId = useAppStore((state) => state.sessionTenantPublicId);
  const subjectPublicId = useAppStore((state) => state.subjectPublicId);
  const [cancellingId, setCancellingId] = useState<string | null>(null);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  // Sort appointments descending by slot (most recent first)
  const sortedAppointments = useMemo(() =>
    [...appointments].sort((a, b) => b.slot.localeCompare(a.slot)),
    [appointments],
  );

  const handleCancel = (appointmentId: string) => {
    if (!authToken || !sessionTenantPublicId || !subjectPublicId) return;
    setCancellingId(appointmentId);
    void sevacareApi.cancelAppointment(sessionTenantPublicId, subjectPublicId, appointmentId, authToken, { reason: 'Cancelled by patient' })
      .then(() => {
        onAppointmentCancelled?.();
      })
      .catch(() => undefined)
      .finally(() => setCancellingId(null));
  };

  const handleDelete = (appointmentId: string) => {
    if (!authToken || !sessionTenantPublicId || !subjectPublicId) return;
    setDeletingId(appointmentId);
    void sevacareApi.deletePatientAppointment(sessionTenantPublicId, subjectPublicId, appointmentId, authToken)
      .then(() => {
        onAppointmentCancelled?.();
      })
      .catch(() => undefined)
      .finally(() => setDeletingId(null));
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems}>
      <PageHeader title="My appointments" />
      <SegmentedControl
        items={[
          { label: 'Upcoming', value: 'upcoming' },
          { label: 'History', value: 'history' },
        ]}
        selected={selectedTab}
        onChange={onTabChange}
      />
      <View style={styles.stackGap}>
        {sortedAppointments.filter((item) => (selectedTab === 'upcoming' ? item.status === 'upcoming' : item.status !== 'upcoming')).length === 0 ? (
          <EmptyState
            icon={selectedTab === 'upcoming' ? '📅' : '📜'}
            title={selectedTab === 'upcoming' ? 'No upcoming appointments' : 'No past appointments'}
            subtitle="Book an appointment to get started"
          />
        ) : (
          sortedAppointments.filter((item) => (selectedTab === 'upcoming' ? item.status === 'upcoming' : item.status !== 'upcoming')).map((appointment) => (
            <Card key={appointment.id}>
              <View style={styles.rowBetween}>
                <View style={styles.doctorCardRow}>
                  <Avatar name={appointment.doctor} size={36} />
                  <View>
                    <Text style={[styles.cardTitle, { color: theme.text }]}>{appointment.doctor}</Text>
                    <Text style={[styles.cardBody, { color: theme.textMuted }]}>{appointment.hospital}</Text>
                  </View>
                </View>
                <StatusBadge status={appointment.status} />
              </View>
              <Chip label={appointment.slot} />
              {appointment.note ? <Text style={[styles.cardBody, { color: theme.textMuted }]}>{appointment.note}</Text> : null}
              {appointment.status === 'upcoming' ? (
                <View style={styles.buttonRow}>
                  <SecondaryButton
                    label={cancellingId === appointment.id ? 'Cancelling...' : 'Cancel'}
                    onPress={() => (cancellingId || deletingId ? undefined : handleCancel(appointment.id))}
                  />
                  <DangerButton
                    label={deletingId === appointment.id ? 'Deleting...' : 'Delete'}
                    onPress={() => (cancellingId || deletingId ? undefined : handleDelete(appointment.id))}
                  />
                  <SecondaryButton label="Reschedule" onPress={() => onNavigate('booking')} />
                </View>
              ) : (
                <View style={styles.buttonRow}>
                  <DangerButton
                    label={deletingId === appointment.id ? 'Deleting...' : 'Delete'}
                    onPress={() => (deletingId ? undefined : handleDelete(appointment.id))}
                  />
                </View>
              )}
            </Card>
          ))
        )}
      </View>
    </AppShell>
  );
}

export function PrescriptionScreen({
  activeTenant,
  onTenantChange,
  currentScreen,
  onNavigate,
  bottomItems,
}: {
  activeTenant: TenantKey;
  onTenantChange: (tenant: TenantKey) => void;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
}) {
  const theme = useTheme();

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems}>
      <PageHeader title="Digital prescription" />
      <EmptyState
        icon="💊"
        title="No prescriptions yet"
        subtitle="Prescriptions will appear here once your doctor has prescribed medicines after a consultation."
      />
    </AppShell>
  );
}

const styles = StyleSheet.create({
  backRow: {
    flexDirection: 'row',
  },
  dashboardHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 12,
  },
  greetingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  greetingText: {
    fontFamily: FONT,
    fontSize: 14,
  },
  greetingName: {
    fontFamily: FONT,
    fontSize: 22,
    fontWeight: '700',
  },
  profileButton: {
    borderRadius: 999,
  },
  quickActionsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  patientActionRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  patientActionCard: {
    minWidth: 160,
    flexGrow: 1,
    borderRadius: 16,
    padding: 16,
    gap: 8,
  },
  quickActionCard: {
    width: '47%',
    borderRadius: 16,
    padding: 16,
    gap: 8,
    minHeight: 100,
  },
  quickActionIcon: {
    fontSize: 28,
  },
  quickActionLabel: {
    fontFamily: FONT,
    fontSize: 13,
    fontWeight: '600',
    textAlign: 'center',
    lineHeight: 18,
    includeFontPadding: false,
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
  sectionSubtitle: {
    fontFamily: FONT,
    fontSize: 12,
    marginTop: 2,
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
  inlineActionWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  doctorCardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  filterRow: {
    flexDirection: 'row',
    gap: 10,
  },
  metaRowWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  stackGap: {
    gap: 12,
  },
  buttonRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  centeredAction: {
    alignItems: 'center',
    marginTop: 8,
    marginBottom: 16,
  },
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 10,
  },
  sectionTitle: {
    fontFamily: FONT,
    fontSize: 15,
    fontWeight: '700',
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
  linkText: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '600',
  },
  slotPill: {
    borderWidth: 1,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  slotPillText: {
    fontFamily: FONT,
    fontSize: 11,
    fontWeight: '500',
  },
  slotSectionLabel: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '600',
    marginTop: 6,
    marginBottom: 2,
  },
  calendarWrap: {
    maxWidth: 340,
    alignSelf: 'center',
    width: '100%',
  },
  calendarHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  calendarArrow: {
    padding: 4,
    paddingHorizontal: 8,
  },
  calendarArrowText: {
    fontSize: 20,
    fontWeight: '600',
    lineHeight: 24,
  },
  calendarMonthLabel: {
    fontFamily: FONT,
    fontSize: 13,
    fontWeight: '600',
  },
  calendarGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  calendarCell: {
    width: '14.28%',
    height: 32,
    justifyContent: 'center',
    alignItems: 'center',
  },
  calendarDowText: {
    fontFamily: FONT,
    fontSize: 10,
    fontWeight: '600',
  },
  calendarDayText: {
    fontFamily: FONT,
    fontSize: 12,
    fontWeight: '500',
  },
  calendarSelectedLabel: {
    fontFamily: FONT,
    fontSize: 11,
    textAlign: 'center',
    marginTop: 6,
  },
});