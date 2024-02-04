//
//  ContentView.swift
//  Shared
//
//  Created by Matheus Gois on 23/10/21.
//

import SwiftUI

struct ContentView: View, LANScannerDelegate {
    func LANScannerDiscovery(_ device: LANDevice) {
        print(device)
    }

    func LANScannerFinished() {
        print(#function)
    }

    func LANScannerRestarted() {
        print(#function)
    }

    func LANScannerFailed(_ error: NSError) {
        print(#function)
    }

//    @ObservedObject var viewModel = CountViewModel()
    @State var showAlert: Bool = false

    lazy var scanner = LANScanner(delegate: self, continuous: true)

    func startScan() {
        var mutatableSelf = self
        mutatableSelf.scanner.startScan()
    }

    var body: some View {
        Text(verbatim: "Teste")
            .onAppear {
                startScan()
            }
//        VStack(alignment: .leading) {
//            VStack {
//                HStack {
//                    Text(viewModel.title)
//                        .font(.title)
//                    Spacer()
//                    Button {
//                        viewModel.reload()
//                    } label: {
//                        Image(systemName: "repeat")
//                            .foregroundColor(.black)
//                    }
//                }
//                ProgressView(value: viewModel.progress)
//            }.padding()
//
//            List {
//                ForEach(viewModel.connectedDevices) { device in
//                    VStack(alignment: .leading) {
//                        Text(device.name)
//                            .font(.body)
//                        Text(device.mac)
//                            .font(.caption)
//                        Text(device.brand)
//                            .font(.footnote)
//                    }
//                    .onTapGesture {
//                        #if os(iOS)
//                            UIPasteboard.general.string = device.name
//                        #endif
//                    }
//                    .padding()
//
//                }
//            }.alert(isPresented: $viewModel.showAlert) {
//                Alert(
//                    title: Text("Scan Finished"),
//                    message: Text("Number of devices connected to your Local Area Network: \(viewModel.connectedDevices.count)")
//                )
//            }
//        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
