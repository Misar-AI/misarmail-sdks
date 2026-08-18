import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type ConversationStatus = "active" | "closed" | "snoozed";

export type Conversation = {
  id: string;
  channel: string;
  status: ConversationStatus;
  intent: string | null;
  last_message: string | null;
  last_message_at: string | null;
  campaign_id: string | null;
  contact_id: string | null;
  created_at: string;
};

export type ConversationsListParams = {
  status?: ConversationStatus;
  intent?: string;
  channel?: string;
  q?: string;
  limit?: number;
  offset?: number;
};

export type ConversationsListResponse = {
  conversations: Conversation[];
  total: number;
};

export type ConversationMessage = {
  id: string;
  conversation_id: string;
  sender: "user" | "system";
  message: string;
  channel: string;
  created_at: string;
};

export type SendMessageRequest = {
  message: string;
};

export type SendMessageResponse = {
  ok: boolean;
  messageId: string;
};

export type SnoozeRequest = {
  emailId: string;
  snooze_until: string;
};

export type UnsubscribeRequest = {
  emailId: string;
};

export type CategorizeRequest = {
  emailIds: string[];
};

export type AiImproveRequest = {
  text: string;
  action:
    | "improve"
    | "shorten"
    | "professional"
    | "friendly"
    | "expand"
    | "reply"
    | "fix_grammar"
    | "suggest_subject"
    | "quick_replies"
    | "custom";
  context?: string;
  subject?: string;
  sender?: string;
  customInstruction?: string;
};

export type AiReplyRequest = {
  emailId: string;
};

export type AiSummarizeRequest = {
  emailId: string;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class InboxResource {
  constructor(private readonly client: BaseClient) {}

  /** List conversations. */
  list(params?: ConversationsListParams): Promise<ConversationsListResponse> {
    const qs = params
      ? `?${new URLSearchParams(params as Record<string, string>).toString()}`
      : "";
    return this.client.requestRoot("GET", `/inbox/conversations${qs}`);
  }

  /** Get a single conversation. */
  get(id: string): Promise<{ conversation: Conversation }> {
    return this.client.requestRoot("GET", `/inbox/conversations/${id}`);
  }

  /** Send a reply to a conversation. */
  send(id: string, request: SendMessageRequest): Promise<SendMessageResponse> {
    return this.client.requestRoot("POST", `/inbox/conversations/${id}/send`, request);
  }

  /** Snooze an email until a given timestamp. */
  snooze(request: SnoozeRequest): Promise<{ success: boolean }> {
    return this.client.requestRoot("POST", "/inbox/snooze", request);
  }

  /** Trigger unsubscribe flow for an email. */
  unsubscribe(request: UnsubscribeRequest): Promise<{ success: boolean }> {
    return this.client.requestRoot("POST", "/inbox/unsubscribe", request);
  }

  /** Categorize one or more emails using AI. */
  categorize(request: CategorizeRequest): Promise<{ success: boolean; results: unknown[] }> {
    return this.client.requestRoot("POST", "/inbox/categorize", request);
  }

  /** Improve, rewrite, or transform email text using AI. */
  improve(request: AiImproveRequest): Promise<{ result: string | string[] }> {
    return this.client.requestRoot("POST", "/inbox/ai/improve", request);
  }

  /** Generate an AI reply suggestion for an inbox email. */
  reply(request: AiReplyRequest): Promise<{ suggestion: string }> {
    return this.client.requestRoot("POST", "/inbox/ai/reply", request);
  }

  /** Summarize an inbox email using AI. */
  summarize(request: AiSummarizeRequest): Promise<{ summary: string }> {
    return this.client.requestRoot("POST", "/inbox/ai/summarize", request);
  }
}
