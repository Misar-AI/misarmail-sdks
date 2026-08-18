import type { BaseClient } from "../types.js";

// ── Types ────────────────────────────────────────────────────────────────────

export type ReferralSource = "direct" | "email" | "twitter" | "linkedin" | "copy_link";

export type ReferralStats = {
  code: string | null;
  shareUrl: string | null;
  totalReferrals: number;
  activeReferrals: number;
  creditsEarned: number;
  pendingRewards: number;
};

export type GenerateReferralResponse = {
  success: boolean;
  code: string;
  shareUrl: string;
};

export type LeaderboardEntry = {
  rank: number;
  userId: string | null;
  displayName: string;
  isSelf: boolean;
  totalReferrals: number;
  activeReferrals: number;
  totalCreditsEarned: number;
};

export type LeaderboardResponse = {
  success: boolean;
  data: {
    leaderboard: LeaderboardEntry[];
    myRank: number | null;
  };
};

export type ReferralMilestone = {
  id: string;
  name: string;
  description: string | null;
  referrals_required: number;
  reward_type: string;
  reward_value: number;
  badge_icon: string | null;
  badge_color: string | null;
};

export type MilestonesResponse = {
  success: boolean;
  data: ReferralMilestone[];
};

export type MilestoneClaim = {
  milestone_id: string;
  claimed_at: string;
  reward_applied: boolean;
};

export type MilestoneClaimsResponse = {
  success: boolean;
  data: MilestoneClaim[];
};

export type ClaimMilestoneRequest = {
  milestone_id: string;
};

export type ClaimMilestoneResponse = {
  success: boolean;
  data: {
    milestoneName: string;
    rewardType: string;
    rewardValue: number;
    creditsApplied: number;
  };
};

export type NudgeStats = {
  code: string | null;
  url: string | null;
  referralCount: number;
  creditsEarned: number;
  nudgeMessage: string;
};

export type NudgeResponse = {
  success: boolean;
  data: NudgeStats;
};

// ── Resource ─────────────────────────────────────────────────────────────────

export class ReferralsResource {
  constructor(private readonly client: BaseClient) {}

  /** GET /referrals — get referral stats for authenticated user */
  stats(): Promise<{ success: boolean; data: ReferralStats }> {
    return this.client.requestRoot("GET", "/referrals");
  }

  /** POST /referrals/generate — generate or retrieve referral code */
  generate(source?: ReferralSource): Promise<GenerateReferralResponse> {
    return this.client.requestRoot("POST", "/referrals/generate", source ? { source } : undefined);
  }

  /** GET /referrals/leaderboard — top 50 referrers */
  leaderboard(): Promise<LeaderboardResponse> {
    return this.client.requestRoot("GET", "/referrals/leaderboard");
  }

  /** POST /referrals/log-share — log a share action (non-critical analytics) */
  logShare(source?: ReferralSource): Promise<{ success: boolean }> {
    return this.client.requestRoot("POST", "/referrals/log-share", source ? { source } : undefined);
  }

  /** GET /referrals/milestones — list all referral milestones */
  milestones(): Promise<MilestonesResponse> {
    return this.client.requestRoot("GET", "/referrals/milestones");
  }

  /** GET /referrals/milestone-claims — list authenticated user's milestone claims */
  milestoneClaims(): Promise<MilestoneClaimsResponse> {
    return this.client.requestRoot("GET", "/referrals/milestone-claims");
  }

  /** POST /referrals/claim — claim a milestone reward */
  claim(request: ClaimMilestoneRequest): Promise<ClaimMilestoneResponse> {
    return this.client.requestRoot("POST", "/referrals/claim", request);
  }

  /** GET /referrals/nudge — contextual nudge message + referral stats */
  nudge(): Promise<NudgeResponse> {
    return this.client.requestRoot("GET", "/referrals/nudge");
  }
}
