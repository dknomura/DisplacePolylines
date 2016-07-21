//
//  SPPolyLineManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 7/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps
import CoreLocation

infix operator ^^ {}
func ^^ (radix:Double, power: Double) -> Double {
    return pow(Double(radix), Double(power))
}

class SPPolylineManager {
    func displacedPolylines(polylines: [GMSPolyline]) -> [GMSPolyline] {
        var returnArray = [GMSPolyline]()
        
        for polyline in polylines {
            guard var path = polyline.path else {
                print("No path for polyline")
                continue
            }
            if let offset = coordinateDisplacement(forPath:path, meters:100) {
                path = path.pathOffsetByLatitude(offset.latitude, longitude: offset.longitude)
            } else {
                print("Unable to get displacement coordinates for path")
            }
            
            let polyline = GMSPolyline(path: path)
            polyline.strokeColor = UIColor.greenColor()
            polyline.strokeWidth = 3
            returnArray.append(polyline)
        }
            //            } else {
            //                print("No signs for location #\(location.locationNumber)")
            //            }
        return returnArray
    }
    
    // MARK: - Offset the path

    //  Need to find deltaLatitude and deltaLongitude to offset the 2 overlapping GMSPaths on each street (2 for both sides of the street). Using a line with 2 points, the distance formula, d = sqrt((x1 - x2)^2 + (y1 - y2)^2), the linear equation y = mx + b, and the quadratic formula, we will find the (deltaLat, deltaLong). In depth explanation below**.
    
    //  ** Let  y = latitude and x = longitude * cos(lat0), where lat0 is a latitude near the middle of the area that we are looking at (see Convert xy to/from lat/long coordinates MARK).
    
    //  d = sqrt((x1 - x2)^2 + (y1 - y2)^2), d will be the distance to displace the polyline, (x1, y1) is one of the intersection coordinates, and we need to find (x2, y2) to find the deltaLat and deltaLong.
    
    //  Let's say that d = 5, x1 = 3, y1 = 2, so with some reduction the distance formula looks like 
    //  25 = (3 - x2)^2 + (2 - y2)^2 
    //  (x2, y2) is a point on a parallel line and the shortest distance between 2 parallel lines is a perpendicular line, so we need to find the perpendicular line that contains (3, 2). We can plug in the linear equation, y = mx + b, of the perpendicular line for y2, so that we can solve for x2, and then get (x2, y2)
    
    //  In the linear equation, y = mx + b, m is the slope and b is the y-intercept. The slope of a perpendicular line is the inverse reciprocal of the slope of the original line. To get the slope we just take the 2 coordinates of the GMSpath and calculate deltaY / deltaX, and the slope of the perpendicular line = - deltaX / deltaY. (Example: original line coordinates = (3, 2) and (4, 5), slope  = (2 - 5) /  (3 - 4) = 3, and perpendicular line slope = -1/3)
    
    //  Once we have the slope, we can plug in one of the coordinates to find the y-intercept. To continue with the example above: 
    //  y = mx + b,
    //  2 = -1/3 * 3 + b, 
    //  b = 3. 
    //  Now that we have the perpendicular line, y = -1/3x + 3, we can put it in where we left off with the distance formula, 
    //  25 = (3 - x)^2 + (2 - y)^2,
    //  25 = (3 - x)^2 + (2 - (-1/3x + 3))^2
    //  0 = 10/9x^2 - 8/3x - 15.
    //  And at that point we can use the quadratic formula, when 0 = ax^2 + bx + c, x = (-b +- sqrt(b^2 - 4ac)) / 2a. Once we have x we can solve for y

