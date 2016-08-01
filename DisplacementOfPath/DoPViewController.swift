//
//  ViewController.swift
//  DisplacementOfPath
//
//  Created by Daniel Nomura on 7/21/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import UIKit
import GoogleMaps

class ViewController: UIViewController, GMSMapViewDelegate {

    var polylines = [GMSPolyline]()
    var startingAndDisplacedPolylines = [GMSPolyline]()
    @IBOutlet weak var mapView: GMSMapView!
    let polylineManager = SPPolylineManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    private func setUpMap() {
        let camera: GMSCameraPosition?
        
        camera = GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7688031, -73.960618), zoom: 14.0)
        
        if camera != nil {
            mapView.camera = camera!
        }
        
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.delegate = self
    }
    
    
    @IBAction func createTestPolylines(sender: UIButton) {
        if polylines.count != 0 {
            for polyline in polylines {
                polyline.map = nil
            }
        }
        polylines = polylineManager.testPolylines(forMapview: mapView)
    }

    
    @IBAction func displacePolylines(sender: UIButton)  {
        let zoom = Double(mapView.camera.zoom)
        
        let meters = polylineManager.metersToDisplace(byPoints: 3.5, zoom: zoom)
        
        print("meters to displace: \(meters)")
        
        let newPolylines =  polylineManager.displace(polylines: polylines, xMeters: meters)
        for polyline in newPolylines {
            polylines.append(polyline)
        }
        
        for i in 0..<polylines.count {
            let polyline = polylines[i]
            polyline.map = mapView
            
        }
    }
}

