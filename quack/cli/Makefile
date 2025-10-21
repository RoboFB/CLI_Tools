# === Build settings ===
TARGET = quack
SRC = cli.c

# === Paths ===
ROOT_DIR 				= $(abspath $(CURDIR)/..)
CURL_DIR        = external/curl
MBEDTLS_DIR     = external/mbedtls
BUILD_DIR       = build
MBEDTLS_BUILD   = $(BUILD_DIR)/mbedtls
MBEDTLS_INSTALL = $(BUILD_DIR)/mbedtls_install
CURL_BUILD      = $(BUILD_DIR)/curl
CURL_INSTALL    = $(BUILD_DIR)/curl_install
OUTPUT_BIN      = $(ROOT_DIR)/$(TARGET)

# === Compiler / Linker ===
CFLAGS  = -I$(CURL_INSTALL)/include
LDFLAGS = -L$(CURL_INSTALL)/lib -lcurl \
           -L$(MBEDTLS_INSTALL)/lib -lmbedtls -lmbedx509 -lmbedcrypto

# === Parallel build settings ===
JOBS := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
MAKEFLAGS += -j$(JOBS)

# === Default target ===
all: submodules $(OUTPUT_BIN)

HAS_CURL := $(shell [ -f /usr/lib/libcurl.dylib ] && echo 1 || echo 0)
HAS_MBEDTLS := $(shell [ -f /usr/local/lib/libmbedtls.a ] && echo 1 || echo 0)
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LDFLAGS += -framework CoreFoundation -framework SystemConfiguration
endif
ifeq ($(HAS_CURL),1)
	CFLAGS  += -I/usr/include
	LDFLAGS += -L/usr/lib -lcurl
else
	CFLAGS  += -I$(CURL_INSTALL)/include
	LDFLAGS += -L$(CURL_INSTALL)/lib -lcurl
endif

ifeq ($(HAS_MBEDTLS),1)
	LDFLAGS += -L/usr/local/lib -lmbedtls -lmbedx509 -lmbedcrypto
else
	LDFLAGS += -L$(MBEDTLS_INSTALL)/lib -lmbedtls -lmbedx509 -lmbedcrypto
endif

# --- Ensure submodules are initialized and up to date ---
submodules:
	@if [ "$(HAS_CURL)" = "1" ] && [ "$(HAS_MBEDTLS)" = "1" ]; then \
		echo "==> System libraries found (libcurl + mbedTLS); skipping submodule fetch."; \
	else \
		echo "==> Fetching and updating submodules..."; \
		git -C $(ROOT_DIR) submodule sync --recursive; \
		git -C $(ROOT_DIR) submodule update --init --recursive --remote; \
		echo "==> Submodules ready."; \
	fi

.PHONY: submodules

# --- Build mbedTLS (only if missing) ---
$(MBEDTLS_INSTALL)/lib/libmbedtls.a: submodules
	@if [ ! -f "$@" ]; then \
		echo "==> Building mbedTLS (static)..."; \
		mkdir -p $(MBEDTLS_BUILD) $(MBEDTLS_INSTALL); \
		cd $(MBEDTLS_BUILD) && cmake ../../$(MBEDTLS_DIR) \
			-DCMAKE_BUILD_TYPE=Release \
			-DBUILD_SHARED_LIBS=OFF \
			-DENABLE_PROGRAMS=OFF \
			-DENABLE_TESTING=OFF \
			-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
			-DCMAKE_INSTALL_PREFIX=$(abspath $(MBEDTLS_INSTALL)) && \
		$(MAKE) && $(MAKE) install; \
	else \
		echo "==> Skipping mbedTLS (already built)"; \
	fi


# --- Build libcurl (only if missing) ---
$(CURL_INSTALL)/lib/libcurl.a: submodules $(MBEDTLS_INSTALL)/lib/libmbedtls.a
	@if [ ! -f "$@" ]; then \
		echo "==> Building libcurl (static, HTTPS via mbedTLS)..."; \
		mkdir -p $(CURL_BUILD) $(CURL_INSTALL); \
		cd $(CURL_BUILD) && cmake ../../$(CURL_DIR) \
			-DCMAKE_BUILD_TYPE=Release \
			-DBUILD_SHARED_LIBS=OFF \
			-DCURL_STATICLIB=ON \
			-DBUILD_CURL_EXE=OFF \
			-DCURL_USE_MBEDTLS=ON \
			-DCURL_USE_LIBPSL=OFF \
			-DCURL_ZLIB=OFF \
			-DCURL_BROTLI=OFF \
			-DCURL_ZSTD=OFF \
			-DCURL_USE_LIBSSH2=OFF \
			-DCURL_DISABLE_LDAP=ON \
			-DCURL_DISABLE_LDAPS=ON \
			-DCMAKE_PREFIX_PATH=$(abspath $(MBEDTLS_INSTALL)) \
			-DCMAKE_INSTALL_PREFIX=$(abspath $(CURL_INSTALL)) && \
		$(MAKE) && $(MAKE) install; \
	else \
		echo "==> Skipping libcurl (already built)"; \
	fi


# --- Build your CLI binary ---
# --- Build your CLI binary ---
ifeq ($(HAS_CURL),1)
$(OUTPUT_BIN): $(SRC)
else
$(OUTPUT_BIN): $(SRC) $(CURL_INSTALL)/lib/libcurl.a
endif
	@echo "==> Compiling $(TARGET)..."
	mkdir -p $(BUILD_DIR)
	$(CC) $(SRC) $(CFLAGS) $(LDFLAGS) -o $(BUILD_DIR)/$(TARGET)
	cp $(BUILD_DIR)/$(TARGET) $(OUTPUT_BIN)
	@echo "==> Built $(OUTPUT_BIN)"

# --- Force rebuild both libraries (manual) ---
.PHONY: rebuild-libs
rebuild-libs:
	@echo "==> Forcing rebuild of mbedTLS and libcurl..."
	rm -rf $(MBEDTLS_BUILD) $(MBEDTLS_INSTALL) $(CURL_BUILD) $(CURL_INSTALL)
	$(MAKE) $(CURL_INSTALL)/lib/libcurl.a

# --- Clean targets ---
clean:
	@echo "==> Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	rm -f $(OUTPUT_BIN)
