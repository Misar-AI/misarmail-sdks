#include "misarmail/client.hpp"

#include <curl/curl.h>

#include <chrono>
#include <sstream>
#include <thread>

namespace misarmail {

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

namespace {

size_t writeCallback(char* ptr, size_t size, size_t nmemb, void* userdata) {
    auto* buf = static_cast<std::string*>(userdata);
    buf->append(ptr, size * nmemb);
    return size * nmemb;
}

bool isRetryable(long code) {
    return code == 429 || code == 500 || code == 502 || code == 503 || code == 504;
}

void backoff(int attempt) {
    auto ms = std::chrono::milliseconds(200 * (1 << attempt));
    std::this_thread::sleep_for(ms);
}

std::string extractError(const std::string& json) {
    const std::string key = "\"error\"";
    auto pos = json.find(key);
    if (pos == std::string::npos) return json;
    pos = json.find(':', pos + key.size());
    if (pos == std::string::npos) return json;
    while (++pos < json.size() && (json[pos] == ' ' || json[pos] == '\t')) {}
    if (pos >= json.size()) return json;
    if (json[pos] == '"') {
        auto start = pos + 1;
        auto end = json.find('"', start);
        if (end != std::string::npos) return json.substr(start, end - start);
    }
    auto start = pos;
    auto end = json.find_first_of(",}\n", start);
    return json.substr(start, end == std::string::npos ? std::string::npos : end - start);
}

// Strip /v1 from the end of a URL to produce apiBase_
std::string makeApiBase(const std::string& url) {
    const std::string suffix = "/v1";
    if (url.size() >= suffix.size() &&
        url.compare(url.size() - suffix.size(), suffix.size(), suffix) == 0) {
        return url.substr(0, url.size() - suffix.size());
    }
    return url;
}

}  // namespace

// ---------------------------------------------------------------------------
// PIMPL
// ---------------------------------------------------------------------------

struct Client::Impl {
    std::string api_key;
    std::string base_url;
    std::string api_base;   // billing/workspaces — no /v1
    int         max_retries;
    CURL*       curl{nullptr};

    // Resource objects — stored by value, constructed with Client ref
    EmailResource        emailRes;
    ContactsResource     contactsRes;
    CampaignsResource    campaignsRes;
    TemplatesResource    templatesRes;
    AutomationsResource  automationsRes;
    DomainsResource      domainsRes;
    AliasesResource      aliasesRes;
    DedicatedIPsResource dedicatedIPsRes;
    ChannelsResource     channelsRes;
    ABTestsResource      abTestsRes;
    SandboxResource      sandboxRes;
    InboundResource      inboundRes;
    AnalyticsResource    analyticsRes;
    TrackResource        trackRes;
    KeysResource         keysRes;
    ValidateResource     validateRes;
    LeadsResource        leadsRes;
    AutopilotResource    autopilotRes;
    SalesAgentResource   salesAgentRes;
    CRMResource          crmRes;
    WebhooksResource     webhooksRes;
    UsageResource        usageRes;
    BillingResource      billingRes;
    WorkspacesResource   workspacesRes;

    Impl(Client& owner, std::string key, std::string url, int retries)
        : api_key(std::move(key)),
          max_retries(retries),
          emailRes(owner),
          contactsRes(owner),
          campaignsRes(owner),
          templatesRes(owner),
          automationsRes(owner),
          domainsRes(owner),
          aliasesRes(owner),
          dedicatedIPsRes(owner),
          channelsRes(owner),
          abTestsRes(owner),
          sandboxRes(owner),
          inboundRes(owner),
          analyticsRes(owner),
          trackRes(owner),
          keysRes(owner),
          validateRes(owner),
          leadsRes(owner),
          autopilotRes(owner),
          salesAgentRes(owner),
          crmRes(owner),
          webhooksRes(owner),
          usageRes(owner),
          billingRes(owner),
          workspacesRes(owner)
    {
        base_url = std::move(url);
        while (!base_url.empty() && base_url.back() == '/') base_url.pop_back();
        api_base = makeApiBase(base_url);
        curl = curl_easy_init();
        if (!curl) throw MisarMailError(0, "curl_easy_init() failed");
    }

    ~Impl() {
        if (curl) curl_easy_cleanup(curl);
    }

