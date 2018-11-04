/*

Copyright 1993, 1994, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

 * Copyright 1993, 1994 NCR Corporation - Dayton, Ohio, USA
 *
 * All Rights Reserved
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name NCR not be used in advertising
 * or publicity pertaining to distribution of the software without specific,
 * written prior permission.  NCR makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 * NCR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN
 * NO EVENT SHALL NCR BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <sys/un.h>
#include <stropts.h>
#include <poll.h>
#include <tiuser.h>

#include <netdir.h>
#include <netconfig.h>


/*
 * This is the TLI implementation of the X Transport service layer
 */

typedef struct _TLItrans2dev {
    char	*transname;
    char	*protofamily;
    char	*devcotsname;
    char	*devcltsname;
    int	family;
} TLItrans2dev;

static TLItrans2dev TLItrans2devtab[] = {
	{"inet","inet","/dev/tcp","/dev/udp",AF_INET},
	{"tcp","inet","/dev/tcp","/dev/udp",AF_INET},
	{"tli","loopback","/dev/ticots","/dev/ticlts",AF_UNIX},
};

#define NUMTLIFAMILIES (sizeof(TLItrans2devtab)/sizeof(TLItrans2dev))
    
/*
 * The local TLI connection, is a form of a local connection, so use a
 * sockaddr_un for the address so that it will be treated just like the other
 * local transports such as UNIX domain sockets, pts, and named.
 */
    
#if defined(X11_t)
#define TLINODENAME	"TLI:xserver"
#endif
    
#if defined(XIM_t)
#define TLINODENAME	"TLI:xim"
#endif
    
#if defined(FS_t) || defined(FONT_t)
#define TLINODENAME	"TLI:fontserver"
#endif
    
#if defined(ICE_t)
#define TLINODENAME	"TLI:ICE"
#endif
    
#if defined(TEST_t)
#define TLINODENAME	"TLI:test"
#endif
    
#ifndef PORTBUFSIZE
#ifdef TRANS_SERVER
#define PORTBUFSIZE	64
#else
#ifdef TRANS_CLIENT
#define PORTBUFSIZE	64
#endif
#endif
#endif


/*
 * These are some utility function used by the real interface function below.
 */

static int
TRANS(TLISelectFamily)(char *family)

{
    int     i;
    
    PRMSG(3,"TLISelectFamily(%s)\n", family, 0,0 );
    
    for(i=0;i<NUMTLIFAMILIES;i++)
    {
	if( !strcmp(family,TLItrans2devtab[i].transname) )
	    return i;
    }
    return -1;
}


/*
 * This function gets the local address of the transport and stores it in the
 * XtransConnInfo structure for the connection.
 */

static int
TRANS(TLIGetAddr)(XtransConnInfo ciptr)

{
    Xtransaddr		sockname;
    struct netbuf	netbuf;
    
    PRMSG(3,"TLIGetAddr(%x)\n", ciptr, 0,0 );
    
    netbuf.buf=(char *)&sockname;
    netbuf.len=sizeof(sockname);
    netbuf.maxlen=sizeof(sockname);
    
    if( t_getname(ciptr->fd,&netbuf,LOCALNAME) < 0 )
    {
	PRMSG(1,"TLIGetAddr: t_getname(LOCALNAME) failed: %d\n",
	      errno, 0,0 );
	return -1;
    }
    
    PRMSG(4,"TLIGetAddr: got family %d len %d\n",
	  ((struct sockaddr *) &sockname)->sa_family ,netbuf.len, 0 );
    
    /*
     * Everything looks good: fill in the XtransConnInfo structure.
     */
    
    if( ciptr->addr )
	xfree(ciptr->addr);
    
    if( (ciptr->addr=(char *)xalloc(netbuf.len)) == NULL )
    {
	PRMSG(1, "TLIGetAddr: Can't allocate space for the addr\n",
	      0,0,0);
	return -1;
    }
    
    ciptr->family=((struct sockaddr *) &sockname)->sa_family;
    ciptr->addrlen=netbuf.len;
    memcpy(ciptr->addr,&sockname,ciptr->addrlen);
    
    return 0;
}


/*
 * This function gets the remote address of the socket and stores it in the
 * XtransConnInfo structure for the connection.
 */

static int
TRANS(TLIGetPeerAddr)(XtransConnInfo ciptr)

{
    Xtransaddr		sockname;
    struct netbuf	netbuf;
    
    PRMSG(3,"TLIGetPeerAddr(%x)\n", ciptr, 0,0 );
    
    netbuf.buf=(char *)&sockname;
    netbuf.len=sizeof(sockname);
    netbuf.maxlen=sizeof(sockname);
    
    if( t_getname(ciptr->fd,&netbuf,REMOTENAME) < 0 )
    {
	PRMSG(1,"TLIGetPeerAddr: t_getname(REMOTENAME) failed: %d\n",
	      errno, 0,0 );
	return -1;
    }
    
    PRMSG(4,"TLIGetPeerAddr: got family %d len %d\n",
	  ((struct sockaddr *) &sockname)->sa_family ,netbuf.len, 0 );
    
    /*
     * Everything looks good: fill in the XtransConnInfo structure.
     */
    
    if( ciptr->peeraddr )
	xfree(ciptr->peeraddr);
    
    if( (ciptr->peeraddr=(char *)xalloc(netbuf.len)) == NULL )
    {
	PRMSG(1,
	      "TLIGetPeerAddr: Can't allocate space for the addr\n",
	      0,0,0);
	return -1;
    }
    
    ciptr->peeraddrlen=netbuf.len;
    memcpy(ciptr->peeraddr,&sockname,ciptr->peeraddrlen);
    
    return 0;
}


