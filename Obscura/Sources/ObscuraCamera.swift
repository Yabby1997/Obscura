//
//  ObscuraCamera.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

@preconcurrency import Combine
import AVFoundation
import LightMeter

/// A class that wraps `AVCaptureDevice` and `AVCaptureSession` to provide a convenient interface for camera operations.
public final class ObscuraCamera: NSObject, Sendable {
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
    
    private var camera: AVCaptureDevice? { willSet { bind(camera: newValue) } }
    private var cameraInput: AVCaptureDeviceInput?
    private var micInput: AVCaptureDeviceInput?
    private let captureSession = AVCaptureSession()
    private let photoOutput =  AVCapturePhotoOutput()
    private var recordOutput: AVCaptureMovieFileOutput?
    private var obscuraRecorder: ObscuraRecordable?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private let sampleBufferDelegateQueue = DispatchQueue(label: "ObscuraCamera.SampleBufferDelegateQueue")
    
    // MARK: - Private Properties
    
    private var _previewLayer: AVCaptureVideoPreviewLayer { previewLayer as! AVCaptureVideoPreviewLayer }
    private let _isRunning = CurrentValueSubject<Bool, Never>(false)
    private let _isFrontFacing = CurrentValueSubject<Bool, Never>(false)
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
    private let _exposureValue = CurrentValueSubject<Float, Never>(.zero)
    private let _exposureOffset = CurrentValueSubject<Float, Never>(.zero)
    private let _exposureBias = CurrentValueSubject<Float, Never>(.zero)
    
    private let imageDirectory = URL.homeDirectory.appending(path: "Documents/Obscura/Images")
    private let videoDirectory = URL.homeDirectory.appending(path: "Documents/Obscura/Videos")
    
    // MARK: - Public Properties
    
    /// The layer that camera feed will be rendered on.
    public let previewLayer: CALayer
    
    /// A `Bool` value indicating whether the camera is running.
    nonisolated public let isRunning: AnyPublisher<Bool, Never>
    /// A `Bool` value that indicates whether the front-facing camera is currently in use.
    nonisolated public let isFrontFacing: AnyPublisher<Bool, Never>
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
    /// A `Float` value representing the metered exposure level in stops.
    nonisolated public let exposureValue: AnyPublisher<Float, Never>
    /// A `Float` value representing the difference between the metered exposure level and the current exposure settings in stops.
    nonisolated public let exposureOffset: AnyPublisher<Float, Never>
    /// A `Float` value representing the currently applied exposure bias level in stops.
    nonisolated public let exposureBias: AnyPublisher<Float, Never>
    
    private var photoContinuation: CheckedContinuation<String, Error>?
    private var videoContinuation: CheckedContinuation<String, Error>?
    private var cancellables: Set<AnyCancellable> = []
    private var cameraSpecificCancellables: Set<AnyCancellable> = []
    
    // MARK: - Initializers
    
    /// Creates an ``ObscuraCamera`` instance.
    ///
    /// - Important: Ensure to call ``setup()`` before utilizing the camera features.
    public override init() {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.isRunning = _isRunning.eraseToAnyPublisher()
        self.isFrontFacing = _isFrontFacing.eraseToAnyPublisher()
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
        self.exposureValue = _exposureValue.eraseToAnyPublisher()
        self.exposureOffset = _exposureOffset.eraseToAnyPublisher()
        self.exposureBias = _exposureBias.eraseToAnyPublisher()
        super.init()
        bind()
    }
    
    // MARK: - Private methods
    
    private func bind() {
        captureSession.publisher(for: \.isRunning)
            .assign(to: \.value, on: _isRunning)
            .store(in: &cancellables)
        
        Publishers.CombineLatest(
            Publishers.CombineLatest3(iso, shutterSpeed, aperture).compactMap { try? LightMeterService.getExposureValue(iso: $0.0, shutterSpeed: $0.1, aperture: $0.2) },
            exposureOffset
        )
        .map { $0 + $1 }
        .assign(to: \.value, on: _exposureValue)
        .store(in: &cancellables)
    }
    
