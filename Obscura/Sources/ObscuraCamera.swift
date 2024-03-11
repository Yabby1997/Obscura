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
public final class ObscuraCamera: NSObject {
    /// Errors that can occur while using ``ObscuraCamera``.
    public enum Errors: Error {
        /// Indicates that camera access is not authorized.
        case notAuthorized
        /// Indicates that setup is not done properly.
        case setupRequired
        /// Indicates that the action requested is not supported.
        case notSupported
        /// Indicates that the capturing has been failed.
        case failedToCapture
    }
    
    // MARK: - Dependencies
    
    private var camera: AVCaptureDevice?
    private let captureSession = AVCaptureSession()
    private let photoOutput =  AVCapturePhotoOutput()
    
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
    @Published private var _zoomFactor: CGFloat = 1
    @Published private var _isCapturing = false
    
    private var photoContinuation: CheckedContinuation<String, Error>?
    private var videoContinuation: CheckedContinuation<String, Error>?
    
    private let imageDirectory = URL.homeDirectory.appending(path: "Documents/Obscura/Images")
    private let videoDirectory = URL.homeDirectory.appending(path: "Documents/Obscura/Videos")
    
    // MARK: - Public Properties
    
    /// A `Bool` value indicating whether the camera is running.
    @Published private(set) public var isRunning = false
    /// A `CGFloat` value indicating the maximum zoom factor.
    @Published private(set) public var maxZoomFactor: CGFloat = .infinity
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
    /// A `CGFloat` value indicating the current zoom factor.
    public var zoomFactor: AnyPublisher<CGFloat, Never> { $_zoomFactor.eraseToAnyPublisher() }
    /// A `Bool` value indicating the camera is currently capturing.
    public var isCapturing: AnyPublisher<Bool, Never> { $_isCapturing.eraseToAnyPublisher() }
    
    
    // MARK: - Initializers
    
    /// Creates an ``ObscuraCamera`` instance.
    ///
    /// - Important: Ensure to call ``setup()`` before utilizing the camera features.
    public override init() {
        self._previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        super.init()
        
        captureSession.publisher(for: \.isRunning)
            .assign(to: &$isRunning)
    }
    
