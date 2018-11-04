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

/*
 * -04 of the protocol (actually the 80th version) has a radically different
 * handshake.  The 04 spec gives the following idea
 *
 *    The handshake from the client looks as follows:
 *
 *      GET /chat HTTP/1.1
 *      Host: server.example.com
 *      Upgrade: websocket
 *      Connection: Upgrade
 *      Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
 *      Sec-WebSocket-Origin: http://example.com
 *      Sec-WebSocket-Protocol: chat, superchat
 *	Sec-WebSocket-Version: 4
 *
 *  The handshake from the server looks as follows:
 *
 *       HTTP/1.1 101 Switching Protocols
 *       Upgrade: websocket
 *       Connection: Upgrade
 *       Sec-WebSocket-Accept: me89jWimTRKTWwrS3aRrL53YZSo=
 *       Sec-WebSocket-Nonce: AQIDBAUGBwgJCgsMDQ4PEC==
 *       Sec-WebSocket-Protocol: chat
 */

/*
 * We have to take care about parsing because the headers may be split
 * into multiple fragments.  They may contain unknown headers with arbitrary
 * argument lengths.  So, we parse using a single-character at a time state
 * machine that is completely independent of packet size.
 */

LWS_VISIBLE int
libwebsocket_read(struct libwebsocket_context *context,
		     struct libwebsocket *wsi, unsigned char *buf, size_t len)
{
	size_t n;

	switch (wsi->state) {

	case WSI_STATE_HTTP_BODY:
http_postbody:
		while (len--) {

			if (wsi->u.http.content_length_seen >= wsi->u.http.content_length)
				break;

			wsi->u.http.post_buffer[wsi->u.http.body_index++] = *buf++;
			wsi->u.http.content_length_seen++;
			n = wsi->protocol->rx_buffer_size;
			if (!n)
				n = LWS_MAX_SOCKET_IO_BUF;

			if (wsi->u.http.body_index != n &&
			    wsi->u.http.content_length_seen != wsi->u.http.content_length)
				continue;

			if (wsi->protocol->callback) {
				n = wsi->protocol->callback(
					wsi->protocol->owning_server, wsi,
					    LWS_CALLBACK_HTTP_BODY,
					    wsi->user_space, wsi->u.http.post_buffer,
							wsi->u.http.body_index);
				wsi->u.http.body_index = 0;
				if (n)
					goto bail;
			}

			if (wsi->u.http.content_length_seen == wsi->u.http.content_length) {
				/* he sent the content in time */
				libwebsocket_set_timeout(wsi, NO_PENDING_TIMEOUT, 0);
				n = wsi->protocol->callback(
					wsi->protocol->owning_server, wsi,
					    LWS_CALLBACK_HTTP_BODY_COMPLETION,
					    wsi->user_space, NULL, 0);
				wsi->u.http.body_index = 0;
				if (n)
					goto bail;
			}

		}

		/* 
		 * we need to spill here so everything is seen in the case
		 * there is no content-length
		 */
		if (wsi->u.http.body_index && wsi->protocol->callback) {
			n = wsi->protocol->callback(
				wsi->protocol->owning_server, wsi,
				    LWS_CALLBACK_HTTP_BODY,
				    wsi->user_space, wsi->u.http.post_buffer,
						wsi->u.http.body_index);
			wsi->u.http.body_index = 0;
			if (n)
				goto bail;
		}
		break;

	case WSI_STATE_HTTP_ISSUING_FILE:
	case WSI_STATE_HTTP:
		wsi->state = WSI_STATE_HTTP_HEADERS;
		wsi->u.hdr.parser_state = WSI_TOKEN_NAME_PART;
		wsi->u.hdr.lextable_pos = 0;
		/* fallthru */
	case WSI_STATE_HTTP_HEADERS:

		lwsl_parser("issuing %d bytes to parser\n", (int)len);

		if (lws_handshake_client(wsi, &buf, len))
			goto bail;

		switch (lws_handshake_server(context, wsi, &buf, len)) {
		case 1:
			goto bail;
		case 2:
			goto http_postbody;
		}
		break;

	case WSI_STATE_AWAITING_CLOSE_ACK:
	case WSI_STATE_ESTABLISHED:
		if (lws_handshake_client(wsi, &buf, len))
			goto bail;
		switch (wsi->mode) {
		case LWS_CONNMODE_WS_SERVING:

			if (libwebsocket_interpret_incoming_packet(wsi, buf, len) < 0) {
				lwsl_info("interpret_incoming_packet has bailed\n");
				goto bail;
			}
			break;
		}
		break;
	default:
		lwsl_err("libwebsocket_read: Unhandled state\n");
		break;
	}

	return 0;

bail:
	lwsl_debug("closing connection at libwebsocket_read bail:\n");

	libwebsocket_close_and_free_session(context, wsi,
						     LWS_CLOSE_STATUS_NOSTATUS);

	return -1;
}
