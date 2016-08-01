//
//  DoPFloatingPointClass.swift
//  DisplacementOfPath
//
//  Created by Daniel Nomura on 8/1/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import CoreGraphics

protocol DoPFloatingPoint {
    func +(lhs:Self, rhs:Self) -> Self
    func -(lhs:Self, rhs:Self) -> Self
    func *(lhs:Self, rhs:Self) -> Self
    func /(lhs:Self, rhs:Self) -> Self
//    init(_ value:Int)
}

extension Int:DoPFloatingPoint {}
extension Float:DoPFloatingPoint {}
extension CGFloat:DoPFloatingPoint {}
extension Double:DoPFloatingPoint {}

