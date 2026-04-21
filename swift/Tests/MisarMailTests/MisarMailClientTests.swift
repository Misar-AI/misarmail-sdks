import XCTest
@testable import MisarMail

// MARK: - URLSession stub

/// A `URLProtocol` subclass that intercepts requests and responds with a
/// pre-configured status code and body without making real network calls.
final class StubURLProtocol: URLProtocol {

    static var statusCode: Int = 200
    static var responseBody: Data = Data()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: StubURLProtocol.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: StubURLProtocol.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Test helpers

extension MisarMailClientTests {

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    func stub(status: Int, body: String) -> MisarMailClient {
        StubURLProtocol.statusCode = status
        StubURLProtocol.responseBody = Data(body.utf8)
        return MisarMailClient(
            apiKey: "your_api_key_here",
            maxRetries: 1,
            session: Self.makeSession()
        )
    }
}

// MARK: - Tests

final class MisarMailClientTests: XCTestCase {

    func testSendEmail_200_returnsParsedResponse() async throws {
        let client = stub(status: 200, body: #"{"id":"msg_1","status":"queued"}"#)
        let result = try await client.sendEmail(["to": "a@b.com", "subject": "Hi"])
        XCTAssertEqual(result["id"] as? String, "msg_1")
        XCTAssertEqual(result["status"] as? String, "queued")
    }

    func testContactsList_200_returnsParsedResponse() async throws {
        let client = stub(status: 200, body: #"{"data":[]}"#)
        let result = try await client.contactsList()
        XCTAssertNotNil(result["data"])
    }

    func testContactsCreate_201_returnsParsedResponse() async throws {
        let client = stub(status: 201, body: #"{"id":"c1","email":"x@y.com"}"#)
        let result = try await client.contactsCreate(["email": "x@y.com"])
        XCTAssertEqual(result["id"] as? String, "c1")
    }

    func testAnalyticsGet_200_returnsParsedResponse() async throws {
        let client = stub(status: 200, body: #"{"opens":10,"clicks":3}"#)
        let result = try await client.analyticsGet(campaignId: "camp_abc")
        XCTAssertEqual(result["opens"] as? Int, 10)
    }

    func testValidateEmail_200_returnsParsedResponse() async throws {
        let client = stub(status: 200, body: #"{"valid":true}"#)
        let result = try await client.validateEmail("test@example.com")
        XCTAssertEqual(result["valid"] as? Bool, true)
    }

    func testTemplatesRender_200_returnsParsedResponse() async throws {
        let client = stub(status: 200, body: #"{"html":"<p>Hello</p>"}"#)
        let result = try await client.templatesRender(
            templateId: "tmpl_1",
            variables: ["name": "World"]
        )
        XCTAssertEqual(result["html"] as? String, "<p>Hello</p>")
    }

    func testNon2xx_throwsApiError_withCorrectStatus() async throws {
        let client = stub(status: 401, body: #"{"error":"Unauthorized"}"#)
        do {
            _ = try await client.sendEmail(["to": "x@y.com"])
            XCTFail("Expected MisarMailError to be thrown")
        } catch MisarMailError.apiError(let status, _) {
            XCTAssertEqual(status, 401)
        }
    }

    func test404_throwsApiError() async throws {
        let client = stub(status: 404, body: #"{"error":"not found"}"#)
        do {
            _ = try await client.analyticsGet(campaignId: "nonexistent")
            XCTFail("Expected MisarMailError to be thrown")
        } catch MisarMailError.apiError(let status, _) {
            XCTAssertEqual(status, 404)
        }
    }

    func testEmptyBody_200_returnsEmptyDict() async throws {
        let client = stub(status: 200, body: "")
        let result = try await client.sandboxList()
        XCTAssertTrue(result.isEmpty)
    }

    func testTrackEvent_200_returnsParsedResponse() async throws {
        let client = stub(status: 200, body: #"{"tracked":true}"#)
        let result = try await client.trackEvent(["event": "signup"])
        XCTAssertEqual(result["tracked"] as? Bool, true)
    }

    func testTrackPurchase_200_returnsParsedResponse() async throws {
        let client = stub(status: 200, body: #"{"tracked":true}"#)
        let result = try await client.trackPurchase(["email": "u@x.com", "amount": 99.0])
        XCTAssertEqual(result["tracked"] as? Bool, true)
    }
}
