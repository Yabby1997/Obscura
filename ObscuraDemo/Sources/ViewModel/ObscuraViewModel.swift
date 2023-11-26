//
//  ObscuraViewModel.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Combine
import Foundation
import Obscura
import QuartzCore

final class ObscuraViewModel: ObservableObject {
    private let obscuraCamera = ObscuraCamera()
    var previewLayer: CALayer { obscuraCamera.previewLayer }
    
    @Published var shouldShowSettings = false
    @Published var iso: Float = .zero
    @Published var shutterSpeed: Float = .zero
    @Published var aperture: Float = .zero
    
    init() {
        obscuraCamera.iso
            .receive(on: DispatchQueue.main)
            .assign(to: &$iso)
        
        obscuraCamera.shutterSpeed
            .receive(on: DispatchQueue.main)
            .assign(to: &$shutterSpeed)
        
        obscuraCamera.aperture
            .receive(on: DispatchQueue.main)
            .assign(to: &$aperture)
    }
    
    func onAppear() {
        Task {
            do {
                try await obscuraCamera.setup()
            } catch {
                if case ObscuraCamera.Errors.notAuthorized = error {
                    Task { @MainActor in
                        shouldShowSettings = true
                    }
                }
            }
        }
    }
}
