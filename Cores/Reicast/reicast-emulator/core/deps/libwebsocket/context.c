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

#ifndef LWS_BUILD_HASH
#define LWS_BUILD_HASH "unknown-build-hash"
#endif

#ifdef WIN32
#define getdtablesize() 30000
#endif

static const char *library_version = LWS_LIBRARY_VERSION " " LWS_BUILD_HASH;

/**
 * lws_get_library_version: get version and git hash library built from
 *
 *	returns a const char * to a string like "1.1 178d78c"
 *	representing the library version followed by the git head hash it
 *	was built from
 */

LWS_VISIBLE const char *
lws_get_library_version(void)
{
	return library_version;
}

/**
 * libwebsocket_create_context() - Create the websocket handler
 * @info:	pointer to struct with parameters
 *
 *	This function creates the listening socket (if serving) and takes care
 *	of all initialization in one step.
 *
 *	After initialization, it returns a struct libwebsocket_context * that
 *	represents this server.  After calling, user code needs to take care
 *	of calling libwebsocket_service() with the context pointer to get the
 *	server's sockets serviced.  This must be done in the same process
 *	context as the initialization call.
 *
 *	The protocol callback functions are called for a handful of events
 *	including http requests coming in, websocket connections becoming
 *	established, and data arriving; it's also called periodically to allow
 *	async transmission.
 *
 *	HTTP requests are sent always to the FIRST protocol in @protocol, since
 *	at that time websocket protocol has not been negotiated.  Other
 *	protocols after the first one never see any HTTP callack activity.
 *
 *	The server created is a simple http server by default; part of the
 *	websocket standard is upgrading this http connection to a websocket one.
 *
 *	This allows the same server to provide files like scripts and favicon /
 *	images or whatever over http and dynamic data over websockets all in
 *	one place; they're all handled in the user callback.
 */

LWS_VISIBLE struct libwebsocket_context *
libwebsocket_create_context(struct lws_context_creation_info *info)
{
	struct libwebsocket_context *context = NULL;
	char *p;

	int pid_daemon = get_daemonize_pid();

	lwsl_notice("Initial logging level %d\n", log_level);
	lwsl_notice("Library version: %s\n", library_version);
#ifdef LWS_USE_IPV6
	if (!(info->options & LWS_SERVER_OPTION_DISABLE_IPV6))
		lwsl_notice("IPV6 compiled in and enabled\n");
	else
		lwsl_notice("IPV6 compiled in but disabled\n");
#else
	lwsl_notice("IPV6 not compiled in\n");
#endif
	lws_feature_status_libev(info);
	lwsl_info(" LWS_MAX_HEADER_LEN: %u\n", LWS_MAX_HEADER_LEN);
	lwsl_info(" LWS_MAX_PROTOCOLS: %u\n", LWS_MAX_PROTOCOLS);

	lwsl_info(" SPEC_LATEST_SUPPORTED: %u\n", SPEC_LATEST_SUPPORTED);
	lwsl_info(" AWAITING_TIMEOUT: %u\n", AWAITING_TIMEOUT);
	lwsl_info(" SYSTEM_RANDOM_FILEPATH: '%s'\n", SYSTEM_RANDOM_FILEPATH);
	lwsl_info(" LWS_MAX_ZLIB_CONN_BUFFER: %u\n", LWS_MAX_ZLIB_CONN_BUFFER);

	if (lws_plat_context_early_init())
		return NULL;

	context = (struct libwebsocket_context *)
				malloc(sizeof(struct libwebsocket_context));
	if (!context) {
		lwsl_err("No memory for websocket context\n");
		return NULL;
	}
	memset(context, 0, sizeof(*context));

	if (pid_daemon) {
		context->started_with_parent = pid_daemon;
		lwsl_notice(" Started with daemon pid %d\n", pid_daemon);
	}

	context->listen_service_extraseen = 0;
	context->protocols = info->protocols;
	context->listen_port = info->port;
	context->http_proxy_port = 0;
	context->http_proxy_address[0] = '\0';
	context->options = info->options;
	context->iface = info->iface;
	/* to reduce this allocation, */
#ifdef WIN32
	context->max_fds = getdtablesize ();
#else
	context->max_fds = sysconf(_SC_OPEN_MAX);
#endif
	lwsl_notice(" static allocation: %u + (%u x %u fds) = %u bytes\n",
		sizeof(struct libwebsocket_context),
		sizeof(struct libwebsocket_pollfd) +
					sizeof(struct libwebsocket *),
		context->max_fds,
		sizeof(struct libwebsocket_context) +
		((sizeof(struct libwebsocket_pollfd) +
					sizeof(struct libwebsocket *)) *
							     context->max_fds));

	context->fds = (struct libwebsocket_pollfd *)
				malloc(sizeof(struct libwebsocket_pollfd) *
							      context->max_fds);
	if (context->fds == NULL) {
		lwsl_err("Unable to allocate fds array for %d connections\n",
							      context->max_fds);
		free(context);
		return NULL;
	}

	context->lws_lookup = (struct libwebsocket **)
		      malloc(sizeof(struct libwebsocket *) * context->max_fds);
	if (context->lws_lookup == NULL) {
		lwsl_err(
		  "Unable to allocate lws_lookup array for %d connections\n",
							      context->max_fds);
		free(context->fds);
		free(context);
		return NULL;
	}
	memset(context->lws_lookup, 0, sizeof(struct libwebsocket *) *
							context->max_fds);

	if (lws_plat_init_fd_tables(context)) {
		free(context->lws_lookup);
		free(context->fds);
		free(context);
		return NULL;
	}

	lws_context_init_extensions(info, context);

	context->user_space = info->user;

	strcpy(context->canonical_hostname, "unknown");

	lws_server_get_canonical_hostname(context, info);

	/* split the proxy ads:port if given */

	if (info->http_proxy_address) {
		strncpy(context->http_proxy_address, info->http_proxy_address,
				      sizeof(context->http_proxy_address) - 1);
		context->http_proxy_address[
				sizeof(context->http_proxy_address) - 1] = '\0';
		context->http_proxy_port = info->http_proxy_port;
	} else {
#ifdef HAVE_GETENV
		p = getenv("http_proxy");
		if (p) {
			strncpy(context->http_proxy_address, p,
				       sizeof(context->http_proxy_address) - 1);
			context->http_proxy_address[
				sizeof(context->http_proxy_address) - 1] = '\0';

			p = strchr(context->http_proxy_address, ':');
			if (p == NULL) {
				lwsl_err("http_proxy needs to be ads:port\n");
				goto bail;
			}
			*p = '\0';
			context->http_proxy_port = atoi(p + 1);
		}
#endif
	}

	if (context->http_proxy_address[0])
		lwsl_notice(" Proxy %s:%u\n",
				context->http_proxy_address,
						      context->http_proxy_port);

	lwsl_notice(
		" per-conn mem: %u + %u headers + protocol rx buf\n",
				sizeof(struct libwebsocket),
					      sizeof(struct allocated_headers));
		
	if (lws_context_init_server_ssl(info, context))
		goto bail;
	
	if (lws_context_init_client_ssl(info, context))
		goto bail;

	if (lws_context_init_server(info, context))
		goto bail;

	/*
	 * drop any root privs for this process
	 * to listen on port < 1023 we would have needed root, but now we are
	 * listening, we don't want the power for anything else
	 */
	lws_plat_drop_app_privileges(info);

	/* initialize supported protocols */

	for (context->count_protocols = 0;
		info->protocols[context->count_protocols].callback;
						   context->count_protocols++) {

		lwsl_parser("  Protocol: %s\n",
				info->protocols[context->count_protocols].name);

		info->protocols[context->count_protocols].owning_server =
									context;
		info->protocols[context->count_protocols].protocol_index =
						       context->count_protocols;

		/*
		 * inform all the protocols that they are doing their one-time
		 * initialization if they want to
		 */
		info->protocols[context->count_protocols].callback(context,
			       NULL, LWS_CALLBACK_PROTOCOL_INIT, NULL, NULL, 0);
	}

	/*
	 * give all extensions a chance to create any per-context
	 * allocations they need
	 */

	if (info->port != CONTEXT_PORT_NO_LISTEN) {
		if (lws_ext_callback_for_each_extension_type(context, NULL,
				LWS_EXT_CALLBACK_SERVER_CONTEXT_CONSTRUCT,
								   NULL, 0) < 0)
			goto bail;
	} else
		if (lws_ext_callback_for_each_extension_type(context, NULL,
				LWS_EXT_CALLBACK_CLIENT_CONTEXT_CONSTRUCT,
								   NULL, 0) < 0)
			goto bail;

	return context;

bail:
	libwebsocket_context_destroy(context);
	return NULL;
}

