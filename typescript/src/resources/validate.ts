import type { BaseClient } from "../types.js";

export interface EmailVerificationOptions {
  skip_smtp?: boolean;
}

export interface SingleValidateRequest {
  email: string;
  options?: EmailVerificationOptions;
}

export interface BatchValidateRequest {
  emails: string[];
  options?: EmailVerificationOptions;
}

export interface EmailVerificationResult {
  email: string;
  is_valid: boolean;
  score: number;
  checks: {
    syntax: boolean;
    mx: boolean;
    smtp: boolean | null;
  };
  flags: {
    disposable: boolean;
    role_account: boolean;
    catch_all: boolean | null;
    free_provider: boolean;
  };
  domain: string;
  provider: string | null;
  mx_records: string[];
  verified_at: string;
}

export interface SingleValidateResponse {
  success: true;
  data: EmailVerificationResult;
  credits: { used: number; balance_after: number };
}

export interface BatchValidateResponse {
  success: true;
  summary: {
    total: number;
    valid: number;
    invalid: number;
    risky: number;
    unknown: number;
    duration_ms: number;
  };
  results: EmailVerificationResult[];
  credits: { used: number; balance_after: number };
}

export interface WalletBalanceResponse {
  success: true;
  credits: { balance: number };
}

export class ValidateResource {
  constructor(private client: BaseClient) {}

  /** POST /validate — verify a single email address */
  email(request: SingleValidateRequest): Promise<SingleValidateResponse> {
    return this.client.request("POST", "/validate", request);
  }

  /** POST /validate — verify a batch of email addresses (max 500) */
  batch(request: BatchValidateRequest): Promise<BatchValidateResponse> {
    return this.client.request("POST", "/validate", request);
  }

  /** GET /validate — get wallet credit balance */
  balance(): Promise<WalletBalanceResponse> {
    return this.client.request("GET", "/validate");
  }
}
