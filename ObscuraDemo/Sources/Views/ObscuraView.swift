//
//  ObscuraView.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import SwiftUI
//import PhotosUI

struct ObscuraView<ViewModel>: View where ViewModel: ObscuraViewModelProtocol {
    @StateObject var viewModel: ViewModel
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        ZStack {
            CameraViewRepresentable(previewLayer: viewModel.previewLayer)
                .ignoresSafeArea()
                .onTapGesture(coordinateSpace: .local) { point in
                    viewModel.didTap(point: point)
                }
            if let point = viewModel.lockPoint {
                Rectangle()
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.clear)
                    .border(viewModel.isLocked ? .green : .red, width: 5)
                    .position(point)
            }
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
            .allowsHitTesting(false)
            VStack {
                Spacer()
                if viewModel.isLocked {
                    Button {
                        viewModel.didTapUnlock()
                    } label: {
                        Text("Unlock")
                    }
                    .foregroundStyle(.yellow)
                    .font(.system(size: 18, weight: .bold))
                    .shadow(radius: 5)
                }
                HStack {
                    Text("Zoom")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 18, weight: .bold))
                        .shadow(radius: 5)
                    Slider(
                        value: .init {
                            viewModel.zoomFactor
                        } set: { newValue in
                            viewModel.zoom(factor: newValue)
                        },
                        in: 1...viewModel.maxZoomFactor
                    ) {}
                        .labelsHidden()
                }
                .padding(.horizontal)
                HStack {
                    Text("HDR")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 18, weight: .bold))
                        .shadow(radius: 5)
                    Toggle(isOn: Binding {
                        viewModel.isHDREnabled
                    } set: { newValue in
                        viewModel.setHDRMode(isEnabled: newValue)
                    }) {}
                        .labelsHidden()
                }
                Button {
                    viewModel.didTapShutter()
                } label: {
                    Circle()
                }
                .frame(width: 30, height: 30)
                .foregroundStyle(.red)
            }
        }
        .onAppear { viewModel.setupIfNeeded() }
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
        .sheet(
            isPresented: Binding(
                get: { viewModel.captureResult != nil },
                set: { _, _ in viewModel.captureResult = nil }
            )
        ){
            if let result = viewModel.captureResult {
                LivePhotoView(urls: result)
            }
        }
    }
}

//#Preview {
//    ObscuraView(viewModel: AELDemoViewModel())
//}
