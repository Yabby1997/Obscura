//
//  ObscuraCameraFeedbackProvidable.swift
//  Obscura
//
//  Created by Seunghun on 12/5/23.
//  Copyright © 2023 seunghun. All rights reserved.
//

import Foundation

public protocol ObscuraCameraFeedbackProvidable: AnyObject {
    func generateExposureFocusLockFeedback()
}
