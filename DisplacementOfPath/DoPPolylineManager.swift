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

//infix operator ^^ {}
//fuPc ^^ (radix:Double, power: Double) -> Double {
//    return pow(Double(radix), Dofuble(power))
//}

class SPPolylineManager {
    
    enum PolylineError: ErrorType {
        case notEnoughPoints
        case unableToRotateGeographicalBearing
        case noPathForPolyline
        case unknownErrorPolylineDisplacement
    }
    
    let streetSides = ["N", "E", "S", "W"]
    var currentSideOfStreet = ""
    
    func testPolylines(forMapview mapView:GMSMapView) -> [GMSPolyline] {
        var path = GMSMutablePath()
        var polylines = [GMSPolyline]()
        let visibleRegion = mapView.projection.visibleRegion()

        path.addCoordinate(visibleRegion.nearRight)
        path.addCoordinate(visibleRegion.farLeft)
        polylines.append(GMSPolyline.init(path: path))
        path = GMSMutablePath()
        path.addCoordinate(visibleRegion.nearLeft)
        path.addCoordinate(visibleRegion.farRight)
        polylines.append(GMSPolyline.init(path: path))
        
        let vertAndHorzPaths = verticalAndHorizontalPaths(forVisibleRegion: visibleRegion)
        polylines.append(GMSPolyline(path: vertAndHorzPaths.vertical))
        let vertPath = vertAndHorzPaths.vertical
        polylines.append(GMSPolyline(path: vertAndHorzPaths.horizontal))
        let horzPath = vertAndHorzPaths.horizontal
        print("vert path coordinates: from: \(vertPath.coordinateAtIndex(0))\nTo: \(vertPath.coordinateAtIndex(1)) \n\n")
        print("horz path coordinates: from: \(horzPath.coordinateAtIndex(0))\nTo: \(horzPath.coordinateAtIndex(1)) ")
        
        //MARK: Path bearings
        // 1. negative bearing
        // 2. positive bearing
        // 3. 0, N as defined in verticalAndHorizontalPaths()
        // 4. M_PI_2, E as defined
        // See MARK Bearing calculation

        for i in 0 ..< polylines.count {
            let polyline = polylines[i]
            polyline.strokeColor = UIColor.redColor()
            polyline.strokeWidth = 2
            polyline.map = mapView
        }
        return polylines
    }
    private func verticalAndHorizontalPaths(forVisibleRegion visibleRegion:GMSVisibleRegion) -> (vertical:GMSMutablePath, horizontal:GMSMutablePath) {
        
        let returnTuple: (vertical:GMSMutablePath, horizontal:GMSMutablePath)
        let farRight = visibleRegion.farRight
        let nearLeft = visibleRegion.nearLeft
        
        let longitudeMidpoint = (farRight.longitude + nearLeft.longitude) / 2
        var path = GMSMutablePath()
        path.addCoordinate(CLLocationCoordinate2DMake(nearLeft.latitude, longitudeMidpoint))
        path.addCoordinate(CLLocationCoordinate2DMake(farRight.latitude, longitudeMidpoint))
        returnTuple.vertical = path
        
        let latitudeMidpoint = (nearLeft.latitude + farRight.latitude) / 2
        path = GMSMutablePath()
        path.addCoordinate(CLLocationCoordinate2DMake(latitudeMidpoint, nearLeft.longitude))
        path.addCoordinate(CLLocationCoordinate2DMake(latitudeMidpoint, farRight.longitude))
        returnTuple.horizontal = path
        
        return returnTuple
    }
    
    func displace(polylines polylines: [GMSPolyline], xMeters meters:Double) -> [GMSPolyline] {
        var returnArray = [GMSPolyline]()
        
        loopThroughSideOfStreet()

        for polyline in polylines {
            do {
                returnArray.append(try displacedPolyline(originalPolyline: polyline, xMeters: meters))
            } catch PolylineError.notEnoughPoints {
                print("Not enough points on path")
                continue
            } catch PolylineError.unableToRotateGeographicalBearing {
                print("Unable to rotate bearing. Original bearing not between pi and -pi")
                continue
            } catch {
                print("Some other error with getting displacement coordinates")
                continue
            }
        }
        return returnArray
    }
    