    // Core request — returns response body; throws MisarMailError on failure
    std::string request(const std::string& method,
                        const std::string& path,
                        const std::string& body = "",
                        bool use_api_base = false) {
        std::string url = (use_api_base ? api_base : base_url) + path;
        std::string auth_header = "Authorization: Bearer " + api_key;

        for (int attempt = 0; attempt < max_retries; ++attempt) {
            if (attempt > 0) backoff(attempt - 1);

            curl_easy_reset(curl);

            std::string response_body;
            long http_code = 0;

            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, writeCallback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response_body);
            curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 1L);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, 2L);
            curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

            struct curl_slist* headers = nullptr;
            headers = curl_slist_append(headers, auth_header.c_str());
            headers = curl_slist_append(headers, "Content-Type: application/json");
            headers = curl_slist_append(headers, "Accept: application/json");
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

            if (method == "POST") {
                curl_easy_setopt(curl, CURLOPT_POST, 1L);
                const std::string& b = body.empty() ? std::string("{}") : body;
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS, b.c_str());
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(b.size()));
            } else if (method == "GET") {
                curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
            } else {
                // PATCH, DELETE, etc.
                curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method.c_str());
                if (!body.empty()) {
                    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
                    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(body.size()));
                }
            }

            CURLcode res = curl_easy_perform(curl);
            curl_slist_free_all(headers);

            if (res != CURLE_OK) {
                if (attempt == max_retries - 1) {
                    throw MisarMailError(0, std::string("curl error: ") + curl_easy_strerror(res));
                }
                continue;
            }

            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
            int code = static_cast<int>(http_code);

            if (code >= 200 && code < 300) return response_body;

            if (isRetryable(code) && attempt < max_retries - 1) continue;

            throw MisarMailError(code, extractError(response_body));
        }

        throw MisarMailError(0, "request failed after retries");
    }
};

// ---------------------------------------------------------------------------
// Client lifecycle
// ---------------------------------------------------------------------------

Client::Client(std::string api_key, std::string base_url, int max_retries)
    : impl_(new Impl(*this, std::move(api_key), std::move(base_url), max_retries)),
      email(impl_->emailRes),
      contacts(impl_->contactsRes),
      campaigns(impl_->campaignsRes),
      templates(impl_->templatesRes),
      automations(impl_->automationsRes),
      domains(impl_->domainsRes),
      aliases(impl_->aliasesRes),
      dedicatedIPs(impl_->dedicatedIPsRes),
      channels(impl_->channelsRes),
      abTests(impl_->abTestsRes),
      sandbox(impl_->sandboxRes),
      inbound(impl_->inboundRes),
      analytics(impl_->analyticsRes),
      track(impl_->trackRes),
      keys(impl_->keysRes),
      validate(impl_->validateRes),
      leads(impl_->leadsRes),
      autopilot(impl_->autopilotRes),
      salesAgent(impl_->salesAgentRes),
      crm(impl_->crmRes),
      webhooks(impl_->webhooksRes),
      usage(impl_->usageRes),
      billing(impl_->billingRes),
      workspaces(impl_->workspacesRes)
{}

Client::~Client() { delete impl_; }

Client::Client(Client&& other) noexcept
    : impl_(other.impl_),
      email(impl_->emailRes),
      contacts(impl_->contactsRes),
      campaigns(impl_->campaignsRes),
      templates(impl_->templatesRes),
      automations(impl_->automationsRes),
      domains(impl_->domainsRes),
      aliases(impl_->aliasesRes),
      dedicatedIPs(impl_->dedicatedIPsRes),
      channels(impl_->channelsRes),
      abTests(impl_->abTestsRes),
      sandbox(impl_->sandboxRes),
      inbound(impl_->inboundRes),
      analytics(impl_->analyticsRes),
      track(impl_->trackRes),
      keys(impl_->keysRes),
      validate(impl_->validateRes),
      leads(impl_->leadsRes),
      autopilot(impl_->autopilotRes),
      salesAgent(impl_->salesAgentRes),
      crm(impl_->crmRes),
      webhooks(impl_->webhooksRes),
      usage(impl_->usageRes),
      billing(impl_->billingRes),
      workspaces(impl_->workspacesRes)
{
    other.impl_ = nullptr;
}

