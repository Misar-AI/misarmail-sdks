import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type Label = {
  id: string;
  name: string;
  color: string;
  builtIn: boolean;
  created_at?: string;
};

export type LabelsListResponse = {
  labels: Label[];
};

export type CreateLabelRequest = {
  name: string;
  color?: string;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class LabelsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /labels — list user's labels (including built-in labels) */
  list(): Promise<LabelsListResponse> {
    return this.client.requestRoot("GET", "/labels");
  }

  /** POST /labels — create a custom label */
  create(request: CreateLabelRequest): Promise<{ label: Omit<Label, "builtIn"> }> {
    return this.client.requestRoot("POST", "/labels", request);
  }

  /** DELETE /labels?id=<id> — delete a custom label */
  delete(id: string): Promise<{ success: boolean }> {
    return this.client.requestRoot("DELETE", `/labels?id=${encodeURIComponent(id)}`);
  }
}
