import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type PreferenceFrequency = "immediate" | "daily" | "weekly" | "monthly" | "never";

export type EmailPreferences = {
  marketing?: boolean;
  productUpdates?: boolean;
  newsletters?: boolean;
  transactional?: boolean;
  frequency?: PreferenceFrequency;
};

export type GetPreferencesResponse = {
  success: boolean;
  /** Masked email address, e.g. u***@example.com */
  email: string;
  preferences: EmailPreferences;
};

export type UpdatePreferencesRequest = {
  /** Secure preference token (from unsubscribe link or preference center) */
  token: string;
  preferences: EmailPreferences;
};

export type UpdatePreferencesResponse = {
  success: boolean;
  message: string;
  preferences: EmailPreferences;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class PreferencesResource {
  constructor(private readonly client: BaseClient) {}

  /**
   * GET /preferences?token=<token>
   * Retrieve email preferences for a contact via a secure preference token.
   * This endpoint does NOT require an API key — it uses token-based auth.
   */
  get(token: string): Promise<GetPreferencesResponse> {
    return this.client.requestRoot("GET", `/preferences?token=${encodeURIComponent(token)}`);
  }

  /**
   * PUT /preferences
   * Update email preferences via a secure preference token.
   * This endpoint does NOT require an API key — it uses token-based auth.
   */
  update(request: UpdatePreferencesRequest): Promise<UpdatePreferencesResponse> {
    return this.client.requestRoot("PUT", "/preferences", request);
  }
}
