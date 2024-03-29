//
//  AELDemoViewModel.swift
//  ObscuraDemo
//
//  Created by Seunghun on 12/9/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Combine
import Foundation
import Obscura
import QuartzCore

final class AELDemoViewModel: ObscuraViewModelProtocol {
    private let obscuraCamera = ObscuraCamera()
    var previewLayer: CALayer { obscuraCamera.previewLayer }
    
    @Published var shouldShowSettings = false
    @Published var iso: Float = .zero
    @Published var shutterSpeed: Float = .zero
    @Published var aperture: Float = .zero
    @Published var lockPoint: CGPoint? = nil
    @Published var isLocked = false
    @Published var isLockMode = false
    @Published var isHDREnabled = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var captureResult: [URL]? = nil
    var maxZoomFactor: CGFloat { obscuraCamera.maxZoomFactor }
    
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
        
        obscuraCamera.exposureLockPoint
            .receive(on: DispatchQueue.main)
            .assign(to: &$lockPoint)
        
        obscuraCamera.isExposureLocked
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocked)
        
        obscuraCamera.isExposureLocked
            .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
            .filter { $0 }
            .map { _ in nil }
            .receive(on: DispatchQueue.main)
            .assign(to: &$lockPoint)
        
        obscuraCamera.isHDREnabled
            .receive(on: DispatchQueue.main)
            .assign(to: &$isHDREnabled)
        
        obscuraCamera.zoomFactor
            .receive(on: DispatchQueue.main)
            .assign(to: &$zoomFactor)
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
    
    func setHDRMode(isEnabled: Bool) {
        try? obscuraCamera.setHDRMode(isEnabled: isEnabled)
    }
    
    func didTapUnlock() {
        try? obscuraCamera.unlockExposure()
    }
    
    func didTap(point: CGPoint) {
        try? obscuraCamera.lockExposure(on: point)
    }
    
    func zoom(factor: CGFloat) {
        try? obscuraCamera.zoom(factor: factor)
    }
    
    func didTapShutter() {
        Task { @MainActor in
            let result = try? await obscuraCamera.capturePhoto()
            captureResult = [result?.imagePath, result?.videoPath]
                .compactMap { $0 }
                .map { URL.documentsDirectory.appending(path: $0) }
        }
    }
}
