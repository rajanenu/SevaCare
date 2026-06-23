import { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ActivityIndicator,
  Pressable,
  FlatList,
} from 'react-native';
import { useTheme } from '../providers/theme-provider';
import { sevacareApi } from '../api/client';
import {
  AppShell,
  PageHeader,
  PrimaryButton,
  SecondaryButton,
  Card,
  BackButton,
} from '../components/ui';
import type { AppScreen, BottomNavItem } from '../types/app';

export function DoctorAppointmentRequestsScreen({
  currentScreen,
  onNavigate,
  bottomItems,
  hospitalName,
  tenantPublicId,
  doctorPublicId,
}: {
  currentScreen: AppScreen;
  onNavigate: (screen: AppScreen) => void;
  bottomItems: BottomNavItem[];
  hospitalName: string;
  tenantPublicId: string;
  doctorPublicId: string;
}) {
  const theme = useTheme();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [requests, setRequests] = useState<any[]>([]);
  const [selectedRequest, setSelectedRequest] = useState<any>(null);
  const [confirmingRequestId, setConfirmingRequestId] = useState<string | null>(null);
  const [assignedSlot, setAssignedSlot] = useState('');
  const [notes, setNotes] = useState('');

  // Load requests on mount
  useEffect(() => {
    loadRequests();
  }, [tenantPublicId, doctorPublicId]);

  const loadRequests = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await sevacareApi.get(
        `/doctors/${tenantPublicId}/${doctorPublicId}/appointment-requests`
      );
      setRequests(response.data?.result?.requests || []);
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to load appointment requests');
    } finally {
      setLoading(false);
    }
  };

  const handleConfirmAppointment = async () => {
    if (!selectedRequest) return;
    if (!assignedSlot.trim()) {
      setError('Please specify an appointment slot');
      return;
    }

    try {
      setConfirmingRequestId(selectedRequest.requestPublicId);
      await sevacareApi.post(
        `/doctors/${tenantPublicId}/${doctorPublicId}/appointment-requests/${selectedRequest.requestPublicId}/confirm`,
        {
          assignedSlot,
          notes,
        }
      );
      // Refresh requests after confirmation
      await loadRequests();
      setSelectedRequest(null);
      setAssignedSlot('');
      setNotes('');
    } catch (err: any) {
      setError(err.response?.data?.message || 'Failed to confirm appointment');
    } finally {
      setConfirmingRequestId(null);
    }
  };

  if (loading) {
    return (
      <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
        <View style={{ justifyContent: 'center', alignItems: 'center', paddingTop: 80 }}>
          <ActivityIndicator size="large" color={theme.primary} />
          <Text style={{ color: theme.text, marginTop: 16 }}>Loading appointment requests...</Text>
        </View>
      </AppShell>
    );
  }

  return (
    <AppShell currentScreen={currentScreen} onNavigate={onNavigate} bottomItems={bottomItems} hospitalName={hospitalName}>
      <View style={{ paddingBottom: 16 }}>
        <BackButton onPress={() => setSelectedRequest(null)} />
      </View>
      <PageHeader title={selectedRequest ? 'Request Details' : 'Appointment Requests'} />

      {error && (
        <Card style={{ backgroundColor: theme.errorSurface, marginHorizontal: 16, marginBottom: 12 }}>
          <Text style={{ color: theme.error }}>{error}</Text>
        </Card>
      )}

      {selectedRequest ? (
        // Detail View
        <ScrollView style={{ paddingHorizontal: 16 }}>
          <Card>
            <Text style={{ color: theme.text, fontWeight: '600', fontSize: 16, marginBottom: 12 }}>Patient Information</Text>
            <View style={styles.detailRow}>
              <Text style={{ color: theme.textMuted }}>Name:</Text>
              <Text style={{ color: theme.text, fontWeight: '600' }}>{selectedRequest.patientName}</Text>
            </View>
            <View style={styles.detailRow}>
              <Text style={{ color: theme.textMuted }}>Age:</Text>
              <Text style={{ color: theme.text, fontWeight: '600' }}>{selectedRequest.patientAge}</Text>
            </View>
            <View style={styles.detailRow}>
              <Text style={{ color: theme.textMuted }}>Mobile:</Text>
              <Text style={{ color: theme.text, fontWeight: '600' }}>{selectedRequest.patientMobile}</Text>
            </View>
          </Card>

          <Card>
            <Text style={{ color: theme.text, fontWeight: '600', fontSize: 16, marginBottom: 12 }}>Medical Details</Text>
            <Text style={{ color: theme.textMuted, marginBottom: 4 }}>Symptoms/Reason:</Text>
            <Text style={{ color: theme.text, marginBottom: 12 }}>{selectedRequest.symptoms}</Text>
            <View style={styles.detailRow}>
              <Text style={{ color: theme.textMuted }}>Preferred Date:</Text>
              <Text style={{ color: theme.text, fontWeight: '600' }}>{selectedRequest.preferredDate}</Text>
            </View>
            <View style={styles.detailRow}>
              <Text style={{ color: theme.textMuted }}>Status:</Text>
              <Text style={{ color: theme.text, fontWeight: '600', textTransform: 'capitalize' }}>
                {selectedRequest.requestStatus}
              </Text>
            </View>
          </Card>

          {selectedRequest.requestStatus === 'pending' && (
            <Card>
              <Text style={{ color: theme.text, fontWeight: '600', fontSize: 16, marginBottom: 12 }}>Assign Appointment</Text>
              
              <Text style={{ color: theme.text, fontWeight: '600', marginBottom: 8 }}>Time Slot *</Text>
              <View style={[styles.input, { borderColor: theme.border, backgroundColor: theme.card }]}>
                <Text
                  style={{ color: assignedSlot ? theme.text : theme.textMuted, padding: 12 }}
                >
                  {assignedSlot || 'Enter time slot (e.g., 2024-04-15 14:30)'}
                </Text>
              </View>

              <Text style={{ color: theme.text, fontWeight: '600', marginBottom: 8, marginTop: 12 }}>Notes (Optional)</Text>
              <View style={[styles.input, { borderColor: theme.border, backgroundColor: theme.card, minHeight: 80 }]}>
                <Text
                  style={{ color: notes ? theme.text : theme.textMuted, padding: 12 }}
                >
                  {notes || 'Add any notes or instructions...'}
                </Text>
              </View>

              <View style={{ paddingVertical: 16, gap: 8 }}>
                <PrimaryButton
                  label={confirmingRequestId === selectedRequest.requestPublicId ? 'Confirming...' : 'Confirm Appointment'}
                  onPress={handleConfirmAppointment}
                  disabled={confirmingRequestId === selectedRequest.requestPublicId}
                />
                <SecondaryButton label="Cancel" onPress={() => setSelectedRequest(null)} />
              </View>
            </Card>
          )}

          {selectedRequest.requestStatus === 'confirmed' && selectedRequest.assignedSlot && (
            <Card style={{ backgroundColor: theme.successSurface }}>
              <Text style={{ color: theme.success, fontWeight: '600', marginBottom: 8 }}>Appointment Confirmed</Text>
              <Text style={{ color: theme.success, marginBottom: 4 }}>Slot: {selectedRequest.assignedSlot}</Text>
              {selectedRequest.notes && (
                <Text style={{ color: theme.success, marginTop: 4 }}>Notes: {selectedRequest.notes}</Text>
              )}
            </Card>
          )}
        </ScrollView>
      ) : (
        // List View
        <View style={{ paddingHorizontal: 16, flex: 1 }}>
          {requests.length === 0 ? (
            <Card style={{ marginTop: 32, alignItems: 'center', paddingVertical: 32 }}>
              <Text style={{ color: theme.textMuted, fontSize: 16 }}>No appointment requests</Text>
            </Card>
          ) : (
            <FlatList
              data={requests}
              keyExtractor={(item) => item.requestPublicId}
              scrollEnabled={false}
              renderItem={({ item }) => (
                <Pressable
                  onPress={() => setSelectedRequest(item)}
                  style={[
                    styles.requestCard,
                    {
                      backgroundColor: item.requestStatus === 'pending' ? theme.primary + '10' : theme.card,
                      borderColor: item.requestStatus === 'pending' ? theme.primary : theme.border,
                    }
                  ]}
                >
                  <View style={{ flex: 1 }}>
                    <Text style={{ color: theme.text, fontWeight: '600', fontSize: 14 }}>{item.patientName}</Text>
                    <Text style={{ color: theme.textMuted, fontSize: 12, marginTop: 4 }}>
                      Age {item.patientAge} • {item.symptoms.substring(0, 40)}...
                    </Text>
                    <Text style={{ color: theme.textMuted, fontSize: 11, marginTop: 4 }}>
                      Preferred: {item.preferredDate}
                    </Text>
                  </View>
                  <View style={{ alignItems: 'flex-end' }}>
                    <Text
                      style={{
                        color: item.requestStatus === 'pending' ? theme.warning : theme.success,
                        fontWeight: '600',
                        fontSize: 12,
                        textTransform: 'capitalize',
                      }}
                    >
                      {item.requestStatus}
                    </Text>
                  </View>
                </Pressable>
              )}
              ListFooterComponent={<View style={{ height: 20 }} />}
            />
          )}
        </View>
      )}
    </AppShell>
  );
}

const styles = StyleSheet.create({
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  input: {
    borderWidth: 1,
    borderRadius: 8,
    minHeight: 44,
  },
  requestCard: {
    borderWidth: 1,
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
    flexDirection: 'row',
    alignItems: 'center',
  },
});
