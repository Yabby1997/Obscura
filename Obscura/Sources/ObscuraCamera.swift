//
//  ObscuraCamera.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Combine
import Foundation
import AVFoundation

public final class ObscuraCamera {
    public enum ExposureFocusLockStatus {
        case idle
        case seeking(point: CGPoint)
        case locked(point: CGPoint)
    }
    
    public enum Errors: Error {
        case notAuthorized
    }
    
    private var captureSession = AVCaptureSession()
    private var camera: AVCaptureDevice?
    
    private let _previewLayer: AVCaptureVideoPreviewLayer
    public var previewLayer: CALayer { _previewLayer }
    
    @Published public private(set) var isRunning = false
    
    @Published private var _iso: Float = .zero
    public var iso: AnyPublisher<Float, Never> { $_iso.eraseToAnyPublisher() }
    
    @Published private var _shutterSpeed: Float = .zero
    public var shutterSpeed: AnyPublisher<Float, Never> { $_shutterSpeed.eraseToAnyPublisher() }
    
    @Published private var _aperture: Float = .zero
    public var aperture: AnyPublisher<Float, Never> { $_aperture.eraseToAnyPublisher() }
    
    private var tempPointOfInterest: CGPoint?
    private var tempExposureFocusLockStatus: ExposureFocusLockStatus?
    @Published private var _exposureFocusLockStatus: ExposureFocusLockStatus = .idle
    public var exposureFocusLockStatus: AnyPublisher<ExposureFocusLockStatus, Never> {
        $_exposureFocusLockStatus.eraseToAnyPublisher()
    }
    
    @Published private var _isExposureFocusLockMode: Bool = false
    public var isExposureFocusLockMode: AnyPublisher<Bool, Never> {
        $_isExposureFocusLockMode.eraseToAnyPublisher()
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    public init(feedbackProvidable: ObscuraCameraFeedbackProvidable? = nil) {
        self._previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        captureSession.publisher(for: \.isRunning)
            .assign(to: &$isRunning)
        
        $_exposureFocusLockStatus
            .sink { status in
                guard case .locked = status else { return }
                feedbackProvidable?.generateExposureFocusLockFeedback()
            }
            .store(in: &cancellables)
        
        $_exposureFocusLockStatus
            .map { [weak self] status -> ExposureFocusLockStatus in
                self?.tempExposureFocusLockStatus = status
                return status
            }
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] status in
                guard case let .locked(point) = status,
                      case let .locked(tempPoint) = self?.tempExposureFocusLockStatus,
                      point == tempPoint else { return }
                self?.tempPointOfInterest = nil
                self?._exposureFocusLockStatus = .idle
            }
            .store(in: &cancellables)
    }
    
    public func setup() async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw Errors.notAuthorized
        }
        
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        let input = try AVCaptureDeviceInput(device: camera)
        
        camera.publisher(for: \.iso)
            .assign(to: &$_iso)
        
        camera.publisher(for: \.exposureDuration)
            .map { Float($0.seconds) }
            .assign(to: &$_shutterSpeed)
        
        camera.publisher(for: \.lensAperture)
            .assign(to: &$_aperture)
        
        Publishers.CombineLatest4(
            camera.publisher(for: \.isAdjustingFocus),
            camera.publisher(for: \.isAdjustingExposure),
            camera.publisher(for: \.focusPointOfInterest),
            camera.publisher(for: \.exposurePointOfInterest)
        )
        .compactMap { [weak self] isAdjustingFocus, isAdjustingExposure, focusPointOfInterest, exposurePointOfInterest in
            guard let self, tempPointOfInterest == focusPointOfInterest else {
                return nil
            }
            let pointOfInterest = _previewLayer.layerPointConverted(fromCaptureDevicePoint: focusPointOfInterest)
            return (!isAdjustingFocus && !isAdjustingExposure && focusPointOfInterest == exposurePointOfInterest)
                ? .locked(point: pointOfInterest)
                : .seeking(point: pointOfInterest)
        }
        .assign(to: &$_exposureFocusLockStatus)
        
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)
        self.camera = camera
            
        _previewLayer.videoGravity = .resizeAspectFill
        _previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
    }
    
    public func lockExposureAndFocus(on point: CGPoint) throws {
        guard let camera,
              camera.isFocusPointOfInterestSupported,
              camera.isExposurePointOfInterestSupported else { return }

        try camera.lockForConfiguration()
        let pointOfInterest = _previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        camera.focusPointOfInterest = pointOfInterest
        camera.exposurePointOfInterest = pointOfInterest
        camera.focusMode = .autoFocus
        camera.exposureMode = .autoExpose
        camera.unlockForConfiguration()
        tempPointOfInterest = pointOfInterest
        _isExposureFocusLockMode = true
    }
    
    public func unlockExposureAndFocus() throws {
        guard let camera,
              camera.isFocusPointOfInterestSupported,
              camera.isExposurePointOfInterestSupported else { return }

        try? camera.lockForConfiguration()
        let pointOfInterest = CGPoint(x: 0.5, y: 0.5)
        camera.focusPointOfInterest = pointOfInterest
        camera.exposurePointOfInterest = pointOfInterest
        camera.focusMode = .continuousAutoFocus
        camera.exposureMode = .continuousAutoExposure
        camera.unlockForConfiguration()
        tempPointOfInterest = nil
        _exposureFocusLockStatus = .idle
        _isExposureFocusLockMode = false
    }
}
