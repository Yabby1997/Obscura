//
//  Dependnecies.swift
//  ObscuraManifests
//
//  Created by Seunghun on 12/27/24.
//

import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: .init(
        [
            .remote(url: "https://github.com/Yabby1997/LightMeter", requirement: .exact("0.2.0")),
        ]
    ),
    platforms: [.iOS]
)
