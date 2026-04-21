#include <assert.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <string>

#include <openssl/bio.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/ssl.h>

static SSL_CTX *g_server_ctx = nullptr;
static std::string g_exe_dir;

static std::string JoinPath(const std::string &base, const char *name) {
  if (base.empty()) {
    return std::string(name);
  }
  return base + "/" + name;
}

static std::string DirName(const char *path) {
  if (path == nullptr || path[0] == '\0') {
    return ".";
  }

  std::string value(path);
  size_t last_slash = value.find_last_of('/');
  if (last_slash == std::string::npos) {
    return ".";
  }
  if (last_slash == 0) {
    return "/";
  }
  return value.substr(0, last_slash);
}

class Environment {
 public:
  Environment() {
    SSL_library_init();
    SSL_load_error_strings();
    OpenSSL_add_all_algorithms();

    g_server_ctx = SSL_CTX_new(TLSv1_method());
    assert(g_server_ctx != nullptr);
    SSL_CTX_set_verify(g_server_ctx, SSL_VERIFY_NONE, nullptr);

    const std::string cert_path = JoinPath(g_exe_dir, "server.pem");
    const std::string key_path = JoinPath(g_exe_dir, "server.key");

    assert(SSL_CTX_use_certificate_file(
               g_server_ctx, cert_path.c_str(), SSL_FILETYPE_PEM) == 1);
    assert(SSL_CTX_use_PrivateKey_file(
               g_server_ctx, key_path.c_str(), SSL_FILETYPE_PEM) == 1);
    assert(SSL_CTX_check_private_key(g_server_ctx) == 1);
  }

  ~Environment() {
    if (g_server_ctx != nullptr) {
      SSL_CTX_free(g_server_ctx);
      g_server_ctx = nullptr;
    }
  }
};

extern "C" int LLVMFuzzerInitialize(int *argc, char ***argv) {
  (void)argc;
  g_exe_dir = DirName((*argv)[0]);
  return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  static Environment env;
  (void)env;

  SSL *server = SSL_new(g_server_ctx);
  if (server == nullptr) {
    return 0;
  }

  BIO *in = BIO_new(BIO_s_mem());
  BIO *out = BIO_new(BIO_s_mem());
  if (in == nullptr || out == nullptr) {
    BIO_free(in);
    BIO_free(out);
    SSL_free(server);
    return 0;
  }

  SSL_set_bio(server, in, out);
  SSL_set_accept_state(server);

  if (size > 0) {
    BIO_write(in, data, static_cast<int>(size));
  }

  SSL_do_handshake(server);

  char drain[4096];
  while (SSL_read(server, drain, sizeof(drain)) > 0) {
  }

  SSL_free(server);
  ERR_clear_error();
  return 0;
}