/**
 * libwebsocket_context_destroy() - Destroy the websocket context
 * @context:	Websocket context
 *
 *	This function closes any active connections and then frees the
 *	context.  After calling this, any further use of the context is
 *	undefined.
 */
LWS_VISIBLE void
libwebsocket_context_destroy(struct libwebsocket_context *context)
{
	int n;
	struct libwebsocket_protocols *protocol = context->protocols;

	lwsl_notice("%s\n", __func__);

#ifdef LWS_LATENCY
	if (context->worst_latency_info[0])
		lwsl_notice("Worst latency: %s\n", context->worst_latency_info);
#endif

	for (n = 0; n < context->fds_count; n++) {
		struct libwebsocket *wsi =
					context->lws_lookup[context->fds[n].fd];
		if (!wsi)
			continue;
		libwebsocket_close_and_free_session(context,
			wsi, LWS_CLOSE_STATUS_NOSTATUS /* no protocol close */);
		n--;
	}

	/*
	 * give all extensions a chance to clean up any per-context
	 * allocations they might have made
	 */
	if (context->listen_port) {
		if (lws_ext_callback_for_each_extension_type(context, NULL,
			 LWS_EXT_CALLBACK_SERVER_CONTEXT_DESTRUCT, NULL, 0) < 0)
			return;
	} else
		if (lws_ext_callback_for_each_extension_type(context, NULL,
			 LWS_EXT_CALLBACK_CLIENT_CONTEXT_DESTRUCT, NULL, 0) < 0)
			return;

	/*
	 * inform all the protocols that they are done and will have no more
	 * callbacks
	 */

	while (protocol->callback) {
		protocol->callback(context, NULL, LWS_CALLBACK_PROTOCOL_DESTROY,
				NULL, NULL, 0);
		protocol++;
	}

	lws_plat_context_early_destroy(context);

	lws_ssl_context_destroy(context);

	if (context->fds)
		free(context->fds);
	if (context->lws_lookup)
		free(context->lws_lookup);

	lws_plat_context_late_destroy(context);

	free(context);
}