Client& Client::operator=(Client&& other) noexcept {
    if (this != &other) {
        delete impl_;
        impl_ = other.impl_;
        other.impl_ = nullptr;
        // Re-bind references would require placement new — not safe here.
        // Users should avoid move-assigning after construction.
    }
    return *this;
}

// ---------------------------------------------------------------------------
// EmailResource
// ---------------------------------------------------------------------------

std::string EmailResource::send(const std::string& json_body) {
    return client_.impl_->request("POST", "/send", json_body);
}

// ---------------------------------------------------------------------------
// ContactsResource
// ---------------------------------------------------------------------------

std::string ContactsResource::list(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/contacts" : "/contacts?" + query);
}
std::string ContactsResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/contacts", json_body);
}
std::string ContactsResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/contacts/" + id);
}
std::string ContactsResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/contacts/" + id, json_body);
}
std::string ContactsResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/contacts/" + id);
}
std::string ContactsResource::importContacts(const std::string& json_body) {
    return client_.impl_->request("POST", "/contacts/import", json_body);
}

// ---------------------------------------------------------------------------
// CampaignsResource
// ---------------------------------------------------------------------------

std::string CampaignsResource::list(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/campaigns" : "/campaigns?" + query);
}
std::string CampaignsResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/campaigns", json_body);
}
std::string CampaignsResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/campaigns/" + id);
}
std::string CampaignsResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/campaigns/" + id, json_body);
}
std::string CampaignsResource::sendCampaign(const std::string& id) {
    return client_.impl_->request("POST", "/campaigns/" + id + "/send");
}
std::string CampaignsResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/campaigns/" + id);
}

// ---------------------------------------------------------------------------
// TemplatesResource
// ---------------------------------------------------------------------------

std::string TemplatesResource::list() {
    return client_.impl_->request("GET", "/templates");
}
std::string TemplatesResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/templates", json_body);
}
std::string TemplatesResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/templates/" + id);
}
std::string TemplatesResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/templates/" + id, json_body);
}
std::string TemplatesResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/templates/" + id);
}
std::string TemplatesResource::render(const std::string& json_body) {
    return client_.impl_->request("POST", "/templates/render", json_body);
}

// ---------------------------------------------------------------------------
// AutomationsResource
// ---------------------------------------------------------------------------

std::string AutomationsResource::list(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/automations" : "/automations?" + query);
}
std::string AutomationsResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/automations", json_body);
}
std::string AutomationsResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/automations/" + id);
}
std::string AutomationsResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/automations/" + id, json_body);
}
std::string AutomationsResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/automations/" + id);
}
std::string AutomationsResource::activate(const std::string& id, bool active) {
    std::string body = std::string("{\"active\":") + (active ? "true" : "false") + "}";
    return client_.impl_->request("POST", "/automations/" + id + "/activate", body);
}

// ---------------------------------------------------------------------------
// DomainsResource
// ---------------------------------------------------------------------------

std::string DomainsResource::list() {
    return client_.impl_->request("GET", "/domains");
}
std::string DomainsResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/domains", json_body);
}
std::string DomainsResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/domains/" + id);
}
std::string DomainsResource::verify(const std::string& id) {
    return client_.impl_->request("POST", "/domains/" + id + "/verify");
}
std::string DomainsResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/domains/" + id);
}

// ---------------------------------------------------------------------------
// AliasesResource
// ---------------------------------------------------------------------------

std::string AliasesResource::list() {
    return client_.impl_->request("GET", "/aliases");
}
std::string AliasesResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/aliases", json_body);
}
std::string AliasesResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/aliases/" + id);
}
std::string AliasesResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/aliases/" + id, json_body);
}
std::string AliasesResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/aliases/" + id);
}

// ---------------------------------------------------------------------------
// DedicatedIPsResource
// ---------------------------------------------------------------------------

std::string DedicatedIPsResource::list() {
    return client_.impl_->request("GET", "/dedicated-ips");
}
std::string DedicatedIPsResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/dedicated-ips", json_body);
}
std::string DedicatedIPsResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/dedicated-ips/" + id, json_body);
}
std::string DedicatedIPsResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/dedicated-ips/" + id);
}

// ---------------------------------------------------------------------------
// ChannelsResource
// ---------------------------------------------------------------------------

