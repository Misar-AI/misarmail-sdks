import type { BaseClient } from "../types.js";

export type TemplateType = "marketing" | "transactional" | "automation";

export interface Template {
  id: string;
  name: string;
  description?: string | null;
  subject: string;
  template_type: TemplateType;
  variables?: string[];
  created_at: string;
  updated_at: string;
}

export interface CreateTemplateRequest {
  name: string;
  subject: string;
  bodyHtml: string;
  bodyText?: string;
  description?: string;
  templateType?: TemplateType;
  variables?: string[];
}

export interface TemplatesListParams {
  page?: number;
  limit?: number;
  type?: TemplateType;
}

export interface TemplatesListResponse {
  success: true;
  data: Template[];
  pagination: { page: number; limit: number; total: number; totalPages: number };
}

export interface RenderTemplateRequest {
  template_id: string;
  variables?: Record<string, string>;
}

export interface RenderTemplateResponse {
  success: true;
  data: {
    subject: string;
    html: string | null;
    text: string | null;
    templateId: string;
    templateName: string;
    warning?: string;
  };
}

export class TemplatesResource {
  constructor(private client: BaseClient) {}

  /** GET /templates — list templates */
  list(params?: TemplatesListParams): Promise<TemplatesListResponse> {
    const qs = params ? `?${new URLSearchParams(params as Record<string, string>).toString()}` : "";
    return this.client.request("GET", `/templates${qs}`);
  }

  /** POST /templates — create a new template */
  create(request: CreateTemplateRequest): Promise<{ success: true; data: Template }> {
    return this.client.request("POST", "/templates", request);
  }

  /**
   * POST /templates/render — render a template with variable substitution.
   * Returns the rendered subject, html, and text.
   */
  render(request: RenderTemplateRequest): Promise<RenderTemplateResponse> {
    return this.client.request("POST", "/templates/render", request);
  }
}
