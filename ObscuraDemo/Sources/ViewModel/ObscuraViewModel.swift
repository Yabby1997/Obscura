//
//  ObscuraViewModel.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Foundation
import Obscura
import QuartzCore

final class ObscuraViewModel: ObservableObject {
    private let obscuraCamera = ObscuraCamera()
    var previewLayer: CALayer { obscuraCamera.previewLayer }
    
    @Published var shouldShowSettings = false
    
    func onAppear() {
        Task {
            do {
                try await obscuraCamera.setup()
            } catch {
                if case ObscuraCamera.Errors.notAuthorized = error {
                    Task { @MainActor in
                        shouldShowSettings = true
                    }
                }
            }
        }
    }
}
