/*
 * libwebsockets - small server side websockets and web server implementation
 *
 * Copyright (C) 2010 - 2013 Andy Green <andy@warmcat.com>
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation:
 *  version 2.1 of the License.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *  MA  02110-1301  USA
 */
#pragma once
#include "build.h"

/* The Libwebsocket version */
#define LWS_LIBRARY_VERSION "1.3"

/* The current git commit hash that we're building from */
#define LWS_BUILD_HASH "c11b847"


/* System introspection configs */
#ifdef CMAKE_BUILD
#include "lws_config.h"
#else
#if HOST_OS == OS_WINDOWS
#define inline __inline
#else /* not WIN32 */
#include "config.h"

#endif /* not WIN32 */
#endif /* not CMAKE */

#ifdef HAVE_SYS_TYPES_H
#include <sys/types.h>
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <ctype.h>
#include <limits.h>
#include <stdarg.h>

#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#if defined(WIN32) || defined(_WIN32)
#define LWS_NO_DAEMONIZE
#define LWS_ERRNO WSAGetLastError()
#define LWS_EAGAIN WSAEWOULDBLOCK
#define LWS_EALREADY WSAEALREADY
#define LWS_EINPROGRESS WSAEINPROGRESS
#define LWS_EINTR WSAEINTR
#define LWS_EISCONN WSAEISCONN
#define LWS_EWOULDBLOCK WSAEWOULDBLOCK
#define LWS_POLLHUP (FD_CLOSE)
#define LWS_POLLIN (FD_READ | FD_ACCEPT)
#define LWS_POLLOUT (FD_WRITE)
#define MSG_NOSIGNAL 0
#define SHUT_RDWR SD_BOTH
#define SOL_TCP IPPROTO_TCP

#define compatible_close(fd) closesocket(fd)
#define compatible_file_close(fd) CloseHandle(fd)
#define compatible_file_seek_cur(fd, offset) SetFilePointer(fd, offset, NULL, FILE_CURRENT)
#define compatible_file_read(amount, fd, buf, len) {\
	DWORD _amount; \
	if (!ReadFile(fd, buf, len, &_amount, NULL)) \
		amount = -1; \
	else \
		amount = _amount; \
	}
#define lws_set_blocking_send(wsi) wsi->sock_send_blocking = TRUE
#include <winsock2.h>
#include <windows.h>
#include <tchar.h>
#ifdef HAVE_IN6ADDR_H
#include <in6addr.h>
#endif
#include <mstcpip.h>

#ifndef __func__
#define __func__ __FUNCTION__
#endif

#ifdef _WIN32_WCE
#define vsnprintf _vsnprintf
#endif

#define LWS_INVALID_FILE INVALID_HANDLE_VALUE
#else /* not windows --> */
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <signal.h>
#include <strings.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/socket.h>
#ifdef LWS_BUILTIN_GETIFADDRS
 #include "deps/ifaddrs/ifaddrs.h"
#else
 #include <ifaddrs.h>
#endif
//#include <sys/syslog.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <netdb.h>
#ifndef LWS_NO_FORK
#ifdef HAVE_SYS_PRCTL_H
#include <sys/prctl.h>
#endif
#endif
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>
#include <poll.h>
#ifdef LWS_USE_LIBEV
#include <ev.h>
#endif /* LWS_USE_LIBEV */

#include <sys/mman.h>
#include <sys/time.h>

#define LWS_ERRNO errno
#define LWS_EAGAIN EAGAIN
#define LWS_EALREADY EALREADY
#define LWS_EINPROGRESS EINPROGRESS
#define LWS_EINTR EINTR
#define LWS_EISCONN EISCONN
#define LWS_EWOULDBLOCK EWOULDBLOCK
#define LWS_INVALID_FILE -1
#define LWS_POLLHUP (POLLHUP|POLLERR)
#define LWS_POLLIN (POLLIN)
#define LWS_POLLOUT (POLLOUT)
#define compatible_close(fd) close(fd)
#define compatible_file_close(fd) close(fd)
#define compatible_file_seek_cur(fd, offset) lseek(fd, offset, SEEK_CUR)
#define compatible_file_read(amount, fd, buf, len) \
		amount = read(fd, buf, len);
