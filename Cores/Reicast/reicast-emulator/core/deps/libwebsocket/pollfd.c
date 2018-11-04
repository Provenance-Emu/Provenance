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

int
insert_wsi_socket_into_fds(struct libwebsocket_context *context,
						       struct libwebsocket *wsi)
{
	struct libwebsocket_pollargs pa = { wsi->sock, LWS_POLLIN, 0 };

	if (context->fds_count >= context->max_fds) {
		lwsl_err("Too many fds (%d)\n", context->max_fds);
		return 1;
	}

	if (wsi->sock >= context->max_fds) {
		lwsl_err("Socket fd %d is too high (%d)\n",
						wsi->sock, context->max_fds);
		return 1;
	}

	assert(wsi);
	assert(wsi->sock >= 0);

	lwsl_info("insert_wsi_socket_into_fds: wsi=%p, sock=%d, fds pos=%d\n",
					    wsi, wsi->sock, context->fds_count);

	context->protocols[0].callback(context, wsi,
		LWS_CALLBACK_LOCK_POLL,
		wsi->user_space, (void *) &pa, 0);

	context->lws_lookup[wsi->sock] = wsi;
	wsi->position_in_fds_table = context->fds_count;
	context->fds[context->fds_count].fd = wsi->sock;
	context->fds[context->fds_count].events = LWS_POLLIN;
	
	lws_plat_insert_socket_into_fds(context, wsi);

	/* external POLL support via protocol 0 */
	context->protocols[0].callback(context, wsi,
		LWS_CALLBACK_ADD_POLL_FD,
		wsi->user_space, (void *) &pa, 0);

	context->protocols[0].callback(context, wsi,
		LWS_CALLBACK_UNLOCK_POLL,
		wsi->user_space, (void *)&pa, 0);

	return 0;
}

int
remove_wsi_socket_from_fds(struct libwebsocket_context *context,
						      struct libwebsocket *wsi)
{
	int m;
	struct libwebsocket_pollargs pa = { wsi->sock, 0, 0 };

	lws_libev_io(context, wsi, LWS_EV_STOP | LWS_EV_READ | LWS_EV_WRITE);

	if (!--context->fds_count) {
		context->protocols[0].callback(context, wsi,
			LWS_CALLBACK_LOCK_POLL,
			wsi->user_space, (void *) &pa, 0);
		goto do_ext;
	}

	if (wsi->sock > context->max_fds) {
		lwsl_err("Socket fd %d too high (%d)\n",
						   wsi->sock, context->max_fds);
		return 1;
	}

	lwsl_info("%s: wsi=%p, sock=%d, fds pos=%d\n", __func__,
				    wsi, wsi->sock, wsi->position_in_fds_table);

	context->protocols[0].callback(context, wsi,
		LWS_CALLBACK_LOCK_POLL,
		wsi->user_space, (void *)&pa, 0);

	m = wsi->position_in_fds_table; /* replace the contents for this */

	/* have the last guy take up the vacant slot */
	context->fds[m] = context->fds[context->fds_count];

	lws_plat_delete_socket_from_fds(context, wsi, m);

	/*
	 * end guy's fds_lookup entry remains unchanged
	 * (still same fd pointing to same wsi)
	 */
	/* end guy's "position in fds table" changed */
	context->lws_lookup[context->fds[context->fds_count].fd]->
						position_in_fds_table = m;
	/* deletion guy's lws_lookup entry needs nuking */
	context->lws_lookup[wsi->sock] = NULL;
	/* removed wsi has no position any more */
	wsi->position_in_fds_table = -1;

do_ext:
	/* remove also from external POLL support via protocol 0 */
	if (wsi->sock) {
		context->protocols[0].callback(context, wsi,
		    LWS_CALLBACK_DEL_POLL_FD, wsi->user_space,
		    (void *) &pa, 0);
	}
	context->protocols[0].callback(context, wsi,
				       LWS_CALLBACK_UNLOCK_POLL,
				       wsi->user_space, (void *) &pa, 0);
	return 0;
}

int
lws_change_pollfd(struct libwebsocket *wsi, int _and, int _or)
{
	struct libwebsocket_context *context = wsi->protocol->owning_server;
	int tid;
	int sampled_tid;
	struct libwebsocket_pollfd *pfd;
	struct libwebsocket_pollargs pa;

	pfd = &context->fds[wsi->position_in_fds_table];
	pa.fd = wsi->sock;

	context->protocols[0].callback(context, wsi,
		LWS_CALLBACK_LOCK_POLL, wsi->user_space,  (void *) &pa, 0);

	pa.prev_events = pfd->events;
	pa.events = pfd->events = (pfd->events & ~_and) | _or;

	context->protocols[0].callback(context, wsi,
			LWS_CALLBACK_CHANGE_MODE_POLL_FD,
				wsi->user_space, (void *) &pa, 0);

	/*
	 * if we changed something in this pollfd...
	 *   ... and we're running in a different thread context
	 *     than the service thread...
	 *       ... and the service thread is waiting ...
	 *         then cancel it to force a restart with our changed events
	 */
	if (pa.prev_events != pa.events) {
		
		if (lws_plat_change_pollfd(context, wsi, pfd)) {
			lwsl_info("%s failed\n", __func__);
			return 1;
		}

		sampled_tid = context->service_tid;
		if (sampled_tid) {
			tid = context->protocols[0].callback(context, NULL,
				     LWS_CALLBACK_GET_THREAD_ID, NULL, NULL, 0);
			if (tid != sampled_tid)
				libwebsocket_cancel_service(context);
		}
	}

	context->protocols[0].callback(context, wsi,
		LWS_CALLBACK_UNLOCK_POLL, wsi->user_space, (void *) &pa, 0);
	
	return 0;
}


/**
 * libwebsocket_callback_on_writable() - Request a callback when this socket
 *					 becomes able to be written to without
 *					 blocking
 *
 * @context:	libwebsockets context
 * @wsi:	Websocket connection instance to get callback for
 */

LWS_VISIBLE int
libwebsocket_callback_on_writable(struct libwebsocket_context *context,
						      struct libwebsocket *wsi)
{
	if (lws_ext_callback_for_each_active(wsi,
				LWS_EXT_CALLBACK_REQUEST_ON_WRITEABLE, NULL, 0))
		return 1;

	if (wsi->position_in_fds_table < 0) {
		lwsl_err("%s: failed to find socket %d\n", __func__, wsi->sock);
		return -1;
	}

	if (lws_change_pollfd(wsi, 0, LWS_POLLOUT))
		return -1;

	lws_libev_io(context, wsi, LWS_EV_START | LWS_EV_WRITE);

	return 1;
}

/**
 * libwebsocket_callback_on_writable_all_protocol() - Request a callback for
 *			all connections using the given protocol when it
 *			becomes possible to write to each socket without
 *			blocking in turn.
 *
 * @protocol:	Protocol whose connections will get callbacks
 */

LWS_VISIBLE int
libwebsocket_callback_on_writable_all_protocol(
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
			libwebsocket_callback_on_writable(context, wsi);
	}

	return 0;
}
