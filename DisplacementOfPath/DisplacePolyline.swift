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


enum PolylineError: Error {
    case notEnoughPoints
    case unableToRotateGeographicalBearing //Bearing must be between pi and -pi.
    case noPath(forPolyline:GMSPolyline)
    case invalidSideOfStreet // side of street must be N/S/E/W or north/south/east/west, case insensitive
    case bearingIsNAN
    case toAndFromCoordinatesAreTheSame
    case unknownErrorPolylineDisplacement
}

enum Direction: String {
    case north, south, east, west
    init?(withString string: String) {
        let lowercase = string.lowercased()
        let value: String
        switch lowercase {
        case "n", "north": value = "north"
        case "s", "south": value = "south"
        case "e", "east": value = "east"
        case "w", "west": value = "west"
        default:
            return nil
        }
        self.init(rawValue: value)
    }
}

extension GMSPolyline {
    // For displacing a single polyline
    func displaced(xMeters meters:Double, direction:Direction) throws -> GMSPolyline {
        guard var path = self.path else {
            throw PolylineError.noPath(forPolyline: self)
        }
        
        if let offset = try path.deltaLatAndLong(xMeters: meters, direction:direction) {
            path = path.pathOffset(byLatitude: offset.latitude, longitude: offset.longitude)
        }
        
        let polyline = GMSPolyline(path: path)
        polyline.strokeColor = UIColor.green
        polyline.strokeWidth = 2
        return polyline
    }
    
    func displaced(xPoints points:Double, zoom: Double, direction:Direction) throws -> GMSPolyline {
        let meters = points.metersToDisplace(fromZoom: zoom)
        return try displaced(xMeters: meters, direction: direction)
    }
}

extension Double {
    var toRadians: Double { return self * M_PI  / 180 }
    var toDegrees: Double { return self * 180 / M_PI }
    // MARK: - Meters to displace
    func metersToDisplace(fromZoom zoom:Double) -> Double {
        // https://developers.google.com/maps/documentation/ios-sdk/views#zoom
        // "at zoom level N, the width of the world is approximately 256 * 2^N, i.e., at zoom level 2, the whole world is approximately 1024 points wide"
        // So taking the proportions local points / world width points = local meters / world width meters
        // local meters = local points * world width meters / world width points
        
        let worldMeters = 40075000.0
        let worldPoints = 256 * pow(2, zoom)
        let meters = Double(self) * worldMeters / worldPoints
        return meters
    }
}

extension GMSPath {
     func deltaLatAndLong(xMeters meters:Double, direction:Direction) throws -> CLLocationCoordinate2D? {
        if self.count() < 2 {
            throw PolylineError.notEnoughPoints
        }
        var pathBearing = bearing(forPath: self)
        do {
            pathBearing = try rotate(pathBearing, direction: direction)
        } catch PolylineError.bearingIsNAN {
            pathBearing = try rotateBearingIfNAN(forPath: self, direction: direction)
        }
        
        let fromCoordinate = self.coordinate(at: 0)
        let newCoordinates = displacedCoordinates(xMeters: meters, pathBearing: pathBearing, fromCoordinate: fromCoordinate)
        // UNCOMMENT TO PRINT THE ACTUAL DISTANCE AND THE ERROR BETWEEN THE ACTUAL AND EXPECTED DISTANCE
        //        let fromLocation = CLLocation(latitude: fromCoordinate.latitude, longitude: fromCoordinate.longitude)
        //        let toLocation = CLLocation(latitude:radiansToDegrees(newLat), longitude:radiansToDegrees(newLong))
        //        let distance = fromLocation.distanceFromLocation(toLocation)
        //        print("distance is: \(distance), margin of error: \((distance - meters) / meters)")
        
        return CLLocationCoordinate2DMake(newCoordinates.latitude - fromCoordinate.latitude, newCoordinates.longitude - fromCoordinate.longitude)
    }
    