#define lws_set_blocking_send(wsi)
#endif

#ifndef HAVE_BZERO
#define bzero(b, len) (memset((b), '\0', (len)), (void) 0)
#endif

#ifndef HAVE_STRERROR
#define strerror(x) ""
#endif

#ifdef LWS_OPENSSL_SUPPORT
#ifdef USE_CYASSL
#include <cyassl/openssl/ssl.h>
#include <cyassl/error.h>
unsigned char *
SHA1(const unsigned char *d, size_t n, unsigned char *md);
#else
#include <openssl/ssl.h>
#include <openssl/evp.h>
#include <openssl/err.h>
#include <openssl/md5.h>
#include <openssl/sha.h>
#endif /* not USE_CYASSL */
#endif

#include "libwebsockets.h"

#if defined(WIN32) || defined(_WIN32)

#ifndef BIG_ENDIAN
#define BIG_ENDIAN    4321  /* to show byte order (taken from gcc) */
#endif
#ifndef LITTLE_ENDIAN
#define LITTLE_ENDIAN 1234
#endif
#ifndef BYTE_ORDER
#define BYTE_ORDER LITTLE_ENDIAN
#endif
typedef unsigned __int64 u_int64_t;

#undef __P
#ifndef __P
#if __STDC__
#define __P(protos) protos
#else
#define __P(protos) ()
#endif
#endif

#else

#include <sys/stat.h>
#include <sys/time.h>

#if defined(__APPLE__)
#include <machine/endian.h>
#elif defined(__FreeBSD__)
#include <sys/endian.h>
#elif defined(__linux__)
#include <endian.h>
#endif

#if !defined(BYTE_ORDER)
# define BYTE_ORDER __BYTE_ORDER
#endif
#if !defined(LITTLE_ENDIAN)
# define LITTLE_ENDIAN __LITTLE_ENDIAN
#endif
#if !defined(BIG_ENDIAN)
# define BIG_ENDIAN __BIG_ENDIAN
#endif

#endif

/*
 * Mac OSX as well as iOS do not define the MSG_NOSIGNAL flag,
 * but happily have something equivalent in the SO_NOSIGPIPE flag.
 */
#ifdef __APPLE__
#define MSG_NOSIGNAL SO_NOSIGPIPE
#endif

#ifndef LWS_MAX_HEADER_LEN
#define LWS_MAX_HEADER_LEN 1024
#endif
#ifndef LWS_MAX_PROTOCOLS
#define LWS_MAX_PROTOCOLS 5
#endif
#ifndef LWS_MAX_EXTENSIONS_ACTIVE
#define LWS_MAX_EXTENSIONS_ACTIVE 3
#endif
#ifndef SPEC_LATEST_SUPPORTED
#define SPEC_LATEST_SUPPORTED 13
#endif
#ifndef AWAITING_TIMEOUT
#define AWAITING_TIMEOUT 5
#endif
#ifndef CIPHERS_LIST_STRING
#define CIPHERS_LIST_STRING "DEFAULT"
#endif
#ifndef LWS_SOMAXCONN
#define LWS_SOMAXCONN SOMAXCONN
#endif

#define MAX_WEBSOCKET_04_KEY_LEN 128
#define LWS_MAX_SOCKET_IO_BUF 4096

#ifndef SYSTEM_RANDOM_FILEPATH
#define SYSTEM_RANDOM_FILEPATH "/dev/urandom"
#endif
#ifndef LWS_MAX_ZLIB_CONN_BUFFER
#define LWS_MAX_ZLIB_CONN_BUFFER (64 * 1024)
#endif

/*
 * if not in a connection storm, check for incoming
 * connections this many normal connection services
 */
#define LWS_LISTEN_SERVICE_MODULO 10

enum lws_websocket_opcodes_07 {
	LWS_WS_OPCODE_07__CONTINUATION = 0,
	LWS_WS_OPCODE_07__TEXT_FRAME = 1,
	LWS_WS_OPCODE_07__BINARY_FRAME = 2,

