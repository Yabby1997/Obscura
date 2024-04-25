//
//  ObscuraResult.swift
//  Obscura
//
//  Created by Seunghun on 1/14/24.
//  Copyright © 2024 seunghun. All rights reserved.
//

import Foundation

/// Capture result of ``ObscuraCamera``.
public struct ObscuraCaptureResult: Sendable {
    /// Relative path to image file from Home directory.
    public let imagePath: String
    /// Relative path to video file from Home directory.
    public let videoPath: String?
}
