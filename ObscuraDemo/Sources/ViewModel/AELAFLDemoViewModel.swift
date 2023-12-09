//
//  AELAFLDemoViewModel.swift
//  ObscuraDemo
//
//  Created by Seunghun on 12/9/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Combine
import Foundation
import Obscura
import QuartzCore

final class AELAFLDemoViewModel: ObscuraViewModelProtocol {
    private let obscuraCamera = ObscuraCamera()
    var previewLayer: CALayer { obscuraCamera.previewLayer }
    
    @Published var shouldShowSettings = false
    @Published var iso: Float = .zero
    @Published var shutterSpeed: Float = .zero
    @Published var aperture: Float = .zero
    @Published var lockPoint: CGPoint? = nil
    @Published var isLocked = false
    @Published var isLockMode = false
    
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
        
        obscuraCamera.exposureLockPoint.combineLatest(obscuraCamera.focusLockPoint)
            .filter { $0 == $1 }
            .map { $0.0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$lockPoint)
        
        obscuraCamera.isExposureLocked.combineLatest(obscuraCamera.isFocusLocked)
            .map { $0 == $1 && $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocked)
        
        obscuraCamera.isExposureLocked.combineLatest(obscuraCamera.isFocusLocked)
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .filter { $0 == $1 && $0 }
            .map { _ in nil }
            .receive(on: DispatchQueue.main)
            .assign(to: &$lockPoint)
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
        try? obscuraCamera.unlockExposure()
        try? obscuraCamera.unlockFocus()
    }
    
    func didTap(point: CGPoint) {
        try? obscuraCamera.lockExposure(on: point)
        try? obscuraCamera.lockFocus(on: point)
    }
}