	LWS_WS_OPCODE_07__NOSPEC__MUX = 7,

	/* control extensions 8+ */

	LWS_WS_OPCODE_07__CLOSE = 8,
	LWS_WS_OPCODE_07__PING = 9,
	LWS_WS_OPCODE_07__PONG = 0xa,
};


enum lws_connection_states {
	WSI_STATE_HTTP,
	WSI_STATE_HTTP_ISSUING_FILE,
	WSI_STATE_HTTP_HEADERS,
	WSI_STATE_HTTP_BODY,
	WSI_STATE_DEAD_SOCKET,
	WSI_STATE_ESTABLISHED,
	WSI_STATE_CLIENT_UNCONNECTED,
	WSI_STATE_RETURNED_CLOSE_ALREADY,
	WSI_STATE_AWAITING_CLOSE_ACK,
	WSI_STATE_FLUSHING_STORED_SEND_BEFORE_CLOSE,
};

enum lws_rx_parse_state {
	LWS_RXPS_NEW,

	LWS_RXPS_04_MASK_NONCE_1,
	LWS_RXPS_04_MASK_NONCE_2,
	LWS_RXPS_04_MASK_NONCE_3,

	LWS_RXPS_04_FRAME_HDR_1,
	LWS_RXPS_04_FRAME_HDR_LEN,
	LWS_RXPS_04_FRAME_HDR_LEN16_2,
	LWS_RXPS_04_FRAME_HDR_LEN16_1,
	LWS_RXPS_04_FRAME_HDR_LEN64_8,
	LWS_RXPS_04_FRAME_HDR_LEN64_7,
	LWS_RXPS_04_FRAME_HDR_LEN64_6,
	LWS_RXPS_04_FRAME_HDR_LEN64_5,
	LWS_RXPS_04_FRAME_HDR_LEN64_4,
	LWS_RXPS_04_FRAME_HDR_LEN64_3,
	LWS_RXPS_04_FRAME_HDR_LEN64_2,
	LWS_RXPS_04_FRAME_HDR_LEN64_1,

	LWS_RXPS_07_COLLECT_FRAME_KEY_1,
	LWS_RXPS_07_COLLECT_FRAME_KEY_2,
	LWS_RXPS_07_COLLECT_FRAME_KEY_3,
	LWS_RXPS_07_COLLECT_FRAME_KEY_4,

	LWS_RXPS_PAYLOAD_UNTIL_LENGTH_EXHAUSTED
};


enum connection_mode {
	LWS_CONNMODE_HTTP_SERVING,
	LWS_CONNMODE_HTTP_SERVING_ACCEPTED, /* actual HTTP service going on */
	LWS_CONNMODE_PRE_WS_SERVING_ACCEPT,

	LWS_CONNMODE_WS_SERVING,
	LWS_CONNMODE_WS_CLIENT,

	/* transient, ssl delay hiding */
	LWS_CONNMODE_SSL_ACK_PENDING,

	/* transient modes */
	LWS_CONNMODE_WS_CLIENT_WAITING_CONNECT,
	LWS_CONNMODE_WS_CLIENT_WAITING_PROXY_REPLY,
	LWS_CONNMODE_WS_CLIENT_ISSUE_HANDSHAKE,
	LWS_CONNMODE_WS_CLIENT_ISSUE_HANDSHAKE2,
	LWS_CONNMODE_WS_CLIENT_WAITING_SSL,
	LWS_CONNMODE_WS_CLIENT_WAITING_SERVER_REPLY,
	LWS_CONNMODE_WS_CLIENT_WAITING_EXTENSION_CONNECT,
	LWS_CONNMODE_WS_CLIENT_PENDING_CANDIDATE_CHILD,

	/* special internal types */
	LWS_CONNMODE_SERVER_LISTENER,
};

enum {
	LWS_RXFLOW_ALLOW = (1 << 0),
	LWS_RXFLOW_PENDING_CHANGE = (1 << 1),
};

struct libwebsocket_protocols;
struct libwebsocket;

