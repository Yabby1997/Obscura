//
//  ObscuraViewModelProtocol.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Foundation
import QuartzCore

protocol ObscuraViewModelProtocol: ObservableObject {
    var previewLayer: CALayer { get }
    var shouldShowSettings: Bool { get set }
    var iso: Float { get set }
    var shutterSpeed: Float { get set }
    var aperture: Float { get set }
    var lockPoint: CGPoint? { get set }
    var isLocked: Bool { get set }
    var isHDREnabled: Bool { get set }
    var zoomFactor: CGFloat { get set }
    var maxZoomFactor: CGFloat { get }
    
    func setupIfNeeded()
    func didTapUnlock()
    func didTap(point: CGPoint)
    func setHDRMode(isEnabled: Bool)
    func zoom(factor: CGFloat)
}
