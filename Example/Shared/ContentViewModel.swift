//
//  CountViewModel.swift
//  LanScannerExample
//
//  Created by Matheus Gois on 23/10/21.
//

import SwiftUI
import LanScanner

class CountViewModel: ObservableObject {

    // Properties

    @Published var connectedDevices = [LanDevice]()
    @Published var progress: CGFloat = .zero
    @Published var title: String = .init()
    @Published var showAlert = false

    private lazy var scanner = LanScanner(delegate: self)

    // Init

    init() {
        scanner.start()
    }

    // Methos

    func reload() {
        connectedDevices.removeAll()
        scanner.start()
    }
}

extension CountViewModel: LanScannerDelegate {
    func lanScanHasUpdatedProgress(_ progress: CGFloat, address: String) {
        self.progress = progress
        self.title = address
    }

    func lanScanDidFindNewDevice(_ device: LanDevice) {
        connectedDevices.append(device)
    }

    func lanScanDidFinishScanning() {
        showAlert = true
    }
}

extension LanDevice: Identifiable {
    public var id: UUID { .init() }
}
