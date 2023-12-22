//
//  ObscuraCamera.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Combine
import AVFoundation

/// A class that wraps `AVCaptureDevice` and `AVCaptureSession` to provide a convenient interface for camera operations.
public final class ObscuraCamera {
    /// Errors that can occur while using ``ObscuraCamera``.
    public enum Errors: Error {
        /// Indicates that camera access is not authorized.
        case notAuthorized
    }
    
    // MARK: - Dependencies
    
    private var camera: AVCaptureDevice?
    private var captureSession = AVCaptureSession()
    
    // MARK: - Private Properties
    
    private let _previewLayer: AVCaptureVideoPreviewLayer
    @Published private var _isHDREnabled = false
    @Published private var _iso: Float = .zero
    @Published private var _shutterSpeed: Float = .zero
    @Published private var _aperture: Float = .zero
    @Published private var _exposureLockPoint: CGPoint?
    @Published private var _focusLockPoint: CGPoint?
    @Published private var _isExposureLocked: Bool = false
    @Published private var _isFocusLocked: Bool = false
    
    // MARK: - Public Properties
    
    /// A `Bool` value indicating whether the camera is running.
    @Published private(set) public var isRunning = false
    /// The layer that camera feed will be rendered on.
    public var previewLayer: CALayer { _previewLayer }
    /// A `Bool` value indicating whether the HDR mode is enabled.
    public var isHDREnabled: AnyPublisher<Bool, Never> { $_isHDREnabled.eraseToAnyPublisher() }
    /// The ISO value that the camera is currently using.
    public var iso: AnyPublisher<Float, Never> { $_iso.eraseToAnyPublisher() }
    /// The Shutter speed value that the camera is currently using.
    public var shutterSpeed: AnyPublisher<Float, Never> { $_shutterSpeed.eraseToAnyPublisher() }
    /// The Aperture f-number value that the camera is currently using.
    public var aperture: AnyPublisher<Float, Never> { $_aperture.eraseToAnyPublisher() }
    /// A `CGPoint` value indicating which point is being used for exposure lock.
    public var exposureLockPoint: AnyPublisher<CGPoint?, Never> { $_exposureLockPoint.eraseToAnyPublisher() }
    /// A `CGPoint` value indicating which point is being used for focus lock.
    public var focusLockPoint: AnyPublisher<CGPoint?, Never> { $_focusLockPoint.eraseToAnyPublisher() }
    /// A `Bool` value indicating whether the exposure is locked.
    public var isExposureLocked: AnyPublisher<Bool, Never> { $_isExposureLocked.eraseToAnyPublisher() }
    /// A `Bool` value indicating whether the focus is locked.
    public var isFocusLocked: AnyPublisher<Bool, Never> { $_isFocusLocked.eraseToAnyPublisher() }
    
    // MARK: - Initializers

    /// Creates an ``ObscuraCamera`` instance.
    ///
    /// - Important: Ensure to call ``setup()`` before utilizing the camera features.
    public init() {
        self._previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        captureSession.publisher(for: \.isRunning)
            .assign(to: &$isRunning)
    }
    
    // MARK: - Public Methods

    /// Sets up the camera.
    ///
    /// - Throws: Errors that occurred while configuring camera including authorization error.
    public func setup() async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw Errors.notAuthorized
        }
        
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        let input = try AVCaptureDeviceInput(device: camera)
        
        camera.publisher(for: \.isVideoHDREnabled)
            .assign(to: &$_isHDREnabled)

        camera.publisher(for: \.iso)
            .assign(to: &$_iso)
        
        camera.publisher(for: \.exposureDuration)
            .map { Float($0.seconds) }
            .assign(to: &$_shutterSpeed)
        
        camera.publisher(for: \.lensAperture)
            .assign(to: &$_aperture)
        
        camera.publisher(for: \.exposureMode)
            .map { $0 == .locked }
            .assign(to: &$_isExposureLocked)
        
        camera.publisher(for: \.focusMode)
            .map { $0 == .locked }
            .assign(to: &$_isFocusLocked)
        
        camera.publisher(for: \.exposurePointOfInterest)
            .dropFirst()
            .compactMap { [weak self] pointOfInterest in
                guard let point = self?._previewLayer.layerPointConverted(fromCaptureDevicePoint: pointOfInterest) else { return nil }
                return point
            }
            .assign(to: &$_exposureLockPoint)
        
        camera.publisher(for: \.focusPointOfInterest)
            .dropFirst()
            .compactMap { [weak self] pointOfInterest in
                guard let point = self?._previewLayer.layerPointConverted(fromCaptureDevicePoint: pointOfInterest) else { return nil }
                return point
            }
            .assign(to: &$_focusLockPoint)
        
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)
        self.camera = camera

        guard captureSession.canSetSessionPreset(.photo) else { return }
        captureSession.sessionPreset = .photo

        _previewLayer.videoGravity = .resizeAspectFill
        _previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
    }
    
    /// Sets the HDR mode.
    ///
    /// - Note: Subscribe ``isHDREnabled`` to receive update of HDR mode.
    ///
    /// - Parameters:
    ///     - isEnabled: Whether or not to enable the HDR mode.
    public func setHDRMode(isEnabled: Bool) throws {
        try camera?.lockForConfiguration()
        camera?.automaticallyAdjustsVideoHDREnabled = false
        camera?.isVideoHDREnabled = isEnabled
        camera?.unlockForConfiguration()
    }
    
    /// Locks the exposure on certain point.
    ///
    /// - Note: Unlock the exposure using ``unlockExposure()``
    ///
    /// - Parameters:
    ///     - point: The certain point on `previewLayer` to lock exposure.
    public func lockExposure(on point: CGPoint) throws {
        guard let camera, camera.isExposurePointOfInterestSupported else { return }
        _exposureLockPoint = nil
        try camera.lockForConfiguration()
        let pointOfInterest = _previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        camera.exposurePointOfInterest = pointOfInterest
        camera.exposureMode = .autoExpose
        camera.unlockForConfiguration()
    }
    
    /// Unlocks the exposure.
    public func unlockExposure() throws {
        guard let camera, camera.isExposurePointOfInterestSupported else { return }
        try camera.lockForConfiguration()
        let pointOfInterest = CGPoint(x: 0.5, y: 0.5)
        camera.exposurePointOfInterest = pointOfInterest
        camera.exposureMode = .continuousAutoExposure
        camera.unlockForConfiguration()
        _exposureLockPoint = nil
    }
    
    /// Locks the focus on certain point.
    ///
    /// - Note: Unlock the focus using ``unlockFocus()``
    ///
    /// - Parameters:
    ///     - point: The certain point on `previewLayer` to lock focus.
    public func lockFocus(on point: CGPoint) throws {
        guard let camera, camera.isFocusPointOfInterestSupported else { return }
        _focusLockPoint = nil
        try camera.lockForConfiguration()
        let pointOfInterest = _previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        camera.focusPointOfInterest = pointOfInterest
        camera.focusMode = .autoFocus
        camera.unlockForConfiguration()
    }
    
    /// Unlocks the focus.
    public func unlockFocus() throws {
        guard let camera, camera.isFocusPointOfInterestSupported else { return }
        try camera.lockForConfiguration()
        let pointOfInterest = CGPoint(x: 0.5, y: 0.5)
        camera.focusPointOfInterest = pointOfInterest
        camera.focusMode = .continuousAutoFocus
        camera.unlockForConfiguration()
        _focusLockPoint = nil
    }
}
