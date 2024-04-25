//
//  AFLDemoViewModel.swift
//  ObscuraDemo
//
//  Created by Seunghun on 12/9/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

@preconcurrency import Combine
import Foundation
import Obscura
@preconcurrency import QuartzCore

final class AFLDemoViewModel: ObscuraViewModelProtocol {
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
            
            await obscuraCamera.focusLockPoint
                .receive(on: DispatchQueue.main)
                .assign(to: &$lockPoint)
            
            await obscuraCamera.isFocusLocked
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
        Task {
            guard isRunning == false else { return }
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
            try? await obscuraCamera.unlockFocus()
        }
    }
    
    func didTap(point: CGPoint) {
        Task {
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
