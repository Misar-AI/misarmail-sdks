import Foundation

// MARK: - Error

public enum MisarMailError: Error {
    case apiError(status: Int, message: String)
    case networkError(message: String)
}

// MARK: - Client

public final class MisarMailClient {

    public let apiKey: String
    public let baseURL: String
    public let maxRetries: Int
    public let session: URLSession

    private static let retryableStatuses: Set<Int> = [429, 500, 502, 503, 504]

    public init(
        apiKey: String,
        baseURL: String = "https://mail.misar.io/api/v1",
        maxRetries: Int = 3,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        let trimmed = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.baseURL = trimmed
        self.maxRetries = maxRetries
        self.session = session
    }

    /// Base for billing/workspaces — strips /v1 suffix.
    internal var apiBase: String {
        if baseURL.hasSuffix("/v1") {
            return String(baseURL.dropLast(3))
        }
        return baseURL
    }

    // MARK: Core request

    internal func request(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        useApiBase: Bool = false
    ) async throws -> [String: Any] {
        let base = useApiBase ? apiBase : baseURL
        guard let url = URL(string: base + path) else {
            throw MisarMailError.networkError(message: "Invalid URL: \(base + path)")
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: 30)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        } else if method == "POST" {
            urlRequest.httpBody = Data("{}".utf8)
        }

        var lastError: Error?

        for attempt in 0..<maxRetries {
            if attempt > 0 {
                let delayNs = UInt64(500_000_000) * UInt64(1 << (attempt - 1))
                try await Task.sleep(nanoseconds: delayNs)
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: urlRequest)
            } catch {
                lastError = error
                continue
            }

            guard let http = response as? HTTPURLResponse else {
                lastError = MisarMailError.networkError(message: "Non-HTTP response")
                continue
            }

            let status = http.statusCode

            if Self.retryableStatuses.contains(status) && attempt < maxRetries - 1 {
                lastError = MisarMailError.apiError(status: status, message: "retryable")
                continue
            }

            if (200..<300).contains(status) {
                if data.isEmpty { return [:] }
                guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return [:]
                }
                return parsed
            }

            let msg = extractError(from: data)
            throw MisarMailError.apiError(status: status, message: msg)
        }

        throw MisarMailError.networkError(message: "max retries exceeded: \(lastError?.localizedDescription ?? "unknown")")
    }

    private func extractError(from data: Data) -> String {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let msg = obj["error"] as? String
        else {
            return String(data: data, encoding: .utf8) ?? "error"
        }
        return msg
    }

    // MARK: - Resource accessors

    public lazy var email        = EmailResource(client: self)
    public lazy var contacts     = ContactsResource(client: self)
    public lazy var campaigns    = CampaignsResource(client: self)
    public lazy var templates    = TemplatesResource(client: self)
    public lazy var automations  = AutomationsResource(client: self)
    public lazy var domains      = DomainsResource(client: self)
    public lazy var aliases      = AliasesResource(client: self)
    public lazy var dedicatedIPs = DedicatedIPsResource(client: self)
    public lazy var channels     = ChannelsResource(client: self)
    public lazy var abTests      = ABTestsResource(client: self)
    public lazy var sandbox      = SandboxResource(client: self)
    public lazy var inbound      = InboundResource(client: self)
    public lazy var analytics    = AnalyticsResource(client: self)
    public lazy var track        = TrackResource(client: self)
    public lazy var keys         = KeysResource(client: self)
    public lazy var validate     = ValidateResource(client: self)
    public lazy var leads        = LeadsResource(client: self)
    public lazy var autopilot    = AutopilotResource(client: self)
    public lazy var salesAgent   = SalesAgentResource(client: self)
    public lazy var crm          = CRMResource(client: self)
    public lazy var webhooks     = WebhooksResource(client: self)
    public lazy var usage        = UsageResource(client: self)
    public lazy var billing      = BillingResource(client: self)
    public lazy var workspaces   = WorkspacesResource(client: self)
}

