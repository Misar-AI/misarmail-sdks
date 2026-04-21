/* MisarMail C SDK — implementation
 * C99 · libcurl only · no external JSON lib
 */

#include "misarmail.h"

#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>   /* usleep */

/* -----------------------------------------------------------------------
 * Internal types
 * ----------------------------------------------------------------------- */

typedef struct {
    char  *data;
    size_t size;
} ResponseBuf;

/* Retry-able HTTP status codes */
static int retryable_status(long code)
{
    return code == 429 || code == 500 || code == 502 || code == 503 || code == 504;
}

/* -----------------------------------------------------------------------
 * Thread-local last error
 * ----------------------------------------------------------------------- */

#if defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L && !defined(__STDC_NO_THREADS__)
#  include <threads.h>
#  define TL thread_local
#elif defined(__GNUC__) || defined(__clang__)
#  define TL __thread
#elif defined(_MSC_VER)
#  define TL __declspec(thread)
#else
#  define TL  /* fallback: not thread-safe */
#endif

static TL MisarMailError tl_last_error;

static void set_error(int code, const char *msg)
{
    tl_last_error.status_code = code;
    strncpy(tl_last_error.message, msg ? msg : "", sizeof(tl_last_error.message) - 1);
    tl_last_error.message[sizeof(tl_last_error.message) - 1] = '\0';
}

const MisarMailError *misarmail_get_last_error(void)
{
    return &tl_last_error;
}

/* -----------------------------------------------------------------------
 * curl write callback — appends chunks into ResponseBuf
 * ----------------------------------------------------------------------- */

static size_t write_cb(void *ptr, size_t size, size_t nmemb, void *userdata)
{
    size_t incoming = size * nmemb;
    ResponseBuf *buf = (ResponseBuf *)userdata;

    char *tmp = realloc(buf->data, buf->size + incoming + 1);
    if (!tmp) return 0; /* signals curl to abort */

    buf->data = tmp;
    memcpy(buf->data + buf->size, ptr, incoming);
    buf->size += incoming;
    buf->data[buf->size] = '\0';
    return incoming;
}

/* -----------------------------------------------------------------------
 * Core request helpers
 *
 * method    : "GET", "POST", "PATCH", "DELETE"
 * full_url  : complete URL (caller builds it)
 * body      : JSON body for POST/PATCH, NULL for GET/DELETE
 *
 * Returns heap-allocated JSON string (caller frees) or NULL on error.
 * ----------------------------------------------------------------------- */

