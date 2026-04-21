#ifndef MISARMAIL_H
#define MISARMAIL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

/* -----------------------------------------------------------------------
 * MisarMail C SDK
 * Base URL : https://mail.misar.io/api/v1
 * API Base : https://mail.misar.io/api  (billing/workspaces)
 * Auth     : Authorization: Bearer <api_key>
 * C99 standard — depends only on libcurl
 * ----------------------------------------------------------------------- */

#define MISARMAIL_DEFAULT_BASE_URL "https://mail.misar.io/api/v1"
#define MISARMAIL_DEFAULT_MAX_RETRIES 3

/* Client ---------------------------------------------------------------- */

typedef struct {
    char *api_key;
    char *base_url;   /* e.g. https://mail.misar.io/api/v1  */
    char *api_base;   /* e.g. https://mail.misar.io/api     */
    int   max_retries;
} MisarMailClient;

/* Error ----------------------------------------------------------------- */

typedef struct {
    int  status_code;       /* HTTP status, or 0 for transport/init errors */
    char message[256];
} MisarMailError;

/* Lifecycle ------------------------------------------------------------- */

/**
 * Allocate and initialise a new client.
 * Returns NULL if api_key is NULL or memory allocation fails.
 * Caller must free with misarmail_free().
 */
MisarMailClient *misarmail_new(const char *api_key);

/**
 * Free all memory owned by the client.
 */
void misarmail_free(MisarMailClient *client);

/* Error access ---------------------------------------------------------- */

/**
 * Return a pointer to the last error set on this thread.
 * Valid until the next SDK call on this thread.
 */
const MisarMailError *misarmail_get_last_error(void);

/* API endpoints --------------------------------------------------------- */

/**
 * All functions return a heap-allocated JSON string on success.
 * Caller MUST free() the returned pointer.
 * Returns NULL on error; inspect misarmail_get_last_error() for details.
 *
 * query_params : optional URL query string WITHOUT leading '?'
 *                e.g. "page=1&limit=25"  — pass NULL for none.
 */

/* ── Email ────────────────────────────────────────────────────────────── */

/** POST /send */
char *misarmail_send_email(MisarMailClient *client, const char *json_body);

/* ── Contacts ─────────────────────────────────────────────────────────── */