    private func bind(camera: AVCaptureDevice?) {
        cameraSpecificCancellables = []
        
        guard let camera else { return }
        
        camera.publisher(for: \.isVideoHDREnabled)
            .assign(to: \.value, on: _isHDREnabled)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.minAvailableVideoZoomFactor)
            .assign(to: \.value, on: _minZoomFactor)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.maxAvailableVideoZoomFactor)
            .assign(to: \.value, on: _maxZoomFactor)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.videoZoomFactor)
            .assign(to: \.value, on: _zoomFactor)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.iso)
            .assign(to: \.value, on: _iso)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.exposureDuration)
            .map { Float($0.seconds) }
            .assign(to: \.value, on: _shutterSpeed)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.lensAperture)
            .assign(to: \.value, on: _aperture)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.exposureMode)
            .map { $0 == .locked || $0 == .custom }
            .assign(to: \.value, on: _isExposureLocked)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.focusMode)
            .map { $0 == .locked }
            .assign(to: \.value, on: _isFocusLocked)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.exposurePointOfInterest)
            .dropFirst()
            .map(convert)
            .assign(to: \.value, on: _exposureLockPoint)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.focusPointOfInterest)
            .dropFirst()
            .map(convert)
            .assign(to: \.value, on: _focusLockPoint)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.exposureTargetOffset)
            .assign(to: \.value, on: _exposureOffset)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.exposureTargetBias)
            .assign(to: \.value, on: _exposureBias)
            .store(in: &cameraSpecificCancellables)
        
        camera.publisher(for: \.position)
            .map { $0 == .front }
            .assign(to: \.value, on: _isFrontFacing)
            .store(in: &cameraSpecificCancellables)
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
    
    private func setupCamera(deviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera, position: AVCaptureDevice.Position) throws {
        guard let newCamera = AVCaptureDevice.default(deviceType, for: .video, position: position) else { throw Errors.notSupported }
        let newCameraInput = try AVCaptureDeviceInput(device: newCamera)
        captureSession.beginConfiguration()
        if let cameraInput { captureSession.removeInput(cameraInput) }
        guard captureSession.canAddInput(newCameraInput) else { throw Errors.notSupported }
        captureSession.addInput(newCameraInput)
        captureSession.commitConfiguration()
        self.camera = newCamera
        self.cameraInput = newCameraInput
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
    @ObscuraGlobalActor
    public func setup() async throws {
        try createDirectoryIfNeeded(for: imageDirectory.path)
        try createDirectoryIfNeeded(for: videoDirectory.path)
        
        guard await AVCaptureDevice.requestAccess(for: .video) else { throw Errors.notAuthorized }
        try setupCamera(position: .back)
        
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
    @ObscuraGlobalActor
    public func requestMicAuthorization() async throws {
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw Errors.notAuthorized
        }
    }
    
    /// Switches the camera's position between front and back.
    ///
    /// - Important: Switching the camera will reset and unlock focus and exposure settings.
    public func switchCamera() throws {
        try? unlockFocus()
        try? unlockExposure()
        try setupCamera(position: _isFrontFacing.value ? .back : .front)
    }
    
    /// Starts camera session.
    @ObscuraGlobalActor
    public func start() async {
        guard _isRunning.value == false else { return }
        captureSession.startRunning()
    }
    
    /// Stops camera session.
    @ObscuraGlobalActor
    public func stop() async {
        captureSession.stopRunning()
    }
    
    /// Sets the zoom factor.
    ///
    /// - Parameters:
    ///     - factor: The zoom factor.
    @ObscuraGlobalActor
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
    
    /// Sets the exposure bias level.
    ///
    /// - Parameters:
    ///   - bias: The exposure bias in stops.
    @ObscuraGlobalActor
    public func setExposure(bias: Float) async throws {
        guard let camera else { throw Errors.setupRequired }
        try camera.lockForConfiguration()
        await camera.setExposureTargetBias(bias)
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
    @ObscuraGlobalActor
    public func lockExposure(shutterSpeed: CMTime? = nil, iso: Float? = nil) async throws {
        guard let camera else { throw Errors.setupRequired }
        try camera.lockForConfiguration()
        camera.exposureMode = .custom
        await withCheckedContinuation { continuation in
            camera.setExposureModeCustom(
                duration: shutterSpeed.map { max(min($0, camera.activeFormat.maxExposureDuration), camera.activeFormat.minExposureDuration) } ?? AVCaptureDevice.currentExposureDuration,
                iso: iso.map { min(max($0, camera.activeFormat.minISO), camera.activeFormat.maxISO) } ?? AVCaptureDevice.currentISO
            ) { _ in
                continuation.resume()
            }
        }
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
    
    /// Locks the frame rate.
    ///
    /// Call this method to lock frame rate of the ``ObscuraCamera``.
    /// To unlock, call ``unlockFrameRate()``.
    ///
    /// - Note: Locking the frame rate affects in preview, Live Photo result and video result.
    ///
    /// - Parameters:
    ///     - frameRate: The desired frame rate.
    public func lockFrameRate(_ frameRate: Int32) throws {
        guard let camera else { throw Errors.setupRequired }
        guard let minimum = (camera.activeFormat.videoSupportedFrameRateRanges.map { $0.minFrameRate }.max()),
              let maximum = (camera.activeFormat.videoSupportedFrameRateRanges.map { $0.maxFrameRate }.min()),
              Int32(ceil(minimum))...Int32(floor(maximum)) ~= frameRate else { throw Errors.notSupported }
        try camera.lockForConfiguration()
        let frameDuration = CMTime(value: 1, timescale: frameRate)
        camera.activeVideoMinFrameDuration = frameDuration
        camera.activeVideoMaxFrameDuration = frameDuration
        camera.unlockForConfiguration()
        try camera.lockForConfiguration()
    }
    
    /// Unlocks the frame rate.
    public func unlockFrameRate() throws {
        guard let camera else { throw Errors.setupRequired }
        try camera.lockForConfiguration()
        camera.activeVideoMinFrameDuration = CMTime.invalid
        camera.activeVideoMaxFrameDuration = CMTime.invalid
        camera.unlockForConfiguration()
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
    @ObscuraGlobalActor
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
            self.micInput = micInput
        }

        photoOutput.capturePhoto(with: photoSetting, delegate: self)
        return try await Task {
            _isCapturing.send(true)
            do {
                let imagePath = try await withCheckedThrowingContinuation { photoContinuation = $0 }
                let videoPath = try await withCheckedThrowingContinuation { videoContinuation = $0 }
                if let micInput {
                    captureSession.removeInput(micInput)
                    self.micInput = nil
                }
                _isCapturing.send(false)
                return ObscuraCaptureResult(imagePath: imagePath, videoPath: videoPath)
            } catch {
                if let micInput {
                    captureSession.removeInput(micInput)
                    self.micInput = nil
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
    @ObscuraGlobalActor
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
    /// - Note: If microphone usage authorization is not granted, the captured video won't have audio. Call ``requestMicAuthorization()`` to request access.
    /// - Throws: Errors that might occur starting video record.
    public func startRecordVideo() throws {
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           captureSession.canAddInput(micInput) {
            captureSession.addInput(micInput)
            self.micInput = micInput
        }
        
        let recordOutput = AVCaptureMovieFileOutput()
        guard captureSession.canAddOutput(recordOutput) else { throw Errors.notSupported }
        captureSession.addOutput(recordOutput)

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
    @ObscuraGlobalActor
    public func stopRecordVideo() async throws -> ObscuraCaptureResult? {
        guard let recordOutput, recordOutput.isRecording else { return nil }
        recordOutput.stopRecording()
        let videoPath = try await withCheckedThrowingContinuation { videoContinuation = $0 }
        captureSession.removeOutput(recordOutput)
        if let micInput {
            captureSession.removeInput(micInput)
            self.micInput = nil
        }
        _isCapturing.send(false)
        return ObscuraCaptureResult(imagePath: nil, videoPath: videoPath)
    }
    
    /// Starts video recording with custom recorder.
    ///
    /// Call this method to start recording a video with ``ObscuraRecordable``.
    /// To stop, call ``stopObscuraRecorder()``.
    ///
    /// - Note: If microphone usage authorization is not granted, the captured video won't have audio. Call ``requestMicAuthorization()`` to request access.
    /// - Parameters:
    ///     - obscuraRecorder: A custom implementation of ``ObscuraRecordable`` that defines how video and audio will be recorded.
    /// - Throws: Errors that might occur starting video record.
    @ObscuraGlobalActor
    public func start(obscuraRecorder: ObscuraRecordable) async throws {
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           captureSession.canAddInput(micInput) {
            captureSession.addInput(micInput)
            self.micInput = micInput
        }
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferDelegateQueue)
        guard captureSession.canAddOutput(videoDataOutput) else { throw Errors.notSupported }
        captureSession.addOutput(videoDataOutput)
        
        let audioDataOutput = AVCaptureAudioDataOutput()
        audioDataOutput.setSampleBufferDelegate(self, queue: sampleBufferDelegateQueue)
        guard captureSession.canAddOutput(audioDataOutput) else { throw Errors.notSupported }
        captureSession.addOutput(audioDataOutput)
        
        self.obscuraRecorder = obscuraRecorder
        self.videoDataOutput = videoDataOutput
        self.audioDataOutput = audioDataOutput
        
        await obscuraRecorder.prepareForStart()
        _isCapturing.send(true)
    }
    
    /// Stops video recording with custom recorder.
    ///
    /// Call this method to stop recording video with ``ObscuraRecordable``.
    ///
    /// - Throws: Errors that might occur stopping video record.
    @ObscuraGlobalActor
    public func stopObscuraRecorder() async throws {
        guard let obscuraRecorder, let videoDataOutput, let audioDataOutput, _isCapturing.value else { return }
        
        await obscuraRecorder.prepareForStop()
        
        captureSession.removeOutput(videoDataOutput)
        captureSession.removeOutput(audioDataOutput)
        
        if let micInput {
            captureSession.removeInput(micInput)
            self.micInput = nil
        }
        
        self.obscuraRecorder = nil
        self.videoDataOutput = nil
        self.audioDataOutput = nil
        _isCapturing.send(false)
    }
}

extension ObscuraCamera: AVCapturePhotoCaptureDelegate {
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        guard _isMuted.value else { return }
        AudioServicesDisposeSystemSoundID(1108)
    }
    
    public func photoOutput(
        _ output: AVCapturePhotoOutput,
        didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings
    ) {
        guard _isMuted.value else { return }
        AudioServicesDisposeSystemSoundID(1108)
    }
    
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

extension ObscuraCamera: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: (any Error)?
    ) {
        if let error = error {
            videoContinuation?.resume(throwing: error)
            return
        }
        videoContinuation?.resume(returning: outputFileURL.relativePath)
    }
}

extension ObscuraCamera: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output is AVCaptureVideoDataOutput {
            obscuraRecorder?.record(video: sampleBuffer)
        } else if output is AVCaptureAudioDataOutput {
            obscuraRecorder?.record(audio: sampleBuffer)
        }
    }
}

extension URL {
    var relativePath: String {
        guard path.hasPrefix(URL.homeDirectory.path) else { return path }
        return String(path.dropFirst(URL.homeDirectory.path.count))
    }
}
