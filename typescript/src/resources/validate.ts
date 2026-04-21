import type { BaseClient, ValidateEmailRequest, ValidateEmailResponse } from "../types.js";

export class ValidateResource {
  constructor(private client: BaseClient) {}

  email(request: ValidateEmailRequest): Promise<ValidateEmailResponse> {
    return this.client.request("POST", "/validate", request);
  }
}
