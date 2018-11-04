/*
 * libwebsockets - small server side websockets and web server implementation
 *
 * Copyright (C) 2010-2013 Andy Green <andy@warmcat.com>
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

int lws_context_init_server(struct lws_context_creation_info *info,
			    struct libwebsocket_context *context)
{
	int n;
	int sockfd;
	struct sockaddr_in sin;
	socklen_t len = sizeof(sin);
	int opt = 1;
	struct libwebsocket *wsi;
#ifdef LWS_USE_IPV6
	struct sockaddr_in6 serv_addr6;
#endif
	struct sockaddr_in serv_addr4;
	struct sockaddr *v;

	/* set up our external listening socket we serve on */

	if (info->port == CONTEXT_PORT_NO_LISTEN)
		return 0;

#ifdef LWS_USE_IPV6
	if (LWS_IPV6_ENABLED(context))
		sockfd = socket(AF_INET6, SOCK_STREAM, 0);
	else
#endif
		sockfd = socket(AF_INET, SOCK_STREAM, 0);

	if (sockfd < 0) {
		lwsl_err("ERROR opening socket\n");
		return 1;
	}

	/*
	 * allow us to restart even if old sockets in TIME_WAIT
	 */
	setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR,
				      (const void *)&opt, sizeof(opt));

	lws_plat_set_socket_options(context, sockfd);

#ifdef LWS_USE_IPV6
	if (LWS_IPV6_ENABLED(context)) {
		v = (struct sockaddr *)&serv_addr6;
		n = sizeof(struct sockaddr_in6);
		bzero((char *) &serv_addr6, sizeof(serv_addr6));
		serv_addr6.sin6_addr = in6addr_any;
		serv_addr6.sin6_family = AF_INET6;
		serv_addr6.sin6_port = htons(info->port);
	} else
#endif
	{
		v = (struct sockaddr *)&serv_addr4;
		n = sizeof(serv_addr4);
		bzero((char *) &serv_addr4, sizeof(serv_addr4));
		serv_addr4.sin_addr.s_addr = INADDR_ANY;
		serv_addr4.sin_family = AF_INET;
		serv_addr4.sin_port = htons(info->port);

		if (info->iface) {
			if (interface_to_sa(context, info->iface,
				   (struct sockaddr_in *)v, n) < 0) {
				lwsl_err("Unable to find interface %s\n",
							info->iface);
				compatible_close(sockfd);
				return 1;
			}
		}
	} /* ipv4 */

	n = bind(sockfd, v, n);
	if (n < 0) {
		lwsl_err("ERROR on binding to port %d (%d %d)\n",
					      info->port, n, LWS_ERRNO);
		compatible_close(sockfd);
		return 1;
	}
	
	if (getsockname(sockfd, (struct sockaddr *)&sin, &len) == -1)
		lwsl_warn("getsockname: %s\n", strerror(LWS_ERRNO));
	else
		info->port = ntohs(sin.sin_port);

	context->listen_port = info->port;

	wsi = (struct libwebsocket *)malloc(sizeof(struct libwebsocket));
	if (wsi == NULL) {
		lwsl_err("Out of mem\n");
		compatible_close(sockfd);
		return 1;
	}
	memset(wsi, 0, sizeof(struct libwebsocket));
	wsi->sock = sockfd;
	wsi->mode = LWS_CONNMODE_SERVER_LISTENER;

	insert_wsi_socket_into_fds(context, wsi);

	context->listen_service_modulo = LWS_LISTEN_SERVICE_MODULO;
	context->listen_service_count = 0;
	context->listen_service_fd = sockfd;

	listen(sockfd, LWS_SOMAXCONN);
	lwsl_notice(" Listening on port %d\n", info->port);
	
	return 0;
}

