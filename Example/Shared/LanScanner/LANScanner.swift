//
//  LANScanner.swift
//  Pods
//
//  Created by Chris Anderson on 2/14/16.
//
//

#if canImport(UIKit)
import UIKit
// import ifaddrsOSX
#elseif os(iOS)
#if (arch(i386) || arch(x86_64))
    import ifaddrsiOSSim
    #else
    import ifaddrsiOS
#endif
#endif

public protocol LANScannerDelegate {
    /**
     Triggered when the scanning has discovered a new device
     */
    func LANScannerDiscovery(_ device: LANDevice)

    /**
     Triggered when all of the scanning has finished
     */
    func LANScannerFinished()

    /**
     Triggered when the scanner starts over
     */
    func LANScannerRestarted()

    /**
     Triggered when there is an error while scanning
     */
    func LANScannerFailed(_ error: NSError)
}

open class LANScanner: NSObject {

    public struct NetInfo {
        public let ip: String
        public let netmask: String
    }

    open var delegate: LANScannerDelegate?
    open var continuous: Bool = true

    var localAddress: String?
    var baseAddress: String?
    var currentHostAddress: Int = 0
    var timer: Timer?
    var netMask: String?
    var baseAddressEnd: Int = 0
    var timerIterationNumber: Int = 0

    var ping: SimplePing?

    public override init() {

        super.init()
    }

    public init(delegate: LANScannerDelegate, continuous: Bool) {

        super.init()

        self.delegate = delegate
        self.continuous = continuous
    }

    // MARK: - Actions
    open func startScan() {

        if let localAddress = LANScanner.getLocalAddress() {

            self.localAddress = localAddress.ip
            self.netMask = localAddress.netmask

            let netMaskComponents = addressParts(self.netMask!)
            let ipComponents = addressParts(self.localAddress!)

            if netMaskComponents.count == 4 && ipComponents.count == 4 {

                for _ in 0 ..< 4 {

                    self.baseAddress = "\(ipComponents[0]).\(ipComponents[1]).\(ipComponents[2])."
                    self.currentHostAddress = 0
                    self.timerIterationNumber = 0
                    self.baseAddressEnd = 255
                }

                self.timer = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(pingAddress), userInfo: nil, repeats: true)
            }
        } else {
            self.delegate?.LANScannerFailed(
                NSError(
                    domain: "LANScanner",
                    code: 101,
                    userInfo: [ "error": "Unable to find a local address" ]
                )
            )
        }
    }

    open func stopScan() {

        self.timer?.invalidate()
    }

    // MARK: - Ping helpers

    @objc func pingAddress() {

        self.currentHostAddress += 1
        let address = "\(self.baseAddress!)\(self.currentHostAddress)"

        if let hostName = LANScanner.getHostName(address) {
            ping = .init(hostName: hostName)
            ping?.delegate = self
        }

        ping?.start()

        if self.currentHostAddress >= 254 && !continuous {
            self.timer?.invalidate()
        }
    }

    @objc func pingResult(_ object: AnyObject) {

        self.timerIterationNumber += 1

        let success = object["status"] as! Bool
        if success {

            /// Send device to delegate
            let device = LANDevice()
            device.ipAddress = "\(self.baseAddress!)\(self.currentHostAddress)"
            if let hostName = LANScanner.getHostName(device.ipAddress) {
                device.hostName = hostName
            }

            self.delegate?.LANScannerDiscovery(device)
        }

        /// When you reach the end, either restart or call it quits
        if self.timerIterationNumber >= 254 {

            if continuous {
                self.timerIterationNumber = 0
                self.currentHostAddress = 0
                self.delegate?.LANScannerRestarted()
            } else {
                self.delegate?.LANScannerFinished()
            }
        }
    }

    // MARK: - Network methods
    public static func getHostName(_ ipaddress: String) -> String? {

        var hostName: String?
        var ifinfo: UnsafeMutablePointer<addrinfo>?

        /// Get info of the passed IP address
        if getaddrinfo(ipaddress, nil, nil, &ifinfo) == 0 {

            var ptr = ifinfo
            while ptr != nil {

                let interface = ptr!.pointee

                /// Parse the hostname for addresses
                var hst = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(interface.ai_addr, socklen_t(interface.ai_addrlen), &hst, socklen_t(hst.count),
                               nil, socklen_t(0), 0) == 0 {

                    if let address = String(validatingUTF8: hst) {
                        hostName = address
                    }
                }
                ptr = interface.ai_next
            }
            freeaddrinfo(ifinfo)
        }

        return hostName
    }

    public static func getLocalAddress() -> NetInfo? {
        var localAddress: NetInfo?

        /// Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0 {

            /// For each interface ...
            var ptr = ifaddr
            while ptr != nil {

                let interface = ptr!.pointee
                let flags = Int32(interface.ifa_flags)
                var addr = interface.ifa_addr.pointee

                /// Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
                if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                    if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {

                        /// Narrow it down to the interfaces matching Standard Ethernet
                        let name = String(cString: interface.ifa_name)
                        if name.range(of: "en") != nil {

                            /// Convert interface address to a human readable string
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(&addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                            nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                                if let address = String(validatingUTF8: hostname) {

                                    var net = interface.ifa_netmask.pointee
                                    var netmaskName = [CChar](repeating: 0, count: Int(NI_MAXHOST))

                                    if getnameinfo(&net, socklen_t(net.sa_len), &netmaskName, socklen_t(netmaskName.count),
                                                   nil, socklen_t(0), NI_NUMERICHOST) == 0 {
                                        if let netmask = String(validatingUTF8: netmaskName) {
                                            localAddress = NetInfo(ip: address, netmask: netmask)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                ptr = interface.ifa_next
            }
            freeifaddrs(ifaddr)
        }
        return localAddress
    }

    func addressParts(_ address: String) -> [String] {
        return address.components(separatedBy: ".")
    }
}

extension LANScanner: SimplePingDelegate {
    public func simplePing(_ pinger: SimplePing, didStart address: Data) {
        print(pinger.hostAddress, address)
    }

    public func simplePing(_ pinger: SimplePing, didFail error: Error) {
        print(pinger, error)
    }

    public func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        print(pinger)
    }

    public func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        print(pinger)
    }

    public func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        print(pinger)
    }

    public func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {
        print(pinger)
    }
}
