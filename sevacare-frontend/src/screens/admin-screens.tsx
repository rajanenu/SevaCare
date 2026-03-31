import { useEffect, useMemo, useState } from 'react';
import { Platform, Pressable, StyleSheet, Text, View } from 'react-native';
import { sevacareApi } from '../api/client';
import type { AdminOverviewMetric, AdminUserRecord, AppointmentRecord, PlatformOnboardingRequestRecord, PlatformTenantRecord } from '../api/types';
import { AppShell, Avatar, Card, DangerButton, DropdownSelect, MetricTile, PageHeader, PrimaryButton, SearchField, SegmentedControl, SecondaryButton, SectionHeader, EmptyState, StatusBadge } from '../components/ui';
import { useAppStore } from '../store/app-store';
import { useTheme } from '../providers/theme-provider';
import { type TenantKey } from '../theme';
import { type AppScreen, type BottomNavItem } from '../types/app';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

type AdminNavValue = 'adminDashboard' | 'adminUsers' | 'doctorManagement';

function AdminNav({ selected, onChange }: { selected: AdminNavValue; onChange: (value: AdminNavValue) => void }) {
  return (
    <SegmentedControl
      items={[
        { label: 'Dashboard', value: 'adminDashboard' },
        { label: 'Admin Users', value: 'adminUsers' },
        { label: 'Doctor Management', value: 'doctorManagement' },
      ]}
      selected={selected}
      onChange={onChange}
    />
  );
}

