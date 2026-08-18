import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type Notification = {
  id: string;
  type: string;
  title: string;
  body: string;
  entity_type: string | null;
  entity_id: string | null;
  is_read: boolean;
  created_at: string;
};

export type NotificationsListParams = {
  unread_only?: boolean;
  limit?: number;
};

export type NotificationsListResponse = {
  success: boolean;
  notifications: Notification[];
  unreadCount: number;
};

export type MarkReadRequest = {
  ids?: string[];
  all?: boolean;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class NotificationsResource {
  constructor(private readonly client: BaseClient) {}

  /** List notifications for the authenticated user. */
  list(params?: NotificationsListParams): Promise<NotificationsListResponse> {
    const searchParams = new URLSearchParams();
    if (params?.unread_only !== undefined) {
      searchParams.set("unread_only", String(params.unread_only));
    }
    if (params?.limit !== undefined) {
      searchParams.set("limit", String(params.limit));
    }
    const qs = searchParams.toString() ? `?${searchParams.toString()}` : "";
    return this.client.requestRoot("GET", `/notifications${qs}`);
  }

  /** Mark one or more notifications as read. Pass ids array or all=true. */
  markRead(request: MarkReadRequest): Promise<{ success: boolean; updated: number }> {
    return this.client.requestRoot("PATCH", "/notifications", request);
  }
}
