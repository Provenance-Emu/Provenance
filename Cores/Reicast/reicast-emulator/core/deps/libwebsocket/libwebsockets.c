/*
 * libwebsockets - small server side websockets and web server implementation
 *
 * Copyright (C) 2010-2014 Andy Green <andy@warmcat.com>
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


#include "private-libwebsockets.h"

#if HOST_OS == OS_WINDOWS
	#pragma comment(lib, "Ws2_32.lib")
#endif

int log_level = LLL_ERR | LLL_WARN | LLL_NOTICE;
static void (*lwsl_emit)(int level, const char *line) = lwsl_emit_stderr;

static const char * const log_level_names[] = {
	"ERR",
	"WARN",
	"NOTICE",
	"INFO",
	"DEBUG",
	"PARSER",
	"HEADER",
	"EXTENSION",
	"CLIENT",
	"LATENCY",
};


void
libwebsocket_close_and_free_session(struct libwebsocket_context *context,
			 struct libwebsocket *wsi, enum lws_close_status reason)
{
	int n, m, ret;
	int old_state;
	unsigned char buf[LWS_SEND_BUFFER_PRE_PADDING + 2 +
						  LWS_SEND_BUFFER_POST_PADDING];
	struct lws_tokens eff_buf;

	if (!wsi)
		return;

	old_state = wsi->state;

	switch (old_state) {
	case WSI_STATE_DEAD_SOCKET:
		return;

	/* we tried the polite way... */
	case WSI_STATE_AWAITING_CLOSE_ACK:
		goto just_kill_connection;

	case WSI_STATE_FLUSHING_STORED_SEND_BEFORE_CLOSE:
		if (wsi->truncated_send_len) {
			libwebsocket_callback_on_writable(context, wsi);
			return;
		}
		lwsl_info("wsi %p completed WSI_STATE_FLUSHING_STORED_SEND_BEFORE_CLOSE\n", wsi);
		goto just_kill_connection;
	default:
		if (wsi->truncated_send_len) {
			lwsl_info("wsi %p entering WSI_STATE_FLUSHING_STORED_SEND_BEFORE_CLOSE\n", wsi);
			wsi->state = WSI_STATE_FLUSHING_STORED_SEND_BEFORE_CLOSE;
			return;
		}
		break;
	}

	wsi->u.ws.close_reason = reason;

	if (wsi->mode == LWS_CONNMODE_WS_CLIENT_WAITING_CONNECT ||
			wsi->mode == LWS_CONNMODE_WS_CLIENT_ISSUE_HANDSHAKE) {

		context->protocols[0].callback(context, wsi,
			LWS_CALLBACK_CLIENT_CONNECTION_ERROR, NULL, NULL, 0);

		free(wsi->u.hdr.ah);
		goto just_kill_connection;
	}

	if (wsi->mode == LWS_CONNMODE_HTTP_SERVING_ACCEPTED) {
		if (wsi->u.http.post_buffer) {
			free(wsi->u.http.post_buffer);
			wsi->u.http.post_buffer = NULL;
		}
		if (wsi->u.http.fd != LWS_INVALID_FILE) {
			lwsl_debug("closing http file\n");
			compatible_file_close(wsi->u.http.fd);
			wsi->u.http.fd = LWS_INVALID_FILE;
			context->protocols[0].callback(context, wsi,
				LWS_CALLBACK_CLOSED_HTTP, wsi->user_space, NULL, 0);
		}
	}

	/*
	 * are his extensions okay with him closing?  Eg he might be a mux
	 * parent and just his ch1 aspect is closing?
	 */
	
	if (lws_ext_callback_for_each_active(wsi,
		      LWS_EXT_CALLBACK_CHECK_OK_TO_REALLY_CLOSE, NULL, 0) > 0) {
		lwsl_ext("extension vetoed close\n");
		return;
	}

	/*
	 * flush any tx pending from extensions, since we may send close packet
	 * if there are problems with send, just nuke the connection
	 */

	do {
		ret = 0;
		eff_buf.token = NULL;
		eff_buf.token_len = 0;

		/* show every extension the new incoming data */

		m = lws_ext_callback_for_each_active(wsi,
			  LWS_EXT_CALLBACK_FLUSH_PENDING_TX, &eff_buf, 0);
		if (m < 0) {
			lwsl_ext("Extension reports fatal error\n");
			goto just_kill_connection;
		}
		if (m)
			/*
			 * at least one extension told us he has more
			 * to spill, so we will go around again after
			 */
			ret = 1;

		/* assuming they left us something to send, send it */

		if (eff_buf.token_len)
			if (lws_issue_raw(wsi, (unsigned char *)eff_buf.token,
				      eff_buf.token_len) != eff_buf.token_len) {
				lwsl_debug("close: ext spill failed\n");
				goto just_kill_connection;
			}
	} while (ret);

	/*
	 * signal we are closing, libsocket_write will
	 * add any necessary version-specific stuff.  If the write fails,
	 * no worries we are closing anyway.  If we didn't initiate this
	 * close, then our state has been changed to
	 * WSI_STATE_RETURNED_CLOSE_ALREADY and we will skip this.
	 *
	 * Likewise if it's a second call to close this connection after we
	 * sent the close indication to the peer already, we are in state
	 * WSI_STATE_AWAITING_CLOSE_ACK and will skip doing this a second time.
	 */

	if (old_state == WSI_STATE_ESTABLISHED &&
					  reason != LWS_CLOSE_STATUS_NOSTATUS) {

		lwsl_debug("sending close indication...\n");

		/* make valgrind happy */
		memset(buf, 0, sizeof(buf));
		n = libwebsocket_write(wsi,
				&buf[LWS_SEND_BUFFER_PRE_PADDING + 2],
							    0, LWS_WRITE_CLOSE);
		if (n >= 0) {
			/*
			 * we have sent a nice protocol level indication we
			 * now wish to close, we should not send anything more
			 */

			wsi->state = WSI_STATE_AWAITING_CLOSE_ACK;

			/*
			 * ...and we should wait for a reply for a bit
			 * out of politeness
			 */

			libwebsocket_set_timeout(wsi,
						  PENDING_TIMEOUT_CLOSE_ACK, 1);

			lwsl_debug("sent close indication, awaiting ack\n");

			return;
		}

		lwsl_info("close: sending close packet failed, hanging up\n");

		/* else, the send failed and we should just hang up */
	}