    private func createDirectoryIfNeeded(for path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            print("Directory Exists: \(path)")
            return
        }
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )
        print("Directory Created: \(path)")
    }
    
    // MARK: - Public Methods
    
    /// Sets up the ``ObscuraCamera``.
    ///
    /// Call this method prior to using the camera. If this method fails, any of its functionality will not work properly.
    ///
    /// - Throws: Errors that occurred while configuring the camera, including authorization error.
    ///
    /// - Important: If it throws an authorization error, ``Errors/notAuthorized``, you must guide your user to manually grant authorization to use the camera and then call this method to try again.
    /// - Note: The LivePhoto and video capture features require microphone usage authorization as well. However, unlike the camera, microphone usage is not mandatory and is omitted in this method. To request microphone usage authorization, call ``requestMicAuthorization()``.
    public func setup() async throws {
        try createDirectoryIfNeeded(for: imageDirectory.path)
        try createDirectoryIfNeeded(for: videoDirectory.path)

        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw Errors.notAuthorized
        }
        
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        let cameraInput = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(cameraInput) else { return }
        captureSession.addInput(cameraInput)
        self.camera = camera
        
        camera.publisher(for: \.isVideoHDREnabled)
            .assign(to: &$_isHDREnabled)
        
        camera.publisher(for: \.maxAvailableVideoZoomFactor)
            .assign(to: &$maxZoomFactor)
        
        camera.publisher(for: \.videoZoomFactor)
            .assign(to: &$_zoomFactor)
        
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
        
        guard captureSession.canAddOutput(photoOutput) else { return }
        captureSession.addOutput(photoOutput)
        photoOutput.connection(with: .video)?.videoOrientation = .portrait
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        
        guard captureSession.canSetSessionPreset(.photo) else { return }
        captureSession.sessionPreset = .photo
        
        _previewLayer.videoGravity = .resizeAspectFill
        _previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
    }
    
    /// Requests microphone usage authorization for ``ObscuraCamera``.
    ///
    /// Call this method along with ``setup()`` if audio recording is required for LivePhoto or video capture features.
    ///
    /// - Note: Although it may fail to acquire authorization, LivePhoto and video will be captured without audio recording.
    ///
    /// - Throws: An error of type ``Errors`` indicating failure to acquire microphone usage authorization.
    public func requestMicAuthorization() async throws {
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw Errors.notAuthorized
        }
    }

    /// Sets the zoom factor.
    ///
    /// - Parameters:
    ///     - factor: The zoom factor.
    public func zoom(factor: CGFloat) throws {
        guard let camera else { throw Errors.setupRequired }
        try camera.lockForConfiguration()
        camera.ramp(toVideoZoomFactor: min(factor, maxZoomFactor), withRate: 30)
        camera.unlockForConfiguration()
    }
    
    /// Sets the HDR mode.
    ///
    /// - Note: Subscribe ``isHDREnabled`` to receive update of HDR mode.
    ///
    /// - Parameters:
    ///     - isEnabled: Whether or not to enable the HDR mode.
    public func setHDRMode(isEnabled: Bool) throws {
        guard let camera else { throw Errors.setupRequired }
        guard camera.activeFormat.isVideoHDRSupported else { throw Errors.notSupported }
        try camera.lockForConfiguration()
        camera.automaticallyAdjustsVideoHDREnabled = false
        camera.isVideoHDREnabled = isEnabled
        camera.unlockForConfiguration()
    }
    
    /// Locks the exposure on certain point.
    ///
    /// - Note: Unlock the exposure using ``unlockExposure()``
    ///
    /// - Parameters:
    ///     - point: The certain point on `previewLayer` to lock exposure.
    public func lockExposure(on point: CGPoint) throws {
        guard let camera else { throw Errors.setupRequired }
        guard camera.isExposurePointOfInterestSupported else { throw Errors.notSupported }
        _exposureLockPoint = nil
        try camera.lockForConfiguration()
        let pointOfInterest = _previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        camera.exposurePointOfInterest = pointOfInterest
        camera.exposureMode = .autoExpose
        camera.unlockForConfiguration()
    }
    
    /// Unlocks the exposure.
    public func unlockExposure() throws {
        guard let camera else { throw Errors.setupRequired }
        guard camera.isExposurePointOfInterestSupported else { throw Errors.notSupported }
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
        guard let camera else { throw Errors.setupRequired }
        guard camera.isFocusPointOfInterestSupported else { throw Errors.notSupported }
        _focusLockPoint = nil
        try camera.lockForConfiguration()
        let pointOfInterest = _previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        camera.focusPointOfInterest = pointOfInterest
        camera.focusMode = .autoFocus
        camera.unlockForConfiguration()
    }
    
    /// Unlocks the focus.
    public func unlockFocus() throws {
        guard let camera else { throw Errors.setupRequired }
        guard camera.isFocusPointOfInterestSupported else { throw Errors.notSupported }
        try camera.lockForConfiguration()
        let pointOfInterest = CGPoint(x: 0.5, y: 0.5)
        camera.focusPointOfInterest = pointOfInterest
        camera.focusMode = .continuousAutoFocus
        camera.unlockForConfiguration()
        _focusLockPoint = nil
    }
    
    /// Captures a LivePhoto.
    ///
    /// Call this method to capture a LivePhoto with ``ObscuraCamera``.
    ///
    /// - Important: Returns `nil` if the camera is currently busy with a previous capture request.
    /// - Note: If microphone usage authorization is not granted, the captured LivePhoto won't have audio.
    /// - SeeAlso: ``requestMicAuthorization()``
    /// - Returns: An ``ObscuraCaptureResult`` containing image and video URLs that can be combined into a LivePhoto in the app sandbox.
    /// - Throws: Errors that might occur while capturing LivePhoto.
    public func captureLivePhoto() async throws -> ObscuraCaptureResult? {
        guard !_isCapturing else { return nil }
        
        let photoSetting = AVCapturePhotoSettings(
            format:  [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoCompressionPropertiesKey: [AVVideoQualityKey: 0.5],
            ]
        )
        photoSetting.livePhotoMovieFileURL = videoDirectory.appending(path: UUID().uuidString + ".mov")
        photoSetting.photoQualityPrioritization = .speed
        
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           captureSession.canAddInput(micInput) {
            captureSession.addInput(micInput)
        }

        photoOutput.capturePhoto(with: photoSetting, delegate: self)
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                _isCapturing = true
                do {
                    let imagePath = try await withCheckedThrowingContinuation { [weak self] continuation in self?.photoContinuation = continuation }
                    let videoPath = try await withCheckedThrowingContinuation { [weak self] continuation in self?.videoContinuation = continuation }
                    continuation.resume(returning: ObscuraCaptureResult(imagePath: imagePath, videoPath: videoPath))
                    if let micInput = (captureSession.inputs.first { $0.ports.contains { $0.sourceDeviceType == .builtInMicrophone } }) {
                        captureSession.removeInput(micInput)
                    }
                    _isCapturing = false
                } catch {
                    continuation.resume(throwing: error)
                    if let micInput = (captureSession.inputs.first { $0.ports.contains { $0.sourceDeviceType == .builtInMicrophone } }) {
                        captureSession.removeInput(micInput)
                    }
                    _isCapturing = false
                }
            }
        }
    }
    
    /// Captures a photo.
    ///
    /// Call this method to capture a still photo with ``ObscuraCamera``.
    ///
    /// - Important: Returns `nil` if the camera is currently busy with a previous capture request.
    /// - Returns: An ``ObscuraCaptureResult`` containing the image URL in the app sandbox.
    /// - Throws: Errors that might occur while capturing the photo.
    public func capturePhoto() async throws -> ObscuraCaptureResult? {
        guard !_isCapturing else { return nil }
        
        let photoSetting = AVCapturePhotoSettings(format:  [AVVideoCodecKey: AVVideoCodecType.hevc])
        photoSetting.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization

        photoOutput.capturePhoto(with: photoSetting, delegate: self)
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                _isCapturing = true
                do {
                    let imagePath = try await withCheckedThrowingContinuation { [weak self] continuation in self?.photoContinuation = continuation }
                    continuation.resume(returning: ObscuraCaptureResult(imagePath: imagePath, videoPath: nil))
                    _isCapturing = false
                } catch {
                    continuation.resume(throwing: error)
                    _isCapturing = false
                }
            }
        }
    }
    
    /// Stops camera session.
    public func stop() async {
        captureSession.stopRunning()
    }
    
    /// Starts camera session.
    public func start() async {
        guard !isRunning else { return }
        captureSession.startRunning()
    }
}

extension ObscuraCamera: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            photoContinuation?.resume(throwing: error)
            return
        }

        guard let fileData = photo.fileDataRepresentation() else {
            photoContinuation?.resume(throwing: Errors.failedToCapture)
            return
        }
        
        do {
            let outputFileURL = imageDirectory.appending(path: UUID().uuidString + ".jpeg")
            try fileData.write(to: outputFileURL, options: [.atomic, .completeFileProtection])
            photoContinuation?.resume(returning: outputFileURL.relativePath)
        } catch {
            photoContinuation?.resume(throwing: error)
        }
    }
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            videoContinuation?.resume(throwing: error)
            return
        }
        videoContinuation?.resume(returning: outputFileURL.relativePath)
    }
}

extension URL {
    var relativePath: String {
        guard path.hasPrefix(URL.homeDirectory.path) else { return path }
        return String(path.dropFirst(URL.homeDirectory.path.count))
    }
}
