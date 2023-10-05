//
//  File.swift
//  
//
//  Created by Matheus Gois on 22/10/21.
//

import LanScanInternal
import CoreGraphics

public struct LanDevice {
    public var name: String
    public var ipAddress: String
    public var mac: String
    public var brand: String
}

public protocol LanScannerDelegate: AnyObject {
    func lanScanHasUpdatedProgress(_ progress: CGFloat, address: String)
    func lanScanDidFindNewDevice(_ device: LanDevice)
    func lanScanDidFinishScanning()
}

public class LanScanner: NSObject {

    // MARK: - Properties

    public var scanner: LanScan?
    public weak var delegate: LanScannerDelegate?

    // MARK: - Init

    public init(delegate: LanScannerDelegate?) {
        self.delegate = delegate
    }

    // MARK: - Methods

    public func stop() {
        scanner?.stop()
    }

    public func start() {
        scanner?.stop()
        scanner = LanScan(delegate: self)
        scanner?.start()
    }

    public func getCurrentWifiSSID() -> String? {
        nil // scanner?.getCurrentWifiSSID()
    }
}

extension LanScanner: LANScanDelegate {
    public func lanScanHasUpdatedProgress(_ counter: Int, address: String!) {
        let progress = CGFloat(counter) / CGFloat(MAX_IP_RANGE)
        delegate?.lanScanHasUpdatedProgress(progress, address: address)
    }

    public func lanScanDidFindNewDevice(_ device: [AnyHashable : Any]!) {
        guard let device = device as? [AnyHashable: String] else { return }
        delegate?.lanScanDidFindNewDevice(
            .init(
                name: device[DEVICE_NAME] ?? "",
                ipAddress: device[DEVICE_IP_ADDRESS] ?? "",
                mac: device[DEVICE_MAC] ?? "",
                brand: device[DEVICE_BRAND] ?? ""
            )
        )
    }

    public func lanScanDidFinishScanning() {
        delegate?.lanScanDidFinishScanning()
    }
}