export function AdminDashboardScreen({
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
  const [metrics, setMetrics] = useState<AdminOverviewMetric[]>([]);
  const [doctorRecords, setDoctorRecords] = useState<{ doctorPublicId: string; fullName: string; specialty: string; availability: string; fee: string; active: boolean }[]>([]);
  const [appointments, setAppointments] = useState<AppointmentRecord[]>([]);
  const [visitFilter, setVisitFilter] = useState<'day' | 'week' | 'month' | 'year'>('day');

  useEffect(() => {
    if (!authToken || !sessionTenantPublicId) return;
    sevacareApi.getAdminOverview(sessionTenantPublicId, authToken)
      .then((data) => setMetrics(data.metrics))
      .catch(() => setMetrics([]));
    sevacareApi.listDoctorRecords(sessionTenantPublicId, authToken)
      .then((data) => setDoctorRecords(data.doctors))
      .catch(() => setDoctorRecords([]));
    sevacareApi.listAppointmentRecords(sessionTenantPublicId, authToken)
      .then((data) => setAppointments(data.appointments ?? []))
      .catch(() => setAppointments([]));
  }, [authToken, sessionTenantPublicId]);

  // Group doctors by department/specialty
  const departmentDoctorMap = useMemo(() => {
    const map: Record<string, number> = {};
    for (const doctor of doctorRecords) {
      const dept = doctor.specialty || 'General';
      map[dept] = (map[dept] ?? 0) + 1;
    }
    return map;
  }, [doctorRecords]);

  // Filter appointments by time window
  const filteredAppointments = useMemo(() => {
    const now = new Date();
    const startOf = (unit: 'day' | 'week' | 'month' | 'year'): Date => {
      const d = new Date(now);
      if (unit === 'day') { d.setHours(0, 0, 0, 0); return d; }
      if (unit === 'week') { const day = d.getDay(); d.setDate(d.getDate() - day); d.setHours(0, 0, 0, 0); return d; }
      if (unit === 'month') { d.setDate(1); d.setHours(0, 0, 0, 0); return d; }
      d.setMonth(0, 1); d.setHours(0, 0, 0, 0); return d;
    };
    const cutoff = startOf(visitFilter);
    return appointments.filter((appt) => {
      if (!appt.slot) return false;
      const apptDate = new Date(appt.slot);
      return !isNaN(apptDate.getTime()) ? apptDate >= cutoff : true;
    });
  }, [appointments, visitFilter]);

  // Group filtered appointments by department (doctor's specialty)
  const departmentVisitMap = useMemo(() => {
    const specialtyByDoctor: Record<string, string> = {};
    for (const doctor of doctorRecords) {
      specialtyByDoctor[doctor.doctorPublicId] = doctor.specialty || 'General';
    }
    const map: Record<string, number> = {};
    for (const appt of filteredAppointments) {
      const dept = specialtyByDoctor[appt.doctorPublicId] ?? 'General';
      map[dept] = (map[dept] ?? 0) + 1;
    }
    return map;
  }, [filteredAppointments, doctorRecords]);

  const visitFilterLabels: { label: string; value: 'day' | 'week' | 'month' | 'year' }[] = [
    { label: 'Today', value: 'day' },
    { label: 'This Week', value: 'week' },
    { label: 'This Month', value: 'month' },
    { label: 'This Year', value: 'year' },
  ];

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Operations dashboard" subtitle={hospitalName} />
      <AdminNav selected="adminDashboard" onChange={onNavigate as (value: AdminNavValue) => void} />

      <SectionHeader title="Hospital Overview" />
      <View style={styles.metricsRow}>
        {metrics.map((metric) => (
          <MetricTile key={metric.label} value={metric.value} label={metric.label} trend={metric.trend} />
        ))}
      </View>

      <SectionHeader title="Doctors by Department" />
      {Object.keys(departmentDoctorMap).length === 0 ? (
        <EmptyState icon="👨‍⚕️" title="No doctor data" subtitle="Doctor records will appear here once added" />
      ) : (
        <View style={styles.metricsRow}>
          {Object.entries(departmentDoctorMap).map(([dept, count]) => (
            <MetricTile key={dept} value={String(count)} label={dept} />
          ))}
        </View>
      )}

      <SectionHeader title="Patient Visits" />
      <SegmentedControl
        items={visitFilterLabels}
        selected={visitFilter}
        onChange={(v) => setVisitFilter(v as 'day' | 'week' | 'month' | 'year')}
      />
      <View style={styles.metricsRow}>
        <MetricTile value={String(filteredAppointments.length)} label="Total Visits" />
        <MetricTile value={String(filteredAppointments.filter((a) => a.status === 'upcoming').length)} label="Upcoming" />
        <MetricTile value={String(filteredAppointments.filter((a) => a.status !== 'upcoming' && a.status !== 'cancelled').length)} label="Completed" />
        <MetricTile value={String(filteredAppointments.filter((a) => a.status === 'cancelled').length)} label="Cancelled" />
      </View>

      {Object.keys(departmentVisitMap).length > 0 ? (
        <>
          <SectionHeader title="Visits by Department" />
          <View style={styles.metricsRow}>
            {Object.entries(departmentVisitMap).map(([dept, count]) => (
              <MetricTile key={dept} value={String(count)} label={dept} />
            ))}
          </View>
        </>
      ) : null}

    </AppShell>
  );
}

