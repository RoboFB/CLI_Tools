# === Build settings ===
TARGET          = quack
SRC             = cli.c

# === Paths ===
ROOT_DIR        = $(abspath $(CURDIR)/..)
CURL_DIR        = external/curl
MBEDTLS_DIR     = external/mbedtls
BUILD_DIR       = build
MBEDTLS_BUILD   = $(BUILD_DIR)/mbedtls
MBEDTLS_INSTALL = $(BUILD_DIR)/mbedtls_install
CURL_BUILD      = $(BUILD_DIR)/curl
CURL_INSTALL    = $(BUILD_DIR)/curl_install
OUTPUT_BIN      = $(ROOT_DIR)/$(TARGET)

# === System detection ===
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
	LDFLAGS += -framework CoreFoundation -framework SystemConfiguration
endif

# === System build flags (uses system curl only) ===
SYS_CFLAGS  = -I/usr/include -I/usr/local/include -I/opt/homebrew/include
SYS_LDFLAGS = -L/usr/lib -L/usr/local/lib -L/opt/homebrew/lib -lcurl

# === Portable build flags (uses vendored curl + mbedTLS) ===
PORTABLE_CFLAGS  = -I$(CURL_INSTALL)/include
PORTABLE_LDFLAGS = -L$(CURL_INSTALL)/lib -lcurl \
                   -L$(MBEDTLS_INSTALL)/lib -lmbedtls -lmbedx509 -lmbedcrypto

# === Parallel build settings ===
JOBS := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
MAKEFLAGS += -j$(JOBS)

# === Targets ===
.PHONY: all portable submodules rebuild-libs clean help

# --- Default: system build ---
all: $(OUTPUT_BIN)

$(OUTPUT_BIN): $(SRC)
	@echo "==> Compiling $(TARGET) (system build)..."
	mkdir -p $(BUILD_DIR)
	$(CC) $(SRC) $(SYS_CFLAGS) $(SYS_LDFLAGS) -o $(BUILD_DIR)/$(TARGET)
	cp $(BUILD_DIR)/$(TARGET) $(OUTPUT_BIN)
	@echo "==> Built $(OUTPUT_BIN)"

# --- Portable build: fetch + build all dependencies ---
portable: submodules $(BUILD_DIR)/$(TARGET)-portable
	@cp $(BUILD_DIR)/$(TARGET)-portable $(OUTPUT_BIN)
	@echo "==> Portable binary ready at $(OUTPUT_BIN)"

$(BUILD_DIR)/$(TARGET)-portable: $(SRC) $(CURL_INSTALL)/lib/libcurl.a
	@echo "==> Compiling $(TARGET) (portable build)..."
	mkdir -p $(BUILD_DIR)
	$(CC) $(SRC) $(PORTABLE_CFLAGS) $(PORTABLE_LDFLAGS) -o $@
	@echo "==> Built $@"

# --- Fetch and update submodules ---
submodules:
	@echo "==> Fetching and updating submodules..."
	git -C $(ROOT_DIR) submodule sync --recursive
	git -C $(ROOT_DIR) submodule update --init --recursive --remote
	@echo "==> Submodules ready."

# --- Build mbedTLS ---
$(MBEDTLS_INSTALL)/lib/libmbedtls.a:
	@echo "==> Building mbedTLS (static)..."
	mkdir -p $(MBEDTLS_BUILD) $(MBEDTLS_INSTALL)
	cd $(MBEDTLS_BUILD) && cmake ../../$(MBEDTLS_DIR) \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=OFF \
		-DENABLE_PROGRAMS=OFF \
		-DENABLE_TESTING=OFF \
		-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
		-DCMAKE_INSTALL_PREFIX=$(abspath $(MBEDTLS_INSTALL))
	$(MAKE) -C $(MBEDTLS_BUILD) install

# --- Build libcurl ---
$(CURL_INSTALL)/lib/libcurl.a: $(MBEDTLS_INSTALL)/lib/libmbedtls.a
	@echo "==> Building libcurl (static, HTTPS via mbedTLS)..."
	mkdir -p $(CURL_BUILD) $(CURL_INSTALL)
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
		-DCMAKE_INSTALL_PREFIX=$(abspath $(CURL_INSTALL))
	$(MAKE) -C $(CURL_BUILD) install

# --- Force rebuild both libraries ---
rebuild-libs:
	@echo "==> Forcing rebuild of mbedTLS and libcurl..."
	rm -rf $(MBEDTLS_BUILD) $(MBEDTLS_INSTALL) $(CURL_BUILD) $(CURL_INSTALL)
	$(MAKE) portable

# --- Clean build artifacts ---
clean:
	@echo "==> Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	rm -f $(OUTPUT_BIN)

# --- Help ---
help:
	@echo "Available targets:"
	@echo "  make            - Build using system libcurl (no mbedTLS required)"
	@echo "  make portable   - Fetch and build static vendored curl + mbedTLS"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make rebuild-libs - Force rebuild of vendored libs"