#include "private-libwebsockets.h"


#include "build.h"

#if HOST_OS == OS_WINDOWS

unsigned long long
time_in_microseconds()
{
#define DELTA_EPOCH_IN_MICROSECS 11644473600000000ULL
	FILETIME filetime;
	ULARGE_INTEGER datetime;

#ifdef _WIN32_WCE
	GetCurrentFT(&filetime);
#else
	GetSystemTimeAsFileTime(&filetime);
#endif

	/*
	 * As per Windows documentation for FILETIME, copy the resulting FILETIME structure to a
	 * ULARGE_INTEGER structure using memcpy (using memcpy instead of direct assignment can
	 * prevent alignment faults on 64-bit Windows).
	 */
	memcpy(&datetime, &filetime, sizeof(datetime));

	/* Windows file times are in 100s of nanoseconds. */
	return (datetime.QuadPart - DELTA_EPOCH_IN_MICROSECS) / 10;
}

#ifdef _WIN32_WCE
time_t time(time_t *t)
{
	time_t ret = time_in_microseconds() / 1000000;
	*t = ret;
	return ret;
}
#endif

LWS_VISIBLE int libwebsockets_get_random(struct libwebsocket_context *context,
							     void *buf, int len)
{
	int n;
	char *p = (char *)buf;

	for (n = 0; n < len; n++)
		p[n] = (unsigned char)rand();

	return n;
}

LWS_VISIBLE int lws_send_pipe_choked(struct libwebsocket *wsi)
{
	return wsi->sock_send_blocking;
}

LWS_VISIBLE int lws_poll_listen_fd(struct libwebsocket_pollfd *fd)
{
	fd_set readfds;
	struct timeval tv = { 0, 0 };

	assert(fd->events == LWS_POLLIN);

	FD_ZERO(&readfds);
	FD_SET(fd->fd, &readfds);

	return select(fd->fd + 1, &readfds, NULL, NULL, &tv);
}

/**
 * libwebsocket_cancel_service() - Cancel servicing of pending websocket activity
 * @context:	Websocket context
 *
 *	This function let a call to libwebsocket_service() waiting for a timeout
 *	immediately return.
 */
LWS_VISIBLE void
libwebsocket_cancel_service(struct libwebsocket_context *context)
{
	WSASetEvent(context->events[0]);
}

LWS_VISIBLE void lwsl_emit_syslog(int level, const char *line)
{
	lwsl_emit_stderr(level, line);
}

LWS_VISIBLE int
lws_plat_service(struct libwebsocket_context *context, int timeout_ms)
{
	int n;
	int i;
	DWORD ev;
	WSANETWORKEVENTS networkevents;
	struct libwebsocket_pollfd *pfd;

	/* stay dead once we are dead */

	if (context == NULL)
		return 1;

	context->service_tid = context->protocols[0].callback(context, NULL,
				     LWS_CALLBACK_GET_THREAD_ID, NULL, NULL, 0);

	for (i = 0; i < context->fds_count; ++i) {
		pfd = &context->fds[i];
		if (pfd->fd == context->listen_service_fd)
			continue;

		if (pfd->events & LWS_POLLOUT) {
			if (context->lws_lookup[pfd->fd]->sock_send_blocking)
				continue;
			pfd->revents = LWS_POLLOUT;
			n = libwebsocket_service_fd(context, pfd);
			if (n < 0)
				return n;
		}
	}

	ev = WSAWaitForMultipleEvents(context->fds_count + 1,
				     context->events, FALSE, timeout_ms, FALSE);
	context->service_tid = 0;

	if (ev == WSA_WAIT_TIMEOUT) {
		libwebsocket_service_fd(context, NULL);
		return 0;
	}

	if (ev == WSA_WAIT_EVENT_0) {
		WSAResetEvent(context->events[0]);
		return 0;
	}

	if (ev < WSA_WAIT_EVENT_0 || ev > WSA_WAIT_EVENT_0 + context->fds_count)
		return -1;

	pfd = &context->fds[ev - WSA_WAIT_EVENT_0 - 1];

	if (WSAEnumNetworkEvents(pfd->fd,
			context->events[ev - WSA_WAIT_EVENT_0],
					      &networkevents) == SOCKET_ERROR) {
		lwsl_err("WSAEnumNetworkEvents() failed with error %d\n",
								     LWS_ERRNO);
		return -1;
	}

	pfd->revents = networkevents.lNetworkEvents;

	if (pfd->revents & LWS_POLLOUT)
		context->lws_lookup[pfd->fd]->sock_send_blocking = FALSE;

	return libwebsocket_service_fd(context, pfd);
}

LWS_VISIBLE int
lws_plat_set_socket_options(struct libwebsocket_context *context, int fd)
{
	int optval = 1;
	int optlen = sizeof(optval);
	u_long optl = 1;
	DWORD dwBytesRet;
	struct tcp_keepalive alive;
	struct protoent *tcp_proto;
			
	if (context->ka_time) {
		/* enable keepalive on this socket */
		optval = 1;
		if (setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE,
					     (const char *)&optval, optlen) < 0)
			return 1;

		alive.onoff = TRUE;
		alive.keepalivetime = context->ka_time;
		alive.keepaliveinterval = context->ka_interval;

		if (WSAIoctl(fd, SIO_KEEPALIVE_VALS, &alive, sizeof(alive), 
					      NULL, 0, &dwBytesRet, NULL, NULL))
			return 1;
	}

	/* Disable Nagle */
	optval = 1;
	tcp_proto = getprotobyname("TCP");
	setsockopt(fd, tcp_proto->p_proto, TCP_NODELAY, (const char *)&optval, optlen);

	/* We are nonblocking... */
	ioctlsocket(fd, FIONBIO, &optl);

	return 0;
}

