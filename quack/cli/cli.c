#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <curl/curl.h>
#include <libgen.h>
#include <limits.h>
#include <sys/stat.h>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

#define BROKER_BASE "https://quack.moritzdiepgen.de"
#define POLL_INTERVAL 3
#define SESSION_FILE ".quack_session"

/* ---- Memory + Headers ---- */
struct Memory { char *data; size_t size; };
struct Headers { char session[128]; };

static size_t write_cb(void *c, size_t s, size_t n, void *u) {
    size_t r = s * n;
    struct Memory *m = u;
    char *p = realloc(m->data, m->size + r + 1);
    if (!p) return 0;
    m->data = p;
    memcpy(m->data + m->size, c, r);
    m->size += r;
    m->data[m->size] = 0;
    return r;
}

static size_t header_cb(char *buffer, size_t size, size_t nitems, void *userdata) {
    size_t total = size * nitems;
    struct Headers *h = userdata;
    if (!h) return total;
    if (total > 9 && strncasecmp(buffer, "Session:", 8) == 0) {
        const char *p = buffer + 8;
        while (*p == ' ' || *p == '\t') p++;
        size_t len = strcspn(p, "\r\n");
        if (len >= sizeof(h->session)) len = sizeof(h->session) - 1;
        strncpy(h->session, p, len);
        h->session[len] = 0;
    }
    return total;
}

/* ---- HTTP GET with optional session + header capture ---- */
char *http_get(const char *url, const char *session, struct Headers *out) {
    CURL *curl = curl_easy_init();
    if (!curl) return NULL;

    struct Memory mem = { malloc(1), 0 };
    struct curl_slist *headers = NULL;

    if (out) out->session[0] = 0;

    if (session && *session) {
        char auth_header[256];
        snprintf(auth_header, sizeof(auth_header), "Authorization: Session %s", session);
        headers = curl_slist_append(headers, auth_header);
    }

    headers = curl_slist_append(headers, "Accept: application/json");

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &mem);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, header_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERDATA, out);

    CURLcode res = curl_easy_perform(curl);

    if (headers) curl_slist_free_all(headers);
    curl_easy_cleanup(curl);

    if (res != CURLE_OK) {
        free(mem.data);
        return NULL;
    }

    return mem.data; // caller frees this
}

