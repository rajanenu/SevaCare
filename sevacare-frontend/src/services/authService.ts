import * as SecureStore from 'expo-secure-store';
import type { AuthenticatedSession, AuthState } from '../api/types';

const AUTH_TOKEN_KEY = 'sevacare_auth_token';
const TENANT_ID_KEY = 'sevacare_tenant_id';
const USER_ID_KEY = 'sevacare_user_id';
const ROLE_KEY = 'sevacare_role';
const SESSION_KEY = 'sevacare_session';

// Fallback storage for web (since SecureStore doesn't work in browsers)
const fallbackStorage: Record<string, string> = {};

async function getSecureValue(key: string): Promise<string | null> {
  try {
    // Try native secure storage first
    const value = await SecureStore.getItemAsync(key);
    if (value !== null) return value;
  } catch (e) {
    // Fall back to in-memory storage
    return fallbackStorage[key] ?? null;
  }
  return fallbackStorage[key] ?? null;
}

async function setSecureValue(key: string, value: string): Promise<void> {
  try {
    // Try native secure storage first
    await SecureStore.setItemAsync(key, value);
  } catch (e) {
    // Fall back to in-memory storage
    fallbackStorage[key] = value;
  }
}

async function removeSecureValue(key: string): Promise<void> {
  try {
    // Try native secure storage first
    await SecureStore.deleteItemAsync(key);
  } catch (e) {
    // Fall back to in-memory storage
    delete fallbackStorage[key];
  }
}

export class AuthService {
  /**
   * Save authenticated session to secure storage
   */
  static async saveSession(session: AuthenticatedSession): Promise<void> {
    await Promise.all([
      setSecureValue(AUTH_TOKEN_KEY, session.token),
      setSecureValue(TENANT_ID_KEY, session.tenantPublicId),
      setSecureValue(USER_ID_KEY, session.subjectPublicId),
      setSecureValue(ROLE_KEY, session.role),
      setSecureValue(SESSION_KEY, JSON.stringify(session)),
    ]);
  }

  /**
   * Load session from secure storage
   */
  static async loadSession(): Promise<AuthenticatedSession | null> {
    try {
      const sessionJson = await getSecureValue(SESSION_KEY);
      if (sessionJson) {
        return JSON.parse(sessionJson) as AuthenticatedSession;
      }

      // Fallback: reconstruct from individual values
      const token = await getSecureValue(AUTH_TOKEN_KEY);
      const tenantPublicId = await getSecureValue(TENANT_ID_KEY);
      const subjectPublicId = await getSecureValue(USER_ID_KEY);
      const role = await getSecureValue(ROLE_KEY);

      if (token && tenantPublicId && subjectPublicId && role) {
        return {
          token,
          tenantPublicId,
          subjectPublicId,
          role: role as 'patient' | 'doctor' | 'admin' | 'platform_admin',
        };
      }

      return null;
    } catch (e) {
      console.error('Failed to load session:', e);
      return null;
    }
  }

  /**
   * Clear session from secure storage
   */
  static async clearSession(): Promise<void> {
    await Promise.all([
      removeSecureValue(AUTH_TOKEN_KEY),
      removeSecureValue(TENANT_ID_KEY),
      removeSecureValue(USER_ID_KEY),
      removeSecureValue(ROLE_KEY),
      removeSecureValue(SESSION_KEY),
    ]);
  }

  /**
   * Get auth token
   */
  static async getToken(): Promise<string | null> {
    return getSecureValue(AUTH_TOKEN_KEY);
  }

  /**
   * Get tenant ID
   */
  static async getTenantId(): Promise<string | null> {
    return getSecureValue(TENANT_ID_KEY);
  }

  /**
   * Get user ID
   */
  static async getUserId(): Promise<string | null> {
    return getSecureValue(USER_ID_KEY);
  }

  /**
   * Get user role
   */
  static async getRole(): Promise<'patient' | 'doctor' | 'admin' | 'platform_admin' | null> {
    const role = await getSecureValue(ROLE_KEY);
    return role as 'patient' | 'doctor' | 'admin' | 'platform_admin' | null;
  }

  /**
   * Check if user is authenticated
   */
  static async isAuthenticated(): Promise<boolean> {
    const token = await getSecureValue(AUTH_TOKEN_KEY);
    return token !== null && token.length > 0;
  }

  /**
   * Get current auth state
   */
  static async getAuthState(): Promise<AuthState> {
    const isAuth = await this.isAuthenticated();
    if (!isAuth) {
      return { isAuthenticated: false };
    }

    const session = await this.loadSession();
    if (!session) {
      return { isAuthenticated: false };
    }

    return {
      isAuthenticated: true,
      token: session.token,
      tenantId: session.tenantPublicId,
      userId: session.subjectPublicId,
      role: session.role,
    };
  }
}

export default AuthService;
