//
//  SPPolyLineManager.swift
//  SwoopParkingApp
//
//  Created by Daniel Nomura on 7/11/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import Foundation
import GoogleMaps
import MapKit
import CoreLocation

// maybe write some tests later.. https://robots.thoughtbot.com/creating-your-first-ios-framework

enum PolylineError: ErrorType {
    case notEnoughPoints
    case unableToRotateGeographicalBearing //Bearing must be between pi and -pi.
    case noPath(forPolyline:GMSPolyline)
    case invalidSideOfStreet // side of street must be N/S/E/W or north/south/east/west, case insensitive
    case bearingIsNAN
    case toAndFromCoordinatesAreTheSame
    case unknownErrorPolylineDisplacement
}

//protocol MapPolyline {}
//extension GMSPolyline: MapPolyline {}
//extension MKPolyline: MapPolyline {}

class DNPolylineDisplacer {
    //MARK: - Polyline displacement
    
    func displace(polylines polylines: [GMSPolyline], xPoints points:Double, zoom: Double, direction:String) -> [GMSPolyline] {
        let meters = metersToDisplace(byPoints: points, zoom: zoom)
        return displace(polylines: polylines, xMeters: meters, direction: direction)
    }

    
    // For multiple polylines will return displaced polylines
    func displace(polylines polylines: [GMSPolyline], xMeters meters:Double, direction:String) -> [GMSPolyline] {
        var returnArray = [GMSPolyline]()
        
        for polyline in polylines {
            do {
                returnArray.append(try displacedPolyline(originalPolyline: polyline, xMeters: meters, direction: direction))
            } catch PolylineError.notEnoughPoints {
                print("Not enough points on path to make a line")
                continue
            } catch PolylineError.unableToRotateGeographicalBearing {
                print("Unable to rotate geographical bearing. Bearing is not between pi and -pi")
                continue
            } catch PolylineError.noPath(let polyline) {
                print("No path for polyline: \(polyline)")
                continue
            } catch PolylineError.invalidSideOfStreet {
                print("Invalid side of street, must be N/S/E/W or North/South/East/West, case insensitive")
                continue
            } catch PolylineError.toAndFromCoordinatesAreTheSame {
                print("Invalid location. To and from coordinates are the same.")
                continue
            } catch {
                print("Unknown polyline displacement error.. Sorry!")
                continue
            }
        }
        return returnArray
    }
    