int
_libwebsocket_rx_flow_control(struct libwebsocket *wsi)
{
	struct libwebsocket_context *context = wsi->protocol->owning_server;

	/* there is no pending change */
	if (!(wsi->u.ws.rxflow_change_to & LWS_RXFLOW_PENDING_CHANGE))
		return 0;

	/* stuff is still buffered, not ready to really accept new input */
	if (wsi->u.ws.rxflow_buffer) {
		/* get ourselves called back to deal with stashed buffer */
		libwebsocket_callback_on_writable(context, wsi);
		return 0;
	}

	/* pending is cleared, we can change rxflow state */

	wsi->u.ws.rxflow_change_to &= ~LWS_RXFLOW_PENDING_CHANGE;

	lwsl_info("rxflow: wsi %p change_to %d\n", wsi,
			      wsi->u.ws.rxflow_change_to & LWS_RXFLOW_ALLOW);

	/* adjust the pollfd for this wsi */

	if (wsi->u.ws.rxflow_change_to & LWS_RXFLOW_ALLOW) {
		if (lws_change_pollfd(wsi, 0, LWS_POLLIN)) {
			lwsl_info("%s: fail\n", __func__);
			return -1;
		}
	} else
		if (lws_change_pollfd(wsi, LWS_POLLIN, 0))
			return -1;

	return 0;
}


int lws_handshake_server(struct libwebsocket_context *context,
		struct libwebsocket *wsi, unsigned char **buf, size_t len)
{
	struct allocated_headers *ah;
	char *uri_ptr = NULL;
	int uri_len = 0;
	char content_length_str[32];
	int n;

	/* LWS_CONNMODE_WS_SERVING */

