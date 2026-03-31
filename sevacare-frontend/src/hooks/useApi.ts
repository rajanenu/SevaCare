import { useCallback, useState } from 'react';
import { sevacareApi } from '../api/client';
import type { ApiError } from '../api/types';
import AuthService from '../services/authService';

type AsyncState<T> = {
  data: T | null;
  loading: boolean;
  error: ApiError | null;
};

/**
 * Hook for making API calls with loading, error, and data states
 */
export function useApi<T>(
  apiCall: () => Promise<T>,
  options?: {
    onSuccess?: (data: T) => void;
    onError?: (error: ApiError) => void;
    autoFetch?: boolean;
  }
) {
  const [state, setState] = useState<AsyncState<T>>({
    data: null,
    loading: options?.autoFetch ?? false,
    error: null,
  });

  const execute = useCallback(async () => {
    setState((prev) => ({ ...prev, loading: true, error: null }));
    try {
      const result = await apiCall();
      setState({ data: result, loading: false, error: null });
      options?.onSuccess?.(result);
      return result;
    } catch (err) {
      const error: ApiError = {
        status: 0,
        message: err instanceof Error ? err.message : 'Unknown error',
      };
      setState({ data: null, loading: false, error });
      options?.onError?.(error);
      throw error;
    }
  }, [apiCall, options]);

  // Auto-fetch on mount if enabled
  useState(() => {
    if (options?.autoFetch) {
      execute();
    }
  });

  return { ...state, execute, retry: execute };
}

/**
 * Hook for authenticated API calls (includes token & tenant ID)
 */
export function useAuthenticatedApi<T>(
  apiCallFactory: (token: string, tenantId: string) => Promise<T>,
  options?: {
    onSuccess?: (data: T) => void;
    onError?: (error: ApiError) => void;
  }
) {
  const [state, setState] = useState<AsyncState<T>>({
    data: null,
    loading: true,
    error: null,
  });

  const execute = useCallback(async () => {
    setState((prev) => ({ ...prev, loading: true, error: null }));
    try {
      const token = await AuthService.getToken();
      const tenantId = await AuthService.getTenantId();

      if (!token || !tenantId) {
        throw new Error('Not authenticated');
      }

      const result = await apiCallFactory(token, tenantId);
      setState({ data: result, loading: false, error: null });
      options?.onSuccess?.(result);
      return result;
    } catch (err) {
      const error: ApiError = {
        status: 0,
        message: err instanceof Error ? err.message : 'Unknown error',
      };
      setState({ data: null, loading: false, error });
      options?.onError?.(error);
      throw error;
    }
  }, [apiCallFactory, options]);

  // Auto-fetch on mount
  useState(() => {
    execute();
  });

  return { ...state, execute, retry: execute };
}

/**
 * Hook for patient home data
 */
export function usePatientHome(options?: {
  onSuccess?: (data: any) => void;
  onError?: (error: ApiError) => void;
}) {
  return useAuthenticatedApi(
    async (token, tenantId) => {
      const userId = await AuthService.getUserId();
      if (!userId) throw new Error('User ID not found');
      return sevacareApi.getPatientHome(tenantId, userId, token);
    },
    options
  );
}

/**
 * Hook for booking setup data
 */
export function useBookingSetup(options?: {
  onSuccess?: (data: any) => void;
  onError?: (error: ApiError) => void;
}) {
  return useAuthenticatedApi(
    async (token, tenantId) => {
      const userId = await AuthService.getUserId();
      if (!userId) throw new Error('User ID not found');
      return sevacareApi.getBookingSetup(tenantId, userId, token);
    },
    options
  );
}

/**
 * Hook for doctor search
 */
export function useDoctorSearch(tenantId?: string, options?: {
  onSuccess?: (data: any) => void;
  onError?: (error: ApiError) => void;
}) {
  return useApi(
    async () => {
      if (!tenantId) throw new Error('Tenant ID required');
      return sevacareApi.listDoctors(tenantId);
    },
    { ...options, autoFetch: !!tenantId }
  );
}

/**
 * Hook for booking appointment
 */
export function useBookAppointment(
  onSuccess?: (appointmentId: string) => void,
  onError?: (error: ApiError) => void
) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const book = useCallback(
    async (appointmentData: any) => {
      setLoading(true);
      setError(null);
      try {
        const token = await AuthService.getToken();
        const tenantId = await AuthService.getTenantId();
        const userId = await AuthService.getUserId();

        if (!token || !tenantId || !userId) {
          throw new Error('Not authenticated');
        }

        const result = await sevacareApi.bookAppointment(
          tenantId,
          userId,
          token,
          appointmentData
        );

        setLoading(false);
        onSuccess?.(result.appointmentPublicId);
        return result;
      } catch (err) {
        const apiError: ApiError = {
          status: 0,
          message: err instanceof Error ? err.message : 'Failed to book appointment',
        };
        setError(apiError);
        onError?.(apiError);
        throw apiError;
      }
    },
    [onSuccess, onError]
  );

  return { booking: false, loading, error, book };
}

/**
 * Hook for doctor profile update
 */
export function useUpdateDoctorProfile(
  onSuccess?: () => void,
  onError?: (error: ApiError) => void
) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const update = useCallback(
    async (profileData: any) => {
      setLoading(true);
      setError(null);
      try {
        const token = await AuthService.getToken();
        const tenantId = await AuthService.getTenantId();
        const userId = await AuthService.getUserId();

        if (!token || !tenantId || !userId) {
          throw new Error('Not authenticated');
        }

        await sevacareApi.upsertDoctorRecord(
          tenantId,
          userId,
          token,
          profileData
        );

        setLoading(false);
        onSuccess?.();
      } catch (err) {
        const apiError: ApiError = {
          status: 0,
          message: err instanceof Error ? err.message : 'Failed to update profile',
        };
        setError(apiError);
        onError?.(apiError);
        throw apiError;
      }
    },
    [onSuccess, onError]
  );

  return { updating: loading, error, update };
}

