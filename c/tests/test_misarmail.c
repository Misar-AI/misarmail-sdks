/* MisarMail C SDK — unit tests
 * Build & run:
 *   cmake -B build && cmake --build build && ./build/misarmail_tests
 */

#include "misarmail.h"

#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

/* -----------------------------------------------------------------------
 * Helpers
 * ----------------------------------------------------------------------- */

static int tests_run  = 0;
static int tests_pass = 0;

#define PASS(name) do { printf("PASS  %s\n", (name)); tests_pass++; } while(0)
#define RUN(fn)    do { tests_run++; fn(); } while(0)

/* -----------------------------------------------------------------------
 * Test cases
 * ----------------------------------------------------------------------- */

/* 1. misarmail_new returns a valid, correctly initialised client */
static void test_new_valid(void)
{
    MisarMailClient *c = misarmail_new("msk_test_key_abc123");
    assert(c != NULL);
    assert(c->api_key != NULL);
    assert(strcmp(c->api_key, "msk_test_key_abc123") == 0);
    assert(c->base_url != NULL);
    assert(strcmp(c->base_url, MISARMAIL_DEFAULT_BASE_URL) == 0);
    assert(c->max_retries == MISARMAIL_DEFAULT_MAX_RETRIES);
    misarmail_free(c);
    PASS("misarmail_new: valid api_key initialises client correctly");
}

/* 2. misarmail_new with NULL api_key returns NULL */
static void test_new_null_key(void)
{
    MisarMailClient *c = misarmail_new(NULL);
    assert(c == NULL);
    PASS("misarmail_new: NULL api_key returns NULL");
}

/* 3. misarmail_free does not crash on valid pointer */
static void test_free_valid(void)
{
    MisarMailClient *c = misarmail_new("msk_free_test");
    assert(c != NULL);
    misarmail_free(c); /* must not crash */
    PASS("misarmail_free: does not crash on valid pointer");
}

/* 4. misarmail_free does not crash on NULL */
static void test_free_null(void)
{
    misarmail_free(NULL); /* must not crash */
    PASS("misarmail_free: does not crash on NULL");
}

/* 5. Offline: all POST endpoints return NULL gracefully (no server) */
static void test_send_email_offline(void)
{
    /* Point at a port nothing listens on — expect graceful NULL, no crash */
    MisarMailClient *c = misarmail_new("msk_offline");
    assert(c != NULL);

    /* Override base_url to an unreachable address */
    free(c->base_url);
    c->base_url    = strdup("http://127.0.0.1:19999/api/v1");
    c->max_retries = 0; /* no retries — test stays fast */

    const char *body = "{\"from\":\"a@b.com\",\"to\":[\"c@d.com\"],\"subject\":\"Hi\"}";
    char *result = misarmail_send_email(c, body);

    assert(result == NULL);
    const MisarMailError *err = misarmail_get_last_error();
    assert(err != NULL);
    assert(err->message[0] != '\0'); /* some error message set */

    misarmail_free(c);
    PASS("misarmail_send_email: returns NULL gracefully when server unreachable");
}

/* 6. Offline: GET endpoint returns NULL gracefully */
static void test_contacts_list_offline(void)
{
    MisarMailClient *c = misarmail_new("msk_offline");
    assert(c != NULL);
    free(c->base_url);
    c->base_url    = strdup("http://127.0.0.1:19999/api/v1");
    c->max_retries = 0;

    char *result = misarmail_contacts_list(c, "page=1&limit=10");
    assert(result == NULL);

    misarmail_free(c);
    PASS("misarmail_contacts_list: returns NULL gracefully when server unreachable");
}

/* 7. Offline: templates_render (parameterised path) returns NULL gracefully */
static void test_templates_render_offline(void)
{
    MisarMailClient *c = misarmail_new("msk_offline");
    assert(c != NULL);
    free(c->base_url);
    c->base_url    = strdup("http://127.0.0.1:19999/api/v1");
    c->max_retries = 0;

    char *result = misarmail_templates_render(c, "tpl_123", "{\"name\":\"Alice\"}");
    assert(result == NULL);

    misarmail_free(c);
    PASS("misarmail_templates_render: returns NULL gracefully when server unreachable");
}

/* 8. misarmail_analytics_get with NULL campaign_id returns NULL */
static void test_analytics_null_campaign(void)
{
    MisarMailClient *c = misarmail_new("msk_test");
    assert(c != NULL);

    char *result = misarmail_analytics_get(c, NULL);
    assert(result == NULL);

    const MisarMailError *err = misarmail_get_last_error();
    assert(err != NULL);
    assert(err->status_code == 0);

    misarmail_free(c);
    PASS("misarmail_analytics_get: NULL campaign_id returns NULL with error");
}

/* 9. misarmail_templates_render with NULL template_id returns NULL */
static void test_templates_render_null_id(void)
{
    MisarMailClient *c = misarmail_new("msk_test");
    assert(c != NULL);

    char *result = misarmail_templates_render(c, NULL, "{}");
    assert(result == NULL);

    misarmail_free(c);
    PASS("misarmail_templates_render: NULL template_id returns NULL with error");
}

/* 10. Default constants are sane */
static void test_default_constants(void)
{
    assert(strcmp(MISARMAIL_DEFAULT_BASE_URL, "https://mail.misar.io/api/v1") == 0);
    assert(MISARMAIL_DEFAULT_MAX_RETRIES == 3);
    PASS("constants: MISARMAIL_DEFAULT_BASE_URL and MISARMAIL_DEFAULT_MAX_RETRIES are correct");
}

/* -----------------------------------------------------------------------
 * main
 * ----------------------------------------------------------------------- */

int main(void)
{
    printf("=== MisarMail C SDK tests ===\n\n");

    RUN(test_new_valid);
    RUN(test_new_null_key);
    RUN(test_free_valid);
    RUN(test_free_null);
    RUN(test_send_email_offline);
    RUN(test_contacts_list_offline);
    RUN(test_templates_render_offline);
    RUN(test_analytics_null_campaign);
    RUN(test_templates_render_null_id);
    RUN(test_default_constants);

    printf("\n%d/%d tests passed\n", tests_pass, tests_run);
    return (tests_pass == tests_run) ? 0 : 1;
}
