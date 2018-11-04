#include "private-libwebsockets.h"

#include "build.h"

#if HOST_OS != OS_WINDOWS
/*
 * included from libwebsockets.c for unix builds
 */

unsigned long long time_in_microseconds(void)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (tv.tv_sec * 1000000) + tv.tv_usec;
}

LWS_VISIBLE int libwebsockets_get_random(struct libwebsocket_context *context,
							     void *buf, int len)
{
	return read(context->fd_random, (char *)buf, len);
}

LWS_VISIBLE int lws_send_pipe_choked(struct libwebsocket *wsi)
{
	struct libwebsocket_pollfd fds;

	/* treat the fact we got a truncated send pending as if we're choked */
	if (wsi->truncated_send_len)
		return 1;

	fds.fd = wsi->sock;
	fds.events = POLLOUT;
	fds.revents = 0;

	if (poll(&fds, 1, 0) != 1)
		return 1;

	if ((fds.revents & POLLOUT) == 0)
		return 1;

	/* okay to send another packet without blocking */

	return 0;
}

LWS_VISIBLE int
lws_poll_listen_fd(struct libwebsocket_pollfd *fd)
{
	return poll(fd, 1, 0);
}

/*
 * This is just used to interrupt poll waiting
 * we don't have to do anything with it.
 */
static void lws_sigusr2(int sig)
{
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
	char buf = 0;

	if (write(context->dummy_pipe_fds[1], &buf, sizeof(buf)) != 1)
		lwsl_err("Cannot write to dummy pipe");
}

LWS_VISIBLE void lwsl_emit_syslog(int level, const char *line)
{
/*
	int syslog_level = LOG_DEBUG;

	switch (level) {
	case LLL_ERR:
		syslog_level = LOG_ERR;
		break;
	case LLL_WARN:
		syslog_level = LOG_WARNING;
		break;
	case LLL_NOTICE:
		syslog_level = LOG_NOTICE;
		break;
	case LLL_INFO:
		syslog_level = LOG_INFO;
		break;
	}
	*/
	printf("%s", line);
}

LWS_VISIBLE int
lws_plat_service(struct libwebsocket_context *context, int timeout_ms)
{
	int n;
	int m;
	char buf;

	/* stay dead once we are dead */

	if (!context)
		return 1;

	lws_libev_run(context);

	context->service_tid = context->protocols[0].callback(context, NULL,
				     LWS_CALLBACK_GET_THREAD_ID, NULL, NULL, 0);

	n = poll(context->fds, context->fds_count, timeout_ms);
	context->service_tid = 0;

	if (n == 0) /* poll timeout */ {
		libwebsocket_service_fd(context, NULL);
		return 0;
	}

	if (n < 0) {
		if (LWS_ERRNO != LWS_EINTR)
			return -1;
		return 0;
	}

	/* any socket with events to service? */

	for (n = 0; n < context->fds_count; n++) {
		if (!context->fds[n].revents)
			continue;

		if (context->fds[n].fd == context->dummy_pipe_fds[0]) {
			if (read(context->fds[n].fd, &buf, 1) != 1)
				lwsl_err("Cannot read from dummy pipe.");
			continue;
		}

		m = libwebsocket_service_fd(context, &context->fds[n]);
		if (m < 0)
			return -1;
		/* if something closed, retry this slot */
		if (m)
			n--;
	}

	return 0;
}

LWS_VISIBLE int
lws_plat_set_socket_options(struct libwebsocket_context *context, int fd)
{
	int optval = 1;
	socklen_t optlen = sizeof(optval);

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__)
	struct protoent *tcp_proto;
#endif

	if (context->ka_time) {
		/* enable keepalive on this socket */
		optval = 1;
		if (setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE,
					     (const void *)&optval, optlen) < 0)
			return 1;

#if defined(__APPLE__) || defined(__FreeBSD__) || defined(__NetBSD__) || defined(__CYGWIN__)

		/*
		 * didn't find a way to set these per-socket, need to
		 * tune kernel systemwide values
		 */
#else
		/* set the keepalive conditions we want on it too */
		optval = context->ka_time;
		if (setsockopt(fd, IPPROTO_IP, TCP_KEEPIDLE,
					     (const void *)&optval, optlen) < 0)
			return 1;

		optval = context->ka_interval;
		if (setsockopt(fd, IPPROTO_IP, TCP_KEEPINTVL,
					     (const void *)&optval, optlen) < 0)
			return 1;

		optval = context->ka_probes;
		if (setsockopt(fd, IPPROTO_IP, TCP_KEEPCNT,
					     (const void *)&optval, optlen) < 0)
			return 1;
#endif
	}

	/* Disable Nagle */
	optval = 1;
#if !defined(__APPLE__) && !defined(__FreeBSD__) && !defined(__NetBSD__)
	setsockopt(fd, SOL_TCP, TCP_NODELAY, (const void *)&optval, optlen);
#else
	tcp_proto = getprotobyname("TCP");
	setsockopt(fd, tcp_proto->p_proto, TCP_NODELAY, &optval, optlen);
#endif

	/* We are nonblocking... */
	fcntl(fd, F_SETFL, O_NONBLOCK);

	return 0;
}

LWS_VISIBLE void
lws_plat_drop_app_privileges(struct lws_context_creation_info *info)
{
	if (info->gid != -1)
		if (setgid(info->gid))
			lwsl_warn("setgid: %s\n", strerror(LWS_ERRNO));
	if (info->uid != -1)
		if (setuid(info->uid))
			lwsl_warn("setuid: %s\n", strerror(LWS_ERRNO));	
}

