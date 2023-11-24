//
//  CameraView.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import SwiftUI
import Obscura

final class CameraView: UIView {
    private let previewLayer: CALayer
    
    init(previewLayer: CALayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        layer.addSublayer(previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = layer.bounds
    }
}

struct CameraViewRepresentable: UIViewRepresentable {
    private let view: CameraView

    init(previewLayer: CALayer) {
        self.view = CameraView(previewLayer: previewLayer)
    }
    
    func makeUIView(context: Context) -> some UIView {
        view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