    private func coordinateDisplacement(forPath originalPath: GMSPath, meters:Double) -> CLLocationCoordinate2D? {
        
        if originalPath.count() < 2 {
            print("Need a line: Not enough points in the path")
            return nil
        }

        var deltaCoordinates = CLLocationCoordinate2D.init()
        
        let fromCoordinate = originalPath.coordinateAtIndex(0)
        let toCoordinate = originalPath.coordinateAtIndex(originalPath.count() - 1)
        
        let coordinateDifference = CLLocationCoordinate2DMake(fromCoordinate.latitude - toCoordinate.latitude, fromCoordinate.longitude - toCoordinate.longitude)
//        let differenceBetweenXY = xyPoint(fromCoordinate: coordinateDifference)
        let originalSlope = coordinateDifference.latitude / coordinateDifference.longitude
        
//        print("slope = \(slope)")
//        
        let fromPoint = xyPoint(fromCoordinate:originalPath.coordinateAtIndex(0))
        let toPoint = xyPoint(fromCoordinate:originalPath.coordinateAtIndex(originalPath.count() - 1))
        var newPoint = (x:0.0, y:0.0)
//
        let distanceOnXY = metersToXYDistance(meters, onPath:originalPath)
//
//        let originalSlope = (fromPoint.y - toPoint.y) / (fromPoint.x - toPoint.x)
        
        print("original slope = \(originalSlope)")
        
        if originalSlope != 0 && !originalSlope.isNaN{
            
            let perpendicularSlope = -1 / originalSlope
            print("Perpendicular slope: \(perpendicularSlope)")
            //  Linear equation: y = mx + b
            // b = y - mx
            let yInterceptOfPerpendicular = fromPoint.y - perpendicularSlope * fromPoint.x
            
            //  Distance formula:       d = sqrt((x1 - x2)^2 + (y1 - y2)^2),
            //  Plug in:                25 = (x1 - point.x)^2 + (y1 - point.y)^2,
            //  Linear equation:                                y = mx + b
            //  Intermediate equation: 0 = (x - point.x)^2 + (mx + b - point.y)^2 - 25
            //  Need to get a, b, c from quadratic equation 0 = ax^2 + bx + c
            
            let yInterceptMinusPointY = yInterceptOfPerpendicular - fromPoint.y
            
            let aQuadratic = (1 * 1) + perpendicularSlope^^2
            let bQuadratic = -(2 * fromPoint.x * 1) + -(2 * perpendicularSlope * (yInterceptMinusPointY))
            let cQuadratic = (fromPoint.x * fromPoint.x) + ((yInterceptMinusPointY)^^2) - distanceOnXY
            
            let quadraticTuple = quadraticFormula(aQuadratic, b: bQuadratic, c: cQuadratic)
            
            
            // If quadratic results is NaN, then
            if quadraticTuple.add.isNaN {
                print("Quadratic Tuple is NaN")
                return nil
            }
            
            //  Quadratic formula: x = (-b +/- sqrt(b^2 - 4ac)) / 2a
            //  So +/- will depend on which side of the street that the sign is on. The x-coordinate of E side of street will always be greater than the original x, so we will +, and the x-coordinate of W side of the street will always be less than the original x, so we will -. If the slope is positive then x of S side of street > original x and x of N < original x, and visa-versa with a negative slope
            
//            if location.sideOfStreet == "E" {
//                newPoint.x = quadraticTuple.add
//            } else if location.sideOfStreet == "W" {
//                newPoint.x = quadraticTuple.subtract
//            } else if location.sideOfStreet == "N" {
//                if originalSlope > 0 {
//                    newPoint.x = quadraticTuple.subtract
//                } else {
//                    newPoint.x = quadraticTuple.add
//                }
//            } else if location.sideOfStreet == "S" {
//                if originalSlope > 0 {
//                    newPoint.x = quadraticTuple.add
//                } else {
//                    newPoint.x = quadraticTuple.subtract
//                }
//            }
//            
            //  Linear equation: y = mx + b
            newPoint.y = perpendicularSlope * newPoint.x + yInterceptOfPerpendicular
            
            
        } else if originalSlope == 0 {
            // Horizontal slope, so newPoint.x = fromPoint.x
            
            // distance formula: d = sqrt((x1 - x2)^2 + (y1 - y2)^2)
            // so 25 = sqrt((fromPoint.x - fromPoint.x)^2 + (y - fromPoint.y)^2),
            // reduced to 0 = y^2 + (-2 * fromPoint.y) * y + fromPoint.y^2 - 25
            
            newPoint.x = fromPoint.x
            let aQuadratic = 1.0
            let bQuadratic = -2 * fromPoint.y
            let cQuadratic = (fromPoint.y^^2) - distanceOnXY
            
            let quadraticTuple = quadraticFormula(aQuadratic, b: bQuadratic, c: cQuadratic)
            
//            if location.sideOfStreet == "N" || location.sideOfStreet == "W" {
//                newPoint.y = quadraticTuple.add
//            } else if location.sideOfStreet == "S" || location.sideOfStreet == "E" {
//                newPoint.y = quadraticTuple.subtract
//            }
            
            
//            } else {
//                print("Location \(location.locationNumber) has a 0 (horizontal) slope, so sideOfStreet property should only be N or S")
//            }
            
        } else if originalSlope.isNaN {
            // Vertical slope, so newPoint.y = fromPoint.y
            
            // distance formula: d = sqrt((x1 - x2)^2 + (y1 - y2)^2)
            // so 25 = sqrt((x - fromPoint.x)^2 + (fromPoint.y - fromPoint.y)^2),
            // reduced to 0 = x^2 + (-2 * fromPoint.x) * x + fromPoint.x^2 - 25
            newPoint.y = fromPoint.y
            
            let aQuadratic = 1.0
            let bQuadratic = -2 * fromPoint.x
            let cQuadratic = (fromPoint.x^^2) - distanceOnXY
            let quadraticTuple = quadraticFormula(aQuadratic, b: bQuadratic, c: cQuadratic)
            
//            if location.sideOfStreet == "E" || location.sideOfStreet == "N" {
//                newPoint.x = quadraticTuple.add
//            } else if location.sideOfStreet == "W" || location.sideOfStreet == "S" {
//                newPoint.x = quadraticTuple.subtract
//            }

            
            //            else {
//                print("Location \(location.locationNumber) has a infinite (vertical) slope, so sideOfStreet property should only be E or W")
//            }
        }
        
        let fromPointLatLong = coordinateDegrees(fromPoint)
        let newPointLatLong = coordinateDegrees(newPoint)
        deltaCoordinates.latitude = fromPointLatLong.latitude - newPointLatLong.latitude
        deltaCoordinates.longitude = fromPointLatLong.longitude - newPointLatLong.longitude
//        let deltaXY: (x:Double, y:Double)
//        deltaXY.x = fromPoint.x - newPoint.x
//        deltaXY.y = fromPoint.y - newPoint.y
        
//        deltaCoordinates = coordinateDegrees(deltaXY)

        return deltaCoordinates
    }