std::string ChannelsResource::sendWhatsApp(const std::string& json_body) {
    return client_.impl_->request("POST", "/channels/whatsapp", json_body);
}
std::string ChannelsResource::sendPush(const std::string& json_body) {
    return client_.impl_->request("POST", "/channels/push", json_body);
}

// ---------------------------------------------------------------------------
// ABTestsResource
// ---------------------------------------------------------------------------

std::string ABTestsResource::list() {
    return client_.impl_->request("GET", "/ab-tests");
}
std::string ABTestsResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/ab-tests", json_body);
}
std::string ABTestsResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/ab-tests/" + id);
}
std::string ABTestsResource::setWinner(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("POST", "/ab-tests/" + id + "/winner", json_body);
}

// ---------------------------------------------------------------------------
// SandboxResource
// ---------------------------------------------------------------------------

std::string SandboxResource::send(const std::string& json_body) {
    return client_.impl_->request("POST", "/sandbox/send", json_body);
}
std::string SandboxResource::list(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/sandbox" : "/sandbox?" + query);
}
std::string SandboxResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/sandbox/" + id);
}

// ---------------------------------------------------------------------------
// InboundResource
// ---------------------------------------------------------------------------

std::string InboundResource::list(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/inbound" : "/inbound?" + query);
}
std::string InboundResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/inbound", json_body);
}
std::string InboundResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/inbound/" + id);
}
std::string InboundResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/inbound/" + id);
}

// ---------------------------------------------------------------------------
// AnalyticsResource
// ---------------------------------------------------------------------------

std::string AnalyticsResource::overview(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/analytics" : "/analytics?" + query);
}

// ---------------------------------------------------------------------------
// TrackResource
// ---------------------------------------------------------------------------

std::string TrackResource::event(const std::string& json_body) {
    return client_.impl_->request("POST", "/track/event", json_body);
}
std::string TrackResource::purchase(const std::string& json_body) {
    return client_.impl_->request("POST", "/track/purchase", json_body);
}

// ---------------------------------------------------------------------------
// KeysResource
// ---------------------------------------------------------------------------

std::string KeysResource::list() {
    return client_.impl_->request("GET", "/keys");
}
std::string KeysResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/keys", json_body);
}
std::string KeysResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/keys/" + id);
}
std::string KeysResource::revoke(const std::string& id) {
    return client_.impl_->request("DELETE", "/keys/" + id);
}

// ---------------------------------------------------------------------------
// ValidateResource
// ---------------------------------------------------------------------------

std::string ValidateResource::email(const std::string& address) {
    std::string body = "{\"email\":\"" + address + "\"}";
    return client_.impl_->request("POST", "/validate", body);
}

// ---------------------------------------------------------------------------
// LeadsResource
// ---------------------------------------------------------------------------

std::string LeadsResource::search(const std::string& json_body) {
    return client_.impl_->request("POST", "/leads/search", json_body);
}
std::string LeadsResource::getJob(const std::string& id) {
    return client_.impl_->request("GET", "/leads/jobs/" + id);
}
std::string LeadsResource::listJobs(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/leads/jobs" : "/leads/jobs?" + query);
}
std::string LeadsResource::results(const std::string& job_id) {
    return client_.impl_->request("GET", "/leads/jobs/" + job_id + "/results");
}
std::string LeadsResource::importLeads(const std::string& json_body) {
    return client_.impl_->request("POST", "/leads/import", json_body);
}
std::string LeadsResource::credits() {
    return client_.impl_->request("GET", "/leads/credits");
}

// ---------------------------------------------------------------------------
// AutopilotResource
// ---------------------------------------------------------------------------

std::string AutopilotResource::start(const std::string& json_body) {
    return client_.impl_->request("POST", "/autopilot", json_body);
}
std::string AutopilotResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/autopilot/" + id);
}
std::string AutopilotResource::list(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/autopilot" : "/autopilot?" + query);
}
std::string AutopilotResource::dailyPlan() {
    return client_.impl_->request("GET", "/autopilot/daily-plan");
}

// ---------------------------------------------------------------------------
// SalesAgentResource
// ---------------------------------------------------------------------------

std::string SalesAgentResource::getConfig() {
    return client_.impl_->request("GET", "/sales-agent/config");
}
std::string SalesAgentResource::updateConfig(const std::string& json_body) {
    return client_.impl_->request("PATCH", "/sales-agent/config", json_body);
}
std::string SalesAgentResource::getActions(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/sales-agent/actions" : "/sales-agent/actions?" + query);
}

