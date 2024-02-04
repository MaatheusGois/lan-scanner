/*
 * SimplePingDelegate.swift
 * SimpleSwiftPing
 *
 * Created by François Lamboley on 13/06/2018.
 * Copyright © 2018 Frizlab. All rights reserved.
 */

import Foundation



public protocol SimplePingDelegate : class {
	
	/** A SimplePing delegate callback, called once the object has started up.
	This is called shortly after you start the object to tell you that the object
	has successfully started. On receiving this callback, you can call
	`-sendPingWithData:` to send pings.
	
	If the object didn't start, `-simplePing:didFailWithError:` is called
	instead.
	
	- parameter pinger: The object issuing the callback.
	- parameter address: The address that's being pinged; at the time this
	delegate callback is made, this will have the same value as the `hostAddress`
	property. */
	func simplePing(_ pinger: SimplePing, didStart address: Data)
	
	/** A SimplePing delegate callback, called if the object fails to start up.
	
	This is called shortly after you start the object to tell you that the object
	has failed to start. The most likely cause of failure is a problem resolving
	`hostName`.
	
	By the time this callback is called, the object has stopped (that is, you
	don’t need to call `-stop` yourself).
	
	- parameter pinger: The object issuing the callback.
	- parameter error: Describes the failure. */
	func simplePing(_ pinger: SimplePing, didFail error: Error)
	
	/** A SimplePing delegate callback, called when the object has successfully
	sent a ping packet.
	
	Each call to `-sendPingWithData:` will result in either a
	`-simplePing:didSendPacket:sequenceNumber:` delegate callback or a
	`-simplePing:didFailToSendPacket:sequenceNumber:error:` delegate callback
	(unless you stop the object before you get the callback). These callbacks are
	currently delivered synchronously from within `-sendPingWithData:`, but this
	synchronous behaviour is not considered API.
	
	- parameter pinger: The object issuing the callback.
	- parameter packet: The packet that was sent; this includes the ICMP header
	(`ICMPHeader`) and the data you passed to `-sendPingWithData:` but does not
	include any IP-level headers.
	- parameter sequenceNumber: The ICMP sequence number of that packet. */
	func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16)
	
	/** A SimplePing delegate callback, called when the object fails to send a
	ping packet.
	
	Each call to `-sendPingWithData:` will result in either a
	`-simplePing:didSendPacket:sequenceNumber:` delegate callback or a
	`-simplePing:didFailToSendPacket:sequenceNumber:error:` delegate callback
	(unless you stop the object before you get the callback). These callbacks are
	currently delivered synchronously from within `-sendPingWithData:`, but this
	synchronous behaviour is not considered API.
	
	- parameter pinger: The object issuing the callback.
	- parameter packet: The packet that was not sent; see
	`-simplePing:didSendPacket:sequenceNumber:` for details.
	- parameter sequenceNumber: The ICMP sequence number of that packet.
	- parameter error: Describes the failure. */
	func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error)
	
	/** A SimplePing delegate callback, called when the object receives a ping
	response.
	
	If the object receives an ping response that matches a ping request that it
	sent, it informs the delegate via this callback.  Matching is primarily done
	based on the ICMP identifier, although other criteria are used as well.
	
	- parameter pinger: The object issuing the callback.
	- parameter packet: The packet received; this includes the ICMP header
	(`ICMPHeader`) and any data that follows that in the ICMP message but does
	not include any IP-level headers.
	- parameter sequenceNumber: The ICMP sequence number of that packet. */
	func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16)
	
	/** A SimplePing delegate callback, called when the object receives an
	unmatched ICMP message.
	
	If the object receives an ICMP message that does not match a ping request
	that it sent, it informs the delegate via this callback. The nature of ICMP
	handling in a BSD kernel makes this a common event because, when an ICMP
	message arrives, it is delivered to all ICMP sockets.
	
	- important: This callback is especially common when using IPv6 because IPv6
	uses ICMP for important network management functions. For example, IPv6
	routers periodically send out Router Advertisement (RA) packets via Neighbor
	Discovery Protocol (NDP), which is implemented on top of ICMP.
	
	For more on matching, see the discussion associated with
	`-simplePing:didReceivePingResponsePacket:sequenceNumber:`.
	
	- parameter pinger: The object issuing the callback.
	- parameter packet: The packet received; this includes the ICMP header
	(`ICMPHeader`) and any data that follows that in the ICMP message but does
	not include any IP-level headers. */
	func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data)
	
}
