//
//  ObscuraDemoApp.swift
//  Obscura
//
//  Created by Seunghun on 11/24/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import SwiftUI
import Obscura

@main
struct ObscuraDemoApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationView {
                List {
                    NavigationLink("Auto Exposure Lock") { ObscuraView(viewModel: AELDemoViewModel()) }
                    NavigationLink("Auto Focus Lock") { ObscuraView(viewModel: AFLDemoViewModel()) }
                    NavigationLink("AEL + AFL") { ObscuraView(viewModel: AELAFLDemoViewModel()) }
                }
                .navigationTitle("Obscura Demo")
            }
        }
    }
}
