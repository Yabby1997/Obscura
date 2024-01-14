//
//  ObscuraResult.swift
//  Obscura
//
//  Created by Seunghun on 1/14/24.
//  Copyright © 2024 seunghun. All rights reserved.
//

import Foundation

/// Capture result by ``ObscuraCamera``.
public struct ObscuraCaptureResult {
    public let image: URL
    public let video: URL
    
    /// A `URL` array that consists of ``image`` and ``video``.
    public var array: [URL] { [image, video] }
}
