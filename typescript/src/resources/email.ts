import type { BaseClient, SendEmailRequest, SendEmailResponse } from "../types.js";

export class EmailResource {
  constructor(private client: BaseClient) {}

  send(request: SendEmailRequest): Promise<SendEmailResponse> {
    return this.client.request("POST", "/send", request);
  }
}