/* ---- Helpers ---- */
static void trim(char *s) {
    char *p = s;
    while (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r') p++;
    memmove(s, p, strlen(p) + 1);
    for (int i = strlen(s) - 1; i >= 0 &&
         (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r'); i--)
        s[i] = 0;
}

char *json_get(const char *json, const char *key) {
    static char val[512];
    char pat[64];
    snprintf(pat, sizeof(pat), "\"%s\":", key);
    const char *p = strstr(json, pat);
    if (!p) return NULL;
    p += strlen(pat);
    while (*p == ' ' || *p == '\"') p++;
    const char *e = p;
    while (*e && *e != '\"' && *e != '}' && *e != ',' && *e != '\n') e++;
    size_t len = (e - p) < sizeof(val) - 1 ? (e - p) : sizeof(val) - 1;
    strncpy(val, p, len);
    val[len] = 0;
    return val;
}

void unescape_slashes(char *s) {
    char *src = s, *dst = s;
    while (*src) {
        if (src[0] == '\\' && src[1] == '/') src++;
        *dst++ = *src++;
    }
    *dst = 0;
}

/* ---- executable directory detection ---- */
static char session_path[PATH_MAX];

static void get_executable_dir(char *buf, size_t len) {
#ifdef __linux__
    ssize_t n = readlink("/proc/self/exe", buf, len - 1);
    if (n > 0) {
        buf[n] = '\0';
        char *slash = strrchr(buf, '/');
        if (slash) *slash = '\0';
    } else {
        strncpy(buf, ".", len);
    }
#elif __APPLE__
    uint32_t size = (uint32_t)len;
    if (_NSGetExecutablePath(buf, &size) == 0) {
        char *slash = strrchr(buf, '/');
        if (slash) *slash = '\0';
    } else {
        strncpy(buf, ".", len);
    }
#else
    strncpy(buf, ".", len);
#endif
}

/* ---- Session persistence ---- */
void save_session(const char *sid) {
    FILE *f = fopen(session_path, "w");
    if (f) { fprintf(f, "%s", sid); fclose(f); }
}

int load_session(char *sid, size_t len) {
    FILE *f = fopen(session_path, "r");
    if (!f) return 0;
    if (!fgets(sid, len, f)) { fclose(f); return 0; }
    fclose(f);
    trim(sid);
    return 1;
}

/* ---- Main ---- */
int main(int argc, char **argv) {
    curl_global_init(CURL_GLOBAL_DEFAULT);

    // Resolve session path based on binary location
    char exe_dir[PATH_MAX];
    get_executable_dir(exe_dir, sizeof(exe_dir));
    snprintf(session_path, sizeof(session_path), "%s/%s", exe_dir, SESSION_FILE);

    char url[1024];
    char session[128] = {0};
    char *resp;
    const char *api_path = NULL;
    const char *out_file = NULL;

    for (int i = 1; i < argc; i++) {
        if ((strcmp(argv[i], "-o") == 0 || strcmp(argv[i], "--out") == 0) && i + 1 < argc)
            out_file = argv[++i];
        else
            api_path = argv[i];
    }

    if (!api_path)
        api_path = "/v2/me";

    /* Try to reuse existing session */
    if (load_session(session, sizeof(session))) {
        snprintf(url, sizeof(url), "%s/42/status", BROKER_BASE);
        resp = http_get(url, session, NULL);
        if (resp) {
            char *st = json_get(resp, "status");
            if (st && strcmp(st, "authorized") == 0) {
                free(resp);
                goto authorized;
            }
            free(resp);
        }
        fprintf(stderr, "⚠️  Saved session invalid or expired. Starting new authorization.\n");
    }

    /* 1️⃣ Create new session */
    snprintf(url, sizeof(url), "%s/42/newsession", BROKER_BASE);
    struct Headers hdr;
    resp = http_get(url, NULL, &hdr);
    if (!resp) { fprintf(stderr, "❌ Server error.\n"); return 1; }

    if (!*hdr.session) {
        fprintf(stderr, "❌ No Session header from server.\n");
        free(resp);
        return 1;
    }

    strncpy(session, hdr.session, sizeof(session));
    session[sizeof(session) - 1] = 0;
    save_session(session);

    char *login = json_get(resp, "login_url");
    if (!login) {
        fprintf(stderr, "❌ Missing login_url: %s\n", resp);
        free(resp);
        return 1;
    }
    unescape_slashes(login);

    fprintf(stderr, "Open this URL in your browser:\n\n  %s\n\n", login);
    free(resp);

    /* 2️⃣ Poll until authorized */
    fprintf(stderr, "Waiting for authorization");
    fflush(stderr);

    for (;;) {
        sleep(POLL_INTERVAL);
        fprintf(stderr, "."); fflush(stderr);
        snprintf(url, sizeof(url), "%s/42/status", BROKER_BASE);
        resp = http_get(url, session, NULL);
        if (!resp) continue;
        char *st = json_get(resp, "status");
        if (st && strcmp(st, "authorized") == 0) {
            free(resp);
            break;
        }
        free(resp);
    }

    fprintf(stderr, "\n\n✅ Authorized!\n");

authorized:
{
    CURL *curl_escape = curl_easy_init();
    char *encoded_path = NULL;
    if (curl_escape)
        encoded_path = curl_easy_escape(curl_escape, api_path, 0);

    if (encoded_path) {
        snprintf(url, sizeof(url),
                 "%s/42/proxy?path=%s", BROKER_BASE, encoded_path);
        curl_free(encoded_path);
    } else {
        snprintf(url, sizeof(url),
                 "%s/42/proxy?path=%s", BROKER_BASE, api_path);
    }

    if (curl_escape)
        curl_easy_cleanup(curl_escape);

    resp = http_get(url, session, NULL);

    fprintf(stderr, "\n📡  %s response:\n", api_path);

    if (resp) {
        const char *status = json_get(resp, "status");

        if (status && (!strncmp(status, "404", 3) || !strncmp(status, "403", 3))) {
            fprintf(stderr, "❌ Access denied or not found (status %s)\n", status);
            free(resp);
            curl_global_cleanup();
            return EXIT_FAILURE;
        }

        // otherwise, print or save the data
        if (out_file) {
            FILE *out = fopen(out_file, "w");
            if (out) {
                fwrite(resp, 1, strlen(resp), out);
                fclose(out);
                fprintf(stderr, "📄 Response written to %s\n", out_file);
            } else {
                fprintf(stderr, "❌ Could not write response file.\n");
            }
        } else {
            printf("%s\n", resp);
        }

        free(resp);
    } else {
        fprintf(stderr, "❌ No response received.\n");
        curl_global_cleanup();
        return EXIT_FAILURE;
    }

    curl_global_cleanup();
    return 0;
}
}