# MisarMail C++ SDK

C++17 SDK for the [MisarMail](https://mail.misar.io) API.

## Requirements

- C++17 compiler (GCC 8+, Clang 7+, MSVC 2019+)
- CMake 3.14+
- libcurl (dev headers)

```bash
# macOS
brew install curl

# Debian/Ubuntu
apt-get install libcurl4-openssl-dev
```

## Build

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

## Usage

```cpp
#include "misarmail/client.hpp"
#include <iostream>

int main() {
    misarmail::Client client("msk_your_api_key");

    // Send an email
    try {
        std::string resp = client.sendEmail(R"({
            "to": "user@example.com",
            "subject": "Hello",
            "html": "<p>Hello from MisarMail!</p>"
        })");
        std::cout << resp << "\n";
    } catch (const misarmail::MisarMailError& e) {
        std::cerr << "HTTP " << e.statusCode() << ": " << e.what() << "\n";
    }

    // List contacts
    std::string contacts = client.contactsList();

    // Render a template
    std::string rendered = client.templatesRender(
        "tmpl_abc123",
        R"({"name": "Alice", "product": "Widget"})"
    );

    return 0;
}
```

## API

| Method | Endpoint |
|--------|----------|
| `sendEmail(json)` | POST /send |
| `contactsList()` | GET /contacts |
| `contactsCreate(json)` | POST /contacts |
| `campaignsList()` | GET /campaigns |
| `campaignsCreate(json)` | POST /campaigns |
| `analyticsGet(campaignId)` | GET /analytics/{id} |
| `validateEmail(email)` | POST /validate |
| `keysList()` | GET /keys |
| `abTestsList()` | GET /ab-tests |
| `sandboxList()` | GET /sandbox |
| `trackEvent(json)` | POST /track/event |
| `trackPurchase(json)` | POST /track/purchase |
| `inboundList()` | GET /inbound |
| `templatesList()` | GET /templates |
| `templatesRender(id, json)` | POST /templates/{id}/render |

All methods return `std::string` (raw JSON response body).  
Failures throw `misarmail::MisarMailError` — inherits `std::runtime_error`.  
Retries: up to 3 attempts on 429/500/502/503/504 with 200ms exponential backoff.

## Tests

```bash
cmake -B build -DMISARMAIL_BUILD_TESTS=ON
cmake --build build
ctest --test-dir build
```

Set `MISARMAIL_API_KEY` env var to enable live network tests.