just_kill_connection:

	lwsl_debug("close: just_kill_connection\n");

	/*
	 * we won't be servicing or receiving anything further from this guy
	 * delete socket from the internal poll list if still present
	 */

	remove_wsi_socket_from_fds(context, wsi);

	wsi->state = WSI_STATE_DEAD_SOCKET;

	if ((old_state == WSI_STATE_ESTABLISHED ||
	     wsi->mode == LWS_CONNMODE_WS_SERVING ||
	     wsi->mode == LWS_CONNMODE_WS_CLIENT)) {

		if (wsi->u.ws.rx_user_buffer) {
			free(wsi->u.ws.rx_user_buffer);
			wsi->u.ws.rx_user_buffer = NULL;
		}
		if (wsi->u.ws.rxflow_buffer) {
			free(wsi->u.ws.rxflow_buffer);
			wsi->u.ws.rxflow_buffer = NULL;
		}
		if (wsi->truncated_send_malloc) {
			/* not going to be completed... nuke it */
			free(wsi->truncated_send_malloc);
			wsi->truncated_send_malloc = NULL;
			wsi->truncated_send_len = 0;
		}
	}

	/* tell the user it's all over for this guy */

	if (wsi->protocol && wsi->protocol->callback &&
			((old_state == WSI_STATE_ESTABLISHED) ||
			 (old_state == WSI_STATE_RETURNED_CLOSE_ALREADY) ||
			 (old_state == WSI_STATE_AWAITING_CLOSE_ACK))) {
		lwsl_debug("calling back CLOSED\n");
		wsi->protocol->callback(context, wsi, LWS_CALLBACK_CLOSED,
						      wsi->user_space, NULL, 0);
	} else if (wsi->mode == LWS_CONNMODE_HTTP_SERVING_ACCEPTED) {
		lwsl_debug("calling back CLOSED_HTTP\n");
		context->protocols[0].callback(context, wsi,
			LWS_CALLBACK_CLOSED_HTTP, wsi->user_space, NULL, 0 );
	} else
		lwsl_debug("not calling back closed\n");

	/* deallocate any active extension contexts */
	
	if (lws_ext_callback_for_each_active(wsi, LWS_EXT_CALLBACK_DESTROY, NULL, 0) < 0)
		lwsl_warn("extension destruction failed\n");