export function PlatformAdminDashboardScreen({
  currentScreen,
  onNavigate,
}: {
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
}) {
  const authToken = useAppStore((state) => state.authToken);
  const [overview, setOverview] = useState<{ activeTenants: number; onboardingRequests: number; approvedOnboardings: number; platformAdmins: number } | null>(null);
  const [tenants, setTenants] = useState<PlatformTenantRecord[]>([]);
  const [requests, setRequests] = useState<PlatformOnboardingRequestRecord[]>([]);

  useEffect(() => {
    if (!authToken) {
      return;
    }

    void sevacareApi.getPlatformOverview(authToken).then(setOverview).catch(() => setOverview(null));
    void sevacareApi.listPlatformTenants(authToken).then((data) => setTenants(data.tenants)).catch(() => setTenants([]));
    void sevacareApi.listPlatformOnboardingRequests(authToken).then((data) => setRequests(data.requests)).catch(() => setRequests([]));
  }, [authToken]);

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} hospitalName="SevaCare Platform">
      <PageHeader title="Platform admin" subtitle="All tenants and onboarding visibility" />

      {overview ? (
        <View style={styles.metricsRow}>
          <MetricTile value={String(overview.activeTenants)} label="Active tenants" />
          <MetricTile value={String(overview.onboardingRequests)} label="Pending requests" />
          <MetricTile value={String(overview.approvedOnboardings)} label="Approved onboarding" />
          <MetricTile value={String(overview.platformAdmins)} label="Platform admins" />
        </View>
      ) : null}

      <SectionHeader title="Active tenants" />
      <View style={styles.stackGap}>
        {tenants.length === 0 ? (
          <EmptyState icon="🏥" title="No tenants found" subtitle="Active tenants will appear here." />
        ) : tenants.map((tenant) => (
          <Card key={tenant.tenantPublicId}>
            <Text style={styles.cardTitle}>{tenant.hospitalName}</Text>
            <Text style={styles.cardBody}>{tenant.tenantPublicId} · {tenant.status} · {tenant.schemaName}</Text>
            <Text style={styles.cardBody}>Theme: {tenant.themeKey || 'default'}</Text>
          </Card>
        ))}
      </View>

      <SectionHeader title="Onboarding requests" />
      <View style={styles.stackGap}>
        {requests.length === 0 ? (
          <EmptyState icon="📋" title="No onboarding requests" subtitle="Submitted requests will appear here." />
        ) : requests.map((request) => (
          <Card key={request.requestPublicId}>
            <Text style={styles.cardTitle}>{request.hospitalName}</Text>
            <Text style={styles.cardBody}>{request.requestPublicId} · {request.status} · {request.city}</Text>
            <Text style={styles.cardBody}>{request.facilityType} · {request.contactName} · {request.contactMobile}</Text>
            <Text style={styles.cardBody}>{request.contactEmail}</Text>
          </Card>
        ))}
      </View>
    </AppShell>
  );
}