    // MARK: Quadratic formula method
    
    //  Quadratic formula: x = (-b +/- sqrt(b^2 - 4ac)) / 2a
    private func quadraticFormula(a:Double, b:Double, c:Double) -> (add:Double, subtract:Double) {
        let returnTuple: (add:Double, subtract:Double)
        let B24AC = ((b^^2) - 4 * a * c)
        let sqrtB24AC = sqrt((b^^2) - 4 * a * c)
        returnTuple.add = (-b + sqrtB24AC) / (2 * a)
        returnTuple.subtract = (-b - sqrtB24AC) / (2 * a)
        return returnTuple
    }
    
    
    // MARK: Convert xy to/from lat/long coordinates
    // Adjusts longitude to the xy coordinate field with equirectangular projection, which is good for small areas.
    // https://en.wikipedia.org/wiki/Equirectangular_projection
    // http://stackoverflow.com/questions/16266809/convert-from-latitude-longitude-to-x-y
    //x = λ cos(φ0), y = φ
    //"use the horizontal axis x to denote longitude λ, the vertical axis y to denote latitude φ. The ratio between these should not be 1:1, though. Instead you should use cos(φ0) as the aspect ratio, where φ0 denotes a latitude close to the center of your map."
    // - MvG on Stack Overflow
    
    var aspectRatio: Double?
    private func xyPoint(fromCoordinate coordinate: CLLocationCoordinate2D) -> (x:Double, y:Double) {
        let xyCoordinate: (x:Double, y:Double)
        
        aspectRatio = cos(degreesToRadians(coordinate.latitude))
        
        if aspectRatio != nil {
            xyCoordinate.x = coordinate.longitude * aspectRatio!
        } else {
            // cos(the mid-lat of NYC) = 0.75807276592
            xyCoordinate.x = coordinate.longitude * 0.75807276592
        }
        xyCoordinate.y = coordinate.latitude

        
        return xyCoordinate
    }
    
    private func degreesToRadians(degrees:Double) -> Double {
        return degrees * M_PI  / 180
    }
    
    
    private func coordinateDegrees(fromXY:(x:Double, y:Double)) -> CLLocationCoordinate2D {
        var latLongCoordinate = CLLocationCoordinate2D.init()
        
        latLongCoordinate.latitude = fromXY.y
        if aspectRatio != nil {
            latLongCoordinate.longitude = fromXY.x / aspectRatio!
        } else {
            // cos(the mid-lat of NYC) = 0.75807276592
            latLongCoordinate.longitude = fromXY.x / 0.75807276592
        }
        
        return latLongCoordinate
    }
    
    private func metersToXYDistance(meters:Double, onPath path:GMSPath) -> Double {
        //If your displacements aren't too great (less than a few kilometers) and you're not right at the poles, use the quick and dirty estimate that 111,111 meters (111.111 km) in the y direction is 1 degree (of latitude) and 111,111 * cos(latitude) meters in the x direction is 1 degree (of longitude).
        // -whuber on Stack Exchange
        
        //http://gis.stackexchange.com/questions/2951/algorithm-for-offsetting-a-latitude-longitude-by-some-amount-of-meters
        
        // Need to make it dynamic with the path slope. With the slope, we can find the angle, then the deltaX, deltaY, then we will use the distance formula to find the distance
        
        return meters / 111111
        
    }
    

    
}