#ifdef LWS_USE_LIBEV
struct lws_io_watcher {
	struct ev_io watcher;
	struct libwebsocket_context* context;
};

struct lws_signal_watcher {
	struct ev_signal watcher;
	struct libwebsocket_context* context;
};
#endif /* LWS_USE_LIBEV */

struct libwebsocket_context {
#ifdef _WIN32
	WSAEVENT *events;
#endif
	struct libwebsocket_pollfd *fds;
	struct libwebsocket **lws_lookup; /* fd to wsi */
	int fds_count;
#ifdef LWS_USE_LIBEV
	struct ev_loop* io_loop;
	struct lws_io_watcher w_accept;
	struct lws_signal_watcher w_sigint;
#endif /* LWS_USE_LIBEV */
	int max_fds;
	int listen_port;
	const char *iface;
	char http_proxy_address[128];
	char canonical_hostname[128];
	unsigned int http_proxy_port;
	unsigned int options;
	time_t last_timeout_check_s;

	/*
	 * usable by anything in the service code, but only if the scope
	 * does not last longer than the service action (since next service
	 * of any socket can likewise use it and overwrite)
	 */
	unsigned char service_buffer[LWS_MAX_SOCKET_IO_BUF];

	int started_with_parent;

	int fd_random;
	int listen_service_modulo;
	int listen_service_count;
	int listen_service_fd;
	int listen_service_extraseen;

	/*
	 * set to the Thread ID that's doing the service loop just before entry
	 * to poll indicates service thread likely idling in poll()
	 * volatile because other threads may check it as part of processing
	 * for pollfd event change.
	 */
	volatile int service_tid;
#ifndef _WIN32
	int dummy_pipe_fds[2];
#endif

	int ka_time;
	int ka_probes;
	int ka_interval;

#ifdef LWS_LATENCY
	unsigned long worst_latency;
	char worst_latency_info[256];
#endif

#ifdef LWS_OPENSSL_SUPPORT
	int use_ssl;
	int allow_non_ssl_on_ssl_port;
	SSL_CTX *ssl_ctx;
	SSL_CTX *ssl_client_ctx;
#endif
	struct libwebsocket_protocols *protocols;
	int count_protocols;
#ifndef LWS_NO_EXTENSIONS
	struct libwebsocket_extension *extensions;
#endif
	void *user_space;
};

enum {
	LWS_EV_READ = (1 << 0),
	LWS_EV_WRITE = (1 << 1),
	LWS_EV_START = (1 << 2),
	LWS_EV_STOP = (1 << 3),
};

#ifdef LWS_USE_LIBEV
#define LWS_LIBEV_ENABLED(context) (context->options & LWS_SERVER_OPTION_LIBEV)
LWS_EXTERN void lws_feature_status_libev(struct lws_context_creation_info *info);
LWS_EXTERN void
lws_libev_accept(struct libwebsocket_context *context,
		 struct libwebsocket *new_wsi, int accept_fd);
LWS_EXTERN void
lws_libev_io(struct libwebsocket_context *context,
				struct libwebsocket *wsi, int flags);
LWS_EXTERN int
lws_libev_init_fd_table(struct libwebsocket_context *context);
LWS_EXTERN void
lws_libev_run(struct libwebsocket_context *context);
#else
#define LWS_LIBEV_ENABLED(context) (0)
#define lws_feature_status_libev(_a) \
			lwsl_notice("libev support not compiled in\n")
#define lws_libev_accept(_a, _b, _c) (0)
#define lws_libev_io(_a, _b, _c) (0)
#define lws_libev_init_fd_table(_a) (0)
#define lws_libev_run(_a) (0)
#endif

#ifdef LWS_USE_IPV6
#define LWS_IPV6_ENABLED(context) (!(context->options & LWS_SERVER_OPTION_DISABLE_IPV6))
#else
#define LWS_IPV6_ENABLED(context) (0)
#endif

enum uri_path_states {
	URIPS_IDLE,
	URIPS_SEEN_SLASH,
	URIPS_SEEN_SLASH_DOT,
	URIPS_SEEN_SLASH_DOT_DOT,
	URIPS_ARGUMENTS,
};

