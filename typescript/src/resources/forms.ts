import type { BaseClient, PaginationParams } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type FormFieldType =
  | "email"
  | "text"
  | "first_name"
  | "last_name"
  | "phone"
  | "custom";

export type FormField = {
  id: string;
  type: FormFieldType;
  label: string;
  required: boolean;
  placeholder?: string;
};

export type FormSettings = {
  success_message?: string;
  redirect_url?: string;
  add_to_list_id?: string;
  double_optin?: boolean;
};

export type Form = {
  id: string;
  name: string;
  description: string | null;
  fields: FormField[];
  settings: FormSettings;
  is_active: boolean;
  submission_count: number;
  created_at: string;
  updated_at: string;
};

export type FormSummary = Pick<
  Form,
  "id" | "name" | "description" | "is_active" | "submission_count" | "created_at" | "updated_at"
>;

export type CreateFormRequest = {
  name: string;
  description?: string;
  fields: FormField[];
  settings?: FormSettings;
};

export type UpdateFormRequest = {
  name?: string;
  description?: string | null;
  fields?: FormField[];
  settings?: FormSettings;
  is_active?: boolean;
};

export type FormSubmission = {
  id: string;
  form_id: string;
  data: Record<string, unknown>;
  contact_id: string | null;
  ip_address: string | null;
  submitted_at: string;
  contacts: {
    email: string;
    first_name: string | null;
    last_name: string | null;
  } | null;
};

export type FormSubmissionsResponse = {
  success: boolean;
  data: FormSubmission[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
};

export type FormEmbedResponse = {
  success: boolean;
  embedCode: string;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export type FormsListParams = Pick<PaginationParams, "page" | "limit"> & {
  status?: "active" | "inactive";
};

export class FormsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /forms — list forms with optional pagination and status filter */
  listForms(params?: FormsListParams): Promise<{ success: boolean; data: FormSummary[] }> {
    const qs = params
      ? `?${new URLSearchParams(
          Object.fromEntries(
            Object.entries(params)
              .filter(([, v]) => v !== undefined)
              .map(([k, v]) => [k, String(v)]),
          ),
        ).toString()}`
      : "";
    return this.client.requestRoot("GET", `/forms${qs}`);
  }

  /** GET /forms/{formId} — get single form detail */
  getForm(formId: string): Promise<{ success: boolean; data: Form }> {
    return this.client.requestRoot("GET", `/forms/${formId}`);
  }

  /** GET /forms/{formId}/submissions — list submissions for a form */
  getFormSubmissions(
    formId: string,
    params?: Pick<PaginationParams, "page" | "limit">,
  ): Promise<FormSubmissionsResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.requestRoot("GET", `/forms/${formId}/submissions${qs}`);
  }

  // ── Legacy aliases ────────────────────────────────────────────────────────

  /** @deprecated Use listForms() */
  list(params?: FormsListParams): Promise<{ success: boolean; data: FormSummary[] }> {
    return this.listForms(params);
  }

  /** @deprecated Use getForm() */
  get(id: string): Promise<{ success: boolean; data: Form }> {
    return this.getForm(id);
  }

  create(request: CreateFormRequest): Promise<{ success: boolean; data: Form }> {
    return this.client.requestRoot("POST", "/forms", request);
  }

  update(
    id: string,
    request: UpdateFormRequest,
  ): Promise<{ success: boolean; data: Form }> {
    return this.client.requestRoot("PATCH", `/forms/${id}`, request);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/forms/${id}`);
  }

  submissions(
    id: string,
    params?: Pick<PaginationParams, "page" | "limit">,
  ): Promise<FormSubmissionsResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.requestRoot("GET", `/forms/${id}/submissions${qs}`);
  }

  embed(id: string): Promise<FormEmbedResponse> {
    return this.client.requestRoot("GET", `/forms/${id}/embed`);
  }
}