// MARK: - EmailResource

public class EmailResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// POST /send
    public func send(_ data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/send", body: data)
    }
}

// MARK: - ContactsResource

public class ContactsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /contacts
    public func list(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/contacts?\($0)" } ?? "/contacts"
        return try await client.request(method: "GET", path: path)
    }

    /// POST /contacts
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/contacts", body: data)
    }

    /// GET /contacts/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/contacts/\(id)")
    }

    /// PATCH /contacts/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/contacts/\(id)", body: data)
    }

    /// DELETE /contacts/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/contacts/\(id)")
    }

    /// POST /contacts/import
    public func importContacts(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/contacts/import", body: data)
    }
}

// MARK: - CampaignsResource

public class CampaignsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /campaigns
    public func list(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/campaigns?\($0)" } ?? "/campaigns"
        return try await client.request(method: "GET", path: path)
    }

    /// POST /campaigns
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/campaigns", body: data)
    }

    /// GET /campaigns/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/campaigns/\(id)")
    }

    /// PATCH /campaigns/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/campaigns/\(id)", body: data)
    }

    /// POST /campaigns/{id}/send
    public func sendCampaign(id: String) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/campaigns/\(id)/send")
    }

    /// DELETE /campaigns/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/campaigns/\(id)")
    }
}

// MARK: - TemplatesResource

public class TemplatesResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /templates
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/templates")
    }

    /// POST /templates
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/templates", body: data)
    }

    /// GET /templates/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/templates/\(id)")
    }

    /// PATCH /templates/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/templates/\(id)", body: data)
    }

    /// DELETE /templates/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/templates/\(id)")
    }

    /// POST /templates/render
    public func render(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/templates/render", body: data)
    }
}

// MARK: - AutomationsResource

public class AutomationsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /automations
    public func list(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/automations?\($0)" } ?? "/automations"
        return try await client.request(method: "GET", path: path)
    }

    /// POST /automations
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/automations", body: data)
    }

    /// GET /automations/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/automations/\(id)")
    }

    /// PATCH /automations/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/automations/\(id)", body: data)
    }

    /// DELETE /automations/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/automations/\(id)")
    }

    /// POST /automations/{id}/activate
    public func activate(id: String, active: Bool) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/automations/\(id)/activate", body: ["active": active])
    }
}

// MARK: - DomainsResource

public class DomainsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /domains
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/domains")
    }

    /// POST /domains
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/domains", body: data)
    }

    /// GET /domains/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/domains/\(id)")
    }

    /// POST /domains/{id}/verify
    public func verify(id: String) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/domains/\(id)/verify")
    }

    /// DELETE /domains/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/domains/\(id)")
    }
}

// MARK: - AliasesResource

public class AliasesResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /aliases
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/aliases")
    }

    /// POST /aliases
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/aliases", body: data)
    }

    /// GET /aliases/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/aliases/\(id)")
    }

    /// PATCH /aliases/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/aliases/\(id)", body: data)
    }

    /// DELETE /aliases/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/aliases/\(id)")
    }
}

// MARK: - DedicatedIPsResource

public class DedicatedIPsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /dedicated-ips
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/dedicated-ips")
    }

    /// POST /dedicated-ips
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/dedicated-ips", body: data)
    }

    /// PATCH /dedicated-ips/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/dedicated-ips/\(id)", body: data)
    }

    /// DELETE /dedicated-ips/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/dedicated-ips/\(id)")
    }
}

// MARK: - ChannelsResource

public class ChannelsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// POST /channels/whatsapp
    public func sendWhatsApp(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/channels/whatsapp", body: data)
    }

    /// POST /channels/push
    public func sendPush(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/channels/push", body: data)
    }
}

// MARK: - ABTestsResource

