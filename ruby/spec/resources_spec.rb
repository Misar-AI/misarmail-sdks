require "spec_helper"

# client_spec.rb covers six resources. The gem ships thirty-odd, and each one is
# a thin wrapper whose entire job is to pick an HTTP verb and build a path — so
# the thing worth asserting is exactly that: the request that went out, and the
# parsed body that came back.
#
# Two base URLs are in play. Most resources use the client's base_url, but
# DomainsResource and BillingResource pass API_BASE/BILLING_BASE explicitly as
# the fourth argument to Client#request, which means base_url: does NOT move
# them. Tests for those must stub the un-versioned host.
RSpec.describe "MisarMail resource routing" do
  V1  = "https://api.misar.io/mail/v1".freeze
  API = "https://api.misar.io/mail".freeze

  let(:client) { MisarMail::Client.new(api_key: "test-key", base_url: V1, max_retries: 1) }

  def json(body)
    { status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  # [description, verb, base, path, callable, expected parsed response]
  #
  # The path is asserted by WebMock itself: net connect is disabled, so a call
  # that builds any other path raises NetConnectNotAllowedError instead of
  # quietly passing.
  ROUTES = [
    ["contacts.get",             :get,    :v1, "/contacts?id=c_1",              ->(c) { c.contacts.get("c_1") },                     { "id" => "c_1" }],
    ["contacts.delete",          :delete, :v1, "/contacts?id=c_1",              ->(c) { c.contacts.delete("c_1") },                  { "deleted" => true }],
    ["contacts.import_contacts", :post,   :v1, "/contacts/import",              ->(c) { c.contacts.import_contacts(rows: []) },      { "imported" => 0 }],

    ["campaigns.create",         :post,   :v1, "/campaigns",                    ->(c) { c.campaigns.create(name: "Launch") },        { "id" => "cmp_1" }],
    ["campaigns.get",            :get,    :v1, "/campaigns/cmp_1",              ->(c) { c.campaigns.get("cmp_1") },                  { "id" => "cmp_1" }],
    ["campaigns.update",         :patch,  :v1, "/campaigns/cmp_1",              ->(c) { c.campaigns.update("cmp_1", name: "New") },  { "id" => "cmp_1", "name" => "New" }],
    ["campaigns.send",           :post,   :v1, "/campaigns/cmp_1/send",         ->(c) { c.campaigns.send("cmp_1") },                 { "status" => "sending" }],
    ["campaigns.delete",         :delete, :v1, "/campaigns/cmp_1",              ->(c) { c.campaigns.delete("cmp_1") },               { "deleted" => true }],

    ["templates.list",           :get,    :v1, "/templates",                    ->(c) { c.templates.list },                          { "templates" => [] }],
    ["templates.create",         :post,   :v1, "/templates",                    ->(c) { c.templates.create(name: "Welcome") },       { "id" => "tpl_1" }],
    ["templates.get",            :get,    :v1, "/templates/tpl_1",              ->(c) { c.templates.get("tpl_1") },                  { "id" => "tpl_1" }],
    ["templates.update",         :patch,  :v1, "/templates/tpl_1",              ->(c) { c.templates.update("tpl_1", name: "W2") },   { "id" => "tpl_1" }],
    ["templates.delete",         :delete, :v1, "/templates/tpl_1",              ->(c) { c.templates.delete("tpl_1") },               { "deleted" => true }],
    ["templates.render",         :post,   :v1, "/templates/render",             ->(c) { c.templates.render(id: "tpl_1") },           { "html" => "<p>Hi</p>" }],

    ["automations.list",         :get,    :v1, "/automations",                  ->(c) { c.automations.list },                        { "automations" => [] }],
    ["automations.create",       :post,   :v1, "/automations",                  ->(c) { c.automations.create(name: "Drip") },        { "id" => "aut_1" }],
    ["automations.get",          :get,    :v1, "/automations/aut_1",            ->(c) { c.automations.get("aut_1") },                { "id" => "aut_1" }],
    ["automations.update",       :patch,  :v1, "/automations/aut_1",            ->(c) { c.automations.update("aut_1", name: "D2") }, { "id" => "aut_1" }],
    ["automations.delete",       :delete, :v1, "/automations/aut_1",            ->(c) { c.automations.delete("aut_1") },             { "deleted" => true }],

    ["domains.list",             :get,    :api, "/domains",                     ->(c) { c.domains.list },                            { "domains" => [] }],
    ["domains.create",           :post,   :api, "/domains",                     ->(c) { c.domains.create(domain: "x.com") },         { "id" => "dom_1" }],
    ["domains.get",              :get,    :api, "/domains/dom_1",               ->(c) { c.domains.get("dom_1") },                    { "id" => "dom_1" }],
    ["domains.verify",           :post,   :api, "/domains/dom_1/verify",        ->(c) { c.domains.verify("dom_1") },                 { "verified" => true }],
    ["domains.delete",           :delete, :api, "/domains/dom_1",               ->(c) { c.domains.delete("dom_1") },                 { "deleted" => true }],

    ["dedicated_ips.list",       :get,    :v1, "/dedicated-ips",                ->(c) { c.dedicated_ips.list },                      { "ips" => [] }],
    ["dedicated_ips.create",     :post,   :v1, "/dedicated-ips",                ->(c) { c.dedicated_ips.create(region: "us") },      { "id" => "ip_1" }],
    ["dedicated_ips.update",     :patch,  :v1, "/dedicated-ips/ip_1",           ->(c) { c.dedicated_ips.update("ip_1", ptr: "a") },  { "id" => "ip_1" }],
    ["dedicated_ips.delete",     :delete, :v1, "/dedicated-ips/ip_1",           ->(c) { c.dedicated_ips.delete("ip_1") },            { "deleted" => true }],

    ["ab_tests.list",            :get,    :v1, "/ab-tests",                     ->(c) { c.ab_tests.list },                           { "tests" => [] }],
    ["ab_tests.create",          :post,   :v1, "/ab-tests",                     ->(c) { c.ab_tests.create(name: "Subject") },        { "id" => "ab_1" }],
    ["ab_tests.get",             :get,    :v1, "/ab-tests/ab_1",                ->(c) { c.ab_tests.get("ab_1") },                    { "id" => "ab_1" }],

    ["sandbox.send",             :post,   :v1, "/sandbox/send",                 ->(c) { c.sandbox.send(to: "a@b.com") },             { "id" => "sbx_1" }],
    ["sandbox.list",             :get,    :v1, "/sandbox",                      ->(c) { c.sandbox.list },                            { "messages" => [] }],
    ["sandbox.delete",           :delete, :v1, "/sandbox/sbx_1",                ->(c) { c.sandbox.delete("sbx_1") },                 { "deleted" => true }],

    ["inbound.list",             :get,    :v1, "/inbound",                      ->(c) { c.inbound.list },                            { "inbound" => [] }],
    ["inbound.create",           :post,   :v1, "/inbound",                      ->(c) { c.inbound.create(address: "in@x.com") },     { "id" => "inb_1" }],
    ["inbound.get",              :get,    :v1, "/inbound/inb_1",                ->(c) { c.inbound.get("inb_1") },                    { "id" => "inb_1" }],
    ["inbound.delete",           :delete, :v1, "/inbound/inb_1",                ->(c) { c.inbound.delete("inb_1") },                 { "deleted" => true }],

    ["track.event",              :post,   :v1, "/track/event",                  ->(c) { c.track.event(name: "signup") },             { "tracked" => true }],
    ["track.purchase",           :post,   :v1, "/track/purchase",               ->(c) { c.track.purchase(amount: 10) },              { "tracked" => true }],

    ["keys.list",                :get,    :v1, "/keys",                         ->(c) { c.keys.list },                               { "keys" => [] }],
    ["keys.create",              :post,   :v1, "/keys",                         ->(c) { c.keys.create(name: "ci") },                 { "id" => "key_1" }],
    ["keys.get",                 :get,    :v1, "/keys/key_1",                   ->(c) { c.keys.get("key_1") },                       { "id" => "key_1" }],
    ["keys.revoke",              :delete, :v1, "/keys/key_1",                   ->(c) { c.keys.revoke("key_1") },                    { "revoked" => true }],

    ["webhooks.list",            :get,    :v1, "/webhooks",                     ->(c) { c.webhooks.list },                           { "webhooks" => [] }],
    ["webhooks.create",          :post,   :v1, "/webhooks",                     ->(c) { c.webhooks.create(url: "https://x/h") },     { "id" => "wh_1" }],
    ["webhooks.get",             :get,    :v1, "/webhooks/wh_1",                ->(c) { c.webhooks.get("wh_1") },                    { "id" => "wh_1" }],
    ["webhooks.update",          :patch,  :v1, "/webhooks/wh_1",                ->(c) { c.webhooks.update("wh_1", url: "https://y") }, { "id" => "wh_1" }],
    ["webhooks.delete",          :delete, :v1, "/webhooks/wh_1",                ->(c) { c.webhooks.delete("wh_1") },                 { "deleted" => true }],
    ["webhooks.test",            :post,   :v1, "/webhooks/wh_1/test",           ->(c) { c.webhooks.test("wh_1") },                   { "delivered" => true }],

    ["usage.get",                :get,    :v1, "/usage",                        ->(c) { c.usage.get },                               { "sent" => 12 }],
    ["billing.subscription",     :get,    :api, "/billing/subscription",        ->(c) { c.billing.subscription },                    { "plan" => "pro" }],
    ["billing.checkout",         :post,   :api, "/billing/checkout",            ->(c) { c.billing.checkout(plan: "pro") },           { "url" => "https://pay" }],

    ["plan.get",                 :get,    :v1, "/plan",                         ->(c) { c.plan.get },                                { "plan" => "pro" }],
    ["plan.monetization",        :get,    :v1, "/monetization/stats",           ->(c) { c.plan.monetization },                       { "revenue" => 0 }],

    ["ai.subject_lines",         :post,   :v1, "/ai/subject-lines",             ->(c) { c.ai.subject_lines(data: { topic: "x" }) },  { "subjects" => [] }],
    ["credit_rates.list",        :get,    :v1, "/credit-rates",                 ->(c) { c.credit_rates.list },                       { "rates" => [] }],
    ["deliverability.audit",     :get,    :v1, "/deliverability/audit",         ->(c) { c.deliverability.audit },                    { "issues" => [] }],
    ["deliverability.score",     :get,    :v1, "/deliverability/score",         ->(c) { c.deliverability.score },                    { "score" => 92 }],

    ["dmarc.list_domains",       :get,    :v1, "/dmarc/domains",                ->(c) { c.dmarc.list_domains },                      { "domains" => [] }],
    ["dmarc.add_domain",         :post,   :v1, "/dmarc/domains",                ->(c) { c.dmarc.add_domain(data: { domain: "x" }) }, { "id" => "dm_1" }],

    ["email_accounts.list",      :get,    :v1, "/email-accounts",               ->(c) { c.email_accounts.list },                     { "accounts" => [] }],
    ["emails.get",               :get,    :v1, "/emails/em_1",                  ->(c) { c.emails.get("em_1") },                      { "id" => "em_1" }],
    ["emails.update",            :patch,  :v1, "/emails/em_1",                  ->(c) { c.emails.update("em_1", data: { read: true }) }, { "id" => "em_1" }],

    ["landing_pages.create",     :post,   :v1, "/landing-pages",                ->(c) { c.landing_pages.create(data: { slug: "a" }) }, { "id" => "lp_1" }],
    ["monetization.tip",         :post,   :v1, "/monetization/tip",             ->(c) { c.monetization.tip(data: { amount: 5 }) },   { "ok" => true }],

    ["subscription.upsert",      :post,   :v1, "/subscription",                 ->(c) { c.subscription.upsert(data: { plan: "pro" }) }, { "plan" => "pro" }],
    ["subscription.cancel",      :delete, :v1, "/subscription",                 ->(c) { c.subscription.cancel(data: { reason: "x" }) }, { "cancelled" => true }],

    ["wallet.get",               :get,    :v1, "/wallet",                       ->(c) { c.wallet.get },                              { "balance" => 100 }],
    ["wallet.credit",            :post,   :v1, "/wallet/credit",                ->(c) { c.wallet.credit(data: { amount: 5 }) },      { "balance" => 105 }],
    ["wallet.debit",             :post,   :v1, "/wallet/debit",                 ->(c) { c.wallet.debit(data: { amount: 5 }) },       { "balance" => 95 }],
    ["warmup.get",               :get,    :v1, "/warmup",                       ->(c) { c.warmup.get },                              { "stage" => 2 }]
  ].freeze

  ROUTES.each do |desc, verb, base, path, call, body|
    it "#{desc} issues #{verb.to_s.upcase} #{path}" do
      host = base == :api ? API : V1
      stub = stub_request(verb, "#{host}#{path}").to_return(json(body))
      expect(call.call(client)).to eq(body)
      expect(stub).to have_been_requested
    end
  end

  # ── Paths and payloads that are built, not just concatenated ───────────────

  it "contacts.update folds the email into the PATCH body" do
    stub = stub_request(:patch, "#{V1}/contacts")
           .with(body: { "name" => "Ada", "email" => "ada@x.com" })
           .to_return(json("id" => "c_1"))
    client.contacts.update("ada@x.com", name: "Ada")
    expect(stub).to have_been_requested
  end

  it "contacts.get percent-encodes an id that would otherwise break the query" do
    stub = stub_request(:get, "#{V1}/contacts").with(query: { "id" => "a b/c" })
                                               .to_return(json("id" => "a b/c"))
    expect(client.contacts.get("a b/c")).to eq("id" => "a b/c")
    expect(stub).to have_been_requested
  end

  it "automations.activate wraps the keyword in an active flag" do
    stub = stub_request(:post, "#{V1}/automations/aut_1/activate")
           .with(body: { "active" => false }).to_return(json("active" => false))
    expect(client.automations.activate("aut_1", active: false)).to eq("active" => false)
    expect(stub).to have_been_requested
  end

  it "ab_tests.set_winner posts the variant id under variant_id" do
    stub = stub_request(:post, "#{V1}/ab-tests/ab_1/winner")
           .with(body: { "variant_id" => "v_2" }).to_return(json("winner" => "v_2"))
    expect(client.ab_tests.set_winner("ab_1", "v_2")).to eq("winner" => "v_2")
    expect(stub).to have_been_requested
  end

  it "campaigns.list forwards filter params as a query string" do
    stub = stub_request(:get, "#{V1}/campaigns").with(query: { "status" => "sent", "limit" => "5" })
                                                .to_return(json("campaigns" => []))
    client.campaigns.list(status: "sent", limit: 5)
    expect(stub).to have_been_requested
  end

  it "contacts.list sends the default page and limit" do
    stub = stub_request(:get, "#{V1}/contacts").with(query: { "page" => "1", "limit" => "20" })
                                               .to_return(json("contacts" => []))
    client.contacts.list
    expect(stub).to have_been_requested
  end

  it "campaigns.send sends no request body despite being a POST" do
    stub = stub_request(:post, "#{V1}/campaigns/cmp_1/send")
           .with { |req| req.body.nil? || req.body.empty? }
           .to_return(json("status" => "sending"))
    client.campaigns.send("cmp_1")
    expect(stub).to have_been_requested
  end

  # ── The generated optional-filter methods ─────────────────────────────────
  #
  # These all build their path as query(compact(...)). Both helpers were
  # missing from the gem entirely until this pass; see the note on
  # MisarMail::Resource.

  it "emails.list omits the filters that were left nil" do
    stub = stub_request(:get, "#{V1}/emails").with(query: { "folder" => "inbox", "limit" => "5" })
                                             .to_return(json("emails" => []))
    client.emails.list(folder: "inbox", limit: 5)
    expect(stub).to have_been_requested
  end

  it "emails.list sends a bare path when every filter is nil" do
    stub = stub_request(:get, "#{V1}/emails").to_return(json("emails" => []))
    client.emails.list
    expect(a_request(:get, "#{V1}/emails")).to have_been_made
    expect(stub).to have_been_requested
  end

  it "dmarc.check passes the domain and selector" do
    stub = stub_request(:get, "#{V1}/dmarc/check")
           .with(query: { "domain" => "x.com", "dkim_selector" => "s1" })
           .to_return(json("pass" => true))
    expect(client.dmarc.check(domain: "x.com", dkim_selector: "s1")).to eq("pass" => true)
    expect(stub).to have_been_requested
  end

  it "dmarc.remove_domain deletes by query parameter, not path segment" do
    stub = stub_request(:delete, "#{V1}/dmarc/domains").with(query: { "domain_id" => "dm_1" })
                                                       .to_return(json("deleted" => true))
    expect(client.dmarc.remove_domain(domain_id: "dm_1")).to eq("deleted" => true)
    expect(stub).to have_been_requested
  end

  it "revenue.attribution filters by campaign and period" do
    stub = stub_request(:get, "#{V1}/revenue/attribution")
           .with(query: { "campaign_id" => "cmp_1", "period" => "30d" })
           .to_return(json("revenue" => 42))
    expect(client.revenue.attribution(campaign_id: "cmp_1", period: "30d")).to eq("revenue" => 42)
    expect(stub).to have_been_requested
  end

  it "segments.members interpolates the id and appends paging" do
    stub = stub_request(:get, "#{V1}/segments/seg_1/members")
           .with(query: { "page" => "2", "limit" => "50" })
           .to_return(json("members" => []))
    client.segments.members("seg_1", page: 2, limit: 50)
    expect(stub).to have_been_requested
  end

  it "subscription.get scopes to a product" do
    stub = stub_request(:get, "#{V1}/subscription").with(query: { "product" => "mail" })
                                                   .to_return(json("plan" => "pro"))
    expect(client.subscription.get(product: "mail")).to eq("plan" => "pro")
    expect(stub).to have_been_requested
  end

  it "team_members.get scopes to an owner" do
    stub = stub_request(:get, "#{V1}/team-members").with(query: { "owner_id" => "own_1" })
                                                   .to_return(json("members" => []))
    expect(client.team_members.get(owner_id: "own_1")).to eq("members" => [])
    expect(stub).to have_been_requested
  end

  it "escapes reserved characters in a query value" do
    stub = stub_request(:get, "#{V1}/emails").with(query: { "search" => "a&b=c d" })
                                             .to_return(json("emails" => []))
    client.emails.list(search: "a&b=c d")
    expect(stub).to have_been_requested
  end
end
