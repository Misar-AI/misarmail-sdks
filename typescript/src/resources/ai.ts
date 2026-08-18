import type { BaseClient } from "../types.js";

export type SubjectLineTone =
  | "professional"
  | "casual"
  | "urgent"
  | "playful"
  | "informative";

export interface GenerateSubjectLinesRequest {
  /** Campaign topic or email content summary (min 5, max 500 chars) */
  topic: string;
  /** Tone for the subject lines (default: professional) */
  tone?: SubjectLineTone;
  /** Target audience description, e.g. "SaaS customers" (max 200 chars) */
  audience?: string;
  /** Number of subject lines to generate (1-10, default: 5) */
  count?: number;
  /** Brand name to include context (max 100 chars) */
  brand?: string;
}

export interface SubjectSuggestion {
  text: string;
  score: number;
  emoji_version?: string;
  reason: string;
}

export interface GenerateSubjectLinesResponse {
  success: true;
  data: { subjects: SubjectSuggestion[] };
}

export class AiResource {
  constructor(private client: BaseClient) {}

  /** POST /ai/subject-lines — generate AI-optimized email subject lines */
  subjectLines(
    request: GenerateSubjectLinesRequest,
  ): Promise<GenerateSubjectLinesResponse> {
    return this.client.request("POST", "/ai/subject-lines", request);
  }
}