static char *do_request_url(MisarMailClient *client,
                             const char *method,
                             const char *full_url,
                             const char *body)
{
    CURL *curl = curl_easy_init();
    if (!curl) {
        set_error(0, "curl_easy_init failed");
        return NULL;
    }

    /* Build Authorization header */
    char auth_hdr[512];
    snprintf(auth_hdr, sizeof(auth_hdr), "Authorization: Bearer %s", client->api_key);

    char *result = NULL;
    long  http_code = 0;

    for (int attempt = 0; attempt <= client->max_retries; attempt++) {

        /* Fresh response buffer each attempt */
        ResponseBuf buf = { NULL, 0 };
        buf.data = malloc(1);
        if (!buf.data) {
            curl_easy_cleanup(curl);
            set_error(0, "malloc failed");
            return NULL;
        }
        buf.data[0] = '\0';

        /* Headers */
        struct curl_slist *hdrs = NULL;
        hdrs = curl_slist_append(hdrs, auth_hdr);
        hdrs = curl_slist_append(hdrs, "Content-Type: application/json");
        hdrs = curl_slist_append(hdrs, "Accept: application/json");
        hdrs = curl_slist_append(hdrs, "User-Agent: misarmail-c-sdk/1.0.0");

        curl_easy_setopt(curl, CURLOPT_URL,            full_url);
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER,     hdrs);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION,  write_cb);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA,      &buf);
        curl_easy_setopt(curl, CURLOPT_TIMEOUT,        30L);
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);

        if (strcmp(method, "POST") == 0) {
            curl_easy_setopt(curl, CURLOPT_POST, 1L);
            if (body) {
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS,    body);
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (curl_off_t)strlen(body));
            } else {
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS,    "{}");
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, 2L);
            }
        } else if (strcmp(method, "PATCH") == 0) {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PATCH");
            if (body) {
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS,    body);
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, (curl_off_t)strlen(body));
            } else {
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS,    "{}");
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, 2L);
            }
        } else if (strcmp(method, "DELETE") == 0) {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
        } else {
            curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
        }

        CURLcode res = curl_easy_perform(curl);
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &http_code);
        curl_slist_free_all(hdrs);

        if (res != CURLE_OK) {
            free(buf.data);
            char msg[256];
            snprintf(msg, sizeof(msg), "curl error: %s", curl_easy_strerror(res));
            set_error(0, msg);

            if (attempt < client->max_retries) {
                usleep((useconds_t)(200000u << attempt));
                continue;
            }
            curl_easy_cleanup(curl);
            return NULL;
        }

        if (http_code >= 200 && http_code < 300) {
            result = buf.data; /* transfer ownership */
            curl_easy_cleanup(curl);
            return result;
        }

        /* HTTP error */
        char msg[256];
        snprintf(msg, sizeof(msg),
                 "HTTP %ld: %.200s", http_code,
                 buf.data && buf.data[0] ? buf.data : "(no body)");
        set_error((int)http_code, msg);
        free(buf.data);

        if (retryable_status(http_code) && attempt < client->max_retries) {
            usleep((useconds_t)(200000u << attempt));
            continue;
        }

        curl_easy_cleanup(curl);
        return NULL;
    }

    curl_easy_cleanup(curl);
    return NULL;
}

/* Build URL from base_url + path (optionally with query string) */
static char *do_request(MisarMailClient *client,
                        const char *method,
                        const char *path,
                        const char *body)
{
    char url[2048];
    int n = snprintf(url, sizeof(url), "%s%s", client->base_url, path);
    if (n < 0 || (size_t)n >= sizeof(url)) {
        set_error(0, "URL too long");
        return NULL;
    }
    return do_request_url(client, method, url, body);
}

/* Build URL from api_base + path (billing/workspaces — no /v1) */
static char *do_request_base(MisarMailClient *client,
                              const char *method,
                              const char *path,
                              const char *body)
{
    char url[2048];
    int n = snprintf(url, sizeof(url), "%s%s", client->api_base, path);
    if (n < 0 || (size_t)n >= sizeof(url)) {
        set_error(0, "URL too long");
        return NULL;
    }
    return do_request_url(client, method, url, body);
}

/* -----------------------------------------------------------------------
 * Path builder helpers
 * ----------------------------------------------------------------------- */

static int build_path_query(char *dst, size_t dst_size,
                             const char *base_path,
                             const char *query_params)
{
    int n;
    if (query_params && query_params[0]) {
        n = snprintf(dst, dst_size, "%s?%s", base_path, query_params);
    } else {
        n = snprintf(dst, dst_size, "%s", base_path);
    }
    return (n < 0 || (size_t)n >= dst_size) ? -1 : 0;
}

static int build_path_id(char *dst, size_t dst_size,
                          const char *prefix, const char *id)
{
    int n = snprintf(dst, dst_size, "%s/%s", prefix, id);
    return (n < 0 || (size_t)n >= dst_size) ? -1 : 0;
}

/* -----------------------------------------------------------------------
 * Client lifecycle
 * ----------------------------------------------------------------------- */

/* Strip /v1 suffix from base_url to produce api_base */
static char *make_api_base(const char *base_url)
{
    size_t len = strlen(base_url);
    const char *suffix = "/v1";
    size_t slen = strlen(suffix);
    if (len >= slen && strcmp(base_url + len - slen, suffix) == 0) {
        char *b = malloc(len - slen + 1);
        if (!b) return NULL;
        memcpy(b, base_url, len - slen);
        b[len - slen] = '\0';
        return b;
    }
    return strdup(base_url);
}

