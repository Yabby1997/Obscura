//
//  LivePhotoView.swift
//  ObscuraDemo
//
//  Created by Seunghun on 1/15/24.
//  Copyright © 2024 seunghun. All rights reserved.
//

import SwiftUI
import PhotosUI

struct CaptureResult: Equatable {
    let image: URL
    let video: URL
}

struct LivePhotoView: UIViewRepresentable, Equatable {
    var urls: [URL]
    
    func makeUIView(context: Context) -> PHLivePhotoView {
        PHLivePhotoView()
    }
    
    func updateUIView(_ view: PHLivePhotoView, context: Context) {
        PHLivePhoto.request(
            withResourceFileURLs: urls,
            placeholderImage: nil,
            targetSize: .zero,
            contentMode: .aspectFit
        ) { photo, x in
            guard let photo else { return }
            view.livePhoto = photo
            view.startPlayback(with: .hint)
        }
    }
}