enum uri_esc_states {
	URIES_IDLE,
	URIES_SEEN_PERCENT,
	URIES_SEEN_PERCENT_H1,
};

/*
 * This is totally opaque to code using the library.  It's exported as a
 * forward-reference pointer-only declaration; the user can use the pointer with
 * other APIs to get information out of it.
 */

struct lws_fragments {
	unsigned short offset;
	unsigned short len;
	unsigned char next_frag_index;
};

struct allocated_headers {
	unsigned short next_frag_index;
	unsigned short pos;
	unsigned char frag_index[WSI_TOKEN_COUNT];
	struct lws_fragments frags[WSI_TOKEN_COUNT * 2];
	char data[LWS_MAX_HEADER_LEN];
#ifndef LWS_NO_CLIENT
	char initial_handshake_hash_base64[30];
	unsigned short c_port;
#endif
};

struct _lws_http_mode_related {
	struct allocated_headers *ah; /* mirroring  _lws_header_related */
#if defined(WIN32) || defined(_WIN32)
	HANDLE fd;
#else
	int fd;
#endif
	unsigned long filepos;
	unsigned long filelen;

	int content_length;
	int content_length_seen;
	int body_index;
	unsigned char *post_buffer;
};

struct _lws_header_related {
	struct allocated_headers *ah;
	short lextable_pos;
	unsigned char parser_state; /* enum lws_token_indexes */
	enum uri_path_states ups;
	enum uri_esc_states ues;
	char esc_stash;
};

struct _lws_websocket_related {
	char *rx_user_buffer;
	int rx_user_buffer_head;
	unsigned char frame_masking_nonce_04[4];
	unsigned char frame_mask_index;
	size_t rx_packet_length;
	unsigned char opcode;
	unsigned int final:1;
	unsigned char rsv;
	unsigned int frame_is_binary:1;
	unsigned int all_zero_nonce:1;
	short close_reason; /* enum lws_close_status */
	unsigned char *rxflow_buffer;
	int rxflow_len;
	int rxflow_pos;
	unsigned int rxflow_change_to:2;
	unsigned int this_frame_masked:1;
	unsigned int inside_frame:1; /* next write will be more of frame */
	unsigned int clean_buffer:1; /* buffer not rewritten by extension */
};

struct libwebsocket {

	/* lifetime members */

#ifdef LWS_USE_LIBEV
    struct lws_io_watcher w_read;
    struct lws_io_watcher w_write;
#endif /* LWS_USE_LIBEV */
	const struct libwebsocket_protocols *protocol;
#ifndef LWS_NO_EXTENSIONS
	struct libwebsocket_extension *
				   active_extensions[LWS_MAX_EXTENSIONS_ACTIVE];
	void *active_extensions_user[LWS_MAX_EXTENSIONS_ACTIVE];
	unsigned char count_active_extensions;
	unsigned int extension_data_pending:1;
#endif
	unsigned char ietf_spec_revision;

	char mode; /* enum connection_mode */
	char state; /* enum lws_connection_states */
	char lws_rx_parse_state; /* enum lws_rx_parse_state */
	char rx_frame_type; /* enum libwebsocket_write_protocol */

	unsigned int hdr_parsing_completed:1;

	char pending_timeout; /* enum pending_timeout */
	time_t pending_timeout_limit;

	int sock;
	int position_in_fds_table;
#ifdef LWS_LATENCY
	unsigned long action_start;
	unsigned long latency_start;
#endif

	/* truncated send handling */
	unsigned char *truncated_send_malloc; /* non-NULL means buffering in progress */
	unsigned int truncated_send_allocation; /* size of malloc */
	unsigned int truncated_send_offset; /* where we are in terms of spilling */
	unsigned int truncated_send_len; /* how much is buffered */

	void *user_space;

	/* members with mutually exclusive lifetimes are unionized */

	union u {
		struct _lws_http_mode_related http;
		struct _lws_header_related hdr;
		struct _lws_websocket_related ws;
	} u;

#ifdef LWS_OPENSSL_SUPPORT
	SSL *ssl;
	BIO *client_bio;
	unsigned int use_ssl:2;
#endif

#ifdef _WIN32
	BOOL sock_send_blocking;
#endif
};