#ifndef LWS_NO_EXTENSIONS
	for (n = 0; n < wsi->count_active_extensions; n++)
		free(wsi->active_extensions_user[n]);
#endif
	/*
	 * inform all extensions in case they tracked this guy out of band
	 * even though not active on him specifically
	 */
	if (lws_ext_callback_for_each_extension_type(context, wsi,
		       LWS_EXT_CALLBACK_DESTROY_ANY_WSI_CLOSING, NULL, 0) < 0)
		lwsl_warn("ext destroy wsi failed\n");

/*	lwsl_info("closing fd=%d\n", wsi->sock); */

	if (!lws_ssl_close(wsi) && wsi->sock >= 0) {
		n = shutdown(wsi->sock, SHUT_RDWR);
		if (n)
			lwsl_debug("closing: shutdown ret %d\n", LWS_ERRNO);

		n = compatible_close(wsi->sock);
		if (n)
			lwsl_debug("closing: close ret %d\n", LWS_ERRNO);
	}

	/* outermost destroy notification for wsi (user_space still intact) */
	context->protocols[0].callback(context, wsi,
			LWS_CALLBACK_WSI_DESTROY, wsi->user_space, NULL, 0);

	if (wsi->protocol && wsi->protocol->per_session_data_size &&
					wsi->user_space) /* user code may own */
		free(wsi->user_space);

	free(wsi);
}

/**
 * libwebsockets_get_peer_addresses() - Get client address information
 * @context:	Libwebsockets context
 * @wsi:	Local struct libwebsocket associated with
 * @fd:		Connection socket descriptor
 * @name:	Buffer to take client address name
 * @name_len:	Length of client address name buffer
 * @rip:	Buffer to take client address IP qotted quad
 * @rip_len:	Length of client address IP buffer
 *
 *	This function fills in @name and @rip with the name and IP of
 *	the client connected with socket descriptor @fd.  Names may be
 *	truncated if there is not enough room.  If either cannot be
 *	determined, they will be returned as valid zero-length strings.
 */

