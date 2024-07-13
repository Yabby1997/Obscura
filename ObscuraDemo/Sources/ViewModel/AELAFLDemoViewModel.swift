//
//  AELAFLDemoViewModel.swift
//  ObscuraDemo
//
//  Created by Seunghun on 12/9/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

@preconcurrency import Combine
import Foundation
import Obscura
@preconcurrency import QuartzCore

final class AELAFLDemoViewModel: ObscuraViewModelProtocol {
    private let obscuraCamera = ObscuraCamera()
    let previewLayer: CALayer
    
    @Published var isRunning = false
    @Published var shouldShowSettings = false
    @Published var iso: Float = .zero
    @Published var shutterSpeed: Float = .zero
    @Published var aperture: Float = .zero
    @Published var lockPoint: CGPoint? = nil
    @Published var isLocked = false
    @Published var isHDREnabled = false
    @Published var zoomFactor: CGFloat = 1.0
    @Published var captureResult: [URL]? = nil
    @Published var maxZoomFactor: CGFloat = 1.0
    
    init() {
        previewLayer = obscuraCamera.previewLayer
        bind()
    }
    
    private func bind() {
        obscuraCamera.isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRunning)
        
        obscuraCamera.maxZoomFactor
            .receive(on: DispatchQueue.main)
            .assign(to: &$maxZoomFactor)
        
        obscuraCamera.iso
            .receive(on: DispatchQueue.main)
            .assign(to: &$iso)
        
        obscuraCamera.shutterSpeed
            .receive(on: DispatchQueue.main)
            .assign(to: &$shutterSpeed)
        
        obscuraCamera.aperture
            .receive(on: DispatchQueue.main)
            .assign(to: &$aperture)
        
        obscuraCamera.focusLockPoint.combineLatest(obscuraCamera.exposureLockPoint)
            .filter { $0 == $1 }
            .map { $0.0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$lockPoint)
        
        obscuraCamera.isFocusLocked.combineLatest(obscuraCamera.isExposureLocked)
            .map { $0 == $1 && $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLocked)
        
        obscuraCamera.isFocusLocked
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
        guard isRunning == false else { return }
        Task {
            do {
                try await obscuraCamera.setup()
            } catch {
                if case ObscuraCamera.Errors.notAuthorized = error {
                    shouldShowSettings = true
                }
            }
        }
    }
    
    func setHDRMode(isEnabled: Bool) {
        Task {
            try? await obscuraCamera.setHDRMode(isEnabled: isEnabled)
        }
    }
    
    func didTapUnlock() {
        Task {
            try? await obscuraCamera.unlockExposure()
            try? await obscuraCamera.unlockFocus()
        }
    }
    
    func didTap(point: CGPoint) {
        Task {
            try? await obscuraCamera.lockExposure(on: point)
            try? await obscuraCamera.lockFocus(on: point)
        }
    }
    
    func zoom(factor: CGFloat) {
        Task {
            try? await obscuraCamera.zoom(factor: factor)
        }
    }
    
    func didTapShutter() {
        Task {
            let result = try? await obscuraCamera.capturePhoto()
            captureResult = [result?.imagePath, result?.videoPath]
                .compactMap { $0 }
                .map { URL.documentsDirectory.appending(path: $0) }
        }
    }
}