    fileprivate func bearing(forPath path:GMSPath) -> Double {
        // http://www.movable-type.co.uk/scripts/latlong.html
        // first find the bearing
        // θ = atan2( sin Δλ ⋅ cos φ2 , cos φ1 ⋅ sin φ2 − sin φ1 ⋅ cos φ2 ⋅ cos Δλ )
        let fromCoordinate = path.coordinate(at: 0)
        let long1 = fromCoordinate.longitude.toRadians
        let lat1 = fromCoordinate.latitude.toRadians
        
        let toCoordinate = path.coordinate(at: path.count() - 1)
        let long2 = toCoordinate.longitude.toRadians
        let lat2 = toCoordinate.latitude.toRadians
        
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
    
    //
    fileprivate func rotateBearingIfNAN(forPath path:GMSPath, direction:Direction) throws -> Double {
        let fromCoordinate = path.coordinate(at: 0)
        let fromLat = fromCoordinate.latitude
        let fromLong = fromCoordinate.longitude
        let toCoordinate = path.coordinate(at: path.count() - 1)
        let toLat = toCoordinate.latitude
        let toLong = toCoordinate.longitude
        if fromLat == toLat && fromLong == toLong { throw PolylineError.toAndFromCoordinatesAreTheSame }
        var slope = (fromLong - toLong) / (fromLat - toLat)
        if slope.isNaN { slope = 0 }
        return slope
    }

    fileprivate func rotate(_ bearing:Double, direction:Direction) throws -> Double {
        //MARK: Bearing calculation
        // To see what direction each path is, see MARK Path bearings
        var pathBearing = bearing
        //        print("Bearing before rotation: \(pathBearing)")
        switch true {
            // "switch true" meaning if the case statements are true
            
        case (pathBearing > 0 && pathBearing < M_PI_2) || pathBearing == M_PI_2:
            if direction == .north || direction == .west {
                pathBearing -= M_PI_2
            } else if direction == .south || direction == .east {
                pathBearing += M_PI_2
            }
        case (pathBearing < 0 && pathBearing > -M_PI_2) || pathBearing == 0:
            if direction == .north || direction == .east {
                pathBearing += M_PI_2
            } else if direction == .south || direction == .west {
                pathBearing -= M_PI_2
            }
        case (pathBearing > M_PI_2 && pathBearing < M_PI) || pathBearing == M_PI, pathBearing == -M_PI:
            if direction == .north || direction == .east {
                pathBearing -= M_PI_2
            } else if direction == .south || direction == .west {
                pathBearing += M_PI_2
            }
        case (pathBearing < -M_PI_2 && pathBearing > -M_PI || pathBearing == -M_PI_2):
            if direction == .north || direction == .west {
                pathBearing += M_PI_2
            } else if direction == .south || direction == .east {
                pathBearing -= M_PI_2
            }
        case pathBearing.isNaN:
            throw PolylineError.bearingIsNAN
        default: throw PolylineError.unableToRotateGeographicalBearing
        }
        return pathBearing
    }
    
    fileprivate func displacedCoordinates(xMeters meters:Double, pathBearing:Double, fromCoordinate:CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // Then you can find the displacement of the path
        //        var φ2 = Math.asin( Math.sin(φ1)*Math.cos(d/R) +
        //          Math.cos(φ1)*Math.sin(d/R)*Math.cos(brng) );
        //        var λ2 = λ1 + Math.atan2(Math.sin(brng)*Math.sin(d/R)*
        //          Math.cos(φ1), Math.cos(d/R)-Math.sin(φ1)*Math.sin(φ2));
        //
        // Angular distance: d/R = distance / radius of earth
        
        let lat1 = fromCoordinate.latitude.toRadians
        let long1 = fromCoordinate.longitude.toRadians
        let angularDistance = meters / 6371000
        let newLat = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(pathBearing))
        let newLong = long1 + atan2(sin(pathBearing) * sin(angularDistance) * cos(lat1), cos(angularDistance) - sin(lat1) * sin(newLat))
        return CLLocationCoordinate2D(latitude: newLat.toDegrees, longitude: newLong.toDegrees)
    }
}

extension GMSMapView {
    //MARK: - Create test polylines
    var testPolylines: [GMSPolyline] {
        // creates test polylines, two connecting opposite corners, and two midpoint horizontal and vertical lines
        var path = GMSMutablePath()
        var polylines = [GMSPolyline]()
        let visibleRegion = self.projection.visibleRegion()
        
        path.add(visibleRegion.nearRight)
        path.add(visibleRegion.farLeft)
        polylines.append(GMSPolyline.init(path: path))
        path = GMSMutablePath()
        path.add(visibleRegion.nearLeft)
        path.add(visibleRegion.farRight)
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
            polyline.strokeColor = UIColor.red
            polyline.strokeWidth = 2
            polyline.map = self
        }
        return polylines
    }
    
    fileprivate func verticalAndHorizontalPaths(forVisibleRegion visibleRegion:GMSVisibleRegion) -> (vertical:GMSMutablePath, horizontal:GMSMutablePath) {
        
        let returnTuple: (vertical:GMSMutablePath, horizontal:GMSMutablePath)
        let farRight = visibleRegion.farRight
        let nearLeft = visibleRegion.nearLeft
        
        let longitudeMidpoint = (farRight.longitude + nearLeft.longitude) / 2
        var path = GMSMutablePath()
        path.add(CLLocationCoordinate2DMake(nearLeft.latitude, longitudeMidpoint))
        path.add(CLLocationCoordinate2DMake(farRight.latitude, longitudeMidpoint))
        returnTuple.vertical = path
        
        let latitudeMidpoint = (nearLeft.latitude + farRight.latitude) / 2
        path = GMSMutablePath()
        path.add(CLLocationCoordinate2DMake(latitudeMidpoint, nearLeft.longitude))
        path.add(CLLocationCoordinate2DMake(latitudeMidpoint, farRight.longitude))
        returnTuple.horizontal = path
        
        return returnTuple
    }

}