/**
 * Hook for patient profile update
 */
export function useUpdatePatientProfile(
  onSuccess?: () => void,
  onError?: (error: ApiError) => void
) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const update = useCallback(
    async (profileData: any) => {
      setLoading(true);
      setError(null);
      try {
        const token = await AuthService.getToken();
        const tenantId = await AuthService.getTenantId();
        const userId = await AuthService.getUserId();

        if (!token || !tenantId || !userId) {
          throw new Error('Not authenticated');
        }

        await sevacareApi.upsertPatientRecord(
          tenantId,
          userId,
          token,
          profileData
        );

        setLoading(false);
        onSuccess?.();
      } catch (err) {
        const apiError: ApiError = {
          status: 0,
          message: err instanceof Error ? err.message : 'Failed to update profile',
        };
        setError(apiError);
        onError?.(apiError);
        throw apiError;
      }
    },
    [onSuccess, onError]
  );

  return { updating: loading, error, update };
}

/**
 * Hook for listing appointments
 */
export function useAppointments(options?: {
  onSuccess?: (data: any) => void;
  onError?: (error: ApiError) => void;
}) {
  return useAuthenticatedApi(
    async (token, tenantId) => {
      return sevacareApi.listAppointmentRecords(tenantId, token);
    },
    options
  );
}

/**
 * Hook for doctor dashboard
 */
export function useDoctorDashboard(options?: {
  onSuccess?: (data: any) => void;
  onError?: (error: ApiError) => void;
}) {
  return useAuthenticatedApi(
    async (token, tenantId) => {
      const userId = await AuthService.getUserId();
      if (!userId) throw new Error('User ID not found');
      return sevacareApi.getDoctorDashboard(tenantId, userId, token);
    },
    options
  );
}

// Phase 3: Prescription Hooks

/**
 * Hook for patient prescriptions
 */
export function usePatientPrescriptions(options?: {
  onSuccess?: (data: any) => void;
  onError?: (error: ApiError) => void;
}) {
  return useAuthenticatedApi(
    async (token, tenantId) => {
      const userId = await AuthService.getUserId();
      if (!userId) throw new Error('User ID not found');
      return sevacareApi.getPatientPrescriptions(tenantId, userId, token);
    },
    options
  );
}

/**
 * Hook for prescription detail view
 */
export function usePrescriptionDetail(
  prescriptionPublicId?: string,
  options?: {
    onSuccess?: (data: any) => void;
    onError?: (error: ApiError) => void;
  }
) {
  return useApi(
    async () => {
      if (!prescriptionPublicId) throw new Error('Prescription ID required');
      const token = await AuthService.getToken();
      const tenantId = await AuthService.getTenantId();
      if (!token || !tenantId) throw new Error('Not authenticated');
      return sevacareApi.getPrescriptionDetail(tenantId, prescriptionPublicId, token);
    },
    { ...options, autoFetch: !!prescriptionPublicId }
  );
}

/**
 * Hook for uploading prescriptions (Doctor)
 */
export function useUploadPrescription(
  onSuccess?: (prescriptionId: string) => void,
  onError?: (error: ApiError) => void
) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const upload = useCallback(
    async (prescriptionData: any) => {
      setLoading(true);
      setError(null);
      try {
        const token = await AuthService.getToken();
        const tenantId = await AuthService.getTenantId();
        const userId = await AuthService.getUserId();

        if (!token || !tenantId || !userId) {
          throw new Error('Not authenticated');
        }

        const patientPublicId = String(prescriptionData?.patientPublicId ?? '').trim();
        if (!patientPublicId) {
          throw new Error('Patient ID is required');
        }

        const medicines = Array.isArray(prescriptionData?.medicines) ? prescriptionData.medicines : [];
        if (medicines.length === 0) {
          throw new Error('At least one medicine is required');
        }

        const doctorRecord = await sevacareApi.getDoctorRecord(tenantId, userId, token).catch(() => null);
        const requestBody = {
          patientPublicId,
          doctorPublicId: userId,
          doctorName: doctorRecord?.fullName ?? 'Doctor',
          notes: prescriptionData?.notes,
          medicines: medicines.map((m: any) => ({
            medicineName: m?.medicineName ?? m?.name ?? '',
            strength: m?.strength ?? '',
            frequency: m?.frequency ?? '',
            duration: m?.duration ?? '',
            instructions: m?.instructions ?? '',
          })),
        };

        const result = await sevacareApi.uploadPrescription(
          tenantId,
          userId,
          token,
          requestBody as any
        );

        setLoading(false);
        onSuccess?.(result.prescriptionPublicId);
        return result;
      } catch (err) {
        const apiError: ApiError = {
          status: 0,
          message: err instanceof Error ? err.message : 'Failed to upload prescription',
        };
        setError(apiError);
        onError?.(apiError);
        throw apiError;
      }
    },
    [onSuccess, onError]
  );

  return { uploading: loading, error, upload };
}

/**
 * Hook for patient medical history
 */
export function useMedicalHistory(options?: {
  onSuccess?: (data: any) => void;
  onError?: (error: ApiError) => void;
}) {
  return useAuthenticatedApi(
    async (token, tenantId) => {
      const userId = await AuthService.getUserId();
      if (!userId) throw new Error('User ID not found');
      return sevacareApi.getPatientMedicalHistory(tenantId, userId, token);
    },
    options
  );
}
