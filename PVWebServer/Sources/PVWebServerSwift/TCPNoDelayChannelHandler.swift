//
//  TCPNoDelayChannelHandler.swift
//  PVWebServer
//
//  Disables Nagle's algorithm on accepted HTTP connections (TCP_NODELAY).
//

import NIOCore

#if canImport(NIOPosix)
import NIOPosix
#endif

/// Sets `TCP_NODELAY` when a child channel becomes active.
final class TCPNoDelayChannelHandler: ChannelInboundHandler, RemovableChannelHandler {
    typealias InboundIn = Any

    func channelActive(context: ChannelHandlerContext) {
        _ = context.channel.setOption(ChannelOptions.socketOption(.tcp_nodelay), value: 1)
        context.fireChannelActive()
    }

    /// Factory for Hummingbird `HTTP1Channel.Configuration.additionalChannelHandlers`.
    static func make() -> [any RemovableChannelHandler] {
        [TCPNoDelayChannelHandler()]
    }
}
