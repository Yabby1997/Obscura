//
//  ObscuraView.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import SwiftUI

struct ObscuraView: View {
    @StateObject var viewModel: ObscuraViewModel
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            CameraViewRepresentable(previewLayer: viewModel.previewLayer)
                .ignoresSafeArea()
            VStack {
                HStack {
                    ResultView(
                        title: "ISO",
                        value: "\(Int(viewModel.iso))"
                    )
                    ResultView(
                        title: "Shutter",
                        value: String(format: "%.3fs", viewModel.shutterSpeed)
                    )
                    ResultView(
                        title: "Aperture",
                        value: String(format: "ƒ%.1f", viewModel.aperture)
                    )
                }
                Spacer()
            }
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            viewModel.setupIfNeeded()
        }
        .alert(isPresented: $viewModel.shouldShowSettings) {
            Alert(
                title: Text("Camera access is required"),
                primaryButton: .default(Text("Open Settings")) {
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsUrl)
                },
                secondaryButton: .destructive(Text("Quit")) {
                    fatalError("Can't demo without camera access")
                }
            )
        }
    }
}

#Preview {
    ObscuraView(viewModel: ObscuraViewModel())
}
