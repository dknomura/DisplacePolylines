//
//  DoPRandomColor.swift
//  DisplacementOfPath
//
//  Created by Daniel Nomura on 7/29/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import CoreGraphics
import UIKit

extension CGFloat {
    static func randomCGFloat() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension UIColor {
    static func randomColor() -> UIColor {
        return UIColor(red: CGFloat.randomCGFloat(), green: CGFloat.randomCGFloat(), blue: CGFloat.randomCGFloat(), alpha: 1.0)
    }
}