/*
 * This function will establish a local name for the transport. This function
 * do extra work for the local tli connection. It must create a sockaddr_un
 * format address so that it will look like an AF_UNIX connection to the
 * higher layer.
 *
 * This function will only be called by the OPENC?TSClient() functions since
 * the local address is set up in the CreateListner() for the server ends.
 */

static int
TRANS(TLITLIBindLocal)(int fd, int family, char *port)

{
    struct sockaddr_un	*sunaddr=NULL;
    struct t_bind	*req=NULL;
    
    PRMSG(2, "TLITLIBindLocal(%d,%d,%s)\n", fd, family, port);
    
    if( family == AF_UNIX )
    {
	if( (req=(struct t_bind *)t_alloc(fd,T_BIND,0)) == NULL )
	{
	    PRMSG(1,
		  "TLITLIBindLocal() failed to allocate a t_bind\n",
		  0,0,0 );
	    return -1;
	}
	
	if( (sunaddr=(struct sockaddr_un *)
	     malloc(sizeof(struct sockaddr_un))) == NULL )
	{
	    PRMSG(1,
		  "TLITLIBindLocal: failed to allocate a sockaddr_un\n",
		  0,0,0 );
	    t_free((char *)req,T_BIND);
	    return -1;
	}
	
	sunaddr->sun_family=AF_UNIX;
	
#ifdef nuke
	if( *port == '/' ) { /* A full pathname */
	    (void) strcpy(sunaddr->sun_path, port);
	} else {
	    (void) sprintf(sunaddr->sun_path,"%s%s", TLINODENAME, port );
	}
#endif /*NUKE*/
	
	(void) sprintf(sunaddr->sun_path,"%s%d",
		       TLINODENAME, getpid()^time(NULL) );
	
	PRMSG(4, "TLITLIBindLocal: binding to %s\n",
	      sunaddr->sun_path, 0,0);
	
	req->addr.buf=(char *)sunaddr;
	req->addr.len=sizeof(*sunaddr);
	req->addr.maxlen=sizeof(*sunaddr);
    }
    
    if( t_bind(fd, req, NULL) < 0 )
    {
	PRMSG(1,
	      "TLIBindLocal: Unable to bind TLI device to %s\n",
	      port, 0,0 );
	if (sunaddr)
	    free((char *) sunaddr);
	if (req)
	    t_free((char *)req,T_BIND);
	return -1;
    }
    return 0;
}

static XtransConnInfo
TRANS(TLIOpen)(char *device)

{
    XtransConnInfo	ciptr;
    
    PRMSG(3,"TLIOpen(%s)\n", device, 0,0 );
    
    if( (ciptr=(XtransConnInfo)xcalloc(1,sizeof(struct _XtransConnInfo))) == NULL )
    {
	PRMSG(1, "TLIOpen: calloc failed\n", 0,0,0 );
	return NULL;
    }
    
    if( (ciptr->fd=t_open( device, O_RDWR, NULL )) < 0 )
    {
	PRMSG(1, "TLIOpen: t_open failed for %s\n", device, 0,0 );
	free(ciptr);
	return NULL;
    }
    
    return ciptr;
}


#ifdef TRANS_REOPEN

static XtransConnInfo
TRANS(TLIReopen)(char *device, int fd, char *port)

{
    XtransConnInfo	ciptr;
    
    PRMSG(3,"TLIReopen(%s,%d, %s)\n", device, fd, port );
    
    if (t_sync (fd) < 0)
    {
	PRMSG(1, "TLIReopen: t_sync failed\n", 0,0,0 );
	return NULL;
    }

    if( (ciptr=(XtransConnInfo)xcalloc(1,sizeof(struct _XtransConnInfo))) == NULL )
    {
	PRMSG(1, "TLIReopen: calloc failed\n", 0,0,0 );
	return NULL;
    }
    
    ciptr->fd = fd;
    
    return ciptr;
}

#endif /* TRANS_REOPEN */


static	int
TRANS(TLIAddrToNetbuf)(int tlifamily, char *host, char *port, 
		       struct netbuf *netbufp)

{
    struct netconfig *netconfigp;
    struct nd_hostserv	nd_hostserv;
    struct nd_addrlist *nd_addrlistp = NULL;
    void *handlep;
    long lport;
    
    PRMSG(3,"TLIAddrToNetbuf(%d,%s,%s)\n", tlifamily, host, port );
    
    if( (handlep=setnetconfig()) == NULL )
	return -1;

    lport = strtol (port, (char**)NULL, 10);
    if (lport < 1024 || lport > USHRT_MAX)
	return -1;
    
    nd_hostserv.h_host = host;
    if( port && *port ) {
	nd_hostserv.h_serv = port;
    } else {
	nd_hostserv.h_serv = NULL;
    }
    
