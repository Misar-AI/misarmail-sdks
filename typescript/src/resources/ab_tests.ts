import type { BaseClient, AbTest, CreateAbTestRequest, AbTestsListResponse } from "../types.js";

export class AbTestsResource {
  constructor(private client: BaseClient) {}

  list(): Promise<AbTestsListResponse> {
    return this.client.request("GET", "/ab-tests");
  }

  create(request: CreateAbTestRequest): Promise<AbTest> {
    return this.client.request("POST", "/ab-tests", request);
  }

  get(id: string): Promise<AbTest> {
    return this.client.request("GET", `/ab-tests/${id}`);
  }

  setWinner(id: string, variantId: string): Promise<AbTest> {
    return this.client.request("POST", `/ab-tests/${id}/winner`, { variant_id: variantId });
  }

  /** @deprecated Use setWinner() */
  pickWinner(id: string, variantId: string): Promise<AbTest> {
    return this.setWinner(id, variantId);
  }
}
