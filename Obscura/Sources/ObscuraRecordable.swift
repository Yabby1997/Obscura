//
//  ObscuraRecordable.swift
//  Obscura
//
//  Created by Seunghun on 12/19/24.
//

import AVFoundation

/// A protocol for custom video and audio stream recording.
public protocol ObscuraRecordable: AnyObject {
    /// Called before starting the recording. Perform necessary setups on it.
    @ObscuraGlobalActor func prepareForStart() async
    
    /// Called before stopping the recording. Perform necessary cleanups on it.
    @ObscuraGlobalActor func prepareForStop() async
    
    /// Called when a video frame is captured.
    ///
    /// - Parameters
    ///     - sampleBuffer: The captured video frame.
    func record(video sampleBuffer: CMSampleBuffer)
    
    /// Called when an audio sample is captured.
    ///
    /// - Parameters
    ///     - sampleBuffer: The captured audio sample.
    func record(audio sampleBuffer: CMSampleBuffer)
}