LWS_VISIBLE void
libwebsockets_get_peer_addresses(struct libwebsocket_context *context,
	struct libwebsocket *wsi, int fd, char *name, int name_len,
					char *rip, int rip_len)
{
	socklen_t len;
#ifdef LWS_USE_IPV6
	struct sockaddr_in6 sin6;
#endif
	struct sockaddr_in sin4;
	struct hostent *host;
	struct hostent *host1;
	char ip[128];
	unsigned char *p;
	int n;
#ifdef AF_LOCAL
	struct sockaddr_un *un;
#endif
	int ret = -1;

	rip[0] = '\0';
	name[0] = '\0';

	lws_latency_pre(context, wsi);

#ifdef LWS_USE_IPV6
	if (LWS_IPV6_ENABLED(context)) {

		len = sizeof(sin6);
		if (getpeername(fd, (struct sockaddr *) &sin6, &len) < 0) {
			lwsl_warn("getpeername: %s\n", strerror(LWS_ERRNO));
			goto bail;
		}

		if (!lws_plat_inet_ntop(AF_INET6, &sin6.sin6_addr, rip, rip_len)) {
			lwsl_err("inet_ntop", strerror(LWS_ERRNO));
			goto bail;
		}

		// Strip off the IPv4 to IPv6 header if one exists
		if (strncmp(rip, "::ffff:", 7) == 0)
			memmove(rip, rip + 7, strlen(rip) - 6);

		getnameinfo((struct sockaddr *)&sin6,
				sizeof(struct sockaddr_in6), name,
							name_len, NULL, 0, 0);

	} else
#endif
	{
		len = sizeof(sin4);
		if (getpeername(fd, (struct sockaddr *) &sin4, &len) < 0) {
			lwsl_warn("getpeername: %s\n", strerror(LWS_ERRNO));
			goto bail;
		}
		host = gethostbyaddr((char *) &sin4.sin_addr,
						sizeof(sin4.sin_addr), AF_INET);
		if (host == NULL) {
			lwsl_warn("gethostbyaddr: %s\n", strerror(LWS_ERRNO));
			goto bail;
		}

		strncpy(name, host->h_name, name_len);
		name[name_len - 1] = '\0';

		host1 = gethostbyname(host->h_name);
		if (host1 == NULL)
			goto bail;
		p = (unsigned char *)host1;
		n = 0;
		while (p != NULL) {
			p = (unsigned char *)host1->h_addr_list[n++];
			if (p == NULL)
				continue;
			if ((host1->h_addrtype != AF_INET)
#ifdef AF_LOCAL
				&& (host1->h_addrtype != AF_LOCAL)
#endif
				)
				continue;

			if (host1->h_addrtype == AF_INET)
				sprintf(ip, "%u.%u.%u.%u",
						p[0], p[1], p[2], p[3]);
#ifdef AF_LOCAL
			else {
				un = (struct sockaddr_un *)p;
				strncpy(ip, un->sun_path, sizeof(ip) - 1);
				ip[sizeof(ip) - 1] = '\0';
			}
#endif
			p = NULL;
			strncpy(rip, ip, rip_len);
			rip[rip_len - 1] = '\0';
		}
	}

	ret = 0;
bail:
	lws_latency(context, wsi, "libwebsockets_get_peer_addresses", ret, 1);
}



/**
 * libwebsocket_context_user() - get the user data associated with the context
 * @context: Websocket context
 *
 *	This returns the optional user allocation that can be attached to
 *	the context the sockets live in at context_create time.  It's a way
 *	to let all sockets serviced in the same context share data without
 *	using globals statics in the user code.
 */
LWS_EXTERN void *
libwebsocket_context_user(struct libwebsocket_context *context)
{
	return context->user_space;
}


/**
 * libwebsocket_callback_all_protocol() - Callback all connections using
 *				the given protocol with the given reason
 *
 * @protocol:	Protocol whose connections will get callbacks
 * @reason:	Callback reason index
 */

LWS_VISIBLE int
libwebsocket_callback_all_protocol(
		const struct libwebsocket_protocols *protocol, int reason)
{
	struct libwebsocket_context *context = protocol->owning_server;
	int n;
	struct libwebsocket *wsi;

	for (n = 0; n < context->fds_count; n++) {
		wsi = context->lws_lookup[context->fds[n].fd];
		if (!wsi)
			continue;
		if (wsi->protocol == protocol)
			protocol->callback(context, wsi,
					reason, wsi->user_space, NULL, 0);
	}

	return 0;
}

/**
 * libwebsocket_set_timeout() - marks the wsi as subject to a timeout
 *
 * You will not need this unless you are doing something special
 *
 * @wsi:	Websocket connection instance
 * @reason:	timeout reason
 * @secs:	how many seconds
 */

LWS_VISIBLE void
libwebsocket_set_timeout(struct libwebsocket *wsi,
					  enum pending_timeout reason, int secs)
{
	time_t now;

	time(&now);

	wsi->pending_timeout_limit = now + secs;
	wsi->pending_timeout = reason;
}


/**
 * libwebsocket_get_socket_fd() - returns the socket file descriptor
 *
 * You will not need this unless you are doing something special
 *
 * @wsi:	Websocket connection instance
 */

LWS_VISIBLE int
libwebsocket_get_socket_fd(struct libwebsocket *wsi)
{
	return wsi->sock;
}

