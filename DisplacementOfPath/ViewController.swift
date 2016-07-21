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

    var startingPolylines = [GMSPolyline]()
    @IBOutlet weak var mapView: GMSMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        startingPolylines = createStartingPolylines()
        
        
        
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    private func setUpMap() {
        let camera: GMSCameraPosition?
        
        camera = GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7688031, -73.960618), zoom: 12.5)
        
        if camera != nil {
            mapView.camera = camera!
        }
        
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.delegate = self
    }

    private func createStartingPolylines() -> [GMSPolyline] {
        var path = GMSMutablePath()
        var polylines = [GMSPolyline]()
        let visibleRegion = mapView.projection.visibleRegion()
//        path.addCoordinate(visibleRegion.farLeft)
//        path.addCoordinate(visibleRegion.farRight)
//        polylines.append(GMSPolyline.init(path: path))
//        path = GMSMutablePath()
        path.addCoordinate(visibleRegion.farLeft)
        path.addCoordinate(visibleRegion.nearRight)
        polylines.append(GMSPolyline.init(path: path))
        path = GMSMutablePath()
        path.addCoordinate(visibleRegion.nearLeft)
        path.addCoordinate(visibleRegion.farRight)
        polylines.append(GMSPolyline.init(path: path))
        
        for i in 0 ..< polylines.count {
            let polyline = polylines[i]
            polyline.strokeColor = UIColor.redColor()
            polyline.map = mapView
        }
        return polylines
    }
    
    @IBAction func displacePolylines(sender: AnyObject) {
        startingPolylines = SPPolylineManager().displacedPolylines(startingPolylines)
        for polyline in startingPolylines {
            polyline.map = mapView
        }
    }
}