	while (len--) {
		if (libwebsocket_parse(wsi, *(*buf)++)) {
			lwsl_info("libwebsocket_parse failed\n");
			goto bail_nuke_ah;
		}

		if (wsi->u.hdr.parser_state != WSI_PARSING_COMPLETE)
			continue;

		lwsl_parser("libwebsocket_parse sees parsing complete\n");

		wsi->mode = LWS_CONNMODE_PRE_WS_SERVING_ACCEPT;
		libwebsocket_set_timeout(wsi, NO_PENDING_TIMEOUT, 0);

		/* is this websocket protocol or normal http 1.0? */

		if (!lws_hdr_total_length(wsi, WSI_TOKEN_UPGRADE) ||
			     !lws_hdr_total_length(wsi, WSI_TOKEN_CONNECTION)) {

			/* it's not websocket.... shall we accept it as http? */

			if (!lws_hdr_total_length(wsi, WSI_TOKEN_GET_URI) &&
			    !lws_hdr_total_length(wsi, WSI_TOKEN_POST_URI)) {
				lwsl_warn("Missing URI in HTTP request\n");
				goto bail_nuke_ah;
			}

			if (lws_hdr_total_length(wsi, WSI_TOKEN_GET_URI) &&
			    lws_hdr_total_length(wsi, WSI_TOKEN_POST_URI)) {
				lwsl_warn("GET and POST methods?\n");
				goto bail_nuke_ah;
			}

			if (libwebsocket_ensure_user_space(wsi))
				goto bail_nuke_ah;

			if (lws_hdr_total_length(wsi, WSI_TOKEN_GET_URI)) {
				uri_ptr = lws_hdr_simple_ptr(wsi, WSI_TOKEN_GET_URI);
				uri_len = lws_hdr_total_length(wsi, WSI_TOKEN_GET_URI);
				lwsl_info("HTTP GET request for '%s'\n",
				    lws_hdr_simple_ptr(wsi, WSI_TOKEN_GET_URI));

			}
			if (lws_hdr_total_length(wsi, WSI_TOKEN_POST_URI)) {
				lwsl_info("HTTP POST request for '%s'\n",
				   lws_hdr_simple_ptr(wsi, WSI_TOKEN_POST_URI));
				uri_ptr = lws_hdr_simple_ptr(wsi, WSI_TOKEN_POST_URI);
				uri_len = lws_hdr_total_length(wsi, WSI_TOKEN_POST_URI);
			}

			/*
			 * Hm we still need the headers so the
			 * callback can look at leaders like the URI, but we
			 * need to transition to http union state.... hold a
			 * copy of u.hdr.ah and deallocate afterwards
			 */
			ah = wsi->u.hdr.ah;

			/* union transition */
			memset(&wsi->u, 0, sizeof(wsi->u));
			wsi->mode = LWS_CONNMODE_HTTP_SERVING_ACCEPTED;
			wsi->state = WSI_STATE_HTTP;
			wsi->u.http.fd = LWS_INVALID_FILE;

			/* expose it at the same offset as u.hdr */
			wsi->u.http.ah = ah;

			/* HTTP header had a content length? */

			wsi->u.http.content_length = 0;
			if (lws_hdr_total_length(wsi, WSI_TOKEN_POST_URI))
				wsi->u.http.content_length = 100 * 1024 * 1024;

			if (lws_hdr_total_length(wsi, WSI_TOKEN_HTTP_CONTENT_LENGTH)) {
				lws_hdr_copy(wsi, content_length_str,
						sizeof(content_length_str) - 1,
								WSI_TOKEN_HTTP_CONTENT_LENGTH);
				wsi->u.http.content_length = atoi(content_length_str);
			}

			if (wsi->u.http.content_length > 0) {
				wsi->u.http.body_index = 0;
				n = wsi->protocol->rx_buffer_size;
				if (!n)
					n = LWS_MAX_SOCKET_IO_BUF;
				wsi->u.http.post_buffer = malloc(n);
				if (!wsi->u.http.post_buffer) {
					lwsl_err("Unable to allocate post buffer\n");
					n = -1;
					goto cleanup;
				}
			}

			n = 0;
			if (wsi->protocol->callback)
				n = wsi->protocol->callback(context, wsi,
					LWS_CALLBACK_FILTER_HTTP_CONNECTION,
					     wsi->user_space, uri_ptr, uri_len);

			if (!n) {
				/*
				 * if there is content supposed to be coming,
				 * put a timeout on it having arrived
				 */
				libwebsocket_set_timeout(wsi,
					PENDING_TIMEOUT_HTTP_CONTENT,
							      AWAITING_TIMEOUT);

				if (wsi->protocol->callback)
					n = wsi->protocol->callback(context, wsi,
					    LWS_CALLBACK_HTTP,
					    wsi->user_space, uri_ptr, uri_len);
			}

cleanup:
			/* now drop the header info we kept a pointer to */
			if (ah)
				free(ah);
			/* not possible to continue to use past here */
			wsi->u.http.ah = NULL;

			if (n) {
				lwsl_info("LWS_CALLBACK_HTTP closing\n");
				return 1; /* struct ah ptr already nuked */
			}

			/*
			 * (if callback didn't start sending a file)
			 * deal with anything else as body, whether
			 * there was a content-length or not
			 */

			if (wsi->state != WSI_STATE_HTTP_ISSUING_FILE)
				wsi->state = WSI_STATE_HTTP_BODY;
			return 2; /* goto http_postbody; */
		}

		if (!wsi->protocol)
			lwsl_err("NULL protocol at libwebsocket_read\n");

		/*
		 * It's websocket
		 *
		 * Make sure user side is happy about protocol
		 */

		while (wsi->protocol->callback) {

			if (!lws_hdr_total_length(wsi, WSI_TOKEN_PROTOCOL)) {
				if (wsi->protocol->name == NULL)
					break;
			} else
				if (wsi->protocol->name && strcmp(
					lws_hdr_simple_ptr(wsi,
						WSI_TOKEN_PROTOCOL),
						      wsi->protocol->name) == 0)
					break;

			wsi->protocol++;
		}

		/* we didn't find a protocol he wanted? */

		if (wsi->protocol->callback == NULL) {
			if (lws_hdr_simple_ptr(wsi, WSI_TOKEN_PROTOCOL) ==
									 NULL) {
				lwsl_info("no protocol -> prot 0 handler\n");
				wsi->protocol = &context->protocols[0];
			} else {
				lwsl_err("Req protocol %s not supported\n",
				   lws_hdr_simple_ptr(wsi, WSI_TOKEN_PROTOCOL));
				goto bail_nuke_ah;
			}
		}

		/* allocate wsi->user storage */
		if (libwebsocket_ensure_user_space(wsi))
			goto bail_nuke_ah;

		/*
		 * Give the user code a chance to study the request and
		 * have the opportunity to deny it
		 */

		if ((wsi->protocol->callback)(wsi->protocol->owning_server, wsi,
				LWS_CALLBACK_FILTER_PROTOCOL_CONNECTION,
				wsi->user_space,
			      lws_hdr_simple_ptr(wsi, WSI_TOKEN_PROTOCOL), 0)) {
			lwsl_warn("User code denied connection\n");
			goto bail_nuke_ah;
		}


		/*
		 * Perform the handshake according to the protocol version the
		 * client announced
		 */

		switch (wsi->ietf_spec_revision) {
		case 13:
			lwsl_parser("lws_parse calling handshake_04\n");
			if (handshake_0405(context, wsi)) {
				lwsl_info("hs0405 has failed the connection\n");
				goto bail_nuke_ah;
			}
			break;

		default:
			lwsl_warn("Unknown client spec version %d\n",
						       wsi->ietf_spec_revision);
			goto bail_nuke_ah;
		}

		/* drop the header info -- no bail_nuke_ah after this */

		if (wsi->u.hdr.ah)
			free(wsi->u.hdr.ah);

		wsi->mode = LWS_CONNMODE_WS_SERVING;

		/* union transition */
		memset(&wsi->u, 0, sizeof(wsi->u));
		wsi->u.ws.rxflow_change_to = LWS_RXFLOW_ALLOW;

		/*
		 * create the frame buffer for this connection according to the
		 * size mentioned in the protocol definition.  If 0 there, use
		 * a big default for compatibility
		 */

		n = wsi->protocol->rx_buffer_size;
		if (!n)
			n = LWS_MAX_SOCKET_IO_BUF;
		n += LWS_SEND_BUFFER_PRE_PADDING + LWS_SEND_BUFFER_POST_PADDING;
		wsi->u.ws.rx_user_buffer = malloc(n);
		if (!wsi->u.ws.rx_user_buffer) {
			lwsl_err("Out of Mem allocating rx buffer %d\n", n);
			return 1;
		}
		lwsl_info("Allocating RX buffer %d\n", n);

		if (setsockopt(wsi->sock, SOL_SOCKET, SO_SNDBUF, (const char *)&n, sizeof n)) {
			lwsl_warn("Failed to set SNDBUF to %d", n);
			return 1;
		}

		lwsl_parser("accepted v%02d connection\n",
						       wsi->ietf_spec_revision);
	} /* while all chars are handled */