MisarMailClient *misarmail_new(const char *api_key)
{
    if (!api_key) return NULL;

    MisarMailClient *c = malloc(sizeof(MisarMailClient));
    if (!c) return NULL;

    c->api_key     = strdup(api_key);
    c->base_url    = strdup(MISARMAIL_DEFAULT_BASE_URL);
    c->api_base    = make_api_base(MISARMAIL_DEFAULT_BASE_URL);
    c->max_retries = MISARMAIL_DEFAULT_MAX_RETRIES;

    if (!c->api_key || !c->base_url || !c->api_base) {
        free(c->api_key);
        free(c->base_url);
        free(c->api_base);
        free(c);
        return NULL;
    }

    return c;
}

void misarmail_free(MisarMailClient *client)
{
    if (!client) return;
    free(client->api_key);
    free(client->base_url);
    free(client->api_base);
    free(client);
}

/* -----------------------------------------------------------------------
 * Public API — Email
 * ----------------------------------------------------------------------- */

char *misarmail_send_email(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/send", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — Contacts
 * ----------------------------------------------------------------------- */

char *misarmail_contacts_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/contacts", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_contacts_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/contacts", json_body);
}

char *misarmail_contacts_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/contacts", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_contacts_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/contacts", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_contacts_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/contacts", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

char *misarmail_contacts_import(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/contacts/import", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — Campaigns
 * ----------------------------------------------------------------------- */

char *misarmail_campaigns_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/campaigns", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_campaigns_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/campaigns", json_body);
}

char *misarmail_campaigns_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/campaigns", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_campaigns_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/campaigns", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_campaigns_send(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/campaigns/%s/send", id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "id too long"); return NULL; }
    return do_request(client, "POST", path, NULL);
}

char *misarmail_campaigns_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/campaigns", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Templates
 * ----------------------------------------------------------------------- */

char *misarmail_templates_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/templates", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_templates_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/templates", json_body);
}

char *misarmail_templates_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/templates", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_templates_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/templates", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_templates_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/templates", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

char *misarmail_templates_render(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/templates/render", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — Automations
 * ----------------------------------------------------------------------- */

char *misarmail_automations_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/automations", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_automations_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/automations", json_body);
}

char *misarmail_automations_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/automations", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_automations_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/automations", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_automations_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/automations", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

char *misarmail_automations_activate(MisarMailClient *client, const char *id, int active)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/automations/%s/activate", id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "id too long"); return NULL; }
    char body[64];
    snprintf(body, sizeof(body), "{\"active\":%s}", active ? "true" : "false");
    return do_request(client, "POST", path, body);
}

/* -----------------------------------------------------------------------
 * Public API — Domains
 * ----------------------------------------------------------------------- */

char *misarmail_domains_list(MisarMailClient *client)
{
    return do_request(client, "GET", "/domains", NULL);
}

char *misarmail_domains_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/domains", json_body);
}

char *misarmail_domains_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/domains", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_domains_verify(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/domains/%s/verify", id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "id too long"); return NULL; }
    return do_request(client, "POST", path, NULL);
}

char *misarmail_domains_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/domains", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Aliases
 * ----------------------------------------------------------------------- */

char *misarmail_aliases_list(MisarMailClient *client)
{
    return do_request(client, "GET", "/aliases", NULL);
}

char *misarmail_aliases_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/aliases", json_body);
}

char *misarmail_aliases_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/aliases", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_aliases_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/aliases", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_aliases_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/aliases", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Dedicated IPs
 * ----------------------------------------------------------------------- */

char *misarmail_dedicated_ips_list(MisarMailClient *client)
{
    return do_request(client, "GET", "/dedicated-ips", NULL);
}

char *misarmail_dedicated_ips_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/dedicated-ips", json_body);
}

char *misarmail_dedicated_ips_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/dedicated-ips", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_dedicated_ips_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/dedicated-ips", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Channels
 * ----------------------------------------------------------------------- */

