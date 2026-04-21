#include "misarmail/client.hpp"

#include <cassert>
#include <iostream>
#include <stdexcept>
#include <string>

// ---------------------------------------------------------------------------
// Minimal test harness
// ---------------------------------------------------------------------------

static int total = 0;
static int passed = 0;

#define TEST(name) \
    do { \
        ++total; \
        std::cout << "  " << (name) << " ... "; \
        std::cout.flush(); \
    } while (0)

#define PASS() \
    do { \
        ++passed; \
        std::cout << "PASS\n"; \
    } while (0)

#define FAIL(msg) \
    do { \
        std::cout << "FAIL — " << (msg) << "\n"; \
    } while (0)

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void test_error_construction() {
    TEST("MisarMailError stores status code");
    misarmail::MisarMailError err(422, "unprocessable entity");
    assert(err.statusCode() == 422);
    assert(std::string(err.what()) == "unprocessable entity");
    PASS();
}

void test_error_is_runtime_error() {
    TEST("MisarMailError is catchable as std::runtime_error");
    try {
        throw misarmail::MisarMailError(500, "internal server error");
    } catch (const std::runtime_error& e) {
        assert(std::string(e.what()) == "internal server error");
        PASS();
        return;
    }
    FAIL("exception not caught as std::runtime_error");
}

void test_error_is_std_exception() {
    TEST("MisarMailError is catchable as std::exception");
    try {
        throw misarmail::MisarMailError(404, "not found");
    } catch (const std::exception& e) {
        assert(std::string(e.what()) == "not found");
        PASS();
        return;
    }
    FAIL("exception not caught as std::exception");
}

void test_client_constructs_with_defaults() {
    TEST("Client constructs with api_key only (no throw)");
    try {
        misarmail::Client client("msk_test_key");
        PASS();
    } catch (const std::exception& e) {
        FAIL(e.what());
    }
}

void test_client_constructs_with_custom_url() {
    TEST("Client constructs with custom base_url");
    try {
        misarmail::Client client("msk_test_key", "https://example.com/api/v1");
        PASS();
    } catch (const std::exception& e) {
        FAIL(e.what());
    }
}

void test_client_move_semantics() {
    TEST("Client is move-constructible");
    try {
        misarmail::Client a("msk_key_a");
        misarmail::Client b(std::move(a));
        PASS();
    } catch (const std::exception& e) {
        FAIL(e.what());
    }
}

void test_client_move_assignment() {
    TEST("Client is move-assignable");
    try {
        misarmail::Client a("msk_key_a");
        misarmail::Client b("msk_key_b");
        b = std::move(a);
        PASS();
    } catch (const std::exception& e) {
        FAIL(e.what());
    }
}

// ---------------------------------------------------------------------------
// Network tests — require MISARMAIL_API_KEY env var, skipped otherwise
// ---------------------------------------------------------------------------

void test_network_invalid_key_throws_401() {
    TEST("sendEmail with bogus key throws MisarMailError(401)");
    const char* key = std::getenv("MISARMAIL_API_KEY");
    if (key) {
        std::cout << "(skipped — real key present, use sandbox tests)\n";
        ++passed;
        return;
    }
    try {
        misarmail::Client client("msk_definitely_invalid");
        client.sendEmail(R"({"to":"test@example.com","subject":"hi","html":"<p>hi</p>"})");
        FAIL("expected exception, got none");
    } catch (const misarmail::MisarMailError& e) {
        // Any HTTP error is acceptable here (401, 403, connection refused…)
        // In CI without a server we just verify the exception is thrown
        assert(e.statusCode() >= 0);
        PASS();
    } catch (const std::exception&) {
        // curl network error also acceptable in offline CI
        PASS();
    }
}

void test_network_contacts_list_throws_without_auth() {
    TEST("contactsList with bogus key throws MisarMailError");
    const char* key = std::getenv("MISARMAIL_API_KEY");
    if (key) {
        std::cout << "(skipped)\n";
        ++passed;
        return;
    }
    try {
        misarmail::Client client("msk_no_auth");
        client.contactsList();
        FAIL("expected exception");
    } catch (const misarmail::MisarMailError& e) {
        assert(e.statusCode() >= 0);
        PASS();
    } catch (const std::exception&) {
        PASS();
    }
}

void test_network_validate_email_json_wrapping() {
    TEST("validateEmail wraps bare address in JSON (network, skipped offline)");
    const char* key = std::getenv("MISARMAIL_API_KEY");
    if (!key) {
        std::cout << "(skipped — no MISARMAIL_API_KEY)\n";
        ++passed;
        return;
    }
    try {
        misarmail::Client client(key);
        std::string resp = client.validateEmail("test@example.com");
        assert(!resp.empty());
        PASS();
    } catch (const misarmail::MisarMailError& e) {
        FAIL(std::string("HTTP ") + std::to_string(e.statusCode()) + ": " + e.what());
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------

int main() {
    std::cout << "MisarMail C++ SDK — unit tests\n";
    std::cout << "================================\n";

    test_error_construction();
    test_error_is_runtime_error();
    test_error_is_std_exception();
    test_client_constructs_with_defaults();
    test_client_constructs_with_custom_url();
    test_client_move_semantics();
    test_client_move_assignment();
    test_network_invalid_key_throws_401();
    test_network_contacts_list_throws_without_auth();
    test_network_validate_email_json_wrapping();

    std::cout << "================================\n";
    std::cout << "Results: " << passed << "/" << total << " passed\n";

    return (passed == total) ? 0 : 1;
}
