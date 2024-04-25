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
        Task {
            await obscuraCamera.isRunning
                .receive(on: DispatchQueue.main)
                .assign(to: &$isRunning)
            
            await obscuraCamera.maxZoomFactor
                .receive(on: DispatchQueue.main)
                .assign(to: &$maxZoomFactor)
            
            await obscuraCamera.iso
                .receive(on: DispatchQueue.main)
                .assign(to: &$iso)
            
            await obscuraCamera.shutterSpeed
                .receive(on: DispatchQueue.main)
                .assign(to: &$shutterSpeed)
            
            await obscuraCamera.aperture
                .receive(on: DispatchQueue.main)
                .assign(to: &$aperture)
            
            let focusLockPoint = await obscuraCamera.focusLockPoint
            let exposureLockPoint = await obscuraCamera.exposureLockPoint
            focusLockPoint.combineLatest(exposureLockPoint)
                .filter { $0 == $1 }
                .map { $0.0 }
                .receive(on: DispatchQueue.main)
                .assign(to: &$lockPoint)
            
            let isFocusLocked = await obscuraCamera.isFocusLocked
            let isExposureLocked = await obscuraCamera.isExposureLocked
            isFocusLocked.combineLatest(isExposureLocked)
                .map { $0 == $1 && $0 }
                .receive(on: DispatchQueue.main)
                .assign(to: &$isLocked)
            
            await obscuraCamera.isFocusLocked
                .debounce(for: .seconds(1.5), scheduler: DispatchQueue.main)
                .filter { $0 }
                .map { _ in nil }
                .receive(on: DispatchQueue.main)
                .assign(to: &$lockPoint)
            
            await obscuraCamera.isHDREnabled
                .receive(on: DispatchQueue.main)
                .assign(to: &$isHDREnabled)
            
            await obscuraCamera.zoomFactor
                .receive(on: DispatchQueue.main)
                .assign(to: &$zoomFactor)
        }
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