char *misarmail_channels_send_whatsapp(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/channels/whatsapp", json_body);
}

char *misarmail_channels_send_push(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/channels/push", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — A/B Tests
 * ----------------------------------------------------------------------- */

char *misarmail_ab_tests_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/ab-tests", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_ab_tests_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/ab-tests", json_body);
}

char *misarmail_ab_tests_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/ab-tests", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_ab_tests_set_winner(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/ab-tests/%s/winner", id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "id too long"); return NULL; }
    return do_request(client, "POST", path, json_body);
}

/* -----------------------------------------------------------------------
 * Public API — Sandbox
 * ----------------------------------------------------------------------- */

char *misarmail_sandbox_send(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/sandbox/send", json_body);
}

char *misarmail_sandbox_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/sandbox", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_sandbox_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/sandbox", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Inbound
 * ----------------------------------------------------------------------- */

char *misarmail_inbound_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/inbound", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_inbound_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/inbound", json_body);
}

char *misarmail_inbound_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/inbound", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_inbound_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/inbound", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Analytics
 * ----------------------------------------------------------------------- */

char *misarmail_analytics_get(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/analytics", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Track
 * ----------------------------------------------------------------------- */

char *misarmail_track_event(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/track/event", json_body);
}

char *misarmail_track_purchase(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/track/purchase", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — API Keys
 * ----------------------------------------------------------------------- */

char *misarmail_keys_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/keys", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_keys_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/keys", json_body);
}

char *misarmail_keys_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/keys", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_keys_revoke(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/keys", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Validate
 * ----------------------------------------------------------------------- */

