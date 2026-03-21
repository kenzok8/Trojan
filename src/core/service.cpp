/*
 * This file is part of the trojan project.
 * Trojan is an unidentifiable mechanism that helps you bypass GFW.
 * Copyright (C) 2017-2020  The Trojan Authors.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "service.h"
#include <cstring>
#include <cerrno>
#include <stdexcept>
#include <fstream>
#ifdef _WIN32
#include <wincrypt.h>
#include <tchar.h>
#endif // _WIN32
#ifdef __APPLE__
#include <Security/Security.h>
#endif // __APPLE__
#include <openssl/ssl.h>
#include <openssl/x509.h>
#include <openssl/opensslv.h>
#include "session/serversession.h"
#include "session/clientsession.h"
#include "session/forwardsession.h"
#include "session/natsession.h"
#include "ssl/ssldefaults.h"
#include "ssl/sslsession.h"
using namespace std;
using namespace boost::asio::ip;
using namespace boost::asio::ssl;

namespace {
void load_platform_root_certificates(SSL_CTX *native_context);

std::string run_type_to_string(const Config &config) {
    switch (config.run_type) {
        case Config::SERVER:
            return "server";
        case Config::FORWARD:
            return "forward";
        case Config::NAT:
            return "nat";
        default:
            return "client";
    }
}

void configure_cipher_preferences(SSL_CTX *native_context, const Config::SSLConfig &ssl_config) {
    if (!ssl_config.cipher.empty()) {
        SSL_CTX_set_cipher_list(native_context, ssl_config.cipher.c_str());
    }

    if (!ssl_config.cipher_tls13.empty()) {
#ifdef ENABLE_TLS13_CIPHERSUITES
        SSL_CTX_set_ciphersuites(native_context, ssl_config.cipher_tls13.c_str());
#else
        Log::log_with_date_time("TLS1.3 ciphersuites are not supported", Log::WARN);
#endif
    }

    if (!ssl_config.curves.empty()) {
        SSL_CTX_set1_curves_list(native_context, ssl_config.curves.c_str());
    }
}

void configure_alpn_server(SSL_CTX *native_context, Config &config) {
    if (config.ssl.alpn.empty()) {
        return;
    }

    SSL_CTX_set_alpn_select_cb(native_context, [](SSL*, const unsigned char **out, unsigned char *outlen, const unsigned char *in, unsigned int inlen, void *config_ptr) -> int {
        auto *config = static_cast<Config *>(config_ptr);
        unsigned char *selected = nullptr;
        if (SSL_select_next_proto(
                &selected,
                outlen,
                reinterpret_cast<const unsigned char *>(config->ssl.alpn.c_str()),
                config->ssl.alpn.length(),
                in,
                inlen) != OPENSSL_NPN_NEGOTIATED) {
            return SSL_TLSEXT_ERR_NOACK;
        }
        *out = selected;
        return SSL_TLSEXT_ERR_OK;
    }, &config);
}

void configure_alpn_client(SSL_CTX *native_context, const Config::SSLConfig &ssl_config) {
    if (!ssl_config.alpn.empty()) {
        SSL_CTX_set_alpn_protos(native_context, reinterpret_cast<const unsigned char *>(ssl_config.alpn.c_str()), ssl_config.alpn.length());
    }
}

void configure_session_cache_for_server(SSL_CTX *native_context, const Config::SSLConfig &ssl_config) {
    if (ssl_config.reuse_session) {
        SSL_CTX_set_timeout(native_context, ssl_config.session_timeout);
        if (!ssl_config.session_ticket) {
            SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
        }
    } else {
        SSL_CTX_set_session_cache_mode(native_context, SSL_SESS_CACHE_OFF);
        SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
    }
}

void configure_session_cache_for_client(SSL_CTX *native_context, const Config::SSLConfig &ssl_config) {
    if (ssl_config.reuse_session) {
        SSL_CTX_set_session_cache_mode(native_context, SSL_SESS_CACHE_CLIENT);
        SSLSession::set_callback(native_context);
        if (!ssl_config.session_ticket) {
            SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
        }
    } else {
        SSL_CTX_set_options(native_context, SSL_OP_NO_TICKET);
    }
}

std::string load_plain_http_response(const std::string &path) {
    if (path.empty()) {
        return {};
    }

    ifstream ifs(path, ios::binary);
    if (!ifs.is_open()) {
        throw runtime_error(path + ": " + strerror(errno));
    }
    return string(istreambuf_iterator<char>(ifs), istreambuf_iterator<char>());
}

void configure_server_dhparams(boost::asio::ssl::context &ssl_context, const Config::SSLConfig &ssl_config) {
    if (ssl_config.dhparam.empty()) {
        ssl_context.use_tmp_dh(boost::asio::const_buffer(SSLDefaults::g_dh2048_sz, SSLDefaults::g_dh2048_sz_size));
        return;
    }

    ssl_context.use_tmp_dh_file(ssl_config.dhparam);
}

void configure_client_verify_store(boost::asio::ssl::context &ssl_context, SSL_CTX *native_context, const Config::SSLConfig &ssl_config) {
    if (ssl_config.cert.empty()) {
        ssl_context.set_default_verify_paths();
        load_platform_root_certificates(native_context);
    } else {
        ssl_context.load_verify_file(ssl_config.cert);
    }
}

void configure_server_ssl_context(boost::asio::ssl::context &ssl_context, SSL_CTX *native_context, Config &config, std::string &plain_http_response) {
    ssl_context.use_certificate_chain_file(config.ssl.cert);
    ssl_context.set_password_callback([&config](size_t, context_base::password_purpose) {
        return config.ssl.key_password;
    });
    ssl_context.use_private_key_file(config.ssl.key, context::pem);

    if (config.ssl.prefer_server_cipher) {
        SSL_CTX_set_options(native_context, SSL_OP_CIPHER_SERVER_PREFERENCE);
    }

    configure_alpn_server(native_context, config);
    configure_session_cache_for_server(native_context, config.ssl);
    plain_http_response = load_plain_http_response(config.ssl.plain_http_response);
    configure_server_dhparams(ssl_context, config.ssl);
}

void configure_client_verify(boost::asio::ssl::context &ssl_context, SSL_CTX *native_context, Config &config) {
    if (!config.ssl.verify) {
        ssl_context.set_verify_mode(verify_none);
        return;
    }

    ssl_context.set_verify_mode(verify_peer);
    configure_client_verify_store(ssl_context, native_context, config.ssl);

    if (config.ssl.verify_hostname) {
#if BOOST_VERSION >= 107300
        ssl_context.set_verify_callback(host_name_verification(config.ssl.sni));
#else
        ssl_context.set_verify_callback(rfc2818_verification(config.ssl.sni));
#endif
    }

    X509_VERIFY_PARAM *param = X509_VERIFY_PARAM_new();
    if (param != nullptr) {
        X509_VERIFY_PARAM_set_flags(param, X509_V_FLAG_PARTIAL_CHAIN);
        SSL_CTX_set1_param(native_context, param);
        X509_VERIFY_PARAM_free(param);
    }
}

void configure_client_ssl_context(boost::asio::ssl::context &ssl_context, SSL_CTX *native_context, Config &config) {
    if (config.ssl.sni.empty()) {
        config.ssl.sni = config.remote_addr;
    }

    configure_client_verify(ssl_context, native_context, config);
    configure_alpn_client(native_context, config.ssl);
    configure_session_cache_for_client(native_context, config.ssl);
}

#ifdef _WIN32
void load_windows_root_certificates(SSL_CTX *native_context) {
    HCERTSTORE h_store = CertOpenSystemStore(0, _T("ROOT"));
    if (!h_store) {
        return;
    }

    X509_STORE *store = SSL_CTX_get_cert_store(native_context);
    PCCERT_CONTEXT p_context = nullptr;
    while ((p_context = CertEnumCertificatesInStore(h_store, p_context))) {
        const unsigned char *encoded_cert = p_context->pbCertEncoded;
        X509 *x509 = d2i_X509(nullptr, &encoded_cert, p_context->cbCertEncoded);
        if (x509) {
            X509_STORE_add_cert(store, x509);
            X509_free(x509);
        }
    }

    CertCloseStore(h_store, 0);
}
#endif // _WIN32

#ifdef __APPLE__
void load_macos_root_certificates(SSL_CTX *native_context) {
    SecKeychainRef pSecKeychain = nullptr;
    OSStatus status = SecKeychainOpen("/System/Library/Keychains/SystemRootCertificates.keychain", &pSecKeychain);
    if (status != noErr) {
        return;
    }

    SecKeychainSearchRef pSecKeychainSearch = nullptr;
    status = SecKeychainSearchCreateFromAttributes(pSecKeychain, kSecCertificateItemClass, nullptr, &pSecKeychainSearch);
    if (status != noErr) {
        CFRelease(pSecKeychain);
        return;
    }

    X509_STORE *store = SSL_CTX_get_cert_store(native_context);
    for (;;) {
        SecKeychainItemRef pSecKeychainItem = nullptr;
        status = SecKeychainSearchCopyNext(pSecKeychainSearch, &pSecKeychainItem);
        if (status == errSecItemNotFound) {
            break;
        }

        if (status == noErr) {
            void *_pCertData = nullptr;
            UInt32 _pCertLength = 0;
            status = SecKeychainItemCopyAttributesAndData(pSecKeychainItem, nullptr, nullptr, nullptr, &_pCertLength, &_pCertData);

            if (status == noErr && _pCertData != nullptr) {
                unsigned char *ptr = static_cast<unsigned char *>(_pCertData);
                X509 *cert = d2i_X509(nullptr, const_cast<const unsigned char **>(&ptr), _pCertLength);
                if (cert != nullptr) {
                    if (!X509_STORE_add_cert(store, cert)) {
                        X509_free(cert);
                    } else {
                        X509_free(cert);
                    }
                }
                SecKeychainItemFreeAttributesAndData(nullptr, _pCertData);
            }
        }

        if (pSecKeychainItem != nullptr) {
            CFRelease(pSecKeychainItem);
        }
    }

    CFRelease(pSecKeychainSearch);
    CFRelease(pSecKeychain);
}
#endif // __APPLE__

void load_platform_root_certificates(SSL_CTX *native_context) {
#ifdef _WIN32
    load_windows_root_certificates(native_context);
#endif
#ifdef __APPLE__
    load_macos_root_certificates(native_context);
#endif
}
}

#ifdef ENABLE_REUSE_PORT
typedef boost::asio::detail::socket_option::boolean<SOL_SOCKET, SO_REUSEPORT> reuse_port;
#endif // ENABLE_REUSE_PORT

Service::Service(Config &config, bool test) :
    config(config),
    socket_acceptor(io_context),
    ssl_context(context::tls),
    auth(nullptr),
    udp_socket(io_context) {
#ifndef ENABLE_NAT
    if (config.run_type == Config::NAT) {
        throw runtime_error("NAT is not supported");
    }
#endif // ENABLE_NAT
    if (!test) {
        tcp::resolver resolver(io_context);
        tcp::endpoint listen_endpoint = *resolver.resolve(config.local_addr, to_string(config.local_port)).begin();
        configure_tcp_acceptor(listen_endpoint);
        socket_acceptor.bind(listen_endpoint);
        socket_acceptor.listen();
        if (config.run_type == Config::FORWARD) {
            configure_forward_udp_socket(listen_endpoint);
        }
    }
    Log::level = config.log_level;
    auto native_context = ssl_context.native_handle();
    ssl_context.set_options(context::default_workarounds | context::no_sslv2 | context::no_sslv3 | context::single_dh_use);
    configure_cipher_preferences(native_context, config.ssl);

    if (config.run_type == Config::SERVER) {
        configure_server_ssl_context(ssl_context, native_context, config, plain_http_response);
        if (config.mysql.enabled) {
#ifdef ENABLE_MYSQL
            auth = std::make_unique<Authenticator>(config);
#else // ENABLE_MYSQL
            Log::log_with_date_time("MySQL is not supported", Log::WARN);
#endif // ENABLE_MYSQL
        }
    } else {
        configure_client_ssl_context(ssl_context, native_context, config);
    }

    if (!test) {
        if (config.tcp.no_delay) {
            socket_acceptor.set_option(tcp::no_delay(true));
        }
        if (config.tcp.keep_alive) {
            socket_acceptor.set_option(boost::asio::socket_base::keep_alive(true));
        }
        configure_fast_open();
    }
    if (Log::keylog) {
#ifdef ENABLE_SSL_KEYLOG
        SSL_CTX_set_keylog_callback(native_context, [](const SSL*, const char *line) {
            fprintf(Log::keylog, "%s\n", line);
            fflush(Log::keylog);
        });
#else // ENABLE_SSL_KEYLOG
        Log::log_with_date_time("SSL KeyLog is not supported", Log::WARN);
#endif // ENABLE_SSL_KEYLOG
    }
}

void Service::run() {
    async_accept();
    if (config.run_type == Config::FORWARD) {
        udp_async_read();
    }
    tcp::endpoint local_endpoint = socket_acceptor.local_endpoint();
    Log::log_with_date_time(string("trojan service (") + run_type_name() + ") started at " + local_endpoint.address().to_string() + ':' + to_string(local_endpoint.port()), Log::WARN);
    io_context.run();
    Log::log_with_date_time("trojan service stopped", Log::WARN);
}

std::string Service::run_type_name() const {
    return run_type_to_string(config);
}

void Service::configure_tcp_acceptor(const tcp::endpoint &listen_endpoint) {
    socket_acceptor.open(listen_endpoint.protocol());
    socket_acceptor.set_option(tcp::acceptor::reuse_address(true));

    if (config.tcp.reuse_port) {
#ifdef ENABLE_REUSE_PORT
        socket_acceptor.set_option(reuse_port(true));
#else
        Log::log_with_date_time("SO_REUSEPORT is not supported", Log::WARN);
#endif
    }
}

void Service::configure_forward_udp_socket(const tcp::endpoint &listen_endpoint) {
    auto udp_bind_endpoint = udp::endpoint(listen_endpoint.address(), listen_endpoint.port());
    udp_socket.open(udp_bind_endpoint.protocol());
    udp_socket.bind(udp_bind_endpoint);
}

void Service::configure_fast_open() {
    if (!config.tcp.fast_open) {
        return;
    }

#ifdef TCP_FASTOPEN
    using fastopen = boost::asio::detail::socket_option::integer<IPPROTO_TCP, TCP_FASTOPEN>;
    boost::system::error_code ec;
    socket_acceptor.set_option(fastopen(config.tcp.fast_open_qlen), ec);
#else
    Log::log_with_date_time("TCP_FASTOPEN is not supported", Log::WARN);
#endif

#ifndef TCP_FASTOPEN_CONNECT
    Log::log_with_date_time("TCP_FASTOPEN_CONNECT is not supported", Log::WARN);
#endif
}

void Service::stop() {
    boost::system::error_code ec;
    socket_acceptor.cancel(ec);
    if (udp_socket.is_open()) {
        udp_socket.cancel(ec);
        udp_socket.close(ec);
    }
    io_context.stop();
}

void Service::async_accept() {
    shared_ptr<Session>session(nullptr);
    if (config.run_type == Config::SERVER) {
        session = make_shared<ServerSession>(config, io_context, ssl_context, auth.get(), plain_http_response);
    } else if (config.run_type == Config::FORWARD) {
        session = make_shared<ForwardSession>(config, io_context, ssl_context);
    } else if (config.run_type == Config::NAT) {
        session = make_shared<NATSession>(config, io_context, ssl_context);
    } else {
        session = make_shared<ClientSession>(config, io_context, ssl_context);
    }
    socket_acceptor.async_accept(session->accept_socket(), [this, session](const boost::system::error_code error) {
        if (error == boost::asio::error::operation_aborted) {
            // got cancel signal, stop calling myself
            return;
        }
        if (!error) {
            boost::system::error_code ec;
            auto endpoint = session->accept_socket().remote_endpoint(ec);
            if (!ec) {
                Log::log_with_endpoint(endpoint, "incoming connection");
                session->start();
            }
        }
        async_accept();
    });
}

void Service::udp_async_read() {
    udp_socket.async_receive_from(boost::asio::buffer(udp_read_buf, MAX_LENGTH), udp_recv_endpoint, [this](const boost::system::error_code error, size_t length) {
        if (error == boost::asio::error::operation_aborted) {
            // got cancel signal, stop calling myself
            return;
        }
        if (error) {
            stop();
            throw runtime_error(error.message());
        }
        string data((const char *)udp_read_buf, length);
        for (auto it = udp_sessions.begin(); it != udp_sessions.end();) {
            auto next = ++it;
            --it;
            if (it->expired()) {
                udp_sessions.erase(it);
            } else if (it->lock()->process(udp_recv_endpoint, data)) {
                udp_async_read();
                return;
            }
            it = next;
        }
        Log::log_with_endpoint(tcp::endpoint(udp_recv_endpoint.address(), udp_recv_endpoint.port()), "new UDP session");
        auto session = make_shared<UDPForwardSession>(config, io_context, ssl_context, udp_recv_endpoint, [this](const udp::endpoint &endpoint, const string &data) {
            boost::system::error_code ec;
            udp_socket.send_to(boost::asio::buffer(data), endpoint, 0, ec);
            if (ec == boost::asio::error::no_permission) {
                Log::log_with_endpoint(tcp::endpoint(endpoint.address(), endpoint.port()), "dropped a UDP packet due to firewall policy or rate limit");
            } else if (ec) {
                throw runtime_error(ec.message());
            }
        });
        udp_sessions.emplace_back(session);
        session->start();
        session->process(udp_recv_endpoint, data);
        udp_async_read();
    });
}

boost::asio::io_context &Service::service() {
    return io_context;
}

void Service::reload_cert() {
    if (config.run_type == Config::SERVER) {
        Log::log_with_date_time("reloading certificate and private key. . . ", Log::WARN);
        ssl_context.use_certificate_chain_file(config.ssl.cert);
        ssl_context.use_private_key_file(config.ssl.key, context::pem);
        boost::system::error_code ec;
        socket_acceptor.cancel(ec);
        async_accept();
        Log::log_with_date_time("certificate and private key reloaded", Log::WARN);
    } else {
        Log::log_with_date_time("cannot reload certificate and private key: wrong run_type", Log::ERROR);
    }
}