// ---------------------------------------------------------------------------
// CRMResource
// ---------------------------------------------------------------------------

std::string CRMResource::listConversations(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/crm/conversations" : "/crm/conversations?" + query);
}
std::string CRMResource::getConversation(const std::string& id) {
    return client_.impl_->request("GET", "/crm/conversations/" + id);
}
std::string CRMResource::updateConversation(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/crm/conversations/" + id, json_body);
}
std::string CRMResource::listMessages(const std::string& conversation_id) {
    return client_.impl_->request("GET", "/crm/conversations/" + conversation_id + "/messages");
}
std::string CRMResource::listDeals(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/crm/deals" : "/crm/deals?" + query);
}
std::string CRMResource::createDeal(const std::string& json_body) {
    return client_.impl_->request("POST", "/crm/deals", json_body);
}
std::string CRMResource::getDeal(const std::string& id) {
    return client_.impl_->request("GET", "/crm/deals/" + id);
}
std::string CRMResource::updateDeal(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/crm/deals/" + id, json_body);
}
std::string CRMResource::deleteDeal(const std::string& id) {
    return client_.impl_->request("DELETE", "/crm/deals/" + id);
}
std::string CRMResource::listClients(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/crm/clients" : "/crm/clients?" + query);
}
std::string CRMResource::createClient(const std::string& json_body) {
    return client_.impl_->request("POST", "/crm/clients", json_body);
}

// ---------------------------------------------------------------------------
// WebhooksResource
// ---------------------------------------------------------------------------

std::string WebhooksResource::list() {
    return client_.impl_->request("GET", "/webhooks");
}
std::string WebhooksResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/webhooks", json_body);
}
std::string WebhooksResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/webhooks/" + id);
}
std::string WebhooksResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/webhooks/" + id, json_body);
}
std::string WebhooksResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/webhooks/" + id);
}
std::string WebhooksResource::test(const std::string& id) {
    return client_.impl_->request("POST", "/webhooks/" + id + "/test");
}

// ---------------------------------------------------------------------------
// UsageResource
// ---------------------------------------------------------------------------

std::string UsageResource::get(const std::string& query) {
    return client_.impl_->request("GET", query.empty() ? "/usage" : "/usage?" + query);
}

// ---------------------------------------------------------------------------
// BillingResource  (api_base — no /v1)
// ---------------------------------------------------------------------------

std::string BillingResource::subscription() {
    return client_.impl_->request("GET", "/billing/subscription", "", true);
}
std::string BillingResource::checkout(const std::string& json_body) {
    return client_.impl_->request("POST", "/billing/checkout", json_body, true);
}

// ---------------------------------------------------------------------------
// WorkspacesResource  (api_base — no /v1)
// ---------------------------------------------------------------------------

std::string WorkspacesResource::list() {
    return client_.impl_->request("GET", "/workspaces", "", true);
}
std::string WorkspacesResource::create(const std::string& json_body) {
    return client_.impl_->request("POST", "/workspaces", json_body, true);
}
std::string WorkspacesResource::get(const std::string& id) {
    return client_.impl_->request("GET", "/workspaces/" + id, "", true);
}
std::string WorkspacesResource::update(const std::string& id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/workspaces/" + id, json_body, true);
}
std::string WorkspacesResource::del(const std::string& id) {
    return client_.impl_->request("DELETE", "/workspaces/" + id, "", true);
}
std::string WorkspacesResource::listMembers(const std::string& ws_id) {
    return client_.impl_->request("GET", "/workspaces/" + ws_id + "/members", "", true);
}
std::string WorkspacesResource::inviteMember(const std::string& ws_id, const std::string& json_body) {
    return client_.impl_->request("POST", "/workspaces/" + ws_id + "/members", json_body, true);
}
std::string WorkspacesResource::updateMember(const std::string& ws_id, const std::string& user_id, const std::string& json_body) {
    return client_.impl_->request("PATCH", "/workspaces/" + ws_id + "/members/" + user_id, json_body, true);
}
std::string WorkspacesResource::removeMember(const std::string& ws_id, const std::string& user_id) {
    return client_.impl_->request("DELETE", "/workspaces/" + ws_id + "/members/" + user_id, "", true);
}

}  // namespace misarmail
