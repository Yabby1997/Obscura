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
    public enum FocusingStatus {
        case idle
        case focusing(point: CGPoint)
        case focused(point: CGPoint)
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
    private var tempFocusingStatus: FocusingStatus?
    @Published private var _focusingStatus: FocusingStatus = .idle
    public var focusingStatus: AnyPublisher<FocusingStatus, Never> { $_focusingStatus.eraseToAnyPublisher() }
    
    public init() {
        self._previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        captureSession.publisher(for: \.isRunning)
            .assign(to: &$isRunning)
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
                ? .focused(point: pointOfInterest)
                : .focusing(point: pointOfInterest)
        }
        .assign(to: &$_focusingStatus)
        
        $_focusingStatus
            .map { [weak self] status in
                self?.tempFocusingStatus = status
                return status
            }
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .compactMap { [weak self] status in
                guard case let .focused(point) = status,
                      case let .focused(tempPoint) = self?.tempFocusingStatus,
                      point == tempPoint else { return nil }
                return .idle
            }
            .assign(to: &$_focusingStatus)
        
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)
        self.camera = camera
            
        _previewLayer.videoGravity = .resizeAspectFill
        _previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
    }
    
    public func focus(on point: CGPoint) throws {
        guard let camera,
              camera.isFocusPointOfInterestSupported,
              camera.isExposurePointOfInterestSupported else { return }

        try camera.lockForConfiguration()
        let pointOfInterest = _previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        camera.focusPointOfInterest = pointOfInterest
        camera.exposurePointOfInterest = pointOfInterest
        camera.focusMode = .continuousAutoFocus
        camera.exposureMode = .continuousAutoExposure
        camera.unlockForConfiguration()
        tempPointOfInterest = pointOfInterest
    }
}