LWS_EXTERN int log_level;

LWS_EXTERN void
libwebsocket_close_and_free_session(struct libwebsocket_context *context,
			       struct libwebsocket *wsi, enum lws_close_status);

LWS_EXTERN int
remove_wsi_socket_from_fds(struct libwebsocket_context *context,
						      struct libwebsocket *wsi);

#ifndef LWS_LATENCY
static inline void lws_latency(struct libwebsocket_context *context,
		struct libwebsocket *wsi, const char *action,
					 int ret, int completion) { while (0); }
static inline void lws_latency_pre(struct libwebsocket_context *context,
					struct libwebsocket *wsi) { while (0); }
#else
#define lws_latency_pre(_context, _wsi) lws_latency(_context, _wsi, NULL, 0, 0)
extern void
lws_latency(struct libwebsocket_context *context,
			struct libwebsocket *wsi, const char *action,
						       int ret, int completion);
#endif

LWS_EXTERN int
libwebsocket_client_rx_sm(struct libwebsocket *wsi, unsigned char c);

LWS_EXTERN int
libwebsocket_parse(struct libwebsocket *wsi, unsigned char c);

LWS_EXTERN int
lws_b64_selftest(void);

LWS_EXTERN struct libwebsocket *
wsi_from_fd(struct libwebsocket_context *context, int fd);

LWS_EXTERN int
insert_wsi_socket_into_fds(struct libwebsocket_context *context,
						      struct libwebsocket *wsi);

LWS_EXTERN int
lws_issue_raw(struct libwebsocket *wsi, unsigned char *buf, size_t len);


LWS_EXTERN int
libwebsocket_service_timeout_check(struct libwebsocket_context *context,
				    struct libwebsocket *wsi, unsigned int sec);

LWS_EXTERN struct libwebsocket *
libwebsocket_client_connect_2(struct libwebsocket_context *context,
	struct libwebsocket *wsi);

LWS_EXTERN struct libwebsocket *
libwebsocket_create_new_server_wsi(struct libwebsocket_context *context);

LWS_EXTERN char *
libwebsockets_generate_client_handshake(struct libwebsocket_context *context,
		struct libwebsocket *wsi, char *pkt);

LWS_EXTERN int
lws_handle_POLLOUT_event(struct libwebsocket_context *context,
			      struct libwebsocket *wsi, struct libwebsocket_pollfd *pollfd);
/*
 * EXTENSIONS
 */

#ifndef LWS_NO_EXTENSIONS
LWS_VISIBLE void
lws_context_init_extensions(struct lws_context_creation_info *info,
				    struct libwebsocket_context *context);
LWS_EXTERN int
lws_any_extension_handled(struct libwebsocket_context *context,
			  struct libwebsocket *wsi,
			  enum libwebsocket_extension_callback_reasons r,
			  void *v, size_t len);

LWS_EXTERN int
lws_ext_callback_for_each_active(struct libwebsocket *wsi, int reason,
						    void *buf, int len);
LWS_EXTERN int
lws_ext_callback_for_each_extension_type(
		struct libwebsocket_context *context, struct libwebsocket *wsi,
			int reason, void *arg, int len);
#else
#define lws_any_extension_handled(_a, _b, _c, _d, _e) (0)
#define lws_ext_callback_for_each_active(_a, _b, _c, _d) (0)
#define lws_ext_callback_for_each_extension_type(_a, _b, _c, _d, _e) (0)
#define lws_issue_raw_ext_access lws_issue_raw
#define lws_context_init_extensions(_a, _b)
#endif

LWS_EXTERN int
lws_client_interpret_server_handshake(struct libwebsocket_context *context,
		struct libwebsocket *wsi);

LWS_EXTERN int
libwebsocket_rx_sm(struct libwebsocket *wsi, unsigned char c);

LWS_EXTERN int
lws_issue_raw_ext_access(struct libwebsocket *wsi,
						unsigned char *buf, size_t len);

