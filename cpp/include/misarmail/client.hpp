#pragma once

#include <stdexcept>
#include <string>

namespace misarmail {

// ---------------------------------------------------------------------------
// MisarMailError
// ---------------------------------------------------------------------------
class MisarMailError : public std::runtime_error {
public:
    MisarMailError(int status, const std::string& msg)
        : std::runtime_error(msg), status_(status) {}

    int statusCode() const noexcept { return status_; }

private:
    int status_;
};

// ---------------------------------------------------------------------------
// Forward declarations — resource classes
// ---------------------------------------------------------------------------
class Client;

class EmailResource;
class ContactsResource;
class CampaignsResource;
class TemplatesResource;
class AutomationsResource;
class DomainsResource;
class AliasesResource;
class DedicatedIPsResource;
class ChannelsResource;
class ABTestsResource;
class SandboxResource;
class InboundResource;
class AnalyticsResource;
class TrackResource;
class KeysResource;
class ValidateResource;
class LeadsResource;
class AutopilotResource;
class SalesAgentResource;
class CRMResource;
class WebhooksResource;
class UsageResource;
class BillingResource;
class WorkspacesResource;

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------
class Client {
public:
    /**
     * @param api_key     MisarMail API key (msk_...)
     * @param base_url    Override base URL (default: https://mail.misar.io/api/v1)
     * @param max_retries Max retry attempts on 429/5xx (default: 3)
     */
    explicit Client(std::string api_key,
                    std::string base_url = "https://mail.misar.io/api/v1",
                    int max_retries = 3);

    ~Client();

    // Non-copyable, movable
    Client(const Client&) = delete;
    Client& operator=(const Client&) = delete;
    Client(Client&&) noexcept;
    Client& operator=(Client&&) noexcept;

    // ── Resource accessors ────────────────────────────────────────────────────
    EmailResource&       email;
    ContactsResource&    contacts;
    CampaignsResource&   campaigns;
    TemplatesResource&   templates;
    AutomationsResource& automations;
    DomainsResource&     domains;
    AliasesResource&     aliases;
    DedicatedIPsResource& dedicatedIPs;
    ChannelsResource&    channels;
    ABTestsResource&     abTests;
    SandboxResource&     sandbox;
    InboundResource&     inbound;
    AnalyticsResource&   analytics;
    TrackResource&       track;
    KeysResource&        keys;
    ValidateResource&    validate;
    LeadsResource&       leads;
    AutopilotResource&   autopilot;
    SalesAgentResource&  salesAgent;
    CRMResource&         crm;
    WebhooksResource&    webhooks;
    UsageResource&       usage;
    BillingResource&     billing;
    WorkspacesResource&  workspaces;

private:
    struct Impl;
    Impl* impl_;