    // For displacing a single polyline
    func displacedPolyline(originalPolyline polyline:GMSPolyline, xMeters meters:Double, direction:String) throws -> GMSPolyline {
        guard var path = polyline.path else { throw PolylineError.noPath(forPolyline: polyline) }
        
        if let offset = try deltaLatAndLong(fromPath: path, xMeters: meters, direction:direction) {
            path = path.pathOffsetByLatitude(offset.latitude, longitude: offset.longitude)
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor.greenColor()
        polyline.strokeWidth = 2

        return polyline
    }
    
    private func deltaLatAndLong(fromPath path:GMSPath, xMeters meters:Double, direction:String) throws -> CLLocationCoordinate2D? {
        if path.count() < 2 {
            throw PolylineError.notEnoughPoints
        }
        var pathBearing = bearing(forPath: path)
        let side = try normalize(direction: direction)
        
        do {
            pathBearing = try rotate(pathBearing, direction: side)
        } catch PolylineError.bearingIsNAN {
            pathBearing = try rotateBearingIfNAN(forPath: path, direction: side)
        }
        
        let fromCoordinate = path.coordinateAtIndex(0)
        let newCoordinates = displacedCoordinates(xMeters: meters, pathBearing: pathBearing, fromCoordinate: fromCoordinate)
        
        //        let fromLocation = CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
        //        let toLocation = CLLocation(latitude:radiansToDegrees(newLat), longitude:radiansToDegrees(newLong))
        //        let distance = fromLocation.distanceFromLocation(toLocation)
        //        print("distance is: \(distance), margin of error: \((distance - meters) / meters)")
        
        return CLLocationCoordinate2DMake(newCoordinates.latitude - fromCoordinate.latitude, newCoordinates.longitude - fromCoordinate.longitude)
    }
    
    private func bearing(forPath path:GMSPath) -> Double {
        // http://www.movable-type.co.uk/scripts/latlong.html
        // first find the bearing
        // θ = atan2( sin Δλ ⋅ cos φ2 , cos φ1 ⋅ sin φ2 − sin φ1 ⋅ cos φ2 ⋅ cos Δλ )
        let fromCoordinate = path.coordinateAtIndex(0)
        let long1 = degreesToRadians(fromCoordinate.longitude)
        let lat1 = degreesToRadians(fromCoordinate.latitude)
        
        let toCoordinate = path.coordinateAtIndex(path.count() - 1)
        let long2 = degreesToRadians(toCoordinate.longitude)
        let lat2 = degreesToRadians(toCoordinate.latitude)
        
        // Above formula to find bearing breaks down to
        //    var y = Math.sin(λ2-λ1) * Math.cos(φ2);
        //    var x = Math.cos(φ1)*Math.sin(φ2) -
        //            Math.sin(φ1)*Math.cos(φ2)*Math.cos(λ2-λ1);
        //    var brng = Math.atan2(y, x).toDegrees();
        
        let y = sin(long2 - long1) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(long2 - long1)
        let bearing = atan2(y, x)
        return bearing
    }
    
    private func rotateBearingIfNAN(forPath path:GMSPath, direction:String) throws -> Double {
        let fromCoordinate = path.coordinateAtIndex(0)
        let fromLat = fromCoordinate.latitude
        let fromLong = fromCoordinate.longitude
        let toCoordinate = path.coordinateAtIndex(path.count() - 1)
        let toLat = toCoordinate.latitude
        let toLong = toCoordinate.longitude
        if fromLat == toLat && fromLong == toLong { throw PolylineError.toAndFromCoordinatesAreTheSame }
        var slope = (fromLong - toLong) / (fromLat - toLat)
        if slope.isNaN { slope = 0 }
        return slope
    }
    
    func normalize(direction direction:String) throws -> String {
        let sideString = direction.lowercaseString
        
        switch sideString {
        case "n", "north":
            return "N"
        case "e", "east":
            return "E"
        case "s", "south":
            return "S"
        case "w", "west":
            return "W"
        default:
            throw PolylineError.invalidSideOfStreet
        }
    }
    
    private func rotate(bearing:Double, direction:String) throws -> Double {
        //MARK: Bearing calculation
        // To see what direction each path is, see MARK Path bearings
        var pathBearing = bearing
//        print("Bearing before rotation: \(pathBearing)")
        switch true {
            // "switch true" meaning if the case statements are true
            
        case (pathBearing > 0 && pathBearing < M_PI_2) || pathBearing == M_PI_2:
            if direction == "N" || direction == "W" {
                pathBearing -= M_PI_2
            } else if direction == "S" || direction == "E" {
                pathBearing += M_PI_2
            }
        case (pathBearing < 0 && pathBearing > -M_PI_2) || pathBearing == 0:
            if direction == "N" || direction == "E" {
                pathBearing += M_PI_2
            } else if direction == "S" || direction == "W" {
                pathBearing -= M_PI_2
            }
        case (pathBearing > M_PI_2 && pathBearing < M_PI) || pathBearing == M_PI, pathBearing == -M_PI:
            if direction == "N" || direction == "E" {
                pathBearing -= M_PI_2
            } else if direction == "S" || direction == "W" {
                pathBearing += M_PI_2
            }
        case (pathBearing < -M_PI_2 && pathBearing > -M_PI || pathBearing == -M_PI_2):
            if direction == "N" || direction == "W" {
                pathBearing += M_PI_2
            } else if direction == "S" || direction == "E" {
                pathBearing -= M_PI_2
            }
        case pathBearing.isNaN:
            throw PolylineError.bearingIsNAN
        default: throw PolylineError.unableToRotateGeographicalBearing
        }
        return pathBearing
    }
    
    private func displacedCoordinates(xMeters meters:Double, pathBearing:Double, fromCoordinate:CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // Then you can find the displacement of the path
        //        var φ2 = Math.asin( Math.sin(φ1)*Math.cos(d/R) +
        //          Math.cos(φ1)*Math.sin(d/R)*Math.cos(brng) );
        //        var λ2 = λ1 + Math.atan2(Math.sin(brng)*Math.sin(d/R)*
        //          Math.cos(φ1), Math.cos(d/R)-Math.sin(φ1)*Math.sin(φ2));
        //
        // Angular distance: d/R = distance / radius of earth
        
        let lat1 = degreesToRadians(fromCoordinate.latitude)
        let long1 = degreesToRadians(fromCoordinate.longitude)
        let angularDistance = meters / 6371000
        let newLat = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(pathBearing))
        let newLong = long1 + atan2(sin(pathBearing) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(newLat))
        return CLLocationCoordinate2D(latitude: radiansToDegrees(newLat), longitude: radiansToDegrees(newLong))
    }

    private func degreesToRadians(degrees:Double) -> Double { return degrees * M_PI  / 180 }
    
    private func radiansToDegrees(radians:Double) -> Double { return radians * 180 / M_PI }
    
    
    // MARK: - Meters to displace
    func metersToDisplace(byPoints points:Double, zoom:Double) -> Double {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
        // So taking the proportions local points / world width points = local meters / world width meters
        // local meters = local points * world width meters / world width points
        
        let worldMeters = 40075000.0
        let worldPoints = 256 * pow(2, zoom)
        let meters = points * worldMeters / worldPoints
        return meters
    }
    
    
    //MARK: - Create test polylines
    func testPolylines(forMapview mapView:GMSMapView) -> [GMSPolyline] {
        // creates test polylines, two connecting opposite corners, and two midpoint horizontal and vertical lines
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
        polylines.append(GMSPolyline(path: vertAndHorzPaths.horizontal))
        
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
}