    while( (netconfigp=getnetconfig(handlep)) != NULL )
    {
	if( strcmp(netconfigp->nc_protofmly,
		   TLItrans2devtab[tlifamily].protofamily) != 0 )
	    continue;
	PRMSG(5,"TLIAddrToNetbuf: Trying to resolve %s.%s for %s\n",
	      host, port, TLItrans2devtab[tlifamily].protofamily );
	if( netdir_getbyname(netconfigp,&nd_hostserv, &nd_addrlistp) == 0 )
	{
	    /* we have at least one address to use */
	    
	    PRMSG(5, "TLIAddrToNetbuf: found address for %s.%s\n", host, port, 0 );
	    PRMSG(5, "TLIAddrToNetbuf: %s\n",taddr2uaddr(netconfigp,nd_addrlistp->n_addrs),
		  0,0 );
	    
	    memcpy(netbufp->buf,nd_addrlistp->n_addrs->buf,
		   nd_addrlistp->n_addrs->len);
	    netbufp->len=nd_addrlistp->n_addrs->len;
	    endnetconfig(handlep);
	    return 0;
	}
    }
    endnetconfig(handlep);
    
    return -1;
}

/*
 * These functions are the interface supplied in the Xtransport structure
 */

#ifdef TRANS_CLIENT

static XtransConnInfo
TRANS(TLIOpenCOTSClient)(Xtransport *thistrans, char *protocol, 
			 char *host, char *port)

