import type { BaseClient, PaginationParams } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type MarketplaceCategory =
  | "email"
  | "campaign"
  | "automation"
  | "welcome"
  | "newsletter"
  | "promotional"
  | "transactional"
  | "ecommerce"
  | "saas"
  | "event"
  | "other";

export type MarketplaceSortOrder = "popular" | "newest" | "rating" | "price";

export type MarketplaceTemplate = {
  id: string;
  title: string;
  description: string;
  category: MarketplaceCategory;
  tags: string[];
  price_cents: number;
  preview_image_url: string | null;
  preview_html: string | null;
  downloads: number;
  rating_avg: number | null;
  rating_count: number | null;
  is_featured: boolean;
  seller_name: string;
  created_at: string;
};

export type MarketplaceTemplateDetail = MarketplaceTemplate & {
  template_id: string;
  reviews: MarketplaceReview[];
  similar: Pick<MarketplaceTemplate, "id" | "title" | "price_cents" | "preview_image_url" | "downloads" | "rating_avg">[];
};

export type MarketplaceListParams = PaginationParams & {
  category?: MarketplaceCategory;
  type?: "email" | "campaign" | "automation";
  sort?: MarketplaceSortOrder;
  free?: boolean;
};

export type MarketplaceListResponse = {
  success: boolean;
  data: MarketplaceTemplate[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type SubmitListingRequest = {
  template_id: string;
  title: string;
  description: string;
  category: MarketplaceCategory;
  tags?: string[];
  price_cents: number;
  preview_image_url?: string;
};

export type TemplateSubmission = {
  id: string;
  user_id: string;
  template_name: string;
  template_description: string | null;
  category: string | null;
  tags: string[];
  preview_image_url: string | null;
  status: string;
  reviewer_notes: string | null;
  reviewed_at: string | null;
  created_at: string;
};

export type SubmitCommunityTemplateRequest = {
  template_name: string;
  template_description?: string;
  template_html: string;
  category?: MarketplaceCategory;
  tags?: string[];
  preview_image_url?: string;
};

export type SubmissionsListResponse = {
  success: boolean;
  data: TemplateSubmission[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type MarketplaceReview = {
  id: string;
  user_id: string;
  rating: number;
  review: string | null;
  created_at: string;
};

export type SubmitReviewRequest = {
  rating: number;
  review?: string;
};

export type PurchaseResponse = {
  success: boolean;
  free?: boolean;
  url?: string;
};

export type DownloadResponse = {
  success: boolean;
  template_id: string;
  step_template_ids?: Record<number, string>;
};

export type PremiumPurchaseRequest = {
  template_id: string;
};

/** Response from POST /marketplace/premium. Paid templates return a Stripe
 * Checkout `url` — the purchase itself is recorded only after Stripe confirms
 * payment via webhook, so it will not yet appear in listPremiumPurchases()
 * until checkout completes. Free templates (`free: true`) are recorded
 * immediately. */
export type PremiumPurchaseResponse = {
  success: boolean;
  free?: boolean;
  url?: string;
  data?: PremiumPurchase;
};

export type PremiumPurchase = {
  id: string;
  template_id: string;
  price_cents: number;
  purchased_at: string;
  template: {
    id: string;
    name: string;
    body_html: string | null;
    is_premium: boolean;
    price_cents: number;
    author_name: string | null;
  } | null;
};

export type PremiumListResponse = {
  success: boolean;
  data: PremiumPurchase[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type MyListing = {
  id: string;
  title: string;
  description: string;
  category: MarketplaceCategory;
  price_cents: number;
  preview_image_url: string | null;
  downloads: number;
  rating_avg: number | null;
  rating_count: number | null;
  is_published: boolean;
  is_featured: boolean;
  created_at: string;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class MarketplaceResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /marketplace — browse published marketplace templates */
  listMarketplaceItems(params?: MarketplaceListParams): Promise<MarketplaceListResponse> {
    return this.list(params);
  }

  /** GET /marketplace/[id] — get single marketplace item detail */
  getMarketplaceItem(itemId: string): Promise<{ success: boolean; data: MarketplaceTemplateDetail }> {
    return this.get(itemId);
  }

  /** @deprecated Use listMarketplaceItems() */
  list(params?: MarketplaceListParams): Promise<MarketplaceListResponse> {
    const qs = params
      ? `?${new URLSearchParams(
          Object.fromEntries(
            Object.entries(params)
              .filter(([, v]) => v !== undefined)
              .map(([k, v]) => [k, String(v)]),
          ),
        ).toString()}`
      : "";
    return this.client.request("GET", `/marketplace${qs}`);
  }

  /** @deprecated Use getMarketplaceItem() */
  get(id: string): Promise<{ success: boolean; data: MarketplaceTemplateDetail }> {
    return this.client.request("GET", `/marketplace/${id}`);
  }

  /** POST /marketplace — submit template as a marketplace listing */
  submitListing(request: SubmitListingRequest): Promise<{
    success: boolean;
    data: MarketplaceTemplate;
    pending_review: boolean;
  }> {
    return this.client.request("POST", "/marketplace", request);
  }

  /** POST /marketplace/[id]/download — install template into user's library */
  download(id: string): Promise<DownloadResponse> {
    return this.client.request("POST", `/marketplace/${id}/download`);
  }

  /** POST /marketplace/[id]/purchase — purchase a paid template (returns Stripe URL for paid) */
  purchase(id: string): Promise<PurchaseResponse> {
    return this.client.request("POST", `/marketplace/${id}/purchase`);
  }

  /** GET /marketplace/[id]/review — list reviews for a template */
  listReviews(id: string): Promise<{ success: boolean; data: MarketplaceReview[] }> {
    return this.client.request("GET", `/marketplace/${id}/review`);
  }

  /** POST /marketplace/[id]/review — submit a review */
  submitReview(
    id: string,
    request: SubmitReviewRequest,
  ): Promise<{ success: boolean; data: MarketplaceReview }> {
    return this.client.request("POST", `/marketplace/${id}/review`, request);
  }

  /** POST /marketplace/premium — record a premium template purchase */
  /** POST /marketplace/premium — purchase a premium template (returns Stripe URL for paid) */
  recordPremiumPurchase(request: PremiumPurchaseRequest): Promise<PremiumPurchaseResponse> {
    return this.client.request("POST", "/marketplace/premium", request);
  }

  /** GET /marketplace/premium — list purchased premium templates */
  listPremiumPurchases(params?: PaginationParams & { template_id?: string }): Promise<
    | PremiumListResponse
    | { success: boolean; purchased: boolean }
  > {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.request("GET", `/marketplace/premium${qs}`);
  }

  /** POST /marketplace/submit — submit a community template (raw HTML, goes through review) */
  submitCommunityTemplate(request: SubmitCommunityTemplateRequest): Promise<{
    success: boolean;
    data: TemplateSubmission;
    message: string;
  }> {
    return this.client.request("POST", "/marketplace/submit", request);
  }

  /** GET /marketplace/submit — list own community template submissions */
  listSubmissions(params?: PaginationParams): Promise<SubmissionsListResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.request("GET", `/marketplace/submit${qs}`);
  }

  /** GET /marketplace/my — get seller's own listings */
  myListings(): Promise<{ success: boolean; data: MyListing[] }> {
    return this.client.request("GET", "/marketplace/my");
  }

  /** PATCH /marketplace/my — update own listing (publish/unpublish) */
  updateListing(id: string, is_published: boolean): Promise<{ success: boolean }> {
    return this.client.request("PATCH", "/marketplace/my", { id, is_published });
  }
}