	return 0;

bail_nuke_ah:
	/* drop the header info */
	if (wsi->u.hdr.ah)
		free(wsi->u.hdr.ah);
	return 1;
}

struct libwebsocket *
libwebsocket_create_new_server_wsi(struct libwebsocket_context *context)
{
	struct libwebsocket *new_wsi;

	new_wsi = (struct libwebsocket *)malloc(sizeof(struct libwebsocket));
	if (new_wsi == NULL) {
		lwsl_err("Out of memory for new connection\n");
		return NULL;
	}

	memset(new_wsi, 0, sizeof(struct libwebsocket));
	new_wsi->pending_timeout = NO_PENDING_TIMEOUT;

	/* intialize the instance struct */

	new_wsi->state = WSI_STATE_HTTP;
	new_wsi->mode = LWS_CONNMODE_HTTP_SERVING;
	new_wsi->hdr_parsing_completed = 0;

	if (lws_allocate_header_table(new_wsi)) {
		free(new_wsi);
		return NULL;
	}

	/*
	 * these can only be set once the protocol is known
	 * we set an unestablished connection's protocol pointer
	 * to the start of the supported list, so it can look
	 * for matching ones during the handshake
	 */
	new_wsi->protocol = context->protocols;
	new_wsi->user_space = NULL;
	new_wsi->ietf_spec_revision = 0;

	/*
	 * outermost create notification for wsi
	 * no user_space because no protocol selection
	 */
	context->protocols[0].callback(context, new_wsi,
			LWS_CALLBACK_WSI_CREATE, NULL, NULL, 0);

	return new_wsi;
}

int lws_server_socket_service(struct libwebsocket_context *context,
			struct libwebsocket *wsi, struct libwebsocket_pollfd *pollfd)
{
	struct libwebsocket *new_wsi = NULL;
	int accept_fd = 0;
	socklen_t clilen;
	struct sockaddr_in cli_addr;
	int n;
	int len;

