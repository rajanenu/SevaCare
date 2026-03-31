import { Platform, Pressable, StyleSheet, Text, View, ScrollView, TextInput, FlatList } from 'react-native';
import { useState, useCallback } from 'react';
import { AppShell, BackButton, Card, Chip, PageHeader, PrimaryButton, SecondaryButton } from '../components/ui';
import { useTenantConfig, useTheme } from '../providers/theme-provider';
import { type AppScreen, type BottomNavItem } from '../types/app';
import { usePatientPrescriptions, usePrescriptionDetail, useUploadPrescription, useMedicalHistory } from '../hooks/useApi';
import type { PrescriptionDetailView, MedicineView, MedicalHistoryRecord } from '../api/types';

const FONT = Platform.select({ web: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif', default: 'System' }) as string;

/**
 * Patient Prescription List Screen
 * Displays all prescriptions for the logged-in patient
 */
export function PrescriptionListScreen({
  activeTenant,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
  onSelectPrescription,
}: {
  activeTenant: string;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  onSelectPrescription?: (id: string) => void;
}) {
  const theme = useTheme();
  const config = useTenantConfig();
  const { data: prescriptionCollection, loading, error, execute } = usePatientPrescriptions();

  const prescriptions = prescriptionCollection?.prescriptions || [];

  const handleSelectPrescription = (id: string) => {
    if (onSelectPrescription) {
      onSelectPrescription(id);
    } else {
      onNavigate('prescription-detail');
    }
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="My Prescriptions" subtitle={`Total: ${prescriptions.length}`} />
      
      {error && (
        <Card>
          <View style={[{ borderLeftWidth: 4, borderLeftColor: '#ef4444', padding: 12 }]}>
            <Text style={{ color: '#ef4444', fontWeight: '600' }}>Error loading prescriptions</Text>
            <Text style={{ color: theme.textMuted, fontSize: 12, marginTop: 4 }}>{error.message}</Text>
            <PrimaryButton label="Retry" onPress={() => execute()} />
          </View>
        </Card>
      )}

      {loading && !prescriptions.length && (
        <Card>
          <Text style={{ color: theme.textMuted }}>Loading prescriptions...</Text>
        </Card>
      )}

      {!loading && prescriptions.length === 0 && (
        <Card>
          <Text style={[styles.cardTitle, { color: theme.text }]}>No Prescriptions Yet</Text>
          <Text style={[styles.cardBody, { color: theme.textMuted }]}>
            Prescriptions from your doctor visits will appear here
          </Text>
        </Card>
      )}

      <FlatList
        data={prescriptions}
        keyExtractor={(item) => item.prescriptionPublicId}
        scrollEnabled={false}
        renderItem={({ item }) => (
          <Pressable onPress={() => handleSelectPrescription(item.prescriptionPublicId)}>
            <View style={{ marginVertical: 8 }}>
              <Card>
              <View style={styles.rowBetween}>
                <View style={{ flex: 1 }}>
                  <Text style={[styles.cardTitle, { color: theme.text }]}>
                    Rx-{item.prescriptionPublicId.substring(0, 6)}
                  </Text>
                  <Text style={[styles.cardBody, { color: theme.textMuted }]}>
                    {item.doctorName}
                  </Text>
                </View>
                <Chip label={item.status} />
              </View>
              <View style={[styles.metaRowWrap, { marginTop: 8 }]}>
                <Chip label={`${item.medicines.length} medicine(s)`} />
                <Chip label={item.issuedOn} />
              </View>
            </Card>
            </View>
          </Pressable>
        )}
      />
    </AppShell>
  );
}

/**
 * Prescription Detail Screen
 * Shows full prescription details including medicines and doctor notes
 */
export function PrescriptionDetailScreen({
  prescriptionId,
  activeTenant,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
}: {
  prescriptionId: string;
  activeTenant: string;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
}) {
  const theme = useTheme();
  const { data: prescription, loading, error } = usePrescriptionDetail(prescriptionId);

  const handleDownload = () => {
    // Implementation: Download PDF or show download options
    console.log('Download prescription:', prescriptionId);
  };

  const handleShare = () => {
    // Implementation: Share prescription via SMS/Email
    console.log('Share prescription:', prescriptionId);
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <PageHeader title="Prescription Details" />

      {error && (
        <Card>
          <View style={[{ borderLeftWidth: 4, borderLeftColor: '#ef4444', padding: 12 }]}>
            <Text style={{ color: '#ef4444', fontWeight: '600' }}>Error loading prescription</Text>
            <Text style={{ color: theme.textMuted, fontSize: 12, marginTop: 4 }}>{error.message}</Text>
          </View>
        </Card>
      )}

      {loading && (
        <Card>
          <Text style={{ color: theme.textMuted }}>Loading prescription details...</Text>
        </Card>
      )}

      {prescription && (
        <ScrollView style={{ flex: 1 }}>
          {/* Prescription Header */}
          <Card>
            <View style={styles.rowBetween}>
              <View>
                <Text style={[styles.cardTitle, { color: theme.text }]}>
                  Prescription ID: {prescription.prescriptionPublicId}
                </Text>
                <Text style={[styles.cardBody, { color: theme.textMuted }]}>
                  {prescription.doctorName}
                </Text>
              </View>
              <Chip label={prescription.status} />
            </View>
            <View style={[styles.metaRowWrap, { marginTop: 12 }]}>
              <Chip label={`Issued: ${prescription.issuedOn}`} />
              {prescription.validUntil && <Chip label={`Valid: ${prescription.validUntil}`} />}
            </View>
          </Card>

          {/* Medicines */}
          <Card>
            <Text style={[styles.cardTitle, { color: theme.text }]}>Medicines</Text>
            {prescription.medicines.map((medicine, index) => (
              <MedicineCard key={index} medicine={medicine} index={index + 1} theme={theme} />
            ))}
          </Card>

          {/* Notes */}
          {prescription.notes && (
            <Card>
              <Text style={[styles.cardTitle, { color: theme.text }]}>Doctor's Notes</Text>
              <Text style={[styles.cardBody, { color: theme.textMuted }]}>{prescription.notes}</Text>
            </Card>
          )}

          {/* Actions */}
          <View style={styles.buttonRow}>
            {prescription.fileUrl && (
              <PrimaryButton label="Download PDF" onPress={handleDownload} />
            )}
            <SecondaryButton label="Share" onPress={handleShare} />
          </View>
        </ScrollView>
      )}
    </AppShell>
  );
}

/**
 * Medicine Upload Screen (For Doctors)
 * Allows doctors to issue prescriptions with multiple medicines
 */
export function MedicineUploadScreen({
  patientPublicId: initialPatientId = '',
  appointmentId,
  activeTenant,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
  onUploadSuccess,
}: {
  patientPublicId?: string;
  appointmentId?: string;
  activeTenant: string;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  onUploadSuccess?: (prescriptionId: string) => void;
}) {
  const theme = useTheme();
  const { uploading, error, upload } = useUploadPrescription(
    (prescriptionId) => {
      onUploadSuccess?.(prescriptionId);
      onNavigate('prescription');
    }
  );

  const [patientPublicId, setPatientPublicId] = useState(initialPatientId);
  const [medicines, setMedicines] = useState<any[]>([{ name: '', strength: '', frequency: '', duration: '', instructions: '' }]);
  const [notes, setNotes] = useState('');
  const [adding, setAdding] = useState(false);

  const addMedicineField = () => {
    setMedicines([...medicines, { name: '', strength: '', frequency: '', duration: '', instructions: '' }]);
  };

  const removeMedicineField = (index: number) => {
    setMedicines(medicines.filter((_, i) => i !== index));
  };

  const updateMedicine = (index: number, field: string, value: string) => {
    const updated = [...medicines];
    updated[index] = { ...updated[index], [field]: value };
    setMedicines(updated);
  };

  const handleSubmit = async () => {
    if (medicines.some((m) => !m.name || !m.frequency || !m.duration)) {
      alert('Please fill in all required medicine fields');
      return;
    }

    try {
      setAdding(true);
      await upload({
        patientPublicId,
        appointmentPublicId: appointmentId,
        medicines: medicines.map((m) => ({
          name: m.name,
          strength: m.strength,
          frequency: m.frequency,
          duration: m.duration,
          instructions: m.instructions,
        })),
        notes,
      });
    } catch (err) {
      console.error('Upload failed:', err);
    } finally {
      setAdding(false);
    }
  };

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('doctorDashboard')} />
      </View>
      <PageHeader title="Issue Prescription" subtitle={patientPublicId ? `Patient: ${patientPublicId}` : 'Enter patient details below'} />

      {error && (
        <Card>
          <View style={[{ borderLeftWidth: 4, borderLeftColor: '#ef4444', padding: 12 }]}>
            <Text style={{ color: '#ef4444', fontWeight: '600' }}>Upload failed</Text>
            <Text style={{ color: theme.textMuted, fontSize: 12, marginTop: 4 }}>{error.message}</Text>
          </View>
        </Card>
      )}

      <ScrollView style={{ flex: 1 }}>
        {/* Patient Identity Section */}
        {!initialPatientId && (
          <Card>
            <Text style={[styles.cardTitle, { color: theme.text }]}>Patient Details</Text>
            <FormField
              label="Patient ID *"
              value={patientPublicId}
              onChangeText={setPatientPublicId}
              placeholder="e.g., P-1001"
              theme={theme}
            />
          </Card>
        )}
        <Card>
          <Text style={[styles.cardTitle, { color: theme.text }]}>Medicines</Text>
          {medicines.map((medicine, index) => (
            <View key={index} style={{ marginBottom: 16, paddingBottom: 16, borderBottomWidth: 1, borderBottomColor: theme.border }}>
              <View style={styles.rowBetween}>
                <Text style={{ color: theme.text, fontWeight: '600' }}>Medicine {index + 1}</Text>
                {index > 0 && (
                  <Pressable onPress={() => removeMedicineField(index)}>
                    <Text style={{ color: '#ef4444' }}>Remove</Text>
                  </Pressable>
                )}
              </View>

              <FormField
                label="Medicine Name *"
                value={medicine.name}
                onChangeText={(value) => updateMedicine(index, 'name', value)}
                placeholder="e.g., Paracetamol"
                theme={theme}
              />
              <FormField
                label="Strength"
                value={medicine.strength}
                onChangeText={(value) => updateMedicine(index, 'strength', value)}
                placeholder="e.g., 500mg"
                theme={theme}
              />
              <FormField
                label="Frequency *"
                value={medicine.frequency}
                onChangeText={(value) => updateMedicine(index, 'frequency', value)}
                placeholder="e.g., Twice daily"
                theme={theme}
              />
              <FormField
                label="Duration *"
                value={medicine.duration}
                onChangeText={(value) => updateMedicine(index, 'duration', value)}
                placeholder="e.g., 7 days"
                theme={theme}
              />
              <FormField
                label="Instructions"
                value={medicine.instructions}
                onChangeText={(value) => updateMedicine(index, 'instructions', value)}
                placeholder="e.g., Take with food"
                theme={theme}
                multiline
              />
            </View>
          ))}

          <SecondaryButton label="+ Add Medicine" onPress={addMedicineField} />
        </Card>

        {/* Notes Section */}
        <Card>
          <Text style={[styles.cardTitle, { color: theme.text }]}>Additional Notes</Text>
          <TextInput
            style={[
              styles.input,
              {
                color: theme.text,
                borderColor: theme.border,
                backgroundColor: theme.background,
              },
            ]}
            placeholder="Add any special instructions or notes"
            placeholderTextColor={theme.textMuted}
            value={notes}
            onChangeText={setNotes}
            multiline
            numberOfLines={4}
          />
        </Card>

        {/* Submit Button */}
        <View style={styles.buttonRow}>
          <PrimaryButton
            label={uploading ? 'Submitting...' : 'Submit Prescription'}
            onPress={handleSubmit}
          />
          <SecondaryButton label="Cancel" onPress={() => onNavigate('prescription')} />
        </View>
      </ScrollView>
    </AppShell>
  );
}

