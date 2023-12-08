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
import AVFoundation

final class ObscuraViewModel: ObservableObject {
    private let obscuraCamera = ObscuraCamera()
    var previewLayer: CALayer { obscuraCamera.previewLayer }
    
    @Published var shouldShowSettings = false
    @Published var iso: Float = .zero
    @Published var shutterSpeed: Float = .zero
    @Published var aperture: Float = .zero
    @Published var focusingPoint: CGPoint? = nil
    @Published var isFocused = false
    @Published var isAELMode = false
    
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
        
        obscuraCamera.exposureFocusLockStatus
            .map { status in
                switch status {
                case .idle: 
                    return nil
                case let .locked(point), let .seeking(point):
                    return point
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$focusingPoint)
        
        obscuraCamera.exposureFocusLockStatus
            .map { status in
                switch status {
                case .locked: return true
                case .seeking, .idle: return false
                }
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFocused)
        
        obscuraCamera.isExposureFocusLockMode
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAELMode)
    }
    
    func setupIfNeeded() {
        guard !obscuraCamera.isRunning else { return }
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
    
    func didTapUnlock() {
        try? obscuraCamera.unlockExposureAndFocus()
    }
    
    func didTap(point: CGPoint) {
        try? obscuraCamera.lockExposureAndFocus(on: point)
    }
}