#ifdef LWS_LATENCY
void
lws_latency(struct libwebsocket_context *context, struct libwebsocket *wsi,
				     const char *action, int ret, int completed)
{
	unsigned long long u;
	char buf[256];

	u = time_in_microseconds();

	if (!action) {
		wsi->latency_start = u;
		if (!wsi->action_start)
			wsi->action_start = u;
		return;
	}
	if (completed) {
		if (wsi->action_start == wsi->latency_start)
			sprintf(buf,
			  "Completion first try lat %luus: %p: ret %d: %s\n",
					u - wsi->latency_start,
						      (void *)wsi, ret, action);
		else
			sprintf(buf,
			  "Completion %luus: lat %luus: %p: ret %d: %s\n",
				u - wsi->action_start,
					u - wsi->latency_start,
						      (void *)wsi, ret, action);
		wsi->action_start = 0;
	} else
		sprintf(buf, "lat %luus: %p: ret %d: %s\n",
			      u - wsi->latency_start, (void *)wsi, ret, action);

	if (u - wsi->latency_start > context->worst_latency) {
		context->worst_latency = u - wsi->latency_start;
		strcpy(context->worst_latency_info, buf);
	}
	lwsl_latency("%s", buf);
}
#endif



/**
 * libwebsocket_rx_flow_control() - Enable and disable socket servicing for
 *				receieved packets.
 *
 * If the output side of a server process becomes choked, this allows flow
 * control for the input side.
 *
 * @wsi:	Websocket connection instance to get callback for
 * @enable:	0 = disable read servicing for this connection, 1 = enable
 */

LWS_VISIBLE int
libwebsocket_rx_flow_control(struct libwebsocket *wsi, int enable)
{
	if (enable == (wsi->u.ws.rxflow_change_to & LWS_RXFLOW_ALLOW))
		return 0;

	lwsl_info("libwebsocket_rx_flow_control(0x%p, %d)\n", wsi, enable);
	wsi->u.ws.rxflow_change_to = LWS_RXFLOW_PENDING_CHANGE | !!enable;

	return 0;
}

/**
 * libwebsocket_rx_flow_allow_all_protocol() - Allow all connections with this protocol to receive
 *
 * When the user server code realizes it can accept more input, it can
 * call this to have the RX flow restriction removed from all connections using
 * the given protocol.
 *
 * @protocol:	all connections using this protocol will be allowed to receive
 */

LWS_VISIBLE void
libwebsocket_rx_flow_allow_all_protocol(
				const struct libwebsocket_protocols *protocol)
{
	struct libwebsocket_context *context = protocol->owning_server;
	int n;
	struct libwebsocket *wsi;

	for (n = 0; n < context->fds_count; n++) {
		wsi = context->lws_lookup[context->fds[n].fd];
		if (!wsi)
			continue;
		if (wsi->protocol == protocol)
			libwebsocket_rx_flow_control(wsi, LWS_RXFLOW_ALLOW);
	}
}


/**
 * libwebsocket_canonical_hostname() - returns this host's hostname
 *
 * This is typically used by client code to fill in the host parameter
 * when making a client connection.  You can only call it after the context
 * has been created.
 *
 * @context:	Websocket context
 */
LWS_VISIBLE extern const char *
libwebsocket_canonical_hostname(struct libwebsocket_context *context)
{
	return (const char *)context->canonical_hostname;
}

int user_callback_handle_rxflow(callback_function callback_function,
		struct libwebsocket_context *context,
			struct libwebsocket *wsi,
			 enum libwebsocket_callback_reasons reason, void *user,
							  void *in, size_t len)
{
	int n;

	n = callback_function(context, wsi, reason, user, in, len);
	if (!n)
		n = _libwebsocket_rx_flow_control(wsi);

	return n;
}