/**
 * Medical History Screen
 * Shows complete medical history including past appointments, prescriptions, and conditions
 */
export function MedicalHistoryScreen({
  activeTenant,
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
}: {
  activeTenant: string;
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
}) {
  const theme = useTheme();
  const { data: history, loading, error } = useMedicalHistory();
  const [activeTab, setActiveTab] = useState<'overview' | 'appointments' | 'prescriptions' | 'records'>('overview');
  const [expandedRxId, setExpandedRxId] = useState<string | null>(null);

  if (loading) {
    return (
      <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
        <View style={styles.backRow}>
          <BackButton onPress={() => onNavigate('patientHome')} />
        </View>
        <PageHeader title="Medical History" />
        <Card>
          <Text style={{ color: theme.textMuted }}>Loading medical history...</Text>
        </Card>
      </AppShell>
    );
  }

  if (error) {
    return (
      <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
        <View style={styles.backRow}>
          <BackButton onPress={() => onNavigate('patientHome')} />
        </View>
        <PageHeader title="Medical History" />
        <Card>
          <View style={[{ borderLeftWidth: 4, borderLeftColor: '#ef4444', padding: 12 }]}>
            <Text style={{ color: '#ef4444', fontWeight: '600' }}>Error loading medical history</Text>
            <Text style={{ color: theme.textMuted, fontSize: 12, marginTop: 4 }}>{error.message}</Text>
          </View>
        </Card>
      </AppShell>
    );
  }

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={styles.backRow}>
        <BackButton onPress={() => onNavigate('patientHome')} />
      </View>
      <PageHeader title="Medical History" />

      {/* Tab Navigation */}
      <View style={[styles.tabContainer, { borderBottomColor: theme.border }]}>
        {(['overview', 'appointments', 'prescriptions', 'records'] as const).map((tab) => (
          <Pressable
            key={tab}
            onPress={() => setActiveTab(tab)}
            style={[styles.tab, activeTab === tab && { borderBottomColor: '#3b82f6', borderBottomWidth: 2 }]}
          >
            <Text style={{ color: activeTab === tab ? '#3b82f6' : theme.textMuted, fontWeight: '600' }}>
              {tab.charAt(0).toUpperCase() + tab.slice(1)}
            </Text>
          </Pressable>
        ))}
      </View>

      <ScrollView style={{ flex: 1 }}>
        {activeTab === 'overview' && history && (
          <>
            <Card>
              <Text style={[styles.cardTitle, { color: theme.text }]}>Overview</Text>
              <View style={{ marginTop: 12 }}>
                {history.lastCheckup && (
                  <View style={styles.rowBetween}>
                    <Text style={{ color: theme.textMuted }}>Last Checkup:</Text>
                    <Text style={{ color: theme.text, fontWeight: '600' }}>{history.lastCheckup}</Text>
                  </View>
                )}
                <View style={styles.rowBetween}>
                  <Text style={{ color: theme.textMuted }}>Follow-up Required:</Text>
                  <Text style={{ color: history.followUpRequired ? '#ef4444' : '#10b981', fontWeight: '600' }}>
                    {history.followUpRequired ? 'Yes' : 'No'}
                  </Text>
                </View>
              </View>
            </Card>

            {history.allergies.length > 0 && (
              <Card>
                <Text style={[styles.cardTitle, { color: theme.text }]}>⚠️ Allergies</Text>
                <View style={styles.metaRowWrap}>
                  {history.allergies.map((allergy, index) => (
                    <View key={index} style={{ backgroundColor: '#fee2e2', borderRadius: 4, padding: 4 }}>
                      <Chip label={typeof allergy === 'string' ? allergy : allergy.recordValue} />
                    </View>
                  ))}
                </View>
              </Card>
            )}

            {history.conditions.length > 0 && (
              <Card>
                <Text style={[styles.cardTitle, { color: theme.text }]}>Conditions</Text>
                <View style={styles.metaRowWrap}>
                  {history.conditions.map((condition, index) => (
                    <Chip key={index} label={typeof condition === 'string' ? condition : condition.recordValue} />
                  ))}
                </View>
              </Card>
            )}
          </>
        )}

        {activeTab === 'appointments' && history?.appointments && (
          <View>
            {history.appointments.map((apt) => (
              <Card key={apt.appointmentPublicId}>
                <View style={styles.rowBetween}>
                  <View>
                    <Text style={[styles.cardTitle, { color: theme.text }]}>{apt.doctorName}</Text>
                    <Text style={[styles.cardBody, { color: theme.textMuted }]}>{apt.slot}</Text>
                  </View>
                  <Chip label={apt.status} />
                </View>
              </Card>
            ))}
          </View>
        )}

        {activeTab === 'prescriptions' && history?.prescriptions && (
          <View>
            {history.prescriptions.map((rx) => (
              <Pressable
                key={rx.prescriptionPublicId}
                onPress={() => setExpandedRxId(expandedRxId === rx.prescriptionPublicId ? null : rx.prescriptionPublicId)}
              >
                <Card>
                  <View style={styles.rowBetween}>
                    <View style={{ flex: 1 }}>
                      <Text style={[styles.cardTitle, { color: theme.text }]}>{rx.doctorName}</Text>
                      <Text style={[styles.cardBody, { color: theme.textMuted }]}>
                        {rx.medicines.length} medicine(s) • {rx.issuedOn}
                      </Text>
                    </View>
                    <View style={{ alignItems: 'flex-end', gap: 4 }}>
                      <Chip label={rx.status} />
                      <Text style={{ color: '#2563EB', fontSize: 11, fontWeight: '600' }}>
                        {expandedRxId === rx.prescriptionPublicId ? '▲ Hide' : '▼ View Rx'}
                      </Text>
                    </View>
                  </View>
                  {expandedRxId === rx.prescriptionPublicId && (
                    <View style={{ marginTop: 10, paddingTop: 10, borderTopWidth: 1, borderTopColor: '#E5E7EB' }}>
                      {rx.medicines.map((med, idx) => (
                        <Text key={idx} style={[styles.cardBody, { color: theme.text, marginBottom: 4 }]}>
                          {'• '}{med.name}{med.strength ? ` ${med.strength}` : ''} — {med.frequency}, {med.duration}
                          {med.instructions ? `\n  (${med.instructions})` : ''}
                        </Text>
                      ))}
                      {'notes' in rx && (rx as { notes?: string }).notes ? (
                        <Text style={[styles.cardBody, { color: theme.textMuted, marginTop: 6, fontStyle: 'italic' }]}>
                          Notes: {(rx as { notes?: string }).notes}
                        </Text>
                      ) : null}
                    </View>
                  )}
                </Card>
              </Pressable>
            ))}
          </View>
        )}

        {activeTab === 'records' && history?.medicalRecords && (
          <View>
            {history.medicalRecords.map((record, index) => (
              <Card key={index}>
                <View style={styles.rowBetween}>
                  <View style={{ flex: 1 }}>
                    <Text style={[styles.cardTitle, { color: theme.text }]}>{record.recordValue}</Text>
                    <Text style={[styles.cardBody, { color: theme.textMuted }]}>
                      {record.recordType.toUpperCase()} {record.recordDate && `• ${record.recordDate}`}
                    </Text>
                  </View>
                </View>
                {record.notes && (
                  <Text style={[styles.cardBody, { color: theme.textMuted, marginTop: 8 }]}>
                    {record.notes}
                  </Text>
                )}
              </Card>
            ))}
          </View>
        )}
      </ScrollView>
    </AppShell>
  );
}