LWS_VISIBLE int
lws_plat_init_fd_tables(struct libwebsocket_context *context)
{
	if (lws_libev_init_fd_table(context))
		/* libev handled it instead */
		return 0;

	if (pipe(context->dummy_pipe_fds)) {
		lwsl_err("Unable to create pipe\n");
		return 1;
	}

	/* use the read end of pipe as first item */
	context->fds[0].fd = context->dummy_pipe_fds[0];
	context->fds[0].events = LWS_POLLIN;
	context->fds[0].revents = 0;
	context->fds_count = 1;
	
	context->fd_random = open(SYSTEM_RANDOM_FILEPATH, O_RDONLY);
	if (context->fd_random < 0) {
		lwsl_err("Unable to open random device %s %d\n",
				    SYSTEM_RANDOM_FILEPATH, context->fd_random);
		return 1;
	}

	return 0;
}

static void sigpipe_handler(int x)
{
}


LWS_VISIBLE int
lws_plat_context_early_init(void)
{
	sigset_t mask;

	signal(SIGUSR2, lws_sigusr2);
	sigemptyset(&mask);
	sigaddset(&mask, SIGUSR2);

	sigprocmask(SIG_BLOCK, &mask, NULL);
	
	signal(SIGPIPE, sigpipe_handler);

	return 0;
}

LWS_VISIBLE void
lws_plat_context_early_destroy(struct libwebsocket_context *context)
{
}

LWS_VISIBLE void
lws_plat_context_late_destroy(struct libwebsocket_context *context)
{
	close(context->dummy_pipe_fds[0]);
	close(context->dummy_pipe_fds[1]);
	close(context->fd_random);
}

/* cast a struct sockaddr_in6 * into addr for ipv6 */

LWS_VISIBLE int
interface_to_sa(struct libwebsocket_context *context,
		const char *ifname, struct sockaddr_in *addr, size_t addrlen)
{
	int rc = -1;

	struct ifaddrs *ifr;
	struct ifaddrs *ifc;
#ifdef LWS_USE_IPV6
	struct sockaddr_in6 *addr6 = (struct sockaddr_in6 *)addr;
#endif

	getifaddrs(&ifr);
	for (ifc = ifr; ifc != NULL && rc; ifc = ifc->ifa_next) {
		if (!ifc->ifa_addr)
			continue;

		lwsl_info(" interface %s vs %s\n", ifc->ifa_name, ifname);

		if (strcmp(ifc->ifa_name, ifname))
			continue;

		switch (ifc->ifa_addr->sa_family) {
		case AF_INET:
#ifdef LWS_USE_IPV6
			if (LWS_IPV6_ENABLED(context)) {
				/* map IPv4 to IPv6 */
				bzero((char *)&addr6->sin6_addr,
						sizeof(struct in6_addr));
				addr6->sin6_addr.s6_addr[10] = 0xff;
				addr6->sin6_addr.s6_addr[11] = 0xff;
				memcpy(&addr6->sin6_addr.s6_addr[12],
					&((struct sockaddr_in *)ifc->ifa_addr)->sin_addr,
							sizeof(struct in_addr));
			} else
#endif
				memcpy(addr,
					(struct sockaddr_in *)ifc->ifa_addr,
						    sizeof(struct sockaddr_in));
			break;
#ifdef LWS_USE_IPV6
		case AF_INET6:
			if (rc >= 0)
				break;
			memcpy(&addr6->sin6_addr,
			  &((struct sockaddr_in6 *)ifc->ifa_addr)->sin6_addr,
						       sizeof(struct in6_addr));
			break;
#endif
		default:
			continue;
		}
		rc = 0;
	}

	freeifaddrs(ifr);
	
	return rc;
}

LWS_VISIBLE void
lws_plat_insert_socket_into_fds(struct libwebsocket_context *context,
						       struct libwebsocket *wsi)
{
	lws_libev_io(context, wsi, LWS_EV_START | LWS_EV_READ);
	context->fds[context->fds_count++].revents = 0;
}

LWS_VISIBLE void
lws_plat_delete_socket_from_fds(struct libwebsocket_context *context,
						struct libwebsocket *wsi, int m)
{
}

LWS_VISIBLE void
lws_plat_service_periodic(struct libwebsocket_context *context)
{
	/* if our parent went down, don't linger around */
	if (context->started_with_parent &&
			      kill(context->started_with_parent, 0) < 0)
		kill(getpid(), SIGTERM);
}

LWS_VISIBLE int
lws_plat_change_pollfd(struct libwebsocket_context *context,
		      struct libwebsocket *wsi, struct libwebsocket_pollfd *pfd)
{
	return 0;
}

LWS_VISIBLE int
lws_plat_open_file(const char* filename, unsigned long* filelen)
{
	struct stat stat_buf;
	int ret = open(filename, O_RDONLY);

	if (ret < 0)
		return LWS_INVALID_FILE;

	fstat(ret, &stat_buf);
	*filelen = stat_buf.st_size;
	return ret;
}

#ifdef LWS_USE_IPV6
LWS_VISIBLE const char *
lws_plat_inet_ntop(int af, const void *src, char *dst, int cnt)
{ 
	return inet_ntop(af, src, dst, cnt);
}
#endif
#endif