	switch (wsi->mode) {

	case LWS_CONNMODE_HTTP_SERVING:
	case LWS_CONNMODE_HTTP_SERVING_ACCEPTED:

		/* handle http headers coming in */

		/* pending truncated sends have uber priority */

		if (wsi->truncated_send_malloc) {
			if (pollfd->revents & LWS_POLLOUT)
				if (lws_issue_raw(wsi, wsi->truncated_send_malloc +
					wsi->truncated_send_offset,
							wsi->truncated_send_len) < 0) {
					lwsl_info("closing from socket service\n");
					return -1;
				}
			/*
			 * we can't afford to allow input processing send
			 * something new, so spin around he event loop until
			 * he doesn't have any partials
			 */
			break;
		}

		/* any incoming data ready? */

		if (pollfd->revents & LWS_POLLIN) {
			len = lws_ssl_capable_read(wsi,
					context->service_buffer,
						       sizeof(context->service_buffer));
			switch (len) {
			case 0:
				lwsl_info("lws_server_skt_srv: read 0 len\n");
				/* lwsl_info("   state=%d\n", wsi->state); */
				if (!wsi->hdr_parsing_completed)
					free(wsi->u.hdr.ah);
				/* fallthru */
			case LWS_SSL_CAPABLE_ERROR:
				libwebsocket_close_and_free_session(
						context, wsi,
						LWS_CLOSE_STATUS_NOSTATUS);
				return 0;
			case LWS_SSL_CAPABLE_MORE_SERVICE:
				break;
			}

			/* just ignore incoming if waiting for close */
			if (wsi->state != WSI_STATE_FLUSHING_STORED_SEND_BEFORE_CLOSE) {
			
				/* hm this may want to send (via HTTP callback for example) */

				n = libwebsocket_read(context, wsi,
							context->service_buffer, len);
				if (n < 0)
					/* we closed wsi */
					return 0;

				/* hum he may have used up the writability above */
				break;
			}
		}

		/* this handles POLLOUT for http serving fragments */

		if (!(pollfd->revents & LWS_POLLOUT))
			break;

		/* one shot */
		if (lws_change_pollfd(wsi, LWS_POLLOUT, 0))
			goto fail;
		
		lws_libev_io(context, wsi, LWS_EV_STOP | LWS_EV_WRITE);

		if (wsi->state != WSI_STATE_HTTP_ISSUING_FILE) {
			n = user_callback_handle_rxflow(
					wsi->protocol->callback,
					wsi->protocol->owning_server,
					wsi, LWS_CALLBACK_HTTP_WRITEABLE,
					wsi->user_space,
					NULL,
					0);
			if (n < 0)
				libwebsocket_close_and_free_session(
				       context, wsi, LWS_CLOSE_STATUS_NOSTATUS);
			break;
		}

		/* nonzero for completion or error */
		if (libwebsockets_serve_http_file_fragment(context, wsi))
			libwebsocket_close_and_free_session(context, wsi,
					       LWS_CLOSE_STATUS_NOSTATUS);
		break;

	case LWS_CONNMODE_SERVER_LISTENER:

		/* pollin means a client has connected to us then */

		if (!(pollfd->revents & LWS_POLLIN))
			break;

		/* listen socket got an unencrypted connection... */

		clilen = sizeof(cli_addr);
		lws_latency_pre(context, wsi);
		accept_fd  = accept(pollfd->fd, (struct sockaddr *)&cli_addr,
								       &clilen);
		lws_latency(context, wsi,
			"unencrypted accept LWS_CONNMODE_SERVER_LISTENER",
						     accept_fd, accept_fd >= 0);
		if (accept_fd < 0) {
			if (LWS_ERRNO == LWS_EAGAIN || LWS_ERRNO == LWS_EWOULDBLOCK) {
				lwsl_debug("accept asks to try again\n");
				break;
			}
			lwsl_warn("ERROR on accept: %s\n", strerror(LWS_ERRNO));
			break;
		}

		lws_plat_set_socket_options(context, accept_fd);

		/*
		 * look at who we connected to and give user code a chance
		 * to reject based on client IP.  There's no protocol selected
		 * yet so we issue this to protocols[0]
		 */

		if ((context->protocols[0].callback)(context, wsi,
				LWS_CALLBACK_FILTER_NETWORK_CONNECTION,
					   NULL, (void *)(long)accept_fd, 0)) {
			lwsl_debug("Callback denied network connection\n");
			compatible_close(accept_fd);
			break;
		}

		new_wsi = libwebsocket_create_new_server_wsi(context);
		if (new_wsi == NULL) {
			compatible_close(accept_fd);
			break;
		}

		new_wsi->sock = accept_fd;

		/* the transport is accepted... give him time to negotiate */
		libwebsocket_set_timeout(new_wsi,
			PENDING_TIMEOUT_ESTABLISH_WITH_SERVER,
							AWAITING_TIMEOUT);

		/*
		 * A new connection was accepted. Give the user a chance to
		 * set properties of the newly created wsi. There's no protocol
		 * selected yet so we issue this to protocols[0]
		 */

		(context->protocols[0].callback)(context, new_wsi,
			LWS_CALLBACK_SERVER_NEW_CLIENT_INSTANTIATED, NULL, NULL, 0);

		lws_libev_accept(context, new_wsi, accept_fd);

		if (!LWS_SSL_ENABLED(context)) {
			lwsl_debug("accepted new conn  port %u on fd=%d\n",
					  ntohs(cli_addr.sin_port), accept_fd);

			insert_wsi_socket_into_fds(context, new_wsi);
		}
		break;

	default:
		break;
	}

