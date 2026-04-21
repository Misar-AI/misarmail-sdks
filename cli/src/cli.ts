#!/usr/bin/env node
import { Command } from "commander";

import { makeSendCommand } from "./commands/send.js";
import { makeEmailCommand } from "./commands/email.js";
import { makeContactsCommand } from "./commands/contacts.js";
import { makeCampaignsCommand } from "./commands/campaigns.js";
import { makeTemplatesCommand } from "./commands/templates.js";
import { makeAutomationsCommand } from "./commands/automations.js";
import { makeDomainsCommand } from "./commands/domains.js";
import { makeAliasesCommand } from "./commands/aliases.js";
import { makeDedicatedIpsCommand } from "./commands/dedicated-ips.js";
import { makeChannelsCommand } from "./commands/channels.js";
import { makeAbTestsCommand } from "./commands/ab-tests.js";
import { makeSandboxCommand } from "./commands/sandbox.js";
import { makeInboundCommand } from "./commands/inbound.js";
import { makeAnalyticsCommand } from "./commands/analytics.js";
import { makeTrackCommand } from "./commands/track.js";
import { makeKeysCommand } from "./commands/keys.js";
import { makeValidateCommand } from "./commands/validate.js";
import { makeLeadsCommand } from "./commands/leads.js";
import { makeAutopilotCommand } from "./commands/autopilot.js";
import { makeSalesAgentCommand } from "./commands/sales-agent.js";
import { makeCrmCommand } from "./commands/crm.js";
import { makeWebhooksCommand } from "./commands/webhooks.js";
import { makeUsageCommand } from "./commands/usage.js";
import { makeBillingCommand } from "./commands/billing.js";
import { makeWorkspacesCommand } from "./commands/workspaces.js";

export const program = new Command();

program
  .name("misarmail")
  .description("MisarMail CLI — email, campaigns, leads, CRM, and more")
  .version("1.0.0")
  .option("--api-key <key>", "MisarMail API key (overrides MISARMAIL_API_KEY and ~/.misarmail.json)")
  .option("--base-url <url>", "API base URL (overrides MISARMAIL_BASE_URL, default: https://mail.misar.io/api/v1)")
  .option("--pretty", "Pretty-print JSON output (default)")
  .option("--quiet", "Suppress output on success");

// ── Commands ─────────────────────────────────────────────────────────────────
program.addCommand(makeSendCommand());          // misarmail send (compat shorthand)
program.addCommand(makeEmailCommand());         // misarmail email send
program.addCommand(makeContactsCommand());      // misarmail contacts *
program.addCommand(makeCampaignsCommand());     // misarmail campaigns *
program.addCommand(makeTemplatesCommand());     // misarmail templates *
program.addCommand(makeAutomationsCommand());   // misarmail automations *
program.addCommand(makeDomainsCommand());       // misarmail domains *
program.addCommand(makeAliasesCommand());       // misarmail aliases *
program.addCommand(makeDedicatedIpsCommand());  // misarmail dedicated-ips *
program.addCommand(makeChannelsCommand());      // misarmail channels whatsapp|push
program.addCommand(makeAbTestsCommand());       // misarmail ab-tests *
program.addCommand(makeSandboxCommand());       // misarmail sandbox *
program.addCommand(makeInboundCommand());       // misarmail inbound *
program.addCommand(makeAnalyticsCommand());     // misarmail analytics overview
program.addCommand(makeTrackCommand());         // misarmail track event|purchase
program.addCommand(makeKeysCommand());          // misarmail keys *
program.addCommand(makeValidateCommand());      // misarmail validate email
program.addCommand(makeLeadsCommand());         // misarmail leads *
program.addCommand(makeAutopilotCommand());     // misarmail autopilot *
program.addCommand(makeSalesAgentCommand());    // misarmail sales-agent *
program.addCommand(makeCrmCommand());           // misarmail crm conversations|deals|clients
program.addCommand(makeWebhooksCommand());      // misarmail webhooks *
program.addCommand(makeUsageCommand());         // misarmail usage
program.addCommand(makeBillingCommand());       // misarmail billing subscription|checkout
program.addCommand(makeWorkspacesCommand());    // misarmail workspaces *

program.parse();