/**
 * Helper Components
 */

function MedicineCard({ medicine, index, theme }: { medicine: MedicineView; index: number; theme: any }) {
  return (
    <View style={{ marginBottom: 12, paddingBottom: 12, borderBottomWidth: 1, borderBottomColor: theme.border }}>
      <View style={styles.rowBetween}>
        <Text style={{ color: theme.text, fontWeight: '600' }}>
          {index}. {medicine.name}
          {medicine.strength && ` ${medicine.strength}`}
        </Text>
      </View>
      <Text style={{ color: theme.textMuted, fontSize: 12, marginTop: 4 }}>
        {medicine.frequency} for {medicine.duration}
      </Text>
      {medicine.instructions && (
        <Text style={{ color: theme.textMuted, fontSize: 12, marginTop: 4, fontStyle: 'italic' }}>
          {medicine.instructions}
        </Text>
      )}
    </View>
  );
}

function FormField({
  label,
  value,
  onChangeText,
  placeholder,
  theme,
  multiline = false,
}: {
  label: string;
  value: string;
  onChangeText: (value: string) => void;
  placeholder: string;
  theme: any;
  multiline?: boolean;
}) {
  return (
    <View style={{ marginBottom: 12 }}>
      <Text style={{ color: theme.text, fontWeight: '600', marginBottom: 4 }}>{label}</Text>
      <TextInput
        style={[
          styles.input,
          {
            color: theme.text,
            borderColor: theme.border,
            backgroundColor: theme.background,
          },
          multiline && { height: 80, textAlignVertical: 'top' },
        ]}
        placeholder={placeholder}
        placeholderTextColor={theme.textMuted}
        value={value}
        onChangeText={onChangeText}
        multiline={multiline}
        numberOfLines={multiline ? 3 : 1}
      />
    </View>
  );
}

// Styles
const styles = StyleSheet.create({
  backRow: {
    flexDirection: 'row',
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  cardBody: {
    fontSize: 14,
    lineHeight: 20,
  },
  rowBetween: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  metaRowWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginTop: 8,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
    marginVertical: 16,
  },
  input: {
    borderWidth: 1,
    borderRadius: 6,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 14,
  },
  tabContainer: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    marginVertical: 12,
  },
  tab: {
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderBottomWidth: 2,
    borderBottomColor: 'transparent',
  },
});
