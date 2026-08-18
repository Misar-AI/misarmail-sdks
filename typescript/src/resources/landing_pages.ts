import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type LandingPageBlockType =
  | "hero"
  | "text"
  | "image"
  | "form"
  | "cta"
  | "features"
  | "testimonial"
  | "countdown"
  | "divider"
  | "video";

export type LandingPageBlock = {
  id: string;
  type: LandingPageBlockType;
  content: Record<string, unknown>;
  style?: Record<string, string>;
};

export type LandingPageStatus = "draft" | "published";

export type LandingPage = {
  id: string;
  title: string;
  slug: string;
  description: string | null;
  status: LandingPageStatus;
  blocks: LandingPageBlock[];
  settings: Record<string, unknown>;
  meta_title: string | null;
  meta_description: string | null;
  og_image_url: string | null;
  custom_css: string | null;
  form_id: string | null;
  campaign_id: string | null;
  visits: number;
  conversions: number;
  conversion_rate: number;
  published_at: string | null;
  created_at: string;
  updated_at: string;
};

export type LandingPageSummary = Pick<
  LandingPage,
  | "id"
  | "title"
  | "slug"
  | "description"
  | "status"
  | "blocks"
  | "visits"
  | "conversions"
  | "conversion_rate"
  | "published_at"
  | "created_at"
  | "updated_at"
  | "form_id"
  | "campaign_id"
>;

export type CreateLandingPageRequest = {
  title: string;
  slug?: string;
  description?: string;
  blocks?: LandingPageBlock[];
  settings?: Record<string, unknown>;
  meta_title?: string;
  meta_description?: string;
  og_image_url?: string;
  custom_css?: string;
  form_id?: string;
  campaign_id?: string;
};

export type UpdateLandingPageRequest = {
  title?: string;
  slug?: string;
  description?: string | null;
  status?: LandingPageStatus;
  blocks?: LandingPageBlock[];
  settings?: Record<string, unknown>;
  meta_title?: string | null;
  meta_description?: string | null;
  og_image_url?: string | null;
  custom_css?: string | null;
  form_id?: string | null;
  campaign_id?: string | null;
};

export type ListLandingPagesParams = {
  status?: "all" | "draft" | "published";
  limit?: number;
  offset?: number;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class LandingPagesResource {
  constructor(private readonly client: BaseClient) {}

  list(
    params?: ListLandingPagesParams,
  ): Promise<{ success: boolean; data: LandingPageSummary[] }> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.requestRoot("GET", `/landing-pages${qs}`);
  }

  get(id: string): Promise<{ success: boolean; data: LandingPage }> {
    return this.client.requestRoot("GET", `/landing-pages/${id}`);
  }

  create(
    request: CreateLandingPageRequest,
  ): Promise<{ success: boolean; data: LandingPage }> {
    return this.client.requestRoot("POST", "/landing-pages", request);
  }

  update(
    id: string,
    request: UpdateLandingPageRequest,
  ): Promise<{ success: boolean; data: LandingPage }> {
    return this.client.requestRoot("PATCH", `/landing-pages/${id}`, request);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/landing-pages/${id}`);
  }
}
