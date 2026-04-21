import type {
  BaseClient,
  Template,
  CreateTemplateRequest,
  TemplatesListResponse,
  RenderTemplateRequest,
  RenderTemplateResponse,
} from "../types.js";

export class TemplatesResource {
  constructor(private client: BaseClient) {}

  list(): Promise<TemplatesListResponse> {
    return this.client.request("GET", "/templates");
  }

  create(request: CreateTemplateRequest): Promise<Template> {
    return this.client.request("POST", "/templates", request);
  }

  get(id: string): Promise<Template> {
    return this.client.request("GET", `/templates/${id}`);
  }

  update(id: string, request: Partial<CreateTemplateRequest>): Promise<Template> {
    return this.client.request("PATCH", `/templates/${id}`, request);
  }

  delete(id: string): Promise<{ success: boolean }> {
    return this.client.request("DELETE", `/templates/${id}`);
  }

  render(request: RenderTemplateRequest): Promise<RenderTemplateResponse> {
    return this.client.request("POST", "/templates/render", request);
  }
}
