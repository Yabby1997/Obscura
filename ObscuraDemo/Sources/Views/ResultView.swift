//
//  ResultView.swift
//  ObscuraDemo
//
//  Created by Seunghun on 11/25/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import SwiftUI

struct ResultView: View {
    let title: String
    let value: String
    var body: some View {
        VStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))
            Text(value)
                .font(.system(size: 20, weight: .semibold))
        }
        .foregroundStyle(.white)
        .shadow(radius: 5)
    }
}

#Preview {
    ResultView(title: "Demo", value: "42")
}