/** GET  /contacts[?query_params] */
char *misarmail_contacts_list(MisarMailClient *client, const char *query_params);
/** POST /contacts */
char *misarmail_contacts_create(MisarMailClient *client, const char *json_body);
/** GET  /contacts/{id} */
char *misarmail_contacts_get(MisarMailClient *client, const char *id);
/** PATCH /contacts/{id} */
char *misarmail_contacts_update(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE /contacts/{id} */
char *misarmail_contacts_delete(MisarMailClient *client, const char *id);
/** POST /contacts/import */
char *misarmail_contacts_import(MisarMailClient *client, const char *json_body);

/* ── Campaigns ────────────────────────────────────────────────────────── */

/** GET  /campaigns[?query_params] */
char *misarmail_campaigns_list(MisarMailClient *client, const char *query_params);
/** POST /campaigns */
char *misarmail_campaigns_create(MisarMailClient *client, const char *json_body);
/** GET  /campaigns/{id} */
char *misarmail_campaigns_get(MisarMailClient *client, const char *id);
/** PATCH /campaigns/{id} */
char *misarmail_campaigns_update(MisarMailClient *client, const char *id, const char *json_body);
/** POST /campaigns/{id}/send */
char *misarmail_campaigns_send(MisarMailClient *client, const char *id);
/** DELETE /campaigns/{id} */
char *misarmail_campaigns_delete(MisarMailClient *client, const char *id);

/* ── Templates ────────────────────────────────────────────────────────── */

/** GET  /templates[?query_params] */
char *misarmail_templates_list(MisarMailClient *client, const char *query_params);
/** POST /templates */
char *misarmail_templates_create(MisarMailClient *client, const char *json_body);
/** GET  /templates/{id} */
char *misarmail_templates_get(MisarMailClient *client, const char *id);
/** PATCH /templates/{id} */
char *misarmail_templates_update(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE /templates/{id} */
char *misarmail_templates_delete(MisarMailClient *client, const char *id);
/** POST /templates/render */
char *misarmail_templates_render(MisarMailClient *client, const char *json_body);

/* ── Automations ──────────────────────────────────────────────────────── */

/** GET  /automations[?query_params] */
char *misarmail_automations_list(MisarMailClient *client, const char *query_params);
/** POST /automations */
char *misarmail_automations_create(MisarMailClient *client, const char *json_body);
/** GET  /automations/{id} */
char *misarmail_automations_get(MisarMailClient *client, const char *id);
/** PATCH /automations/{id} */
char *misarmail_automations_update(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE /automations/{id} */
char *misarmail_automations_delete(MisarMailClient *client, const char *id);
/** POST /automations/{id}/activate  — active: 1=true 0=false */
char *misarmail_automations_activate(MisarMailClient *client, const char *id, int active);

/* ── Domains ──────────────────────────────────────────────────────────── */

/** GET  /domains */
char *misarmail_domains_list(MisarMailClient *client);
/** POST /domains */
char *misarmail_domains_create(MisarMailClient *client, const char *json_body);
/** GET  /domains/{id} */
char *misarmail_domains_get(MisarMailClient *client, const char *id);
/** POST /domains/{id}/verify */
char *misarmail_domains_verify(MisarMailClient *client, const char *id);
/** DELETE /domains/{id} */
char *misarmail_domains_delete(MisarMailClient *client, const char *id);

/* ── Aliases ──────────────────────────────────────────────────────────── */

/** GET  /aliases */
char *misarmail_aliases_list(MisarMailClient *client);
/** POST /aliases */
char *misarmail_aliases_create(MisarMailClient *client, const char *json_body);
/** GET  /aliases/{id} */
char *misarmail_aliases_get(MisarMailClient *client, const char *id);
/** PATCH /aliases/{id} */
char *misarmail_aliases_update(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE /aliases/{id} */
char *misarmail_aliases_delete(MisarMailClient *client, const char *id);

/* ── Dedicated IPs ────────────────────────────────────────────────────── */

/** GET  /dedicated-ips */
char *misarmail_dedicated_ips_list(MisarMailClient *client);
/** POST /dedicated-ips */
char *misarmail_dedicated_ips_create(MisarMailClient *client, const char *json_body);
/** PATCH /dedicated-ips/{id} */
char *misarmail_dedicated_ips_update(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE /dedicated-ips/{id} */
char *misarmail_dedicated_ips_delete(MisarMailClient *client, const char *id);

/* ── Channels ─────────────────────────────────────────────────────────── */

/** POST /channels/whatsapp */
char *misarmail_channels_send_whatsapp(MisarMailClient *client, const char *json_body);
/** POST /channels/push */
char *misarmail_channels_send_push(MisarMailClient *client, const char *json_body);

/* ── A/B Tests ────────────────────────────────────────────────────────── */

/** GET  /ab-tests[?query_params] */
char *misarmail_ab_tests_list(MisarMailClient *client, const char *query_params);
/** POST /ab-tests */
char *misarmail_ab_tests_create(MisarMailClient *client, const char *json_body);
/** GET  /ab-tests/{id} */
char *misarmail_ab_tests_get(MisarMailClient *client, const char *id);
/** POST /ab-tests/{id}/winner  — json: {"variantId":"..."} */
char *misarmail_ab_tests_set_winner(MisarMailClient *client, const char *id, const char *json_body);

/* ── Sandbox ──────────────────────────────────────────────────────────── */

/** POST /sandbox/send */
char *misarmail_sandbox_send(MisarMailClient *client, const char *json_body);
/** GET  /sandbox[?query_params] */
char *misarmail_sandbox_list(MisarMailClient *client, const char *query_params);
/** DELETE /sandbox/{id} */
char *misarmail_sandbox_delete(MisarMailClient *client, const char *id);

/* ── Inbound ──────────────────────────────────────────────────────────── */

/** GET  /inbound[?query_params] */
char *misarmail_inbound_list(MisarMailClient *client, const char *query_params);
/** POST /inbound */
char *misarmail_inbound_create(MisarMailClient *client, const char *json_body);
/** GET  /inbound/{id} */
char *misarmail_inbound_get(MisarMailClient *client, const char *id);
/** DELETE /inbound/{id} */
char *misarmail_inbound_delete(MisarMailClient *client, const char *id);

/* ── Analytics ────────────────────────────────────────────────────────── */

/** GET /analytics[?query_params] */
char *misarmail_analytics_get(MisarMailClient *client, const char *query_params);

/* ── Track ────────────────────────────────────────────────────────────── */

/** POST /track/event */
char *misarmail_track_event(MisarMailClient *client, const char *json_body);
/** POST /track/purchase */
char *misarmail_track_purchase(MisarMailClient *client, const char *json_body);

/* ── API Keys ─────────────────────────────────────────────────────────── */

/** GET  /keys[?query_params] */
char *misarmail_keys_list(MisarMailClient *client, const char *query_params);
/** POST /keys */
char *misarmail_keys_create(MisarMailClient *client, const char *json_body);
/** GET  /keys/{id} */
char *misarmail_keys_get(MisarMailClient *client, const char *id);
/** DELETE /keys/{id} */
char *misarmail_keys_revoke(MisarMailClient *client, const char *id);

/* ── Validate ─────────────────────────────────────────────────────────── */

/** POST /validate  — json: {"email":"<address>"} */
char *misarmail_validate_email(MisarMailClient *client, const char *json_body);

/* ── Leads ────────────────────────────────────────────────────────────── */

/** POST /leads/search */
char *misarmail_leads_search(MisarMailClient *client, const char *json_body);
/** GET  /leads/jobs/{id} */
char *misarmail_leads_get_job(MisarMailClient *client, const char *id);
/** GET  /leads/jobs[?query_params] */
char *misarmail_leads_list_jobs(MisarMailClient *client, const char *query_params);
/** GET  /leads/jobs/{job_id}/results */
char *misarmail_leads_results(MisarMailClient *client, const char *job_id);
/** POST /leads/import */
char *misarmail_leads_import(MisarMailClient *client, const char *json_body);
/** GET  /leads/credits */
char *misarmail_leads_credits(MisarMailClient *client);

/* ── Autopilot ────────────────────────────────────────────────────────── */

/** POST /autopilot */
char *misarmail_autopilot_start(MisarMailClient *client, const char *json_body);
/** GET  /autopilot/{id} */
char *misarmail_autopilot_get(MisarMailClient *client, const char *id);
/** GET  /autopilot[?query_params] */
char *misarmail_autopilot_list(MisarMailClient *client, const char *query_params);
/** GET  /autopilot/daily-plan */
char *misarmail_autopilot_daily_plan(MisarMailClient *client);

/* ── Sales Agent ──────────────────────────────────────────────────────── */

/** GET  /sales-agent/config */
char *misarmail_sales_agent_get_config(MisarMailClient *client);
/** PATCH /sales-agent/config */
char *misarmail_sales_agent_update_config(MisarMailClient *client, const char *json_body);
/** GET  /sales-agent/actions[?query_params] */
char *misarmail_sales_agent_get_actions(MisarMailClient *client, const char *query_params);

/* ── CRM ──────────────────────────────────────────────────────────────── */

/** GET  /crm/conversations[?query_params] */
char *misarmail_crm_list_conversations(MisarMailClient *client, const char *query_params);
/** GET  /crm/conversations/{id} */
char *misarmail_crm_get_conversation(MisarMailClient *client, const char *id);
/** PATCH /crm/conversations/{id} */
char *misarmail_crm_update_conversation(MisarMailClient *client, const char *id, const char *json_body);
/** GET  /crm/conversations/{conversation_id}/messages */
char *misarmail_crm_list_messages(MisarMailClient *client, const char *conversation_id);
/** GET  /crm/deals[?query_params] */
char *misarmail_crm_list_deals(MisarMailClient *client, const char *query_params);
/** POST /crm/deals */
char *misarmail_crm_create_deal(MisarMailClient *client, const char *json_body);
/** GET  /crm/deals/{id} */
char *misarmail_crm_get_deal(MisarMailClient *client, const char *id);
/** PATCH /crm/deals/{id} */
char *misarmail_crm_update_deal(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE /crm/deals/{id} */
char *misarmail_crm_delete_deal(MisarMailClient *client, const char *id);
/** GET  /crm/clients[?query_params] */
char *misarmail_crm_list_clients(MisarMailClient *client, const char *query_params);
/** POST /crm/clients */
char *misarmail_crm_create_client(MisarMailClient *client, const char *json_body);

/* ── Webhooks ─────────────────────────────────────────────────────────── */

/** GET  /webhooks */
char *misarmail_webhooks_list(MisarMailClient *client);
/** POST /webhooks */
char *misarmail_webhooks_create(MisarMailClient *client, const char *json_body);
/** GET  /webhooks/{id} */
char *misarmail_webhooks_get(MisarMailClient *client, const char *id);
/** PATCH /webhooks/{id} */
char *misarmail_webhooks_update(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE /webhooks/{id} */
char *misarmail_webhooks_delete(MisarMailClient *client, const char *id);
/** POST /webhooks/{id}/test */
char *misarmail_webhooks_test(MisarMailClient *client, const char *id);

/* ── Usage ────────────────────────────────────────────────────────────── */

/** GET /usage[?query_params] */
char *misarmail_usage_get(MisarMailClient *client, const char *query_params);

/* ── Billing  (api_base — no /v1) ─────────────────────────────────────── */

/** GET  {api_base}/billing/subscription */
char *misarmail_billing_subscription(MisarMailClient *client);
/** POST {api_base}/billing/checkout */
char *misarmail_billing_checkout(MisarMailClient *client, const char *json_body);

/* ── Workspaces  (api_base — no /v1) ─────────────────────────────────── */

/** GET  {api_base}/workspaces */
char *misarmail_workspaces_list(MisarMailClient *client);
/** POST {api_base}/workspaces */
char *misarmail_workspaces_create(MisarMailClient *client, const char *json_body);
/** GET  {api_base}/workspaces/{id} */
char *misarmail_workspaces_get(MisarMailClient *client, const char *id);
/** PATCH {api_base}/workspaces/{id} */
char *misarmail_workspaces_update(MisarMailClient *client, const char *id, const char *json_body);
/** DELETE {api_base}/workspaces/{id} */
char *misarmail_workspaces_delete(MisarMailClient *client, const char *id);
/** GET  {api_base}/workspaces/{ws_id}/members */
char *misarmail_workspaces_list_members(MisarMailClient *client, const char *ws_id);
/** POST {api_base}/workspaces/{ws_id}/members */
char *misarmail_workspaces_invite_member(MisarMailClient *client, const char *ws_id, const char *json_body);
/** PATCH {api_base}/workspaces/{ws_id}/members/{user_id} */
char *misarmail_workspaces_update_member(MisarMailClient *client, const char *ws_id, const char *user_id, const char *json_body);
/** DELETE {api_base}/workspaces/{ws_id}/members/{user_id} */
char *misarmail_workspaces_remove_member(MisarMailClient *client, const char *ws_id, const char *user_id);

#ifdef __cplusplus
}
#endif

#endif /* MISARMAIL_H */
