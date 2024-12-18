//
//  ObscuraCamera.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

@preconcurrency import Combine
import AVFoundation

/// A class that wraps `AVCaptureDevice` and `AVCaptureSession` to provide a convenient interface for camera operations.
public actor ObscuraCamera: NSObject {
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
    private var recordOutput: AVCaptureMovieFileOutput?
    
    // MARK: - Private Properties
    
    private var _previewLayer: AVCaptureVideoPreviewLayer { previewLayer as! AVCaptureVideoPreviewLayer }
    private let _isRunning = CurrentValueSubject<Bool, Never>(false)
    private let _minZoomFactor = CurrentValueSubject<CGFloat, Never>(.zero)
    private let _maxZoomFactor = CurrentValueSubject<CGFloat, Never>(.infinity)
    private let _isHDREnabled = CurrentValueSubject<Bool, Never>(false)
    private let _iso = CurrentValueSubject<Float, Never>(.zero)
    private let _shutterSpeed = CurrentValueSubject<Float, Never>(.zero)
    private let _aperture = CurrentValueSubject<Float, Never>(.zero)
    private let _exposureLockPoint = CurrentValueSubject<CGPoint?, Never>(nil)
    private let _focusLockPoint = CurrentValueSubject<CGPoint?, Never>(nil)
    private let _isExposureLocked = CurrentValueSubject<Bool, Never>(false)
    private let _isFocusLocked = CurrentValueSubject<Bool, Never>(false)
    private let _zoomFactor = CurrentValueSubject<CGFloat, Never>(1)
    private let _isCapturing = CurrentValueSubject<Bool, Never>(false)
    private let _isMuted = CurrentValueSubject<Bool, Never>(false)
    
    private let imageDirectory = URL.homeDirectory.appending(path: "Documents/Obscura/Images")
    private let videoDirectory = URL.homeDirectory.appending(path: "Documents/Obscura/Videos")
    
    // MARK: - Public Properties
    
    /// The layer that camera feed will be rendered on.
    nonisolated public let previewLayer: CALayer
    
    /// A `Bool` value indicating whether the camera is running.
    nonisolated public let isRunning: AnyPublisher<Bool, Never>
    /// A `CGFloat` value indicating the mimimum zoom factor.
    nonisolated public let minZoomFactor: AnyPublisher<CGFloat, Never>
    /// A `CGFloat` value indicating the maximum zoom factor.
    nonisolated public let maxZoomFactor: AnyPublisher<CGFloat, Never>
    /// A `Bool` value indicating whether the HDR mode is enabled.
    nonisolated public let isHDREnabled: AnyPublisher<Bool, Never>
    /// The ISO value that the camera is currently using.
    nonisolated public let iso: AnyPublisher<Float, Never>
    /// The Shutter speed value that the camera is currently using.
    nonisolated public let shutterSpeed: AnyPublisher<Float, Never>
    /// The Aperture f-number value that the camera is currently using.
    nonisolated public let aperture: AnyPublisher<Float, Never>
    /// A `CGPoint` value indicating which point is being used for exposure lock.
    nonisolated public let exposureLockPoint: AnyPublisher<CGPoint?, Never>
    /// A `CGPoint` value indicating which point is being used for focus lock.
    nonisolated public let focusLockPoint: AnyPublisher<CGPoint?, Never>
    /// A `Bool` value indicating whether the exposure is locked.
    nonisolated public let isExposureLocked: AnyPublisher<Bool, Never>
    /// A `Bool` value indicating whether the focus is locked.
    nonisolated public let isFocusLocked: AnyPublisher<Bool, Never>
    /// A `CGFloat` value indicating the current zoom factor.
    nonisolated public let zoomFactor: AnyPublisher<CGFloat, Never>
    /// A `Bool` value indicating the camera is currently capturing.
    nonisolated public let isCapturing: AnyPublisher<Bool, Never>
    /// A `Bool` value indicating the camera is muted.
    nonisolated public let isMuted: AnyPublisher<Bool, Never>
    
    private var photoContinuation: CheckedContinuation<String, Error>?
    private var videoContinuation: CheckedContinuation<String, Error>?
    private var zoomTask: Task<Void, Error>?
    private var cancellables: Set<AnyCancellable> = []
    
    // MARK: - Initializers
    
    /// Creates an ``ObscuraCamera`` instance.
    ///
    /// - Important: Ensure to call ``setup()`` before utilizing the camera features.
    public override init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.isRunning = _isRunning.eraseToAnyPublisher()
        self.minZoomFactor = _minZoomFactor.eraseToAnyPublisher()
        self.maxZoomFactor = _maxZoomFactor.eraseToAnyPublisher()
        self.isHDREnabled = _isHDREnabled.eraseToAnyPublisher()
        self.iso = _iso.eraseToAnyPublisher()
        self.shutterSpeed = _shutterSpeed.eraseToAnyPublisher()
        self.aperture = _aperture.eraseToAnyPublisher()
        self.exposureLockPoint = _exposureLockPoint.eraseToAnyPublisher()
        self.focusLockPoint = _focusLockPoint.eraseToAnyPublisher()
        self.isExposureLocked = _isExposureLocked.eraseToAnyPublisher()
        self.isFocusLocked = _isFocusLocked.eraseToAnyPublisher()
        self.zoomFactor = _zoomFactor.eraseToAnyPublisher()
        self.isCapturing = _isCapturing.eraseToAnyPublisher()
        self.isMuted = _isMuted.removeDuplicates().eraseToAnyPublisher()
        super.init()
    }
    
    // MARK: - Private methods
    
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
    
    private func convert(point: CGPoint) -> CGPoint {
        _previewLayer.layerPointConverted(fromCaptureDevicePoint: point)
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
        
        captureSession.publisher(for: \.isRunning)
            .assign(to: \.value, on: _isRunning)
            .store(in: &cancellables)
        
        camera.publisher(for: \.isVideoHDREnabled)
            .assign(to: \.value, on: _isHDREnabled)
            .store(in: &cancellables)
        
        camera.publisher(for: \.minAvailableVideoZoomFactor)
            .assign(to: \.value, on: _minZoomFactor)
            .store(in: &cancellables)
        
        camera.publisher(for: \.maxAvailableVideoZoomFactor)
            .assign(to: \.value, on: _maxZoomFactor)
            .store(in: &cancellables)
        
        camera.publisher(for: \.videoZoomFactor)
            .assign(to: \.value, on: _zoomFactor)
            .store(in: &cancellables)
        
        camera.publisher(for: \.iso)
            .assign(to: \.value, on: _iso)
            .store(in: &cancellables)
        
        camera.publisher(for: \.exposureDuration)
            .map { Float($0.seconds) }
            .assign(to: \.value, on: _shutterSpeed)
            .store(in: &cancellables)
        
        camera.publisher(for: \.lensAperture)
            .assign(to: \.value, on: _aperture)
            .store(in: &cancellables)
        
        camera.publisher(for: \.exposureMode)
            .map { $0 == .locked || $0 == .custom }
            .assign(to: \.value, on: _isExposureLocked)
            .store(in: &cancellables)
        
        camera.publisher(for: \.focusMode)
            .map { $0 == .locked }
            .assign(to: \.value, on: _isFocusLocked)
            .store(in: &cancellables)
        
        camera.publisher(for: \.exposurePointOfInterest)
            .dropFirst()
            .map(convert)
            .assign(to: \.value, on: _exposureLockPoint)
            .store(in: &cancellables)
        
        camera.publisher(for: \.focusPointOfInterest)
            .dropFirst()
            .map(convert)
            .assign(to: \.value, on: _focusLockPoint)
            .store(in: &cancellables)
        
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
    
    /// Starts camera session.
    public func start() async {
        guard _isRunning.value == false else { return }
        captureSession.startRunning()
    }
    
    /// Stops camera session.
    public func stop() async {
        captureSession.stopRunning()
    }
    
    /// Sets the zoom factor.
    ///
    /// - Parameters:
    ///     - factor: The zoom factor.
    public func zoom(factor: CGFloat) async throws {
        guard let camera else { throw Errors.setupRequired }
        try camera.lockForConfiguration()
        camera.ramp(toVideoZoomFactor: max(_minZoomFactor.value, min(factor, _maxZoomFactor.value)), withRate: 30)
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
    
    /// Sets the mute status.
    ///
    /// - Parameters:
    ///     - isMuted: The mute state to be set.
    public func setMute(_ isMuted: Bool) {
        _isMuted.send(isMuted)
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
        _exposureLockPoint.send(nil)
        try camera.lockForConfiguration()
        let pointOfInterest = _previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        camera.exposurePointOfInterest = pointOfInterest
        camera.exposureMode = .autoExpose
        camera.unlockForConfiguration()
    }
    
    /// Locks the exposure for given shutter speed and ISO.
    ///
    /// - Note: Unlock the exposure using ``unlockExposure()``
    ///
    /// - Paramters:
    ///     - shutterSpeed: The shutter speed to lock exposure. Provide `nil` to leave it unchaged. Default value is `nil`.
    ///     - iso: The ISO value to lock exposure. Provide `nil` to leave it unchanged. Default value is `nil`.
    public func lockExposure(shutterSpeed: CMTime? = nil, iso: Float? = nil) throws {
        guard let camera else { return }
        try camera.lockForConfiguration()
        camera.exposureMode = .custom
        camera.setExposureModeCustom(duration: shutterSpeed ?? AVCaptureDevice.currentExposureDuration, iso: iso ?? camera.iso)
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
        _exposureLockPoint.send(nil)
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
        _focusLockPoint.send(nil)
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
        _focusLockPoint.send(nil)
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
        guard !_isCapturing.value else { return nil }
        
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
        return try await Task {
            _isCapturing.send(true)
            do {
                let imagePath = try await withCheckedThrowingContinuation { photoContinuation = $0 }
                let videoPath = try await withCheckedThrowingContinuation { videoContinuation = $0 }
                if let micInput = (captureSession.inputs.first { $0.ports.contains { $0.sourceDeviceType == .builtInMicrophone } }) {
                    captureSession.removeInput(micInput)
                }
                _isCapturing.send(false)
                return ObscuraCaptureResult(imagePath: imagePath, videoPath: videoPath)
            } catch {
                if let micInput = (captureSession.inputs.first { $0.ports.contains { $0.sourceDeviceType == .builtInMicrophone } }) {
                    captureSession.removeInput(micInput)
                }
                _isCapturing.send(false)
                throw error
            }
        }
        .value
    }
    
    /// Captures a photo.
    ///
    /// Call this method to capture a still photo with ``ObscuraCamera``.
    ///
    /// - Important: Returns `nil` if the camera is currently busy with a previous capture request.
    /// - Returns: An ``ObscuraCaptureResult`` containing the image URL in the app sandbox.
    /// - Throws: Errors that might occur while capturing the photo.
    public func capturePhoto() async throws -> ObscuraCaptureResult? {
        guard !_isCapturing.value else { return nil }
        
        let photoSetting = AVCapturePhotoSettings(format:  [AVVideoCodecKey: AVVideoCodecType.hevc])
        photoSetting.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization

        photoOutput.capturePhoto(with: photoSetting, delegate: self)
        return try await Task {
            _isCapturing.send(true)
            do {
                let imagePath = try await withCheckedThrowingContinuation { photoContinuation = $0 }
                _isCapturing.send(false)
                return ObscuraCaptureResult(imagePath: imagePath, videoPath: nil)
            } catch {
                _isCapturing.send(false)
                throw error
            }
        }
        .value
    }
    
    /// Starts video recording.
    ///
    /// Call this method to start recording a video with ``ObscuraCamera``.
    /// To stop, call ``stopRecord()``.
    ///
    /// - Note: If microphone usage authorization is not granted, the captured video won't have audio.
    /// - SeeAlso: ``requestMicAuthorization()``
    /// - Returns: An ``ObscuraCaptureResult`` containing image and video URLs that can be combined into a LivePhoto in the app sandbox.
    /// - Throws: Errors that might occur starting video record.
    public func startRecord(with frameRate: Int32) throws {
        guard let camera else { throw Errors.setupRequired }
        
        let recordOutput = AVCaptureMovieFileOutput()
        guard captureSession.canAddOutput(recordOutput) else { throw Errors.notSupported }
        captureSession.addOutput(recordOutput)
        
        try camera.lockForConfiguration()
        
        let frameDuration = CMTime(value: 1, timescale: frameRate)
        camera.activeVideoMinFrameDuration = frameDuration
        camera.activeVideoMaxFrameDuration = frameDuration
        
        camera.unlockForConfiguration()
        
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           captureSession.canAddInput(micInput) {
            captureSession.addInput(micInput)
        }

        _isCapturing.send(true)
        recordOutput.startRecording(to: videoDirectory.appending(path: UUID().uuidString + ".mov"), recordingDelegate: self)
        self.recordOutput = recordOutput
    }

    /// Stops video recording.
    ///
    /// Call this method to stop recording video with ``ObscuraCamera``.
    ///
    /// - Important: Returns `nil` if the camera is not recording video.
    /// - Returns: An ``ObscuraCaptureResult`` containing the video URL in the app sandbox.
    /// - Throws: Errors that might occur stopping video record.
    public func stopRecord() async throws -> ObscuraCaptureResult? {
        guard let recordOutput, recordOutput.isRecording else { return nil }
        recordOutput.stopRecording()
        let videoPath = try await withCheckedThrowingContinuation { videoContinuation = $0 }
        _isCapturing.send(false)
        return ObscuraCaptureResult(imagePath: nil, videoPath: videoPath)
    }
}

extension ObscuraCamera: AVCapturePhotoCaptureDelegate {
    nonisolated public func photoOutput(
        _ output: AVCapturePhotoOutput,
        willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        Task {
            guard await _isMuted.value else { return }
            AudioServicesDisposeSystemSoundID(1108)
        }
    }
    
    nonisolated public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        Task {
            guard await _isMuted.value else { return }
            AudioServicesDisposeSystemSoundID(1108)
        }
    }
    
    nonisolated public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            Task { await photoContinuation?.resume(throwing: error) }
            return
        }

        guard let fileData = photo.fileDataRepresentation() else {
            Task { await photoContinuation?.resume(throwing: Errors.failedToCapture) }
            return
        }
        
        do {
            let outputFileURL = imageDirectory.appending(path: UUID().uuidString + ".jpeg")
            try fileData.write(to: outputFileURL, options: [.atomic, .completeFileProtection])
            Task { await photoContinuation?.resume(returning: outputFileURL.relativePath) }
        } catch {
            Task { await photoContinuation?.resume(throwing: error) }
        }
    }
    
    nonisolated public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL,
        duration: CMTime,
        photoDisplayTime: CMTime,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if let error {
            Task { await videoContinuation?.resume(throwing: error) }
            return
        }
        Task { await videoContinuation?.resume(returning: outputFileURL.relativePath) }
    }
}

extension ObscuraCamera: AVCaptureFileOutputRecordingDelegate {
    nonisolated public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        if let error = error {
            Task { await videoContinuation?.resume(throwing: error) }
            return
        }
        Task { await videoContinuation?.resume(returning: outputFileURL.relativePath) }
    }
}

extension URL {
    var relativePath: String {
        guard path.hasPrefix(URL.homeDirectory.path) else { return path }
        return String(path.dropFirst(URL.homeDirectory.path.count))
    }
}