public class ABTestsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /ab-tests
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/ab-tests")
    }

    /// POST /ab-tests
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/ab-tests", body: data)
    }

    /// GET /ab-tests/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/ab-tests/\(id)")
    }

    /// POST /ab-tests/{id}/winner
    public func setWinner(id: String, variantId: String) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/ab-tests/\(id)/winner", body: ["variantId": variantId])
    }
}

// MARK: - SandboxResource

public class SandboxResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// POST /sandbox/send
    public func send(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/sandbox/send", body: data)
    }

    /// GET /sandbox
    public func list(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/sandbox?\($0)" } ?? "/sandbox"
        return try await client.request(method: "GET", path: path)
    }

    /// DELETE /sandbox/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/sandbox/\(id)")
    }
}

// MARK: - InboundResource

public class InboundResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /inbound
    public func list(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/inbound?\($0)" } ?? "/inbound"
        return try await client.request(method: "GET", path: path)
    }

    /// POST /inbound
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/inbound", body: data)
    }

    /// GET /inbound/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/inbound/\(id)")
    }

    /// DELETE /inbound/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/inbound/\(id)")
    }
}

// MARK: - AnalyticsResource

public class AnalyticsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /analytics
    public func overview(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/analytics?\($0)" } ?? "/analytics"
        return try await client.request(method: "GET", path: path)
    }
}

// MARK: - TrackResource

public class TrackResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// POST /track/event
    public func event(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/track/event", body: data)
    }

    /// POST /track/purchase
    public func purchase(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/track/purchase", body: data)
    }
}

// MARK: - KeysResource

public class KeysResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /keys
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/keys")
    }

    /// POST /keys
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/keys", body: data)
    }

    /// GET /keys/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/keys/\(id)")
    }

    /// DELETE /keys/{id}
    public func revoke(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/keys/\(id)")
    }
}

// MARK: - ValidateResource

public class ValidateResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// POST /validate
    public func email(address: String) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/validate", body: ["email": address])
    }
}

// MARK: - LeadsResource

public class LeadsResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// POST /leads/search
    public func search(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/leads/search", body: data)
    }

    /// GET /leads/jobs/{id}
    public func getJob(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/leads/jobs/\(id)")
    }

    /// GET /leads/jobs
    public func listJobs(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/leads/jobs?\($0)" } ?? "/leads/jobs"
        return try await client.request(method: "GET", path: path)
    }

    /// GET /leads/jobs/{jobId}/results
    public func results(jobId: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/leads/jobs/\(jobId)/results")
    }

    /// POST /leads/import
    public func importLeads(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/leads/import", body: data)
    }

    /// GET /leads/credits
    public func credits() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/leads/credits")
    }
}

// MARK: - AutopilotResource

public class AutopilotResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// POST /autopilot
    public func start(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/autopilot", body: data)
    }

    /// GET /autopilot/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/autopilot/\(id)")
    }

    /// GET /autopilot
    public func list(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/autopilot?\($0)" } ?? "/autopilot"
        return try await client.request(method: "GET", path: path)
    }

    /// GET /autopilot/daily-plan
    public func dailyPlan() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/autopilot/daily-plan")
    }
}

// MARK: - SalesAgentResource

public class SalesAgentResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /sales-agent/config
    public func getConfig() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/sales-agent/config")
    }

    /// PATCH /sales-agent/config
    public func updateConfig(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/sales-agent/config", body: data)
    }

    /// GET /sales-agent/actions
    public func getActions(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/sales-agent/actions?\($0)" } ?? "/sales-agent/actions"
        return try await client.request(method: "GET", path: path)
    }
}

// MARK: - CRMResource