{
    XtransConnInfo	ciptr;
    int 		i;
    
    PRMSG(2,"TLIOpenCOTSClient(%s,%s,%s)\n", protocol, host, port );
    
    if( (i=TRANS(TLISelectFamily)(thistrans->TransName)) < 0 )
    {
	PRMSG(1,"TLIOpenCOTSClient: Unable to determine device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    if( (ciptr=TRANS(TLIOpen)(TLItrans2devtab[i].devcotsname)) == NULL )
    {
	PRMSG(1,"TLIOpenCOTSClient: Unable to open device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    if( TRANS(TLITLIBindLocal)(ciptr->fd,TLItrans2devtab[i].family,port) < 0 )
    {
	PRMSG(1,
	      "TLIOpenCOTSClient: ...TLITLIBindLocal() failed: %d\n",
	      errno, 0,0 );
	t_close(ciptr->fd);
	xfree(ciptr);
	return NULL;
    }
    
    if( TRANS(TLIGetAddr)(ciptr) < 0 )
    {
	PRMSG(1,
	      "TLIOpenCOTSClient: ...TLIGetAddr() failed: %d\n",
	      errno, 0,0 );
	t_close(ciptr->fd);
	xfree(ciptr);
	return NULL;
    }
    
    /* Save the TLIFamily for later use in TLIAddrToNetbuf() lookups */
    ciptr->index = i;
    
    return ciptr;
}

#endif /* TRANS_CLIENT */


#ifdef TRANS_SERVER

static XtransConnInfo
TRANS(TLIOpenCOTSServer)(Xtransport *thistrans, char *protocol, 
			 char *host, char *port)

{
    XtransConnInfo	ciptr;
    int 		i;
    
    PRMSG(2,"TLIOpenCOTSServer(%s,%s,%s)\n", protocol, host, port );
    
    if( (i=TRANS(TLISelectFamily)(thistrans->TransName)) < 0 )
    {
	PRMSG(1,
	      "TLIOpenCOTSServer: Unable to determine device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    if( (ciptr=TRANS(TLIOpen)(TLItrans2devtab[i].devcotsname)) == NULL )
    {
	PRMSG(1,
	      "TLIOpenCOTSServer: Unable to open device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    /* Set the family type */

    ciptr->family = TLItrans2devtab[i].family;


    /* Save the TLIFamily for later use in TLIAddrToNetbuf() lookups */
    
    ciptr->index = i;
    
    return ciptr;
}

#endif /* TRANS_SERVER */


#ifdef TRANS_CLIENT

static XtransConnInfo
TRANS(TLIOpenCLTSClient)(Xtransport *thistrans, char *protocol, 
			 char *host, char *port)

{
    XtransConnInfo	ciptr;
    int 		i;
    
    PRMSG(2,"TLIOpenCLTSClient(%s,%s,%s)\n", protocol, host, port );
    
    if( (i=TRANS(TLISelectFamily)(thistrans->TransName)) < 0 )
    {
	PRMSG(1,
	      "TLIOpenCLTSClient: Unable to determine device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    if( (ciptr=TRANS(TLIOpen)(TLItrans2devtab[i].devcltsname)) == NULL )
    {
	PRMSG(1,
	      "TLIOpenCLTSClient: Unable to open device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    if( TRANS(TLITLIBindLocal)(ciptr->fd,TLItrans2devtab[i].family,port) < 0 )
    {
	PRMSG(1,
	      "TLIOpenCLTSClient: ...TLITLIBindLocal() failed: %d\n",
	      errno, 0,0 );
	t_close(ciptr->fd);
	xfree(ciptr);
	return NULL;
    }
    
    if( TRANS(TLIGetAddr)(ciptr) < 0 )
    {
	PRMSG(1,
	      "TLIOpenCLTSClient: ...TLIGetPeerAddr() failed: %d\n",
	      errno, 0,0 );
	t_close(ciptr->fd);
	xfree(ciptr);
	return NULL;
    }
    
    return ciptr;
}			

#endif /* TRANS_CLIENT */


#ifdef TRANS_SERVER

static XtransConnInfo
TRANS(TLIOpenCLTSServer)(Xtransport *thistrans, char *protocol, 
			 char *host, char *port)

{
    XtransConnInfo	ciptr;
    int 		i;
    
    PRMSG(2,"TLIOpenCLTSServer(%s,%s,%s)\n", protocol, host, port );
    
    if( (i=TRANS(TLISelectFamily)(thistrans->TransName)) < 0 )
    {
	PRMSG(1,
	      "TLIOpenCLTSServer: Unable to determine device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    if( (ciptr=TRANS(TLIOpen)(TLItrans2devtab[i].devcltsname)) == NULL )
    {
	PRMSG(1,
	      "TLIOpenCLTSServer: Unable to open device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    return ciptr;
}			

#endif /* TRANS_SERVER */


#ifdef TRANS_REOPEN

static XtransConnInfo
TRANS(TLIReopenCOTSServer)(Xtransport *thistrans, int fd, char *port)

{
    XtransConnInfo	ciptr;
    int			i;
    
    PRMSG(2,"TLIReopenCOTSServer(%d, %s)\n", fd, port, 0 );
    
    if( (i=TRANS(TLISelectFamily)(thistrans->TransName)) < 0 )
    {
	PRMSG(1,
	      "TLIReopenCOTSServer: Unable to determine device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }

    if( (ciptr=TRANS(TLIReopen)(
	TLItrans2devtab[i].devcotsname, fd, port)) == NULL )
    {
	PRMSG(1,
	      "TLIReopenCOTSServer: Unable to open device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    /* Save the TLIFamily for later use in TLIAddrToNetbuf() lookups */
    
    ciptr->index = i;
    
    return ciptr;
}


static XtransConnInfo
TRANS(TLIReopenCLTSServer)(Xtransport *thistrans, int fd, char *port)

{
    XtransConnInfo	ciptr;
    int 		i;
    
    PRMSG(2,"TLIReopenCLTSServer(%d, %s)\n", fd, port, 0 );
    
    if( (i=TRANS(TLISelectFamily)(thistrans->TransName)) < 0 )
    {
	PRMSG(1,
	      "TLIReopenCLTSServer: Unable to determine device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }

    if( (ciptr=TRANS(TLIReopen)(
	TLItrans2devtab[i].devcltsname, fd, port)) == NULL )
    {
	PRMSG(1,
	      "TLIReopenCLTSServer: Unable to open device for %s\n",
	      thistrans->TransName, 0,0 );
	return NULL;
    }
    
    ciptr->index = i;

    return ciptr;
}			

#endif /* TRANS_REOPEN */


static int
TRANS(TLISetOption)(XtransConnInfo ciptr, int option, int arg)

{
    PRMSG(2,"TLISetOption(%d,%d,%d)\n", ciptr->fd, option, arg );
    
    return -1;
}


#ifdef TRANS_SERVER

static int
TRANS(TLICreateListener)(XtransConnInfo ciptr, struct t_bind *req)

{
    struct t_bind	*ret;
    
    PRMSG(2,"TLICreateListener(%x->%d,%x)\n", ciptr, ciptr->fd, req );
    
    if( (ret=(struct t_bind *)t_alloc(ciptr->fd,T_BIND,T_ALL)) == NULL )
    {
	PRMSG(1, "TLICreateListener: failed to allocate a t_bind\n",
	      0,0,0 );
	t_free((char *)req,T_BIND);
	return TRANS_CREATE_LISTENER_FAILED;
    }
    
    if( t_bind(ciptr->fd, req, ret) < 0 )
    {
	PRMSG(1, "TLICreateListener: t_bind failed\n", 0,0,0 );
	t_free((char *)req,T_BIND);
	t_free((char *)ret,T_BIND);
	return TRANS_CREATE_LISTENER_FAILED;
    }
    
    if( memcmp(req->addr.buf,ret->addr.buf,req->addr.len) != 0 )
    {
	PRMSG(1, "TLICreateListener: unable to bind to %x\n",
	      req, 0,0 );
	t_free((char *)req,T_BIND);
	t_free((char *)ret,T_BIND);
	return TRANS_ADDR_IN_USE;
    }
    
    /*
     * Everything looks good: fill in the XtransConnInfo structure.
     */
    
    if( (ciptr->addr=(char *)xalloc(ret->addr.len)) == NULL )
    {
	PRMSG(1,
	      "TLICreateListener: Unable to allocate space for the address\n",
	      0,0,0 );
	t_free((char *)req,T_BIND);
	t_free((char *)ret, T_BIND);
	return TRANS_CREATE_LISTENER_FAILED;
    }
    
    ciptr->addrlen=ret->addr.len;
    memcpy(ciptr->addr,ret->addr.buf,ret->addr.len);
    
    t_free((char *)req,T_BIND);
    t_free((char *)ret, T_BIND);
    
    return 0;
}


static int
TRANS(TLIINETCreateListener)(XtransConnInfo ciptr, char *port, unsigned int flags)

{
    char    portbuf[PORTBUFSIZE];
    struct t_bind	*req;
    struct sockaddr_in	*sinaddr;
    long		tmpport;
    
    PRMSG(2,"TLIINETCreateListener(%x->%d,%s)\n", ciptr,
	ciptr->fd, port ? port : "NULL" );
    
#ifdef X11_t
    /*
     * X has a well known port, that is transport dependent. It is easier
     * to handle it here, than try and come up with a transport independent
     * representation that can be passed in and resolved the usual way.
     *
     * The port that is passed here is really a string containing the idisplay
     * from ConnectDisplay().
     */
    
    if (is_numeric (port))
    {
	tmpport = X_TCP_PORT + strtol (port, (char**)NULL, 10);
	sprintf(portbuf,"%u", tmpport);
	port = portbuf;
    }
#endif
    
    if( (req=(struct t_bind *)t_alloc(ciptr->fd,T_BIND,T_ALL)) == NULL )
    {
	PRMSG(1,
	    "TLIINETCreateListener: failed to allocate a t_bind\n",
	    0,0,0 );
	return TRANS_CREATE_LISTENER_FAILED;
    }

    if( port && *port ) {
	if(TRANS(TLIAddrToNetbuf)(ciptr->index,HOST_SELF,port,&(req->addr)) < 0)
	{
	    PRMSG(1,
		  "TLIINETCreateListener: can't resolve name:HOST_SELF.%s\n",
		  port, 0,0 );
	    t_free((char *)req,T_BIND);
	    return TRANS_CREATE_LISTENER_FAILED;
	}
    } else {
	sinaddr=(struct sockaddr_in *) req->addr.buf;
	sinaddr->sin_family=AF_INET;
	sinaddr->sin_port=htons(0);
	sinaddr->sin_addr.s_addr=0;
    }

    /* Set the qlen */

    req->qlen=1;
    
    return TRANS(TLICreateListener)(ciptr, req);
}


static int
TRANS(TLITLICreateListener)(XtransConnInfo ciptr, char *port, unsigned int flags)

{
    struct t_bind	*req;
    struct sockaddr_un	*sunaddr;
    int 		ret_value;
    
    PRMSG(2,"TLITLICreateListener(%x->%d,%s)\n", ciptr, ciptr->fd,
	port ? port : "NULL");
    
    if( (req=(struct t_bind *)t_alloc(ciptr->fd,T_BIND,0)) == NULL )
    {
	PRMSG(1,
	      "TLITLICreateListener: failed to allocate a t_bind\n",
	      0,0,0 );
	return TRANS_CREATE_LISTENER_FAILED;
    }
    
    if( (sunaddr=(struct sockaddr_un *)
	 malloc(sizeof(struct sockaddr_un))) == NULL )
    {
	PRMSG(1,
	      "TLITLICreateListener: failed to allocate a sockaddr_un\n",
	      0,0,0 );
	t_free((char *)req,T_BIND);
	return TRANS_CREATE_LISTENER_FAILED;
    }
    
    sunaddr->sun_family=AF_UNIX;
    if( port && *port ) {
	if( *port == '/' ) { /* A full pathname */
	    (void) strcpy(sunaddr->sun_path, port);
	} else {
	    (void) sprintf(sunaddr->sun_path,"%s%s", TLINODENAME, port );
	}
    } else {
	(void) sprintf(sunaddr->sun_path,"%s%d", TLINODENAME, getpid());
    }
    
    req->addr.buf=(char *)sunaddr;
    req->addr.len=sizeof(*sunaddr);
    req->addr.maxlen=sizeof(*sunaddr);
    
    /* Set the qlen */
    
    req->qlen=1;
    
    ret_value = TRANS(TLICreateListener)(ciptr, req);

    free((char *) sunaddr);

    return ret_value;
}


static XtransConnInfo
TRANS(TLIAccept)(XtransConnInfo ciptr, int *status)

{
    struct t_call	*call;
    XtransConnInfo	newciptr;
    int	i;
    
    PRMSG(2,"TLIAccept(%x->%d)\n", ciptr, ciptr->fd, 0 );
    
    if( (call=(struct t_call *)t_alloc(ciptr->fd,T_CALL,T_ALL)) == NULL )
    {
	PRMSG(1, "TLIAccept() failed to allocate a t_call\n", 0,0,0 );
	*status = TRANS_ACCEPT_BAD_MALLOC;
	return NULL;
    }
    
    if( t_listen(ciptr->fd,call) < 0 )
    {
	extern char *t_errlist[];
	extern int t_errno;
	PRMSG(1, "TLIAccept() t_listen() failed\n", 0,0,0 );
	PRMSG(1, "TLIAccept: %s\n", t_errlist[t_errno], 0,0 );
	t_free((char *)call,T_CALL);
	*status = TRANS_ACCEPT_MISC_ERROR;
	return NULL;
    }
    
    /*
     * Now we need to set up the new endpoint for the incoming connection.
     */
    
    i=ciptr->index; /* Makes the next line more readable */
    
    if( (newciptr=TRANS(TLIOpen)(TLItrans2devtab[i].devcotsname)) == NULL )
    {
	PRMSG(1, "TLIAccept() failed to open a new endpoint\n", 0,0,0 );
	t_free((char *)call,T_CALL);
	*status = TRANS_ACCEPT_MISC_ERROR;
	return NULL;
    }
    
    if( TRANS(TLITLIBindLocal)(newciptr->fd,TLItrans2devtab[i].family,"") < 0 )
    {
	PRMSG(1,
	      "TLIAccept: TRANS(TLITLIBindLocal)() failed: %d\n",
	      errno, 0,0 );
	t_free((char *)call,T_CALL);
	t_close(newciptr->fd);
	xfree(newciptr);
	*status = TRANS_ACCEPT_MISC_ERROR;
	return NULL;
    }
    
    
    if( t_accept(ciptr->fd,newciptr->fd,call) < 0 )
    {
	extern char *t_errlist[];
	extern int t_errno;
	PRMSG(1, "TLIAccept() t_accept() failed\n", 0,0,0 );
	PRMSG(1, "TLIAccept: %s\n", t_errlist[t_errno], 0,0 );
	if( t_errno == TLOOK )
	{
	    int evtype = t_look(ciptr->fd);
	    PRMSG(1, "TLIAccept() t_look() returned %d\n", evtype,0,0 );
	    switch( evtype )
	    {
		case T_DISCONNECT:
		    if( t_rcvdis(ciptr->fd, NULL) < 0 )
		    {
			PRMSG(1, "TLIAccept() t_rcvdis() failed\n", 0,0,0 );
			PRMSG(1, "TLIAccept: %s\n", t_errlist[t_errno], 0,0 );
		    }
		    break;
		default:
		    break;
	    }
	}
	t_free((char *)call,T_CALL);
	t_close(newciptr->fd);
	free(newciptr);
	*status = TRANS_ACCEPT_FAILED;
	return NULL;
    }
    
    t_free((char *)call,T_CALL);
    
    if( TRANS(TLIGetAddr)(newciptr) < 0 )
    {
	PRMSG(1,
	      "TLIAccept: TRANS(TLIGetPeerAddr)() failed: %d\n",
	      errno, 0,0 );
	t_close(newciptr->fd);
	xfree(newciptr);
	*status = TRANS_ACCEPT_MISC_ERROR;
	return NULL;
    }
    
    if( TRANS(TLIGetPeerAddr)(newciptr) < 0 )
    {
	PRMSG(1,
	      "TLIAccept: TRANS(TLIGetPeerAddr)() failed: %d\n",
	      errno, 0,0 );
	t_close(newciptr->fd);
	xfree(newciptr->addr);
	xfree(newciptr);
	*status = TRANS_ACCEPT_MISC_ERROR;
	return NULL;
    }
    
    if( ioctl(newciptr->fd, I_POP,"timod") < 0 )
    {
	PRMSG(1, "TLIAccept() ioctl(I_POP, \"timod\") failed %d\n",
	      errno,0,0 );
	t_close(newciptr->fd);
	xfree(newciptr->addr);
	xfree(newciptr);
	*status = TRANS_ACCEPT_MISC_ERROR;
	return NULL;
    }
    
    if( ioctl(newciptr->fd, I_PUSH,"tirdwr") < 0 )
    {
	PRMSG(1, "TLIAccept() ioctl(I_PUSH,\"tirdwr\") failed %d\n",
	      errno,0,0 );
	t_close(newciptr->fd);
	xfree(newciptr->addr);
	xfree(newciptr);
	*status = TRANS_ACCEPT_MISC_ERROR;
	return NULL;
    }
    
    *status = 0;

    return newciptr;
}

#endif /* TRANS_SERVER */


#ifdef TRANS_CLIENT

static int
TRANS(TLIConnect)(XtransConnInfo ciptr, struct t_call *sndcall )

{
    PRMSG(2, "TLIConnect(%x->%d,%x)\n", ciptr, ciptr->fd, sndcall);
    
    if( t_connect(ciptr->fd,sndcall,NULL) < 0 )
    {
	extern char *t_errlist[];
	extern int t_errno;
	PRMSG(1, "TLIConnect() t_connect() failed\n", 0,0,0 );
	PRMSG(1, "TLIConnect: %s\n", t_errlist[t_errno], 0,0 );
	t_free((char *)sndcall,T_CALL);
	if (t_errno == TLOOK && t_look(ciptr->fd) == T_DISCONNECT)
	{
	    t_rcvdis(ciptr->fd,NULL);
	    return TRANS_TRY_CONNECT_AGAIN;
	}
	else
	    return TRANS_CONNECT_FAILED;
    }
    
    t_free((char *)sndcall,T_CALL);
    
    /*
     * Sync up the address fields of ciptr.
     */
    
    if( TRANS(TLIGetAddr)(ciptr) < 0 )
    {
	PRMSG(1,
	      "TLIConnect: ...TLIGetAddr() failed: %d\n",
	      errno, 0,0 );
	return TRANS_CONNECT_FAILED;
    }
    
    if( TRANS(TLIGetPeerAddr)(ciptr) < 0 )
    {
	PRMSG(1,
	      "TLIConnect: ...TLIGetPeerAddr() failed: %d\n",
	      errno, 0,0 );
	return TRANS_CONNECT_FAILED;
    }
    
    if( ioctl(ciptr->fd, I_POP,"timod") < 0 )
    {
	PRMSG(1, "TLIConnect() ioctl(I_POP,\"timod\") failed %d\n",
	      errno,0,0 );
	return TRANS_CONNECT_FAILED;
    }
    
    if( ioctl(ciptr->fd, I_PUSH,"tirdwr") < 0 )
    {
	PRMSG(1, "TLIConnect() ioctl(I_PUSH,\"tirdwr\") failed %d\n",
	      errno,0,0 );
	return TRANS_CONNECT_FAILED;
    }
    
    return 0;
}


static int
TRANS(TLIINETConnect)(XtransConnInfo ciptr, char *host, char *port)

{
    char	portbuf[PORTBUFSIZE];	
    struct	t_call	*sndcall;
    long	tmpport;
    
    PRMSG(2, "TLIINETConnect(%s,%s)\n", host, port, 0);
    
#ifdef X11_t
    /*
     * X has a well known port, that is transport dependant. It is easier
     * to handle it here, than try and come up with a transport independent
     * representation that can be passed in and resolved the usual way.
     *
     * The port that is passed here is really a string containing the idisplay
     * from ConnectDisplay().
     */
    
    if (is_numeric (port))
    {
	tmpport = X_TCP_PORT + strtol (port, (char**)NULL, 10);
	sprintf(portbuf,"%u", tmpport );
	port = portbuf;
    }
#endif
    
    if( (sndcall=(struct t_call *)t_alloc(ciptr->fd,T_CALL,T_ALL)) == NULL )
    {
	PRMSG(1, "TLIINETConnect() failed to allocate a t_call\n", 0,0,0 );
	return TRANS_CONNECT_FAILED;
    }
    
    if( TRANS(TLIAddrToNetbuf)(ciptr->index, host, port, &(sndcall->addr) ) < 0 )
    {
	PRMSG(1, "TLIINETConnect() unable to resolve name:%s.%s\n",
	      host, port, 0 );
	t_free((char *)sndcall,T_CALL);
	return TRANS_CONNECT_FAILED;
    }
    
    return TRANS(TLIConnect)(ciptr, sndcall );
}


static int
TRANS(TLITLIConnect)(XtransConnInfo ciptr, char *host, char *port)

{
    struct t_call	*sndcall;
    struct sockaddr_un	*sunaddr;
    int			ret_value;
    
    PRMSG(2, "TLITLIConnect(%s,%s)\n", host, port, 0);
    
    if( (sndcall=(struct t_call *)t_alloc(ciptr->fd,T_CALL,T_OPT|T_UDATA)) == NULL )
    {
	PRMSG(1, "TLITLIConnect() failed to allocate a t_call\n", 0,0,0 );
	return TRANS_CONNECT_FAILED;
    }
    
    if( (sunaddr=(struct sockaddr_un *)
	 malloc(sizeof(struct sockaddr_un))) == NULL )
    {
	PRMSG(1,
	      "TLITLIConnect: failed to allocate a sockaddr_un\n",
	      0,0,0 );
	t_free((char *)sndcall,T_CALL);
	return TRANS_CONNECT_FAILED;
    }
    
    sunaddr->sun_family=AF_UNIX;
    if( *port == '/' ||
	strncmp (port, TLINODENAME, strlen (TLINODENAME)) == 0) {
	/* Use the port as is */
	(void) strcpy(sunaddr->sun_path, port);
    } else {
	(void) sprintf(sunaddr->sun_path,"%s%s", TLINODENAME, port );
    }

    sndcall->addr.buf=(char *)sunaddr;
    sndcall->addr.len=sizeof(*sunaddr);
    sndcall->addr.maxlen=sizeof(*sunaddr);
    
    ret_value = TRANS(TLIConnect)(ciptr, sndcall );

    free((char *) sunaddr);

    return ret_value;
}

#endif /* TRANS_CLIENT */


static int
TRANS(TLIBytesReadable)(XtransConnInfo ciptr, BytesReadable_t *pend)

{
    int ret;
    struct pollfd filedes;

    PRMSG(2, "TLIByteReadable(%x->%d,%x)\n", ciptr, ciptr->fd, pend );

    /*
     * This function should detect hangup conditions. Use poll to check
     * if no data is present. On SVR4, the M_HANGUP message sits on the
     * streams head, and ioctl(N_READ) keeps returning 0 because there is
     * no data available. The hangup goes undetected, and the client hangs.
     */
    
    ret=ioctl(ciptr->fd, I_NREAD, (char *)pend);

    if( ret != 0 )
	return ret; /* Data present or error */


    /* Zero data, or POLLHUP message */

    filedes.fd=ciptr->fd;
    filedes.events=POLLIN;

    ret=poll(&filedes, 1, 0);
 
    if( ret == 0 ) {
	*pend=0;
	return 0; /* Really, no data */
	}

    if( ret < 0 )
	return -1; /* just pass back the error */

    if( filedes.revents & (POLLHUP|POLLERR) ) /* check for hangup */
	return -1;

    /* Should only get here if data arrived after the first ioctl() */
    return ioctl(ciptr->fd, I_NREAD, (char *)pend);
}


static int
TRANS(TLIRead)(XtransConnInfo ciptr, char *buf, int size)

{
    PRMSG(2, "TLIRead(%d,%x,%d)\n", ciptr->fd, buf, size );
    
    return read(ciptr->fd,buf,size);
}


static int
TRANS(TLIWrite)(XtransConnInfo ciptr, char *buf, int size)

{
    PRMSG(2, "TLIWrite(%d,%x,%d)\n", ciptr->fd, buf, size );
    
    return write(ciptr->fd,buf,size);
}


static int
TRANS(TLIReadv)(XtransConnInfo ciptr, struct iovec *buf, int size)

{
    PRMSG(2, "TLIReadv(%d,%x,%d)\n", ciptr->fd, buf, size );
    
    return READV(ciptr,buf,size);
}


static int
TRANS(TLIWritev)(XtransConnInfo ciptr, struct iovec *buf, int size)

{
    PRMSG(2, "TLIWritev(%d,%x,%d)\n", ciptr->fd, buf, size );
    
    return WRITEV(ciptr,buf,size);
}


static int
TRANS(TLIDisconnect)(XtransConnInfo ciptr)

{
    PRMSG(2, "TLIDisconnect(%x->%d)\n", ciptr, ciptr->fd, 0 );
    
    /*
     * Restore the TLI modules so that the connection can be properly shutdown.
     * This avoids the situation where a connection goes into the TIME_WAIT
     * state, and the address remains unavailable for a while.
     */
    ioctl(ciptr->fd, I_POP,"tirdwr");
    ioctl(ciptr->fd, I_PUSH,"timod");

    t_snddis(ciptr->fd,NULL);
    
    return 0;
}


static int
TRANS(TLIClose)(XtransConnInfo ciptr)

{
    PRMSG(2, "TLIClose(%x->%d)\n", ciptr, ciptr->fd, 0 );
    
    t_unbind(ciptr->fd);

    return (t_close(ciptr->fd));
}


static int
TRANS(TLICloseForCloning)(XtransConnInfo ciptr)

{
    /*
     * Don't unbind.
     */

    PRMSG(2, "TLICloseForCloning(%x->%d)\n", ciptr, ciptr->fd, 0 );
    
    return (t_close(ciptr->fd));
}


Xtransport	TRANS(TLITCPFuncs) = {
	/* TLI Interface */
	"tcp",
	0,
#ifdef TRANS_CLIENT
	TRANS(TLIOpenCOTSClient),
#endif /* TRANS_CLIENT */
#ifdef TRANS_SERVER
	NULL,
	TRANS(TLIOpenCOTSServer),
#endif /* TRANS_SERVER */
#ifdef TRANS_CLIENT
	TRANS(TLIOpenCLTSClient),
#endif /* TRANS_CLIENT */
#ifdef TRANS_SERVER
	TRANS(TLIOpenCLTSServer),
#endif /* TRANS_SERVER */
#ifdef TRANS_REOPEN
	TRANS(TLIReopenCOTSServer),
	TRANS(TLIReopenCLTSServer),
#endif
	TRANS(TLISetOption),
#ifdef TRANS_SERVER
	TRANS(TLIINETCreateListener),
	NULL,		       			/* ResetListener */
	TRANS(TLIAccept),
#endif /* TRANS_SERVER */
#ifdef TRANS_CLIENT
	TRANS(TLIINETConnect),
#endif /* TRANS_CLIENT */
	TRANS(TLIBytesReadable),
	TRANS(TLIRead),
	TRANS(TLIWrite),
	TRANS(TLIReadv),
	TRANS(TLIWritev),
	TRANS(TLIDisconnect),
	TRANS(TLIClose),
	TRANS(TLICloseForCloning),
};

#ifdef TRANS_SERVER
static char * inet_aliases[] = { "tcp", NULL };
#endif
Xtransport	TRANS(TLIINETFuncs) = {
	/* TLI Interface */
	"inet",
	TRANS_ALIAS,
#ifdef TRANS_CLIENT
	TRANS(TLIOpenCOTSClient),
#endif /* TRANS_CLIENT */
#ifdef TRANS_SERVER
	inet_aliases,
	TRANS(TLIOpenCOTSServer),
#endif /* TRANS_SERVER */
#ifdef TRANS_CLIENT
	TRANS(TLIOpenCLTSClient),
#endif /* TRANS_CLIENT */
#ifdef TRANS_SERVER
	TRANS(TLIOpenCLTSServer),
#endif /* TRANS_SERVER */
#ifdef TRANS_REOPEN
	TRANS(TLIReopenCOTSServer),
	TRANS(TLIReopenCLTSServer),
#endif
	TRANS(TLISetOption),
#ifdef TRANS_SERVER
	TRANS(TLIINETCreateListener),
	NULL,		       			/* ResetListener */
	TRANS(TLIAccept),
#endif /* TRANS_SERVER */
#ifdef TRANS_CLIENT
	TRANS(TLIINETConnect),
#endif /* TRANS_CLIENT */
	TRANS(TLIBytesReadable),
	TRANS(TLIRead),
	TRANS(TLIWrite),
	TRANS(TLIReadv),
	TRANS(TLIWritev),
	TRANS(TLIDisconnect),
	TRANS(TLIClose),
	TRANS(TLICloseForCloning),
};

Xtransport	TRANS(TLITLIFuncs) = {
	/* TLI Interface */
	"tli",
	0,
#ifdef TRANS_CLIENT
	TRANS(TLIOpenCOTSClient),
#endif /* TRANS_CLIENT */
#ifdef TRANS_SERVER
	NULL,
	TRANS(TLIOpenCOTSServer),
#endif /* TRANS_SERVER */
#ifdef TRANS_CLIENT
	TRANS(TLIOpenCLTSClient),
#endif /* TRANS_CLIENT */
#ifdef TRANS_SERVER
	TRANS(TLIOpenCLTSServer),
#endif /* TRANS_SERVER */
#ifdef TRANS_REOPEN
	TRANS(TLIReopenCOTSServer),
	TRANS(TLIReopenCLTSServer),
#endif
	TRANS(TLISetOption),
#ifdef TRANS_SERVER
	TRANS(TLITLICreateListener),
	NULL,		       			/* ResetListener */
	TRANS(TLIAccept),
#endif /* TRANS_SERVER */
#ifdef TRANS_CLIENT
	TRANS(TLITLIConnect),
#endif /* TRANS_CLIENT */
	TRANS(TLIBytesReadable),
	TRANS(TLIRead),
	TRANS(TLIWrite),
	TRANS(TLIReadv),
	TRANS(TLIWritev),
	TRANS(TLIDisconnect),
	TRANS(TLIClose),
	TRANS(TLICloseForCloning),
};
