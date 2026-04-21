# MisarMail C SDK

C99 client for the [MisarMail](https://mail.misar.io) API.  
Depends only on **libcurl** — no other external libraries required.

---

## Build

```bash
# Prerequisites: cmake >= 3.14, libcurl-dev
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build

# Run tests
cd build && ctest --output-on-failure
```

The build produces a static library `libmisarmail.a` and the test binary `misarmail_tests`.

---

## Usage

```c
#include "misarmail.h"
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    MisarMailClient *client = misarmail_new("msk_your_api_key_here");
    if (!client) {
        fprintf(stderr, "Failed to create client\n");
        return 1;
    }

    /* Send an email — body is plain JSON */
    const char *body =
        "{"
        "\"from\":\"you@example.com\","
        "\"to\":[\"recipient@example.com\"],"
        "\"subject\":\"Hello from C\","
        "\"html\":\"<p>Hello!</p>\""
        "}";

    char *response = misarmail_send_email(client, body);
    if (response) {
        printf("Response: %s\n", response);
        free(response);          /* caller must free */
    } else {
        const MisarMailError *err = misarmail_get_last_error();
        fprintf(stderr, "Error %d: %s\n", err->status_code, err->message);
    }

    misarmail_free(client);
    return 0;
}
```

Link with `-lmisarmail -lcurl`.

---

## Error handling

Every function returns `NULL` on failure. Call `misarmail_get_last_error()` immediately after to inspect the error:

```c
const MisarMailError *err = misarmail_get_last_error();
// err->status_code : HTTP status code, or 0 for transport/init errors
// err->message     : human-readable description (max 255 chars)
```

---

## Retry behaviour

Requests that receive HTTP `429`, `500`, `502`, `503`, or `504` are automatically retried up to `max_retries` times (default **3**) with exponential back-off: `200 ms × 2^attempt`.

---

## API reference

| Function | Method | Endpoint |
|---|---|---|
| `misarmail_send_email(c, json_body)` | POST | `/send` |
| `misarmail_contacts_list(c, query_params)` | GET | `/contacts` |
| `misarmail_contacts_create(c, json_body)` | POST | `/contacts` |
| `misarmail_campaigns_list(c, query_params)` | GET | `/campaigns` |
| `misarmail_campaigns_create(c, json_body)` | POST | `/campaigns` |
| `misarmail_analytics_get(c, campaign_id)` | GET | `/analytics/{campaignId}` |
| `misarmail_validate_email(c, json_body)` | POST | `/validate` |
| `misarmail_keys_list(c, query_params)` | GET | `/keys` |
| `misarmail_ab_tests_list(c, query_params)` | GET | `/ab-tests` |
| `misarmail_sandbox_list(c, query_params)` | GET | `/sandbox` |
| `misarmail_track_event(c, json_body)` | POST | `/track/event` |
| `misarmail_track_purchase(c, json_body)` | POST | `/track/purchase` |
| `misarmail_inbound_list(c, query_params)` | GET | `/inbound` |
| `misarmail_templates_list(c, query_params)` | GET | `/templates` |
| `misarmail_templates_render(c, template_id, json_body)` | POST | `/templates/{id}/render` |

`query_params` — optional URL query string without the leading `?`, e.g. `"page=1&limit=25"`. Pass `NULL` for none.

All functions return a heap-allocated JSON string. **The caller must `free()` it.**

---

## Thread safety

Each thread has its own `last_error` storage. The `MisarMailClient` struct itself is not protected by a mutex — do not share a single client across threads without external locking.