LWS_EXTERN int
_libwebsocket_rx_flow_control(struct libwebsocket *wsi);

LWS_EXTERN int
user_callback_handle_rxflow(callback_function,
		struct libwebsocket_context *context,
			struct libwebsocket *wsi,
			 enum libwebsocket_callback_reasons reason, void *user,
							  void *in, size_t len);

LWS_EXTERN int
lws_plat_set_socket_options(struct libwebsocket_context *context, int fd);

LWS_EXTERN int
lws_allocate_header_table(struct libwebsocket *wsi);

LWS_EXTERN char *
lws_hdr_simple_ptr(struct libwebsocket *wsi, enum lws_token_indexes h);

LWS_EXTERN int
lws_hdr_simple_create(struct libwebsocket *wsi,
				enum lws_token_indexes h, const char *s);

LWS_EXTERN int
libwebsocket_ensure_user_space(struct libwebsocket *wsi);

LWS_EXTERN int
lws_change_pollfd(struct libwebsocket *wsi, int _and, int _or);

#ifndef LWS_NO_SERVER
int lws_context_init_server(struct lws_context_creation_info *info,
			    struct libwebsocket_context *context);
LWS_EXTERN int handshake_0405(struct libwebsocket_context *context,
						      struct libwebsocket *wsi);
LWS_EXTERN int
libwebsocket_interpret_incoming_packet(struct libwebsocket *wsi,
						unsigned char *buf, size_t len);
LWS_EXTERN void
lws_server_get_canonical_hostname(struct libwebsocket_context *context,
				struct lws_context_creation_info *info);
#else
#define lws_context_init_server(_a, _b) (0)
#define libwebsocket_interpret_incoming_packet(_a, _b, _c) (0)
#define lws_server_get_canonical_hostname(_a, _b)
#endif

#ifndef LWS_NO_DAEMONIZE
LWS_EXTERN int get_daemonize_pid();
#else
#define get_daemonize_pid() (0)
#endif

LWS_EXTERN int interface_to_sa(struct libwebsocket_context *context,
		const char *ifname, struct sockaddr_in *addr, size_t addrlen);

LWS_EXTERN void lwsl_emit_stderr(int level, const char *line);

#ifdef _WIN32
LWS_EXTERN HANDLE lws_plat_open_file(const char* filename, unsigned long* filelen);
#else
LWS_EXTERN int lws_plat_open_file(const char* filename, unsigned long* filelen);
#endif

enum lws_ssl_capable_status {
	LWS_SSL_CAPABLE_ERROR = -1,
	LWS_SSL_CAPABLE_MORE_SERVICE = -2,
};

#ifndef LWS_OPENSSL_SUPPORT
#define LWS_SSL_ENABLED(context) (0)
unsigned char *
SHA1(const unsigned char *d, size_t n, unsigned char *md);
#define lws_context_init_server_ssl(_a, _b) (0)
#define lws_ssl_destroy(_a)
#define lws_context_init_http2_ssl(_a)
#define lws_ssl_pending(_a) (0)
#define lws_ssl_capable_read lws_ssl_capable_read_no_ssl
#define lws_ssl_capable_write lws_ssl_capable_write_no_ssl
#define lws_server_socket_service_ssl(_a, _b, _c, _d, _e) (0)
#define lws_ssl_close(_a) (0)
#define lws_ssl_context_destroy(_a)
#else
#define LWS_SSL_ENABLED(context) (context->use_ssl)
LWS_EXTERN int lws_ssl_pending(struct libwebsocket *wsi);
LWS_EXTERN int openssl_websocket_private_data_index;
LWS_EXTERN int
lws_ssl_capable_read(struct libwebsocket *wsi, unsigned char *buf, int len);

LWS_EXTERN int
lws_ssl_capable_write(struct libwebsocket *wsi, unsigned char *buf, int len);
LWS_EXTERN int
lws_server_socket_service_ssl(struct libwebsocket_context *context,
		struct libwebsocket **wsi, struct libwebsocket *new_wsi,
		int accept_fd, struct libwebsocket_pollfd *pollfd);
