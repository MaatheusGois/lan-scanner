//
//  Host.swift
//  Pods
//
//  Created by Chris Anderson on 10/24/16.
//
//

import Foundation

open class LANHost: NSObject {
    enum ResolveType {
        case name
        case address
        case current
    }
    internal var _info: String?
    internal var _type: ResolveType
    internal var _resolved = false
    internal var _names = [String]()
    internal var _addresses = [String]()

    internal init(_ info: String?, _ type: ResolveType) {
        _info = info
        _type = type
    }

    static internal let _current = LANHost(nil, .current)

    open class func current() -> LANHost {
        return _current
    }

    public convenience init(name: String?) {
        self.init(name, .name)
    }

    public convenience init(address: String) {
        self.init(address, .address)
    }

    open func isEqual(to aHost: LANHost) -> Bool {
        return false
    }

    internal func _resolveCurrent() {
        // TODO: cannot access getifaddrs here...
    }

    internal func _resolve() {
        if _resolved {
            return
        }
        if let info = _info {
            var flags: Int32 = 0
            switch _type {
            case .name:
                flags = AI_PASSIVE | AI_CANONNAME
                break
            case .address:
                flags = AI_PASSIVE | AI_CANONNAME | AI_NUMERICHOST
                break
            case .current:
                _resolveCurrent()
                return
            }
            var hints = addrinfo()
            hints.ai_family = PF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            hints.ai_flags = flags

            var res0: UnsafeMutablePointer<addrinfo>?
            let r = getaddrinfo(info, nil, &hints, &res0)
            if r != 0 {
                return
            }
            var res: UnsafeMutablePointer<addrinfo>? = res0
            while res != nil {
                let info = res!.pointee
                let family = info.ai_family
                if family != AF_INET && family != AF_INET6 {
                    res = info.ai_next
                    continue
                }
                let sa_len: socklen_t = socklen_t((family == AF_INET6) ? MemoryLayout<sockaddr_in6>.size : MemoryLayout<sockaddr_in>.size)
                let lookupInfo = { (content: inout [String], flags: Int32) in
                    let hname = UnsafeMutablePointer<Int8>.allocate(capacity: 1024)
                    if getnameinfo(info.ai_addr, sa_len, hname, 1024, nil, 0, flags) == 0 {
                        content.append(String(describing: hname))
                    }
//                    hname.deinitialize()
//                    hname.deallocate(capacity: 1024)
                }
                lookupInfo(&_addresses, NI_NUMERICHOST)
                lookupInfo(&_names, NI_NAMEREQD)
                lookupInfo(&_names, NI_NOFQDN|NI_NAMEREQD)
                res = info.ai_next
            }

            freeaddrinfo(res0)
        }

    }

    open var name: String? {
        return names.first
    }

    open var names: [String] {
        _resolve()
        return _names
    }

    open var address: String? {
        return addresses.first
    }

    open var addresses: [String] {
        _resolve()
        return _addresses
    }

    open var localizedName: String? {
        return nil
    }
}
