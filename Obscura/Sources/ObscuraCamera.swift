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
    public enum Errors: Error {
        case notAuthorized
    }
    
    private var captureSession = AVCaptureSession()
    
    private let _previewLayer: AVCaptureVideoPreviewLayer
    public var previewLayer: CALayer { _previewLayer }
    
    @Published private var _iso: Float = .zero
    public var iso: AnyPublisher<Float, Never> { $_iso.eraseToAnyPublisher() }
    
    @Published private var _shutterSpeed: Float = .zero
    public var shutterSpeed: AnyPublisher<Float, Never> { $_shutterSpeed.eraseToAnyPublisher() }
    
    @Published private var _aperture: Float = .zero
    public var aperture: AnyPublisher<Float, Never> { $_aperture.eraseToAnyPublisher() }
    
    public init() {
        self._previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
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
        
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)
            
        _previewLayer.videoGravity = .resizeAspectFill
        _previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
    }
}
