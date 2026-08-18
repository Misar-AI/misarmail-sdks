import type { BaseClient, PaginationParams } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type SegmentOperator = "AND" | "OR";

export type SegmentFilterOperator =
  | "equals"
  | "not_equals"
  | "contains"
  | "not_contains"
  | "starts_with"
  | "ends_with"
  | "greater_than"
  | "less_than"
  | "is_empty"
  | "is_not_empty"
  | "in"
  | "not_in"
  | "before"
  | "after";

export type SegmentFilterLeaf = {
  field: string;
  operator: SegmentFilterOperator;
  value: string | number | boolean | string[];
};

export type SegmentFilterGroup = {
  operator: SegmentOperator;
  rules: SegmentFilterRule[];
};

export type SegmentFilterRule = SegmentFilterLeaf | SegmentFilterGroup;

export type SegmentFilterCriteria = {
  operator: SegmentOperator;
  rules: SegmentFilterRule[];
};

export type Segment = {
  id: string;
  name: string;
  description: string | null;
  segment_type: "dynamic" | "static";
  contact_count: number;
  membership_count?: number;
  last_calculated_at: string | null;
  filter_criteria: SegmentFilterCriteria;
  created_at: string;
  updated_at: string;
};

export type SegmentsListResponse = {
  success: boolean;
  data: Segment[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type CreateSegmentRequest = {
  name: string;
  description?: string;
  segment_type: "dynamic" | "static";
  filter_criteria: SegmentFilterCriteria;
};

export type UpdateSegmentRequest = {
  name?: string;
  description?: string | null;
  filter_criteria?: SegmentFilterCriteria;
};

export type SegmentPreviewRequest = {
  filter_criteria: SegmentFilterCriteria;
};

export type SegmentPreviewResponse = {
  success: boolean;
  data: {
    count: number;
    sampleContacts: Array<{
      id: string;
      email: string;
      first_name: string | null;
      last_name: string | null;
      status: string;
      engagement_tier: string | null;
    }>;
  };
};

export type SegmentRefreshResponse = {
  success: boolean;
  data: {
    segment_id: string;
    contact_count: number;
    last_calculated_at: string;
  };
};

export type SegmentMembersParams = {
  page?: number;
  limit?: number;
};

export type SegmentMembersResponse = {
  success: boolean;
  data: {
    segment_id: string;
    contact_ids: string[];
  };
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class SegmentsResource {
  constructor(private readonly client: BaseClient) {}

  list(params?: PaginationParams): Promise<SegmentsListResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.requestRoot("GET", `/segments${qs}`);
  }

  get(id: string): Promise<{ success: boolean; data: Segment }> {
    return this.client.requestRoot("GET", `/segments/${id}`);
  }

  create(request: CreateSegmentRequest): Promise<{ success: boolean; data: Segment }> {
    return this.client.requestRoot("POST", "/segments", request);
  }

  update(
    id: string,
    request: UpdateSegmentRequest,
  ): Promise<{ success: boolean; data: Segment }> {
    return this.client.requestRoot("PATCH", `/segments/${id}`, request);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/segments/${id}`);
  }

  /** Preview a filter_criteria without saving. Pass "new" as id for unsaved segments. */
  preview(id: string, request: SegmentPreviewRequest): Promise<SegmentPreviewResponse> {
    return this.client.requestRoot("POST", `/segments/${id}/preview`, request);
  }

  /** Re-evaluate the segment's filter_criteria and repopulate memberships. */
  refresh(id: string): Promise<SegmentRefreshResponse> {
    return this.client.requestRoot("POST", `/segments/${id}/refresh`);
  }

  /**
   * GET /v1/segments/{id}/members — paginated contact ids for a segment the
   * user owns. API-key-authed, read-only. Used to build recipient lists.
   */
  members(id: string, params?: SegmentMembersParams): Promise<SegmentMembersResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.request("GET", `/segments/${id}/members${qs}`);
  }
}