public class CRMResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /crm/conversations
    public func listConversations(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/crm/conversations?\($0)" } ?? "/crm/conversations"
        return try await client.request(method: "GET", path: path)
    }

    /// GET /crm/conversations/{id}
    public func getConversation(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/crm/conversations/\(id)")
    }

    /// PATCH /crm/conversations/{id}
    public func updateConversation(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/crm/conversations/\(id)", body: data)
    }

    /// GET /crm/conversations/{conversationId}/messages
    public func listMessages(conversationId: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/crm/conversations/\(conversationId)/messages")
    }

    /// GET /crm/deals
    public func listDeals(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/crm/deals?\($0)" } ?? "/crm/deals"
        return try await client.request(method: "GET", path: path)
    }

    /// POST /crm/deals
    public func createDeal(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/crm/deals", body: data)
    }

    /// GET /crm/deals/{id}
    public func getDeal(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/crm/deals/\(id)")
    }

    /// PATCH /crm/deals/{id}
    public func updateDeal(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/crm/deals/\(id)", body: data)
    }

    /// DELETE /crm/deals/{id}
    public func deleteDeal(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/crm/deals/\(id)")
    }

    /// GET /crm/clients
    public func listClients(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/crm/clients?\($0)" } ?? "/crm/clients"
        return try await client.request(method: "GET", path: path)
    }

    /// POST /crm/clients
    public func createClient(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/crm/clients", body: data)
    }
}

// MARK: - WebhooksResource

public class WebhooksResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /webhooks
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/webhooks")
    }

    /// POST /webhooks
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/webhooks", body: data)
    }

    /// GET /webhooks/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/webhooks/\(id)")
    }

    /// PATCH /webhooks/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/webhooks/\(id)", body: data)
    }

    /// DELETE /webhooks/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/webhooks/\(id)")
    }

    /// POST /webhooks/{id}/test
    public func test(id: String) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/webhooks/\(id)/test")
    }
}

// MARK: - UsageResource

public class UsageResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET /usage
    public func get(params: String? = nil) async throws -> [String: Any] {
        let path = params.map { "/usage?\($0)" } ?? "/usage"
        return try await client.request(method: "GET", path: path)
    }
}

// MARK: - BillingResource

public class BillingResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET {apiBase}/billing/subscription
    public func subscription() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/billing/subscription", useApiBase: true)
    }

    /// POST {apiBase}/billing/checkout
    public func checkout(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/billing/checkout", body: data, useApiBase: true)
    }
}

// MARK: - WorkspacesResource

public class WorkspacesResource {
    private unowned let client: MisarMailClient
    init(client: MisarMailClient) { self.client = client }

    /// GET {apiBase}/workspaces
    public func list() async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/workspaces", useApiBase: true)
    }

    /// POST {apiBase}/workspaces
    public func create(data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/workspaces", body: data, useApiBase: true)
    }

    /// GET {apiBase}/workspaces/{id}
    public func get(id: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/workspaces/\(id)", useApiBase: true)
    }

    /// PATCH {apiBase}/workspaces/{id}
    public func update(id: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/workspaces/\(id)", body: data, useApiBase: true)
    }

    /// DELETE {apiBase}/workspaces/{id}
    public func delete(id: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/workspaces/\(id)", useApiBase: true)
    }

    /// GET {apiBase}/workspaces/{wsId}/members
    public func listMembers(wsId: String) async throws -> [String: Any] {
        try await client.request(method: "GET", path: "/workspaces/\(wsId)/members", useApiBase: true)
    }

    /// POST {apiBase}/workspaces/{wsId}/members
    public func inviteMember(wsId: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "POST", path: "/workspaces/\(wsId)/members", body: data, useApiBase: true)
    }

    /// PATCH {apiBase}/workspaces/{wsId}/members/{userId}
    public func updateMember(wsId: String, userId: String, data: [String: Any]) async throws -> [String: Any] {
        try await client.request(method: "PATCH", path: "/workspaces/\(wsId)/members/\(userId)", body: data, useApiBase: true)
    }

    /// DELETE {apiBase}/workspaces/{wsId}/members/{userId}
    public func removeMember(wsId: String, userId: String) async throws -> [String: Any] {
        try await client.request(method: "DELETE", path: "/workspaces/\(wsId)/members/\(userId)", useApiBase: true)
    }
}
