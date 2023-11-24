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
            VStack {
                Text(Foo().bar())
                Text("Hello from ObscuraDemoApp")
            }
        }
    }
}