LWS_VISIBLE void
lws_plat_drop_app_privileges(struct lws_context_creation_info *info)
{
}

LWS_VISIBLE int
lws_plat_init_fd_tables(struct libwebsocket_context *context)
{
	context->events = (WSAEVENT *)malloc(sizeof(WSAEVENT) *
							(context->max_fds + 1));
	if (context->events == NULL) {
		lwsl_err("Unable to allocate events array for %d connections\n",
			context->max_fds);
		return 1;
	}
	
	context->fds_count = 0;
	context->events[0] = WSACreateEvent();
	
	context->fd_random = 0;

	return 0;
}

LWS_VISIBLE int
lws_plat_context_early_init(void)
{
	WORD wVersionRequested;
	WSADATA wsaData;
	int err;

	/* Use the MAKEWORD(lowbyte, highbyte) macro from Windef.h */
	wVersionRequested = MAKEWORD(2, 2);

	err = WSAStartup(wVersionRequested, &wsaData);
	if (!err)
		return 0;
	/*
	 * Tell the user that we could not find a usable
	 * Winsock DLL
	 */
	lwsl_err("WSAStartup failed with error: %d\n", err);

	return 1;
}

LWS_VISIBLE void
lws_plat_context_early_destroy(struct libwebsocket_context *context)
{
	if (context->events) {
		WSACloseEvent(context->events[0]);
		free(context->events);
	}
}

LWS_VISIBLE void
lws_plat_context_late_destroy(struct libwebsocket_context *context)
{
	WSACleanup();
}

LWS_VISIBLE int
interface_to_sa(struct libwebsocket_context *context,
		const char *ifname, struct sockaddr_in *addr, size_t addrlen)
{
	return -1;
}

LWS_VISIBLE void
lws_plat_insert_socket_into_fds(struct libwebsocket_context *context,
						       struct libwebsocket *wsi)
{
	context->fds[context->fds_count++].revents = 0;
	context->events[context->fds_count] = WSACreateEvent();
	WSAEventSelect(wsi->sock, context->events[context->fds_count], LWS_POLLIN);
}

LWS_VISIBLE void
lws_plat_delete_socket_from_fds(struct libwebsocket_context *context,
						struct libwebsocket *wsi, int m)
{
	WSACloseEvent(context->events[m + 1]);
	context->events[m + 1] = context->events[context->fds_count + 1];
}

LWS_VISIBLE void
lws_plat_service_periodic(struct libwebsocket_context *context)
{
}

LWS_VISIBLE int
lws_plat_change_pollfd(struct libwebsocket_context *context,
		      struct libwebsocket *wsi, struct libwebsocket_pollfd *pfd)
{
	long networkevents = LWS_POLLOUT | LWS_POLLHUP;
		
	if ((pfd->events & LWS_POLLIN))
		networkevents |= LWS_POLLIN;

	if (WSAEventSelect(wsi->sock,
			context->events[wsi->position_in_fds_table + 1],
					       networkevents) != SOCKET_ERROR)
		return 0;

	lwsl_err("WSAEventSelect() failed with error %d\n", LWS_ERRNO);

	return 1;
}

LWS_VISIBLE HANDLE
lws_plat_open_file(const char* filename, unsigned long* filelen)
{
	HANDLE ret;
	WCHAR buffer[MAX_PATH];

	MultiByteToWideChar(CP_UTF8, 0, filename, -1, buffer,
				sizeof(buffer) / sizeof(buffer[0]));
	ret = CreateFileW(buffer, GENERIC_READ, FILE_SHARE_READ,
				NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);

	if (ret != LWS_INVALID_FILE)
		*filelen = GetFileSize(ret, NULL);

	return ret;
}

LWS_VISIBLE const char *
lws_plat_inet_ntop(int af, const void *src, char *dst, int cnt)
{ 
	WCHAR *buffer;
	DWORD bufferlen = cnt;
	BOOL ok = FALSE;

	buffer = malloc(bufferlen);
	if (!buffer) {
		lwsl_err("Out of memory\n");
		return NULL;
	}

	if (af == AF_INET) {
		struct sockaddr_in srcaddr;
		bzero(&srcaddr, sizeof(srcaddr));
		srcaddr.sin_family = AF_INET;
		memcpy(&(srcaddr.sin_addr), src, sizeof(srcaddr.sin_addr));

		if (!WSAAddressToStringW((struct sockaddr*)&srcaddr, sizeof(srcaddr), 0, buffer, &bufferlen))
			ok = TRUE;
#ifdef LWS_USE_IPV6
	} else if (af == AF_INET6) {
		struct sockaddr_in6 srcaddr;
		bzero(&srcaddr, sizeof(srcaddr));
		srcaddr.sin6_family = AF_INET6;
		memcpy(&(srcaddr.sin6_addr), src, sizeof(srcaddr.sin6_addr));

		if (!WSAAddressToStringW((struct sockaddr*)&srcaddr, sizeof(srcaddr), 0, buffer, &bufferlen))
			ok = TRUE;
#endif
	} else
		lwsl_err("Unsupported type\n");

	if (!ok) {
		int rv = WSAGetLastError();
		lwsl_err("WSAAddressToString() : %d\n", rv);
	} else {
		if (WideCharToMultiByte(CP_ACP, 0, buffer, bufferlen, dst, cnt, 0, NULL) <= 0)
			ok = FALSE;
	}

	free(buffer);
	return ok ? dst : NULL;
}

#endif