LWS_EXTERN int
lws_ssl_close(struct libwebsocket *wsi);
LWS_EXTERN void
lws_ssl_context_destroy(struct libwebsocket_context *context);
#ifndef LWS_NO_SERVER
LWS_EXTERN int
lws_context_init_server_ssl(struct lws_context_creation_info *info,
		     struct libwebsocket_context *context);
#else
#define lws_context_init_server_ssl(_a, _b) (0)
#endif
LWS_EXTERN void
lws_ssl_destroy(struct libwebsocket_context *context);

/* HTTP2-related */

#ifdef LWS_USE_HTTP2
LWS_EXTERN void
lws_context_init_http2_ssl(struct libwebsocket_context *context);
#else
#define lws_context_init_http2_ssl(_a)
#endif
#endif

LWS_EXTERN int
lws_ssl_capable_read_no_ssl(struct libwebsocket *wsi, unsigned char *buf, int len);

LWS_EXTERN int
lws_ssl_capable_write_no_ssl(struct libwebsocket *wsi, unsigned char *buf, int len);

#ifndef LWS_NO_CLIENT
	LWS_EXTERN int lws_client_socket_service(
		struct libwebsocket_context *context,
		struct libwebsocket *wsi, struct libwebsocket_pollfd *pollfd);
#ifdef LWS_OPENSSL_SUPPORT
	LWS_EXTERN int lws_context_init_client_ssl(struct lws_context_creation_info *info,
			    struct libwebsocket_context *context);
#else
	#define lws_context_init_client_ssl(_a, _b) (0)
#endif
	LWS_EXTERN int lws_handshake_client(struct libwebsocket *wsi, unsigned char **buf, size_t len);
	LWS_EXTERN void
	libwebsockets_decode_ssl_error(void);
#else
#define lws_context_init_client_ssl(_a, _b) (0)
#define lws_handshake_client(_a, _b, _c) (0)
#endif
#ifndef LWS_NO_SERVER
	LWS_EXTERN int lws_server_socket_service(
		struct libwebsocket_context *context,
		struct libwebsocket *wsi, struct libwebsocket_pollfd *pollfd);
	LWS_EXTERN int _libwebsocket_rx_flow_control(struct libwebsocket *wsi);
	LWS_EXTERN int lws_handshake_server(struct libwebsocket_context *context,
		     struct libwebsocket *wsi, unsigned char **buf, size_t len);
#else
#define lws_server_socket_service(_a, _b, _c) (0)
#define _libwebsocket_rx_flow_control(_a) (0)
#define lws_handshake_server(_a, _b, _c, _d) (0)
#endif

/*
 * lws_plat_
 */
LWS_EXTERN void
lws_plat_delete_socket_from_fds(struct libwebsocket_context *context,
					       struct libwebsocket *wsi, int m);
LWS_EXTERN void
lws_plat_insert_socket_into_fds(struct libwebsocket_context *context,
						      struct libwebsocket *wsi);
LWS_EXTERN void
lws_plat_service_periodic(struct libwebsocket_context *context);

LWS_EXTERN int
lws_plat_change_pollfd(struct libwebsocket_context *context,
		     struct libwebsocket *wsi, struct libwebsocket_pollfd *pfd);
LWS_EXTERN int
lws_plat_context_early_init(void);
LWS_EXTERN void
lws_plat_context_early_destroy(struct libwebsocket_context *context);
LWS_EXTERN void
lws_plat_context_late_destroy(struct libwebsocket_context *context);
LWS_EXTERN int
lws_poll_listen_fd(struct libwebsocket_pollfd *fd);
LWS_EXTERN int
lws_plat_service(struct libwebsocket_context *context, int timeout_ms);
LWS_EXTERN int
lws_plat_init_fd_tables(struct libwebsocket_context *context);
LWS_EXTERN void
lws_plat_drop_app_privileges(struct lws_context_creation_info *info);
LWS_EXTERN unsigned long long
time_in_microseconds(void);
LWS_EXTERN const char *
lws_plat_inet_ntop(int af, const void *src, char *dst, int cnt);