	if (lws_server_socket_service_ssl(context, &wsi, new_wsi, accept_fd, pollfd))
		goto fail;

	return 0;
	
fail:
	libwebsocket_close_and_free_session(context, wsi,
						 LWS_CLOSE_STATUS_NOSTATUS);
	return 1;
}


static const char *err400[] = {
	"Bad Request",
	"Unauthorized",
	"Payment Required",
	"Forbidden",
	"Not Found",
	"Method Not Allowed",
	"Not Acceptable",
	"Proxy Auth Required",
	"Request Timeout",
	"Conflict",
	"Gone",
	"Length Required",
	"Precondition Failed",
	"Request Entity Too Large",
	"Request URI too Long",
	"Unsupported Media Type",
	"Requested Range Not Satisfiable",
	"Expectation Failed"
};

static const char *err500[] = {
	"Internal Server Error",
	"Not Implemented",
	"Bad Gateway",
	"Service Unavailable",
	"Gateway Timeout",
	"HTTP Version Not Supported"
};

/**
 * libwebsockets_return_http_status() - Return simple http status
 * @context:		libwebsockets context
 * @wsi:		Websocket instance (available from user callback)
 * @code:		Status index, eg, 404
 * @html_body:		User-readable HTML description, or NULL
 *
 *	Helper to report HTTP errors back to the client cleanly and
 *	consistently
 */
LWS_VISIBLE int libwebsockets_return_http_status(
		struct libwebsocket_context *context, struct libwebsocket *wsi,
				       unsigned int code, const char *html_body)
{
	int n, m;
	const char *description = "";

	if (!html_body)
		html_body = "";

	if (code >= 400 && code < (400 + ARRAY_SIZE(err400)))
		description = err400[code - 400];
	if (code >= 500 && code < (500 + ARRAY_SIZE(err500)))
		description = err500[code - 500];

	n = sprintf((char *)context->service_buffer,
		"HTTP/1.0 %u %s\x0d\x0a"
		"Server: libwebsockets\x0d\x0a"
		"Content-Type: text/html\x0d\x0a\x0d\x0a"
		"<h1>%u %s</h1>%s",
		code, description, code, description, html_body);

	lwsl_info((const char *)context->service_buffer);

	m = libwebsocket_write(wsi, context->service_buffer, n, LWS_WRITE_HTTP);

	return m;
}