/**
 * libwebsocket_set_proxy() - Setups proxy to libwebsocket_context.
 * @context:	pointer to struct libwebsocket_context you want set proxy to
 * @proxy: pointer to c string containing proxy in format address:port
 *
 * Returns 0 if proxy string was parsed and proxy was setup. 
 * Returns -1 if @proxy is NULL or has incorrect format.
 *
 * This is only required if your OS does not provide the http_proxy
 * enviroment variable (eg, OSX)
 *
 *   IMPORTANT! You should call this function right after creation of the
 *   libwebsocket_context and before call to connect. If you call this
 *   function after connect behavior is undefined.
 *   This function will override proxy settings made on libwebsocket_context
 *   creation with genenv() call.
 */

LWS_VISIBLE int
libwebsocket_set_proxy(struct libwebsocket_context *context, const char *proxy)
{
	char *p;
	
	if (!proxy)
		return -1;

	strncpy(context->http_proxy_address, proxy,
				sizeof(context->http_proxy_address) - 1);
	context->http_proxy_address[
				sizeof(context->http_proxy_address) - 1] = '\0';
	
	p = strchr(context->http_proxy_address, ':');
	if (!p) {
		lwsl_err("http_proxy needs to be ads:port\n");

		return -1;
	}
	*p = '\0';
	context->http_proxy_port = atoi(p + 1);
	
	lwsl_notice(" Proxy %s:%u\n", context->http_proxy_address,
						context->http_proxy_port);

	return 0;
}

/**
 * libwebsockets_get_protocol() - Returns a protocol pointer from a websocket
 *				  connection.
 * @wsi:	pointer to struct websocket you want to know the protocol of
 *
 *
 *	Some apis can act on all live connections of a given protocol,
 *	this is how you can get a pointer to the active protocol if needed.
 */

LWS_VISIBLE const struct libwebsocket_protocols *
libwebsockets_get_protocol(struct libwebsocket *wsi)
{
	return wsi->protocol;
}

LWS_VISIBLE int
libwebsocket_is_final_fragment(struct libwebsocket *wsi)
{
	return wsi->u.ws.final;
}

LWS_VISIBLE unsigned char
libwebsocket_get_reserved_bits(struct libwebsocket *wsi)
{
	return wsi->u.ws.rsv;
}

int
libwebsocket_ensure_user_space(struct libwebsocket *wsi)
{
	if (!wsi->protocol)
		return 1;

	/* allocate the per-connection user memory (if any) */

	if (wsi->protocol->per_session_data_size && !wsi->user_space) {
		wsi->user_space = malloc(
				  wsi->protocol->per_session_data_size);
		if (wsi->user_space  == NULL) {
			lwsl_err("Out of memory for conn user space\n");
			return 1;
		}
		memset(wsi->user_space, 0,
					 wsi->protocol->per_session_data_size);
	}
	return 0;
}

LWS_VISIBLE void lwsl_emit_stderr(int level, const char *line)
{
	char buf[300];
	unsigned long long now;
	int n;

	buf[0] = '\0';
	for (n = 0; n < LLL_COUNT; n++)
		if (level == (1 << n)) {
			now = time_in_microseconds() / 100;
			sprintf(buf, "[%lu:%04d] %s: ", (unsigned long) now / 10000,
				(int)(now % 10000), log_level_names[n]);
			break;
		}

	fprintf(stderr, "%s%s", buf, line);
}


LWS_VISIBLE void _lws_log(int filter, const char *format, ...)
{
	char buf[256];
	va_list ap;

	if (!(log_level & filter))
		return;

	va_start(ap, format);
	vsnprintf(buf, sizeof(buf), format, ap);
	buf[sizeof(buf) - 1] = '\0';
	va_end(ap);

	lwsl_emit(filter, buf);
}

/**
 * lws_set_log_level() - Set the logging bitfield
 * @level:	OR together the LLL_ debug contexts you want output from
 * @log_emit_function:	NULL to leave it as it is, or a user-supplied
 *			function to perform log string emission instead of
 *			the default stderr one.
 *
 *	log level defaults to "err", "warn" and "notice" contexts enabled and
 *	emission on stderr.
 */

LWS_VISIBLE void lws_set_log_level(int level, void (*log_emit_function)(int level,
							      const char *line))
{
	log_level = level;
	if (log_emit_function)
		lwsl_emit = log_emit_function;
}