export function DoctorManagementScreen({
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
  const authToken = useAppStore((state) => state.authToken);
  const sessionTenantPublicId = useAppStore((state) => state.sessionTenantPublicId);
  const [doctorRecords, setDoctorRecords] = useState<{
    doctorPublicId: string;
    fullName: string;
    specialty: string;
    availability: string;
    fee: string;
    active: boolean;
  }[]>([]);
  const [patientRecords, setPatientRecords] = useState<{
    patientPublicId: string;
    fullName: string;
    mobileNumber: string;
    status: string;
  }[]>([]);

  const [doctorPublicId, setDoctorPublicId] = useState('D-2001');
  const [doctorName, setDoctorName] = useState('');
  const [doctorSpecialty, setDoctorSpecialty] = useState('Cardiologist');
  const [doctorAvailability, setDoctorAvailability] = useState('Today · Open');
  const [doctorFee, setDoctorFee] = useState('₹500');
  const [doctorAvailableFrom, setDoctorAvailableFrom] = useState('');
  const [doctorReadyToLook, setDoctorReadyToLook] = useState(true);
  const [isEditingDoctor, setIsEditingDoctor] = useState(false);
  const [specializationOptions, setSpecializationOptions] = useState<string[]>([]);

  const effectiveTenant = useMemo(() => sessionTenantPublicId, [sessionTenantPublicId]);

  const refreshData = () => {
    if (!authToken || !effectiveTenant) {
      return;
    }

    void sevacareApi.listDoctorRecords(effectiveTenant, authToken).then((data) => setDoctorRecords(data.doctors));
    void sevacareApi.listPatientRecords(effectiveTenant, authToken).then((data) => setPatientRecords(data.patients));
    void sevacareApi.getNextDoctorPublicId(effectiveTenant, authToken).then((nextId) => {
      if (!isEditingDoctor) {
        setDoctorPublicId(nextId);
      }
    });
    void sevacareApi.getLookups().then((data) => {
      setSpecializationOptions(data.specializations ?? []);
      if ((data.specializations ?? []).length > 0) {
        setDoctorSpecialty(data.specializations[0]);
      }
    });
  };

  useEffect(() => {
    refreshData();
  }, [authToken, effectiveTenant]);

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Doctor management" subtitle={hospitalName} />
      <AdminNav selected="doctorManagement" onChange={onNavigate as (value: AdminNavValue) => void} />

      <Card>
        <Text style={styles.cardTitle}>Add or update doctor</Text>
        <Text style={styles.cardBody}>Doctor ID: {doctorPublicId || 'Loading next ID...'}</Text>
        <SearchField value={doctorName} onChangeText={setDoctorName} placeholder="Doctor name (required)" showIcon={false} />
        {!doctorName.trim() && isEditingDoctor === false && (
          <Text style={{ color: '#EF4444', fontSize: 12, marginTop: 4 }}>Doctor name is mandatory</Text>
        )}
        <DropdownSelect
          label="Specialty"
          value={doctorSpecialty}
          options={(specializationOptions.length > 0 ? specializationOptions : ['Cardiologist', 'Neurologist', 'Gynecologist', 'Skin Specialist', 'General Physician']).map((item) => ({ label: item, value: item }))}
          onChange={(value) => setDoctorSpecialty(String(value))}
        />
        <SearchField value={doctorAvailableFrom} onChangeText={setDoctorAvailableFrom} placeholder="Available from (YYYY-MM-DD)" showIcon={false} />
        <SearchField value={doctorFee} onChangeText={setDoctorFee} placeholder="Fee" showIcon={false} />
        <View style={{ marginVertical: 8 }}>
          <Text style={{ fontSize: 13, fontWeight: '600', marginBottom: 8 }}>Ready to look patients</Text>
          <SegmentedControl
            items={[
              { label: 'Yes', value: 'yes' },
              { label: 'No', value: 'no' },
            ]}
            selected={doctorReadyToLook ? 'yes' : 'no'}
            onChange={(value) => setDoctorReadyToLook(value === 'yes')}
          />
        </View>
        <View style={styles.rowGap}>
          <PrimaryButton
            label={isEditingDoctor ? 'Update Doctor' : 'Add Doctor'}
            onPress={() => {
              if (!doctorName.trim()) {
                return;
              }
              if (!authToken || !effectiveTenant || !doctorPublicId.trim()) {
                return;
              }
              const payload = {
                fullName: doctorName || 'Doctor',
                specialty: doctorSpecialty || 'Cardiologist',
                availability: doctorAvailability || 'Today · Open',
                fee: doctorFee || '₹500',
                active: true,
                availableFrom: doctorAvailableFrom || undefined,
                readyToLookPatients: doctorReadyToLook,
              };

              if (isEditingDoctor) {
                void sevacareApi.upsertDoctorRecord(effectiveTenant, doctorPublicId.trim(), authToken, payload).then(() => {
                  setIsEditingDoctor(false);
                  setDoctorName('');
                  refreshData();
                });
              } else {
                void sevacareApi.createDoctorRecord(effectiveTenant, authToken, payload).then((created) => {
                  setDoctorPublicId(created.doctorPublicId);
                  setDoctorName('');
                  refreshData();
                });
              }
            }}
          />
          <SecondaryButton
            label="New Doctor"
            onPress={() => {
              setIsEditingDoctor(false);
              setDoctorName('');
              setDoctorAvailability('Today · Open');
              setDoctorFee('₹500');
              setDoctorAvailableFrom('');
              setDoctorReadyToLook(true);
              if (authToken && effectiveTenant) {
                void sevacareApi.getNextDoctorPublicId(effectiveTenant, authToken).then(setDoctorPublicId);
              }
            }}
          />
          <SecondaryButton label="Refresh" onPress={refreshData} />
        </View>
      </Card>

      <View style={styles.stackGap}>
        {doctorRecords.map((doctor) => (
          <Pressable
            key={doctor.doctorPublicId}
            onPress={() => {
              setIsEditingDoctor(true);
              setDoctorPublicId(doctor.doctorPublicId);
              setDoctorName(doctor.fullName);
              setDoctorSpecialty(doctor.specialty);
              setDoctorAvailability(doctor.availability);
              setDoctorFee(doctor.fee);
              setDoctorAvailableFrom((doctor as any).availableFrom || '');
              setDoctorReadyToLook((doctor as any).readyToLookPatients !== false);
            }}
          >
            <Card>
            <Text style={styles.cardTitle}>{doctor.doctorPublicId} · {doctor.fullName}</Text>
            <Text style={styles.cardBody}>{doctor.specialty} · {doctor.availability} · {doctor.fee}</Text>
            <DangerButton
              label="Delete doctor"
              onPress={() => {
                if (!authToken || !effectiveTenant) {
                  return;
                }
                void sevacareApi.deleteDoctorRecord(effectiveTenant, doctor.doctorPublicId, authToken).then(() => {
                  if (doctorPublicId === doctor.doctorPublicId) {
                    setIsEditingDoctor(false);
                    setDoctorName('');
                  }
                  refreshData();
                });
              }}
            />
            </Card>
          </Pressable>
        ))}
      </View>

      <Card>
        <Text style={styles.cardTitle}>Patients (view only)</Text>
        <View style={styles.stackGap}>
          {patientRecords.map((patient) => (
            <Text key={patient.patientPublicId} style={styles.cardBody}>
              {patient.patientPublicId} · {patient.fullName} · {patient.mobileNumber} · {patient.status}
            </Text>
          ))}
        </View>
      </Card>
    </AppShell>
  );
}

