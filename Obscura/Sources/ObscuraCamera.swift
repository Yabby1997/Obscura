//
//  ObscuraCamera.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Foundation
import AVFoundation

public final class ObscuraCamera {
    public enum Errors: Error {
        case notAuthorized
    }
    
    private var captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private let _previewLayer: AVCaptureVideoPreviewLayer
    public var previewLayer: CALayer { _previewLayer }
    
    public init() {
        self._previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    }
    
    public func setup() async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw Errors.notAuthorized
        }
        
        guard let camera = AVCaptureDevice.default(for: .video) else { return }
        
        let input = try AVCaptureDeviceInput(device: camera)
        
        guard captureSession.canAddInput(input) else { return }
        captureSession.addInput(input)
        
        guard captureSession.canAddOutput(videoOutput) else { return }
        captureSession.addOutput(videoOutput)
            
        _previewLayer.videoGravity = .resizeAspectFill
        _previewLayer.connection?.videoOrientation = .portrait
        
        captureSession.startRunning()
    }
}
