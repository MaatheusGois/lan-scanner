/*
 * main.swift
 * SimpleSwiftPing
 *
 * Created by François Lamboley on 13/06/2018.
 * Copyright © 2018 Frizlab. All rights reserved.
 */

import Foundation
import os.log

//
/// * *****************
// MARK: - Utilities
//   ***************** */
//
/// ** Returns the string representation of the supplied address.
//
// - parameter address: Contains a (struct sockaddr) with the address to render.
// - returns: A string representation of that address. */
// private func displayAddress(for address: Data) -> String {
//	var error = Int32(0)
//	let hostStrDataCount = Int(NI_MAXHOST)
//	var hostStrData = Data(count: hostStrDataCount)
//	hostStrData.withUnsafeMutableBytes{ (hostStrPtr: UnsafeMutablePointer<Int8>) in
//		address.withUnsafeBytes{ (sockaddrPtr: UnsafePointer<sockaddr>) in
//			error = getnameinfo(sockaddrPtr, socklen_t(address.count), hostStrPtr, socklen_t(hostStrDataCount), nil, 0, NI_NUMERICHOST)
//		}
//	}
//	
//	if error == 0, let hostStr = String(data: hostStrData, encoding: .ascii) {return hostStr}
//	else                                                                     {return "?"}
// }
//
/// ** Returns a short error string for the supplied error.
//
// - parameter error: The error to render.
// - returns: A short string representing that error. */
// private func shortError(from error: Error) -> String {
//	let nsError = error as NSError
//	
//	/* *** Handle DNS errors as a special case. *** */
//	if nsError.domain == kCFErrorDomainCFNetwork as String && nsError.code == Int(CFNetworkErrors.cfHostErrorUnknown.rawValue) {
//		if let failure = (nsError.userInfo[kCFGetAddrInfoFailureKey as String] as? NSNumber)?.int32Value,
//			failure != 0,
//			let failureCStr = gai_strerror(failure), let failureStr = String(cString: failureCStr, encoding: .ascii)
//		{
//			return failureStr /* To do things perfectly we should punny-decode the error message… */
//		}
//	}
//	
//	/* *** Otherwise try various properties of the error object. *** */
//	return nsError.localizedFailureReason ?? nsError.localizedDescription
// }
//
//
/// * ************
// MARK: - Main
//   ************ */
//
/// ** The main object for our tool.
//
// This exists primarily because SimplePing requires an object to act as its
// delegate. */
// class Main : SimplePingDelegate {
//	
//	let forceIPv4: Bool
//	let forceIPv6: Bool
//	
//	var pinger: SimplePing?
//	var sendTimer: Timer?
//	
//	init(forceIPv4 ipv4: Bool, forceIPv6 ipv6: Bool) {
//		forceIPv4 = ipv4
//		forceIPv6 = ipv6
//	}
//	
//	deinit {
//		pinger?.stop()
//		sendTimer?.invalidate()
//	}
//	
//	/** The Objective-C 'main' for this program.
//	
//	This creates a SimplePing object, configures it, and then runs the run loop
//	sending pings and printing the results.
//	
//	- parameter hostName: The host to ping. */
//	func run(hostName: String) {
//		assert(pinger == nil)
//		
//		let addressStyle: SimplePing.AddressStyle
//		switch (forceIPv4, forceIPv6) {
//		case (true, false): addressStyle = .icmpV4
//		case (false, true): addressStyle = .icmpV6
//		default:            addressStyle = .any
//		}
//		let p = SimplePing(hostName: hostName, addressStyle: addressStyle)
//		pinger = p
//		
//		p.delegate = self
//		p.start()
//		
//		repeat {
//			RunLoop.current.run(mode: .default, before: .distantFuture)
//		} while pinger != nil
//	}
//	
//	/** Sends a ping.
//	
//	Called to send a ping, both directly (as soon as the SimplePing object starts
//	up) and via a timer (to continue sending pings periodically). */
//	func sendPing() {
//		pinger!.sendPing(data: nil)
//	}
//	
//	func simplePing(_ pinger: SimplePing, didStart address: Data) {
//		assert(pinger === self.pinger)
//		
//		os_log("pinging %@", displayAddress(for: address))
//		
//		/* *** Send the first ping straight away. *** */
//		
//		sendPing()
//		
//		/* *** And start a timer to send the subsequent pings. *** */
//		
//		assert(sendTimer == nil)
//		sendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] timer in self?.sendPing() })
//	}
//	
//	func simplePing(_ pinger: SimplePing, didFail error: Error) {
//		assert(pinger === self.pinger)
//		
//		os_log("failed: %@", shortError(from: error))
//		
//		sendTimer?.invalidate()
//		sendTimer = nil
//		
//		/* No need to call -stop. The pinger will stop itself in this case. We do
//		 * however want to nil out pinger so that the runloop stops. */
//		
//		self.pinger = nil
//	}
//	
//	func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
//		assert(pinger === self.pinger)
//		
//		os_log("#%u sent", UInt(sequenceNumber))
//	}
//	
//	func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
//		assert(pinger === self.pinger)
//		
//		os_log("#%u send failed: %@", UInt(sequenceNumber), shortError(from: error))
//	}
//	
//	func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
//		assert(pinger === self.pinger)
//		
//		os_log("#%u received, size=%zu", UInt(sequenceNumber), size_t(packet.count))
//	}
//	
//	func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
//		assert(pinger === self.pinger)
//		
//		os_log("unexpected packet, size=%zu", size_t(packet.count))
//	}
//	
// }
//
//
//
// var retVal = EXIT_SUCCESS
// autoreleasepool{
//	var forceIPv4 = false
//	var forceIPv6 = false
//	
//	var ch: Int32
//	repeat {
//		ch = getopt(CommandLine.argc, CommandLine.unsafeArgv, "46")
//		
//		switch ch {
//		case -1: (/*nop*/)
//		case Int32(Character("4").unicodeScalars.first!.value): forceIPv4 = true
//		case Int32(Character("6").unicodeScalars.first!.value): forceIPv6 = true
//		case Int32(Character("?").unicodeScalars.first!.value): fallthrough
//		default: retVal = EXIT_FAILURE
//		}
//	} while ch != -1 && retVal == EXIT_SUCCESS
//	
//	if retVal == EXIT_SUCCESS && optind + 1 != CommandLine.argc {
//		retVal = EXIT_FAILURE
//	}
//	
//	if retVal == EXIT_FAILURE {
//		/* A print to stderr would be better… */
//		os_log("usage: %{public}@ [-4] [-6] host", CommandLine.arguments[0])
//	} else {
//		Main(forceIPv4: forceIPv4, forceIPv6: forceIPv6).run(hostName: CommandLine.arguments.last!)
//	}
// }
//
// exit(retVal)