char *misarmail_validate_email(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/validate", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — Leads
 * ----------------------------------------------------------------------- */

char *misarmail_leads_search(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/leads/search", json_body);
}

char *misarmail_leads_get_job(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/leads/jobs", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_leads_list_jobs(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/leads/jobs", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_leads_results(MisarMailClient *client, const char *job_id)
{
    if (!job_id) { set_error(0, "job_id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/leads/jobs/%s/results", job_id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "job_id too long"); return NULL; }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_leads_import(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/leads/import", json_body);
}

char *misarmail_leads_credits(MisarMailClient *client)
{
    return do_request(client, "GET", "/leads/credits", NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Autopilot
 * ----------------------------------------------------------------------- */

char *misarmail_autopilot_start(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/autopilot", json_body);
}

char *misarmail_autopilot_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/autopilot", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_autopilot_list(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/autopilot", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_autopilot_daily_plan(MisarMailClient *client)
{
    return do_request(client, "GET", "/autopilot/daily-plan", NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Sales Agent
 * ----------------------------------------------------------------------- */

char *misarmail_sales_agent_get_config(MisarMailClient *client)
{
    return do_request(client, "GET", "/sales-agent/config", NULL);
}

char *misarmail_sales_agent_update_config(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "PATCH", "/sales-agent/config", json_body);
}

char *misarmail_sales_agent_get_actions(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/sales-agent/actions", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — CRM
 * ----------------------------------------------------------------------- */

char *misarmail_crm_list_conversations(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/crm/conversations", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_crm_get_conversation(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/crm/conversations", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_crm_update_conversation(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/crm/conversations", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_crm_list_messages(MisarMailClient *client, const char *conversation_id)
{
    if (!conversation_id) { set_error(0, "conversation_id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/crm/conversations/%s/messages", conversation_id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "conversation_id too long"); return NULL; }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_crm_list_deals(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/crm/deals", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_crm_create_deal(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/crm/deals", json_body);
}

char *misarmail_crm_get_deal(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/crm/deals", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_crm_update_deal(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/crm/deals", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_crm_delete_deal(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/crm/deals", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

char *misarmail_crm_list_clients(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/crm/clients", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_crm_create_client(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/crm/clients", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — Webhooks
 * ----------------------------------------------------------------------- */

char *misarmail_webhooks_list(MisarMailClient *client)
{
    return do_request(client, "GET", "/webhooks", NULL);
}

char *misarmail_webhooks_create(MisarMailClient *client, const char *json_body)
{
    return do_request(client, "POST", "/webhooks", json_body);
}

char *misarmail_webhooks_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/webhooks", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

char *misarmail_webhooks_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/webhooks", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "PATCH", path, json_body);
}

char *misarmail_webhooks_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/webhooks", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request(client, "DELETE", path, NULL);
}

char *misarmail_webhooks_test(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/webhooks/%s/test", id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "id too long"); return NULL; }
    return do_request(client, "POST", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Usage
 * ----------------------------------------------------------------------- */

char *misarmail_usage_get(MisarMailClient *client, const char *query_params)
{
    char path[512];
    if (build_path_query(path, sizeof(path), "/usage", query_params) < 0) {
        set_error(0, "path too long"); return NULL;
    }
    return do_request(client, "GET", path, NULL);
}

/* -----------------------------------------------------------------------
 * Public API — Billing  (api_base — no /v1)
 * ----------------------------------------------------------------------- */

char *misarmail_billing_subscription(MisarMailClient *client)
{
    return do_request_base(client, "GET", "/billing/subscription", NULL);
}

char *misarmail_billing_checkout(MisarMailClient *client, const char *json_body)
{
    return do_request_base(client, "POST", "/billing/checkout", json_body);
}

/* -----------------------------------------------------------------------
 * Public API — Workspaces  (api_base — no /v1)
 * ----------------------------------------------------------------------- */

char *misarmail_workspaces_list(MisarMailClient *client)
{
    return do_request_base(client, "GET", "/workspaces", NULL);
}

char *misarmail_workspaces_create(MisarMailClient *client, const char *json_body)
{
    return do_request_base(client, "POST", "/workspaces", json_body);
}

char *misarmail_workspaces_get(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/workspaces", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request_base(client, "GET", path, NULL);
}

char *misarmail_workspaces_update(MisarMailClient *client, const char *id, const char *json_body)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/workspaces", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request_base(client, "PATCH", path, json_body);
}

char *misarmail_workspaces_delete(MisarMailClient *client, const char *id)
{
    if (!id) { set_error(0, "id is NULL"); return NULL; }
    char path[512];
    if (build_path_id(path, sizeof(path), "/workspaces", id) < 0) {
        set_error(0, "id too long"); return NULL;
    }
    return do_request_base(client, "DELETE", path, NULL);
}

char *misarmail_workspaces_list_members(MisarMailClient *client, const char *ws_id)
{
    if (!ws_id) { set_error(0, "ws_id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/workspaces/%s/members", ws_id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "ws_id too long"); return NULL; }
    return do_request_base(client, "GET", path, NULL);
}

char *misarmail_workspaces_invite_member(MisarMailClient *client, const char *ws_id, const char *json_body)
{
    if (!ws_id) { set_error(0, "ws_id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/workspaces/%s/members", ws_id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "ws_id too long"); return NULL; }
    return do_request_base(client, "POST", path, json_body);
}

char *misarmail_workspaces_update_member(MisarMailClient *client, const char *ws_id, const char *user_id, const char *json_body)
{
    if (!ws_id || !user_id) { set_error(0, "ws_id/user_id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/workspaces/%s/members/%s", ws_id, user_id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "ids too long"); return NULL; }
    return do_request_base(client, "PATCH", path, json_body);
}

char *misarmail_workspaces_remove_member(MisarMailClient *client, const char *ws_id, const char *user_id)
{
    if (!ws_id || !user_id) { set_error(0, "ws_id/user_id is NULL"); return NULL; }
    char path[512];
    int n = snprintf(path, sizeof(path), "/workspaces/%s/members/%s", ws_id, user_id);
    if (n < 0 || (size_t)n >= sizeof(path)) { set_error(0, "ids too long"); return NULL; }
    return do_request_base(client, "DELETE", path, NULL);
}
