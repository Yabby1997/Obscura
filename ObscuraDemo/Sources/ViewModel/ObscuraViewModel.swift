//
//  ObscuraViewModel.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Combine
import Foundation
import Obscura
import QuartzCore

final class ObscuraViewModel: ObservableObject {
    private let obscuraCamera = ObscuraCamera()
    var previewLayer: CALayer { obscuraCamera.previewLayer }
    
    @Published var shouldShowSettings = false
    
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        obscuraCamera.iso
            .sink { iso in
                print("ISO", iso)
            }
            .store(in: &cancellables)
        
        obscuraCamera.shutterSpeed
            .sink { shutterSpeed in
                print("ShutterSpeed", shutterSpeed)
            }
            .store(in: &cancellables)
        
        obscuraCamera.aperture
            .sink { aperture in
                print("aperture", aperture)
            }
            .store(in: &cancellables)
    }
    
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