    func displacedPolyline(originalPolyline polyline:GMSPolyline, xMeters meters:Double) throws -> GMSPolyline {
        guard var path = polyline.path else {
            throw PolylineError.noPathForPolyline
        }
        
        do {
            if let offset = try displacementCoordinate(fromPath: path, xMeters: meters, sideOfStreet: currentSideOfStreet) {
                path = path.pathOffsetByLatitude(offset.latitude, longitude: offset.longitude)
            }
        } catch PolylineError.notEnoughPoints{
            throw PolylineError.notEnoughPoints
        } catch PolylineError.unableToRotateGeographicalBearing {
            throw PolylineError.unableToRotateGeographicalBearing
        } catch {
            print("Unknown error while trying to displace coordinates")
            throw PolylineError.unknownErrorPolylineDisplacement
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor.greenColor()
        polyline.strokeWidth = 2

        return polyline
    }
    
    private func loopThroughSideOfStreet() {
        if var index = streetSides.indexOf(currentSideOfStreet) {
            if index > streetSides.count - 1 {
                index = 0
            } else {
                index += 1
            }
            currentSideOfStreet = streetSides[index]
        } else {
            if currentSideOfStreet != "" {
                print("\(currentSideOfStreet) is not in array: \(streetSides)")
            }
            currentSideOfStreet = "N"
        }
        print("Side of street is: \(currentSideOfStreet)")
    }
    
    private func displacementCoordinate(fromPath path:GMSPath, xMeters meters:Double, sideOfStreet:String) throws -> CLLocationCoordinate2D? {
        // http://www.movable-type.co.uk/scripts/latlong.html
        // first find the bearing
        //        θ = atan2( sin Δλ ⋅ cos φ2 , cos φ1 ⋅ sin φ2 − sin φ1 ⋅ cos φ2 ⋅ cos Δλ )
        if path.count() < 2 {
            throw PolylineError.notEnoughPoints
        }
        
        let fromCoordinate = path.coordinateAtIndex(0)
        let long1 = degreesToRadians(fromCoordinate.longitude)
        let lat1 = degreesToRadians(fromCoordinate.latitude)
        let toCoordinate = path.coordinateAtIndex(path.count() - 1)
        let long2 = degreesToRadians(toCoordinate.longitude)
        let lat2 = degreesToRadians(toCoordinate.latitude)
        
        //    var y = Math.sin(λ2-λ1) * Math.cos(φ2);
        //    var x = Math.cos(φ1)*Math.sin(φ2) -
        //            Math.sin(φ1)*Math.cos(φ2)*Math.cos(λ2-λ1);
        //    var brng = Math.atan2(y, x).toDegrees();
        
        let y = sin(long2 - long1) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(long2 - long1)
        var bearing = atan2(y, x)
        
        //MARK: Bearing calculation
        // To see what direction each path is, see MARK Path bearings
        switch true {
            // "switch true" meaning if the case statements are true
            
        case (bearing > 0 && bearing < M_PI_2) || bearing == M_PI_2:
            switch sideOfStreet {
            case "N", "W":
                bearing -= M_PI_2
            case "S", "E":
                bearing += M_PI_2
            default: break
            }
        case (bearing < 0 && bearing > -M_PI_2) || bearing == 0:
            switch sideOfStreet {
            case "N", "E":
                bearing += M_PI_2
            case "S", "W":
                bearing -= M_PI_2
            default: break
            }
        case (bearing > M_PI_2 && bearing < M_PI) || bearing == M_PI, bearing == -M_PI:
            switch sideOfStreet {
            case "N", "E":
                bearing -= M_PI_2
            case "S", "W":
                bearing += M_PI_2
            default: break
            }
        case (bearing < -M_PI_2 && bearing > -M_PI):
            switch sideOfStreet {
            case "N", "W":
                bearing += M_PI_2
            case "S", "E":
                bearing -= M_PI_2
            default: break
            }
        default: throw PolylineError.unableToRotateGeographicalBearing
        }
        
        // Then you can find the displacement of the path
        //        var φ2 = Math.asin( Math.sin(φ1)*Math.cos(d/R) +
        //          Math.cos(φ1)*Math.sin(d/R)*Math.cos(brng) );
        //        var λ2 = λ1 + Math.atan2(Math.sin(brng)*Math.sin(d/R)*
        //          Math.cos(φ1), Math.cos(d/R)-Math.sin(φ1)*Math.sin(φ2));
        //
        // Angular distance = distance / radius of earth
        let angularDistance = meters / 6371000
        let newLat = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let newLong = long1 + atan2(sin(bearing) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(newLat))
        
        let fromLocation = CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
        let toLocation = CLLocation(latitude:radiansToDegrees(newLat), longitude:radiansToDegrees(newLong))
        let distance = fromLocation.distanceFromLocation(toLocation)
        print("distance is: \(distance), margin of error: \((distance - meters) / meters)")
        
        
        return CLLocationCoordinate2DMake(radiansToDegrees(newLat) - fromCoordinate.latitude, radiansToDegrees(newLong) - fromCoordinate.longitude)
    }

    private func degreesToRadians(degrees:Double) -> Double {
        return degrees * M_PI  / 180
    }
    
    private func radiansToDegrees(radians:Double) -> Double {
        return radians * 180 / M_PI
    }
    
    
    
    func distanceBetween<T: protocol <FloatingPointType, DoPFloatingPoint>> (point1 point1:(T, T), point2:(T, T)) -> Double? {
        if let dx = point1.0 - point2.0 as? Double,
            let dy = point1.1 - point2.1 as? Double {
            return sqrt(dx * dx + dy * dy)

        } else {
            return nil
        }
    }
    
    func metersToDisplace(byPoints points:Double, zoom:Double) -> Double {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
        // So taking the proportions local points / world width points = local meters / world width meters

        let worldMeters = 40075000.0
        let worldPoints = 256 * pow(2, zoom)
        let meters = points * worldMeters / worldPoints
        return meters
    }
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

//    private func coordinateDisplacement(forPath originalPath: GMSPath, meters:Double, sideOfStreet:String) -> CLLocationCoordinate2D? {
//        
//        //http://stackoverflow.com/questions/17195055/calculate-a-perpendicular-offset-from-a-diagonal-line/17195324#17195324
//        //http://stackoverflow.com/questions/133897/how-do-you-find-a-point-at-a-given-perpendicular-distance-from-a-line
//        if originalPath.count() < 2 {
//            print("Need a line: Not enough points in the path")
//            return nil
//        }
//        
//        let fromPoint = xyPoint(fromCoordinate:originalPath.coordinateAtIndex(0))
//        let toPoint = xyPoint(fromCoordinate:originalPath.coordinateAtIndex(originalPath.count() - 1))
//
//        
////        let fromPoint = (x:1.0, y:-1.0)
////        let toPoint = (x:-3.0, y:2.0)
//        let originalSlope = (toPoint.y - fromPoint.y) / (toPoint.x - fromPoint.x)
//        var newPoint = (x:0.0, y:0.0)
//        
//        var dx = fromPoint.x - toPoint.x
//        var dy = fromPoint.y - toPoint.y
//        let distance = sqrt(dx * dx + dy * dy)
//        dx /= distance
//        dy /= distance
//        
//        let displacementOnXY = xyPerpendicularDistance(fromPath: originalPath, meters: meters)
////        newPoint.x = fromPoint.x + meters * dy
////        newPoint.y = fromPoint.y - meters * dx
////        newPoint.x = fromPoint.x - meters * dy
////        newPoint.y = fromPoint.y + meters * dx
//        
//        if originalSlope > 0 {
//            if dx > 0 && dy > 0 {
//                if sideOfStreet == "N" || sideOfStreet == "W" {
//                    newPoint.x = fromPoint.x - displacementOnXY * dy
//                    newPoint.y = fromPoint.y + displacementOnXY * dx
//                }
//                else if sideOfStreet == "S" || sideOfStreet == "E"{
//                    newPoint.x = fromPoint.x + displacementOnXY * dy
//                    newPoint.y = fromPoint.y - displacementOnXY * dx
//                }
//            } else if dx < 0 && dy < 0 {
//                if sideOfStreet == "N" || sideOfStreet == "W" {
//                    newPoint.x = fromPoint.x + displacementOnXY * dy
//                    newPoint.y = fromPoint.y - displacementOnXY * dx
//                } else if sideOfStreet == "S" || sideOfStreet == "E"{
//                    newPoint.x = fromPoint.x - displacementOnXY * dy
//                    newPoint.y = fromPoint.y + displacementOnXY * dx
//                }
//            }
//        } else if originalSlope < 0 {
//            if dy < 0 && dx > 0 {
//                if sideOfStreet == "S" || sideOfStreet == "W" {
//                    newPoint.x = fromPoint.x + displacementOnXY * dy
//                    newPoint.y = fromPoint.y - displacementOnXY * dx
//                } else if sideOfStreet == "N" || sideOfStreet == "E" {
//                    newPoint.x = fromPoint.x - displacementOnXY * dy
//                    newPoint.y = fromPoint.y + displacementOnXY * dx
//                }
//            } else if dy > 0 && dx < 0 {
//                if sideOfStreet == "S" || sideOfStreet == "W" {
//                    newPoint.x = fromPoint.x - displacementOnXY * dy
//                    newPoint.y = fromPoint.y + displacementOnXY * dx
//                    
//                } else if sideOfStreet == "N" || sideOfStreet == "E" {
//                    newPoint.x = fromPoint.x + displacementOnXY * dy
//                    newPoint.y = fromPoint.y - displacementOnXY * dx
//                }
//            }
//        } else if originalSlope == 0 {
//            
//        } else if originalSlope.isNaN {
//            
//        }
//        
//        let deltaXY: (x:Double, y:Double)
//        deltaXY.x = fromPoint.x - newPoint.x
//        deltaXY.y = fromPoint.y - newPoint.y
//        
//        let deltaCoordinates = coordinateDegrees(deltaXY)
//
//        return deltaCoordinates
//    }
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
            //            newPoint.y = perpendicularSlope * newPoint.x + yInterceptOfPerpendicular
            
            
//                    } else if originalSlope == 0 {
                        // Horizontal slope, so newPoint.x = fromPoint.x
            
                        // distance formula: d = sqrt((x1 - x2)^2 + (y1 - y2)^2)
                        // so 25 = sqrt((fromPoint.x - fromPoint.x)^2 + (y - fromPoint.y)^2),
                        // reduced to 0 = y^2 + (-2 * fromPoint.y) * y + fromPoint.y^2 - 25
            //            if location.sideOfStreet == "N" || location.sideOfStreet == "W" {
            //                newPoint.y = quadraticTuple.add
            //            } else if location.sideOfStreet == "S" || location.sideOfStreet == "E" {
//                            newPoint.y = quadraticTuple.subtract
            //            }
            
            
            //            } else {
            //                print("Location \(location.locationNumber) has a 0 (horizontal) slope, so sideOfStreet property should only be N or S")
            //            }
            
//                    } else if originalSlope.isNaN {
                        // Vertical slope, so newPoint.y = fromPoint.y
            
                        // distance formula: d = sqrt((x1 - x2)^2 + (y1 - y2)^2)
                        // so 25 = sqrt((x - fromPoint.x)^2 + (fromPoint.y - fromPoint.y)^2),
                        // reduced to 0 = x^2 + (-2 * fromPoint.x) * x + fromPoint.x^2 - 25
            //            if location.sideOfStreet == "E" || location.sideOfStreet == "N" {
            //                newPoint.x = quadraticTuple.add
            //            } else if location.sideOfStreet == "W" || location.sideOfStreet == "S" {
            //                newPoint.x = quadraticTuple.subtract
            //            }
            
                        
                        //            else {
            //                print("Location \(location.locationNumber) has a infinite (vertical) slope, so sideOfStreet property should only be E or W")
            //            }
//                    }
//
//        }
//
//
//        let originalSlope = (fromPoint.y - toPoint.y) / (fromPoint.x - toPoint.x)
        
//        print("original slope = \(originalSlope)")
//        
//        if originalSlope != 0 && !originalSlope.isNaN{
//            
//            let perpendicularSlope = -1 / originalSlope
//            print("Perpendicular slope: \(perpendicularSlope)")
//            
//            // x = x1 +/- d / sqrt(1 + m^2)
//            
//            newPoint.x = fromPoint.x + distanceOnXY / sqrt(1 + perpendicularSlope)
//            
//            // m = (y - y1) / (x - x1),
//            // y = m(x - x1) + y1
//            newPoint.y = perpendicularSlope * (newPoint.x - fromPoint.x) + fromPoint.y
//            
//            let d = sqrt(pow((newPoint.x - fromPoint.x), 2) + pow((newPoint.y - fromPoint.y), 2))
//            print("distance between new point and from point is \(d)")
//            
//            
//            //With quadratic equation
//            //  Linear equation: y = mx + b
//            // b = y - mx
////            let yInterceptOfPerpendicular = fromPoint.y - perpendicularSlope * fromPoint.x
////            
////            //  Distance formula:       d = sqrt((x1 - x2)^2 + (y1 - y2)^2),
////            //  Plug in:                25 = (x1 - point.x)^2 + (y1 - point.y)^2,
////            //  Linear equation:                                y = mx + b
////            //  Intermediate equation: 0 = (x - point.x)^2 + (mx + b - point.y)^2 - 25
////            //  Need to get a, b, c from quadratic equation 0 = ax^2 + bx + c
////            
////            let yInterceptMinusPointY = yInterceptOfPerpendicular - fromPoint.y
////            
////            let aQuadratic = (1.0 * 1.0) + pow(perpendicularSlope, 2)
////            let bQuadratic = -(2.0 * fromPoint.x * 1.0) + -(2.0 * perpendicularSlope * (yInterceptMinusPointY))
////            let cQuadratic = (fromPoint.x * fromPoint.x) + (pow(perpendicularSlope, 2) - distanceOnXY)
////            
////            let quadraticTuple = quadraticFormula(aQuadratic, b: bQuadratic, c: cQuadratic)
////            
////            
////            // If quadratic results is NaN, then
////            if quadraticTuple.add.isNaN {
////                print("Quadratic Tuple is NaN")
////                return nil
////            }
//            
//
//        let fromPointLatLong = coordinateDegrees(fromPoint)
//        let newPointLatLong = coordinateDegrees(newPoint)
//        deltaCoordinates.latitude = fromPointLatLong.latitude - newPointLatLong.latitude
//        deltaCoordinates.longitude = fromPointLatLong.longitude - newPointLatLong.longitude
////        let deltaXY: (x:Double, y:Double)
////        deltaXY.x = fromPoint.x - newPoint.x
////        deltaXY.y = fromPoint.y - newPoint.y
//        
////        deltaCoordinates = coordinateDegrees(deltaXY)

//        return deltaCoordinates
//    }

    // MARK: Quadratic formula method
    
//    //  Quadratic formula: x = (-b +/- sqrt(b^2 - 4ac)) / 2a
//    private func quadraticFormula(a:Double, b:Double, c:Double) -> (add:Double, subtract:Double) {
//        let returnTuple: (add:Double, subtract:Double)
////        let B24AC = (pow(b, 2) - 4 * a * c)
//        let sqrtB24AC = sqrt(pow(b, 2) - 4 * a * c)
//        returnTuple.add = (-b + sqrtB24AC) / (2 * a)
//        returnTuple.subtract = (-b - sqrtB24AC) / (2 * a)
//        return returnTuple
//    }
    
    
    // MARK: Convert xy to/from lat/long coordinates
    // Adjusts longitude to the xy coordinate field with equirectangular projection, which is good for small areas.
    // https://en.wikipedia.org/wiki/Equirectangular_projection
    // http://stackoverflow.com/questions/16266809/convert-from-latitude-longitude-to-x-y
    //x = λ cos(φ0), y = φ
    //"use the horizontal axis x to denote longitude λ, the vertical axis y to denote latitude φ. The ratio between these should not be 1:1, though. Instead you should use cos(φ0) as the aspect ratio, where φ0 denotes a latitude close to the center of your map."
    // - MvG on Stack Overflow
    
    
//    // aspectRatio = cos(centerLatitude)
//    var aspectRatio: Double?
//    
//    // cos(the mid-lat of NYC) = 0.75807276592
//    let defaultAspectRatio = 0.75807276592
//    
//    private func xyPoint(fromCoordinate coordinate: CLLocationCoordinate2D) -> (x:Double, y:Double) {
//        let xyCoordinate: (x:Double, y:Double)
//        
//        aspectRatio = cos(degreesToRadians(coordinate.latitude))
//        
//        if aspectRatio != nil {
//            xyCoordinate.x = coordinate.longitude * aspectRatio!
//        } else {
//            // cos(the mid-lat of NYC) = 0.75807276592
//            xyCoordinate.x = coordinate.longitude * defaultAspectRatio
//        }
//        xyCoordinate.y = coordinate.latitude
//
//        return xyCoordinate
//    }
//
//    private func coordinateDegrees(fromXY:(x:Double, y:Double)) -> CLLocationCoordinate2D {
//        var latLongCoordinate = CLLocationCoordinate2D.init()
//        
//        latLongCoordinate.latitude = fromXY.y
//        if aspectRatio != nil {
//            latLongCoordinate.longitude = fromXY.x / aspectRatio!
//        } else {
//            // cos(the mid-lat of NYC) = 0.75807276592
//            latLongCoordinate.longitude = fromXY.x / defaultAspectRatio
//        }
//        
//        return latLongCoordinate
//    }
//    
//    // d = sqrt(dx*dx + dy*dy)
//    private func distanceBetween(point1:(Double, Double), point2:(Double, Double)) -> Double {
//        let dx = point1.0 - point2.0
//        let dy = point1.1 - point2.1
//        return sqrt(dx * dx + dy * dy)
//    }
    
//    private func xyPerpendicularDistance(fromPath path:GMSPath, meters: Double) -> Double {
//        //If your displacements aren't too great (less than a few kilometers) and you're not right at the poles, use the quick and dirty estimate that 111,111 meters (111.111 km) in the y direction is 1 degree (of latitude) and 111,111 * cos(latitude) meters in the x direction is 1 degree (of longitude).
//        // -whuber on Stack Exchange
//        
//        //http://gis.stackexchange.com/questions/2951/algorithm-for-offsetting-a-latitude-longitude-by-some-amount-of-meters
//        
//        
//        // http://www.movable-type.co.uk/scripts/latlong.html
//        
//
//        // λ = longitude, φ = latitude, φ0 = reference latitude (near the middle of the area of reference)
//        // λ = xMeters / (111,111 * cos(φ0))
//        // φ = yMeters / 111,111
//        // dy / dx = slope
//        
//        
////        let fromCoordinate = path.coordinateAtIndex(0)
////        let toCoordinate = path.coordinateAtIndex(path.count() - 1)
////        let deltaLatLong = CLLocationCoordinate2DMake(fromCoordinate.latitude - toCoordinate.latitude, fromCoordinate.longitude - toCoordinate.longitude)
////        let perpendicularDeltaLatLong = CLLocationCoordinate2DMake(-deltaLatLong.longitude, deltaLatLong.latitude)
////        let perpendicularDeltaXY: (x:Double, y:Double)
////        perpendicularDeltaXY.y = perpendicularDeltaLatLong.latitude * meters / 111111
////        if aspectRatio != nil {
////            perpendicularDeltaXY.x = perpendicularDeltaLatLong.longitude * meters / (111111 * aspectRatio!)
////        } else {
////            perpendicularDeltaXY.x = perpendicularDeltaLatLong.longitude * meters / (111111 * defaultAspectRatio)
////        }
////        // d = sqrt(dx * dx + dy * dy)
////        let xyDistance = sqrt(perpendicularDeltaXY.x * perpendicularDeltaXY.x + perpendicularDeltaXY.y * perpendicularDeltaXY.y)
//        
//        return meters / 111111
//        
//    }