/**
 * libwebsockets_serve_http_file() - Send a file back to the client using http
 * @context:		libwebsockets context
 * @wsi:		Websocket instance (available from user callback)
 * @file:		The file to issue over http
 * @content_type:	The http content type, eg, text/html
 * @other_headers:	NULL or pointer to \0-terminated other header string
 *
 *	This function is intended to be called from the callback in response
 *	to http requests from the client.  It allows the callback to issue
 *	local files down the http link in a single step.
 *
 *	Returning <0 indicates error and the wsi should be closed.  Returning
 *	>0 indicates the file was completely sent and the wsi should be closed.
 *	==0 indicates the file transfer is started and needs more service later,
 *	the wsi should be left alone.
 */

LWS_VISIBLE int libwebsockets_serve_http_file(
		struct libwebsocket_context *context,
			struct libwebsocket *wsi, const char *file,
			   const char *content_type, const char *other_headers)
{
	unsigned char *p = context->service_buffer;
	int ret = 0;
	int n;

	wsi->u.http.fd = lws_plat_open_file(file, &wsi->u.http.filelen);

	if (wsi->u.http.fd == LWS_INVALID_FILE) {
		lwsl_err("Unable to open '%s'\n", file);
		libwebsockets_return_http_status(context, wsi,
						HTTP_STATUS_NOT_FOUND, NULL);
		return -1;
	}

	p += sprintf((char *)p,
"HTTP/1.0 200 OK\x0d\x0aServer: libwebsockets\x0d\x0a""Content-Type: %s\x0d\x0a",
								  content_type);
	if (other_headers) {
		n = strlen(other_headers);
		memcpy(p, other_headers, n);
		p += n;
	}
	p += sprintf((char *)p,
		"Content-Length: %lu\x0d\x0a\x0d\x0a", wsi->u.http.filelen);

	ret = libwebsocket_write(wsi, context->service_buffer,
				   p - context->service_buffer, LWS_WRITE_HTTP);
	if (ret != (p - context->service_buffer)) {
		lwsl_err("_write returned %d from %d\n", ret, (p - context->service_buffer));
		return -1;
	}

	wsi->u.http.filepos = 0;
	wsi->state = WSI_STATE_HTTP_ISSUING_FILE;

	return libwebsockets_serve_http_file_fragment(context, wsi);
}


int libwebsocket_interpret_incoming_packet(struct libwebsocket *wsi,
						 unsigned char *buf, size_t len)
{
	size_t n = 0;
	int m;

#if 0
	lwsl_parser("received %d byte packet\n", (int)len);
	lwsl_hexdump(buf, len);
#endif

	/* let the rx protocol state machine have as much as it needs */

	while (n < len) {
		/*
		 * we were accepting input but now we stopped doing so
		 */
		if (!(wsi->u.ws.rxflow_change_to & LWS_RXFLOW_ALLOW)) {
			/* his RX is flowcontrolled, don't send remaining now */
			if (!wsi->u.ws.rxflow_buffer) {
				/* a new rxflow, buffer it and warn caller */
				lwsl_info("new rxflow input buffer len %d\n",
								       len - n);
				wsi->u.ws.rxflow_buffer =
					       (unsigned char *)malloc(len - n);
				wsi->u.ws.rxflow_len = len - n;
				wsi->u.ws.rxflow_pos = 0;
				memcpy(wsi->u.ws.rxflow_buffer,
							buf + n, len - n);
			} else
				/* rxflow while we were spilling prev rxflow */
				lwsl_info("stalling in existing rxflow buf\n");

			return 1;
		}

		/* account for what we're using in rxflow buffer */
		if (wsi->u.ws.rxflow_buffer)
			wsi->u.ws.rxflow_pos++;

		/* process the byte */
		m = libwebsocket_rx_sm(wsi, buf[n++]);
		if (m < 0)
			return -1;
	}

	return 0;
}

LWS_VISIBLE void
lws_server_get_canonical_hostname(struct libwebsocket_context *context,
				struct lws_context_creation_info *info)
{
	if (info->options & LWS_SERVER_OPTION_SKIP_SERVER_CANONICAL_NAME)
		return;

	/* find canonical hostname */
	gethostname((char *)context->canonical_hostname,
				       sizeof(context->canonical_hostname) - 1);

	lwsl_notice(" canonical_hostname = %s\n", context->canonical_hostname);
}