export function AdminUsersScreen({
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
  const authToken = useAppStore((state) => state.authToken);
  const sessionTenantPublicId = useAppStore((state) => state.sessionTenantPublicId);
  const [adminUsers, setAdminUsers] = useState<AdminUserRecord[]>([]);
  const [activeFilter, setActiveFilter] = useState<'all' | 'active'>('all');
  const [adminPublicId, setAdminPublicId] = useState('');
  const [adminFullName, setAdminFullName] = useState('');
  const [adminName, setAdminName] = useState('');
  const [adminEmail, setAdminEmail] = useState('');
  const [adminMobile, setAdminMobile] = useState('');
  const [adminActive, setAdminActive] = useState(true);
  const [isEditingAdmin, setIsEditingAdmin] = useState(false);
  const [feedbackMessage, setFeedbackMessage] = useState<string | null>(null);

  const effectiveTenant = useMemo(() => sessionTenantPublicId, [sessionTenantPublicId]);

  const resetForm = (nextId = '') => {
    setIsEditingAdmin(false);
    setAdminPublicId(nextId);
    setAdminFullName('');
    setAdminName('');
    setAdminEmail('');
    setAdminMobile('');
    setAdminActive(true);
  };

  const refreshAdminUsers = () => {
    if (!authToken || !effectiveTenant) {
      return;
    }

    void sevacareApi.listAdminUsers(effectiveTenant, authToken, activeFilter === 'active')
      .then((data) => setAdminUsers(data.admins))
      .catch(() => setAdminUsers([]));

    if (!isEditingAdmin) {
      void sevacareApi.getNextAdminPublicId(effectiveTenant, authToken)
        .then((nextId) => setAdminPublicId(nextId))
        .catch(() => setAdminPublicId(''));
    }
  };

  useEffect(() => {
    refreshAdminUsers();
  }, [authToken, effectiveTenant, activeFilter]);

  const submitAdminUser = () => {
    if (!authToken || !effectiveTenant || !adminFullName.trim()) {
      return;
    }

    const payload = {
      fullName: adminFullName.trim(),
      name: adminName.trim() || undefined,
      email: adminEmail.trim() || undefined,
      mobileNumber: adminMobile.trim() || undefined,
      active: adminActive,
    };

    const request = isEditingAdmin
      ? sevacareApi.updateAdminUser(effectiveTenant, adminPublicId, authToken, payload)
      : sevacareApi.createAdminUser(effectiveTenant, authToken, payload);

    void request
      .then((admin) => {
        setFeedbackMessage(isEditingAdmin ? `Updated ${admin.fullName}` : `Added ${admin.fullName}`);
        resetForm('');
        void sevacareApi.getNextAdminPublicId(effectiveTenant, authToken).then((nextId) => setAdminPublicId(nextId));
        refreshAdminUsers();
      })
      .catch((error: Error) => {
        setFeedbackMessage(error.message);
      });
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Admin users" subtitle={hospitalName} />
      <AdminNav selected="adminUsers" onChange={onNavigate as (value: AdminNavValue) => void} />

      <Card>
        <Text style={styles.cardTitle}>Add or update admin user</Text>
        <Text style={styles.cardBody}>Admin ID: {adminPublicId || 'Loading next ID...'}</Text>
        <SearchField value={adminFullName} onChangeText={setAdminFullName} placeholder="Admin full name (required)" showIcon={false} />
        <SearchField value={adminName} onChangeText={setAdminName} placeholder="Display name" showIcon={false} />
        <SearchField value={adminEmail} onChangeText={setAdminEmail} placeholder="Email address" showIcon={false} />
        <SearchField value={adminMobile} onChangeText={setAdminMobile} placeholder="Mobile number" showIcon={false} />
        <View style={{ marginVertical: 8 }}>
          <Text style={{ fontSize: 13, fontWeight: '600', marginBottom: 8 }}>Status</Text>
          <SegmentedControl
            items={[
              { label: 'Active', value: 'active' },
              { label: 'Inactive', value: 'inactive' },
            ]}
            selected={adminActive ? 'active' : 'inactive'}
            onChange={(value) => setAdminActive(value === 'active')}
          />
        </View>
        {feedbackMessage ? <Text style={styles.cardBody}>{feedbackMessage}</Text> : null}
        <View style={styles.rowGap}>
          <PrimaryButton label={isEditingAdmin ? 'Update Admin User' : 'Add Admin User'} onPress={submitAdminUser} />
          <SecondaryButton
            label="New Admin User"
            onPress={() => {
              setFeedbackMessage(null);
              if (authToken && effectiveTenant) {
                void sevacareApi.getNextAdminPublicId(effectiveTenant, authToken).then((nextId) => resetForm(nextId));
              } else {
                resetForm('');
              }
            }}
          />
          <SecondaryButton label="Refresh" onPress={refreshAdminUsers} />
        </View>
      </Card>

      <SectionHeader title="Admin roster" />
      <SegmentedControl
        items={[
          { label: 'All', value: 'all' },
          { label: 'Active only', value: 'active' },
        ]}
        selected={activeFilter}
        onChange={(value) => setActiveFilter(value as 'all' | 'active')}
      />

      {adminUsers.length === 0 ? (
        <EmptyState icon="🛡️" title="No admin users found" subtitle="Create the first admin user for this tenant." />
      ) : (
        <View style={styles.stackGap}>
          {adminUsers.map((admin) => (
            <Card key={admin.adminPublicId}>
              <View style={styles.rowBetween}>
                <View style={{ flex: 1, gap: 6 }}>
                  <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                    <Avatar name={admin.fullName} size={40} />
                    <View style={{ flex: 1 }}>
                      <Text style={styles.cardTitle}>{admin.fullName}</Text>
                      <Text style={styles.cardBody}>{admin.adminPublicId}</Text>
                    </View>
                  </View>
                  <Text style={styles.cardBody}>Email: {admin.email || 'Not set'}</Text>
                  <Text style={styles.cardBody}>Mobile: {admin.mobileNumber || 'Not set'}</Text>
                  <Text style={styles.cardBody}>Display: {admin.name || admin.fullName}</Text>
                </View>
                <StatusBadge status={admin.active ? 'active' : 'inactive'} />
              </View>
              <View style={styles.rowGap}>
                <SecondaryButton
                  label="Edit admin"
                  onPress={() => {
                    setIsEditingAdmin(true);
                    setAdminPublicId(admin.adminPublicId);
                    setAdminFullName(admin.fullName);
                    setAdminName(admin.name || '');
                    setAdminEmail(admin.email || '');
                    setAdminMobile(admin.mobileNumber || '');
                    setAdminActive(admin.active);
                    setFeedbackMessage(null);
                  }}
                />
                {admin.active ? (
                  <DangerButton
                    label="Deactivate admin"
                    onPress={() => {
                      if (!authToken || !effectiveTenant) {
                        return;
                      }
                      void sevacareApi.deactivateAdminUser(effectiveTenant, admin.adminPublicId, authToken)
                        .then(() => {
                          setFeedbackMessage(`Deactivated ${admin.fullName}`);
                          if (adminPublicId === admin.adminPublicId) {
                            resetForm('');
                          }
                          refreshAdminUsers();
                        })
                        .catch((error: Error) => setFeedbackMessage(error.message));
                    }}
                  />
                ) : null}
              </View>
            </Card>
          ))}
        </View>
      )}
    </AppShell>
  );
}

export function AdminReportsScreen({
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
  const authToken = useAppStore((state) => state.authToken);
  const sessionTenantPublicId = useAppStore((state) => state.sessionTenantPublicId);
  const [metrics, setMetrics] = useState<AdminOverviewMetric[]>([]);
  const [appointments, setAppointments] = useState<AppointmentRecord[]>([]);

  useEffect(() => {
    if (!authToken || !sessionTenantPublicId) return;
    sevacareApi.getAdminOverview(sessionTenantPublicId, authToken)
      .then((data) => setMetrics(data.metrics))
      .catch(() => setMetrics([]));
    sevacareApi.listAppointmentRecords(sessionTenantPublicId, authToken)
      .then((data) => setAppointments(data.appointments ?? []))
      .catch(() => setAppointments([]));
  }, [authToken, sessionTenantPublicId]);

  const upcomingCount = appointments.filter((a) => a.status === 'upcoming').length;
  const cancelledCount = appointments.filter((a) => a.status === 'cancelled').length;
  const completedCount = appointments.filter((a) => a.status !== 'upcoming' && a.status !== 'cancelled').length;

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Reports & Analytics" subtitle={hospitalName} />

      <SectionHeader title="Overview" />
      <View style={styles.metricsRow}>
        {metrics.map((metric) => (
          <MetricTile key={metric.label} value={metric.value} label={metric.label} trend={metric.trend} />
        ))}
      </View>

      <SectionHeader title="Appointment Breakdown" />
      <View style={styles.metricsRow}>
        <MetricTile value={String(upcomingCount)} label="Upcoming" />
        <MetricTile value={String(completedCount)} label="Completed" />
        <MetricTile value={String(cancelledCount)} label="Cancelled" />
      </View>

      <SectionHeader title="Recent Appointments" />
      {appointments.length === 0 ? (
        <EmptyState icon="📊" title="No data yet" subtitle="Appointments will appear here once booked" />
      ) : (
        <View style={styles.stackGap}>
          {appointments.slice(0, 10).map((appt) => (
            <Card key={appt.appointmentPublicId}>
              <View style={styles.rowBetween}>
                <View>
                  <Text style={styles.cardTitle}>{appt.appointmentPublicId}</Text>
                  <Text style={styles.cardBody}>Patient: {appt.patientPublicId} · Doctor: {appt.doctorPublicId}</Text>
                  <Text style={styles.cardBody}>Slot: {appt.slot}</Text>
                </View>
                <StatusBadge status={appt.status} />
              </View>
            </Card>
          ))}
        </View>
      )}
    </AppShell>
  );
}

const styles = StyleSheet.create({
  metricsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 12,
  },
  stackGap: {
    gap: 12,
  },
  rowGap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
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
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    gap: 10,
  },
});