    friend class EmailResource;
    friend class ContactsResource;
    friend class CampaignsResource;
    friend class TemplatesResource;
    friend class AutomationsResource;
    friend class DomainsResource;
    friend class AliasesResource;
    friend class DedicatedIPsResource;
    friend class ChannelsResource;
    friend class ABTestsResource;
    friend class SandboxResource;
    friend class InboundResource;
    friend class AnalyticsResource;
    friend class TrackResource;
    friend class KeysResource;
    friend class ValidateResource;
    friend class LeadsResource;
    friend class AutopilotResource;
    friend class SalesAgentResource;
    friend class CRMResource;
    friend class WebhooksResource;
    friend class UsageResource;
    friend class BillingResource;
    friend class WorkspacesResource;
};

// ---------------------------------------------------------------------------
// Resource classes
// ---------------------------------------------------------------------------

class EmailResource {
public:
    explicit EmailResource(Client& c) : client_(c) {}
    /// POST /send
    std::string send(const std::string& json_body);
private:
    Client& client_;
};

class ContactsResource {
public:
    explicit ContactsResource(Client& c) : client_(c) {}
    /// GET /contacts[?query]
    std::string list(const std::string& query = "");
    /// POST /contacts
    std::string create(const std::string& json_body);
    /// GET /contacts/{id}
    std::string get(const std::string& id);
    /// PATCH /contacts/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// DELETE /contacts/{id}
    std::string del(const std::string& id);
    /// POST /contacts/import
    std::string importContacts(const std::string& json_body);
private:
    Client& client_;
};

class CampaignsResource {
public:
    explicit CampaignsResource(Client& c) : client_(c) {}
    /// GET /campaigns[?query]
    std::string list(const std::string& query = "");
    /// POST /campaigns
    std::string create(const std::string& json_body);
    /// GET /campaigns/{id}
    std::string get(const std::string& id);
    /// PATCH /campaigns/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// POST /campaigns/{id}/send
    std::string sendCampaign(const std::string& id);
    /// DELETE /campaigns/{id}
    std::string del(const std::string& id);
private:
    Client& client_;
};

class TemplatesResource {
public:
    explicit TemplatesResource(Client& c) : client_(c) {}
    /// GET /templates
    std::string list();
    /// POST /templates
    std::string create(const std::string& json_body);
    /// GET /templates/{id}
    std::string get(const std::string& id);
    /// PATCH /templates/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// DELETE /templates/{id}
    std::string del(const std::string& id);
    /// POST /templates/render
    std::string render(const std::string& json_body);
private:
    Client& client_;
};

class AutomationsResource {
public:
    explicit AutomationsResource(Client& c) : client_(c) {}
    /// GET /automations[?query]
    std::string list(const std::string& query = "");
    /// POST /automations
    std::string create(const std::string& json_body);
    /// GET /automations/{id}
    std::string get(const std::string& id);
    /// PATCH /automations/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// DELETE /automations/{id}
    std::string del(const std::string& id);
    /// POST /automations/{id}/activate
    std::string activate(const std::string& id, bool active);
private:
    Client& client_;
};

class DomainsResource {
public:
    explicit DomainsResource(Client& c) : client_(c) {}
    /// GET /domains
    std::string list();
    /// POST /domains
    std::string create(const std::string& json_body);
    /// GET /domains/{id}
    std::string get(const std::string& id);
    /// POST /domains/{id}/verify
    std::string verify(const std::string& id);
    /// DELETE /domains/{id}
    std::string del(const std::string& id);
private:
    Client& client_;
};

class AliasesResource {
public:
    explicit AliasesResource(Client& c) : client_(c) {}
    /// GET /aliases
    std::string list();
    /// POST /aliases
    std::string create(const std::string& json_body);
    /// GET /aliases/{id}
    std::string get(const std::string& id);
    /// PATCH /aliases/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// DELETE /aliases/{id}
    std::string del(const std::string& id);
private:
    Client& client_;
};

class DedicatedIPsResource {
public:
    explicit DedicatedIPsResource(Client& c) : client_(c) {}
    /// GET /dedicated-ips
    std::string list();
    /// POST /dedicated-ips
    std::string create(const std::string& json_body);
    /// PATCH /dedicated-ips/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// DELETE /dedicated-ips/{id}
    std::string del(const std::string& id);
private:
    Client& client_;
};

class ChannelsResource {
public:
    explicit ChannelsResource(Client& c) : client_(c) {}
    /// POST /channels/whatsapp
    std::string sendWhatsApp(const std::string& json_body);
    /// POST /channels/push
    std::string sendPush(const std::string& json_body);
private:
    Client& client_;
};

class ABTestsResource {
public:
    explicit ABTestsResource(Client& c) : client_(c) {}
    /// GET /ab-tests
    std::string list();
    /// POST /ab-tests
    std::string create(const std::string& json_body);
    /// GET /ab-tests/{id}
    std::string get(const std::string& id);
    /// POST /ab-tests/{id}/winner
    std::string setWinner(const std::string& id, const std::string& json_body);
private:
    Client& client_;
};

class SandboxResource {
public:
    explicit SandboxResource(Client& c) : client_(c) {}
    /// POST /sandbox/send
    std::string send(const std::string& json_body);
    /// GET /sandbox[?query]
    std::string list(const std::string& query = "");
    /// DELETE /sandbox/{id}
    std::string del(const std::string& id);
private:
    Client& client_;
};

class InboundResource {
public:
    explicit InboundResource(Client& c) : client_(c) {}
    /// GET /inbound[?query]
    std::string list(const std::string& query = "");
    /// POST /inbound
    std::string create(const std::string& json_body);
    /// GET /inbound/{id}
    std::string get(const std::string& id);
    /// DELETE /inbound/{id}
    std::string del(const std::string& id);
private:
    Client& client_;
};

class AnalyticsResource {
public:
    explicit AnalyticsResource(Client& c) : client_(c) {}
    /// GET /analytics[?query]
    std::string overview(const std::string& query = "");
private:
    Client& client_;
};

class TrackResource {
public:
    explicit TrackResource(Client& c) : client_(c) {}
    /// POST /track/event
    std::string event(const std::string& json_body);
    /// POST /track/purchase
    std::string purchase(const std::string& json_body);
private:
    Client& client_;
};

class KeysResource {
public:
    explicit KeysResource(Client& c) : client_(c) {}
    /// GET /keys
    std::string list();
    /// POST /keys
    std::string create(const std::string& json_body);
    /// GET /keys/{id}
    std::string get(const std::string& id);
    /// DELETE /keys/{id}
    std::string revoke(const std::string& id);
private:
    Client& client_;
};

class ValidateResource {
public:
    explicit ValidateResource(Client& c) : client_(c) {}
    /// POST /validate  — body: {"email":"<address>"}
    std::string email(const std::string& address);
private:
    Client& client_;
};

class LeadsResource {
public:
    explicit LeadsResource(Client& c) : client_(c) {}
    /// POST /leads/search
    std::string search(const std::string& json_body);
    /// GET /leads/jobs/{id}
    std::string getJob(const std::string& id);
    /// GET /leads/jobs[?query]
    std::string listJobs(const std::string& query = "");
    /// GET /leads/jobs/{job_id}/results
    std::string results(const std::string& job_id);
    /// POST /leads/import
    std::string importLeads(const std::string& json_body);
    /// GET /leads/credits
    std::string credits();
private:
    Client& client_;
};

class AutopilotResource {
public:
    explicit AutopilotResource(Client& c) : client_(c) {}
    /// POST /autopilot
    std::string start(const std::string& json_body);
    /// GET /autopilot/{id}
    std::string get(const std::string& id);
    /// GET /autopilot[?query]
    std::string list(const std::string& query = "");
    /// GET /autopilot/daily-plan
    std::string dailyPlan();
private:
    Client& client_;
};

class SalesAgentResource {
public:
    explicit SalesAgentResource(Client& c) : client_(c) {}
    /// GET /sales-agent/config
    std::string getConfig();
    /// PATCH /sales-agent/config
    std::string updateConfig(const std::string& json_body);
    /// GET /sales-agent/actions[?query]
    std::string getActions(const std::string& query = "");
private:
    Client& client_;
};

class CRMResource {
public:
    explicit CRMResource(Client& c) : client_(c) {}
    /// GET /crm/conversations[?query]
    std::string listConversations(const std::string& query = "");
    /// GET /crm/conversations/{id}
    std::string getConversation(const std::string& id);
    /// PATCH /crm/conversations/{id}
    std::string updateConversation(const std::string& id, const std::string& json_body);
    /// GET /crm/conversations/{conversation_id}/messages
    std::string listMessages(const std::string& conversation_id);
    /// GET /crm/deals[?query]
    std::string listDeals(const std::string& query = "");
    /// POST /crm/deals
    std::string createDeal(const std::string& json_body);
    /// GET /crm/deals/{id}
    std::string getDeal(const std::string& id);
    /// PATCH /crm/deals/{id}
    std::string updateDeal(const std::string& id, const std::string& json_body);
    /// DELETE /crm/deals/{id}
    std::string deleteDeal(const std::string& id);
    /// GET /crm/clients[?query]
    std::string listClients(const std::string& query = "");
    /// POST /crm/clients
    std::string createClient(const std::string& json_body);
private:
    Client& client_;
};

class WebhooksResource {
public:
    explicit WebhooksResource(Client& c) : client_(c) {}
    /// GET /webhooks
    std::string list();
    /// POST /webhooks
    std::string create(const std::string& json_body);
    /// GET /webhooks/{id}
    std::string get(const std::string& id);
    /// PATCH /webhooks/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// DELETE /webhooks/{id}
    std::string del(const std::string& id);
    /// POST /webhooks/{id}/test
    std::string test(const std::string& id);
private:
    Client& client_;
};

class UsageResource {
public:
    explicit UsageResource(Client& c) : client_(c) {}
    /// GET /usage[?query]
    std::string get(const std::string& query = "");
private:
    Client& client_;
};

class BillingResource {
public:
    explicit BillingResource(Client& c) : client_(c) {}
    /// GET {apiBase}/billing/subscription
    std::string subscription();
    /// POST {apiBase}/billing/checkout
    std::string checkout(const std::string& json_body);
private:
    Client& client_;
};

class WorkspacesResource {
public:
    explicit WorkspacesResource(Client& c) : client_(c) {}
    /// GET {apiBase}/workspaces
    std::string list();
    /// POST {apiBase}/workspaces
    std::string create(const std::string& json_body);
    /// GET {apiBase}/workspaces/{id}
    std::string get(const std::string& id);
    /// PATCH {apiBase}/workspaces/{id}
    std::string update(const std::string& id, const std::string& json_body);
    /// DELETE {apiBase}/workspaces/{id}
    std::string del(const std::string& id);
    /// GET {apiBase}/workspaces/{ws_id}/members
    std::string listMembers(const std::string& ws_id);
    /// POST {apiBase}/workspaces/{ws_id}/members
    std::string inviteMember(const std::string& ws_id, const std::string& json_body);
    /// PATCH {apiBase}/workspaces/{ws_id}/members/{user_id}
    std::string updateMember(const std::string& ws_id, const std::string& user_id, const std::string& json_body);
    /// DELETE {apiBase}/workspaces/{ws_id}/members/{user_id}
    std::string removeMember(const std::string& ws_id, const std::string& user_id);
private:
    Client& client_;
};

}  // namespace misarmail
