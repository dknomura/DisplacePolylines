//
//  ViewController.swift
//  DisplacementOfPath
//
//  Created by Daniel Nomura on 7/21/16.
//  Copyright © 2016 Daniel Nomura. All rights reserved.
//

import UIKit
import GoogleMaps

class ViewController:
UIViewController, GMSMapViewDelegate, UITextFieldDelegate {

    var currentPolylines = [GMSPolyline]()
    var startingAndDisplacedPolylines = [GMSPolyline]()
    let polylineManager = DNPolylineDisplacer()

    @IBOutlet weak var mapView: GMSMapView!
    @IBOutlet weak var pointDisplacementTextField: UITextField!
    @IBOutlet weak var directionTextField: UITextField!
    
    var isKeyboardshown = false
    
    @IBOutlet weak var scrollContainerView: UIScrollView!
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMap()
        addGestures()
        addNotifications()
        var contentSize = scrollContainerView.frame.size
        contentSize.height += 100
        scrollContainerView.contentSize = contentSize
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self)
    }
    
    private func addNotifications() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: #selector(keyboardWasShown), name: UIKeyboardDidShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillBeHidden), name: UIKeyboardDidHideNotification, object: nil)
    }
    
    @objc private func keyboardWasShown(notification:NSNotification) {
        if isKeyboardshown { return }
        if let info: NSDictionary = notification.userInfo {
            if let keyboardValue = info.objectForKey(UIKeyboardFrameBeginUserInfoKey) as? NSValue {
                let keyboardSize = keyboardValue.CGRectValue()
                var viewFrame = scrollContainerView.frame
                viewFrame.size.height -= keyboardSize.height
                UIView.animateWithDuration(0.3, animations: {
                    self.scrollContainerView.frame = viewFrame
                })
                isKeyboardshown = true
            }
        }
    }
    
    @objc private func keyboardWillBeHidden(notification:NSNotification) {
        if let info: NSDictionary = notification.userInfo {
            if let keyboardValue = info.objectForKey(UIKeyboardFrameBeginUserInfoKey) as? NSValue {
                let keyboardSize = keyboardValue.CGRectValue()
                var viewFrame = scrollContainerView.frame
                viewFrame.size.height += keyboardSize.height
                UIView.animateWithDuration(0.3, animations: {
                    self.scrollContainerView.frame = viewFrame
                })
                isKeyboardshown = false
            }
        }
    }
    
    
    private func addGestures() {
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
    private func setUpMap() {
        mapView.camera = GMSCameraPosition.cameraWithTarget(CLLocationCoordinate2DMake(40.7688031, -73.960618), zoom: 14.0)
        mapView.myLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.consumesGesturesInView = false
        mapView.delegate = self
    }
    
    @IBAction func createTestPolylines(sender: UIButton) {
        hide(currentPolylines)
        currentPolylines = polylineManager.testPolylines(forMapview: mapView)
        show(currentPolylines)
    }
    
    private func hide(polylines:[GMSPolyline]) {
        if polylines.count != 0 {
            for polyline in polylines {
                polyline.map = nil
            }
        }
    }
    
    private func show(polylines:[GMSPolyline]) {
        if polylines.count != 0 {
            for polyline in polylines {
                polyline.map = mapView
            }
        }
    }

    @IBAction func displacePolylines(sender: UIButton)  {
        displacePolylines()
    }
    
    private func displacePolylines() {
        if currentPolylines.count == 0 { return }
        let zoom = Double(mapView.camera.zoom)
        guard let points = Double(pointDisplacementTextField.text!) else {
            let alertController = UIAlertController.init(title: "Error", message: "Need to have valid number in text field", preferredStyle: .Alert)
            let confirmationAction = UIAlertAction.init(title: "Okay", style: .Default, handler: nil)
            alertController.addAction(confirmationAction)
            presentViewController(alertController, animated: true, completion: nil)
            return
        }
        let meters = polylineManager.metersToDisplace(byPoints: points, zoom: zoom)
        guard var direction = directionTextField.text else { return }
        
        do {
            direction = try polylineManager.normalize(direction: direction)
            let newPolylines = polylineManager.displace(polylines: currentPolylines, xMeters: meters, direction:direction)
            show(newPolylines)
            
            for polyline in newPolylines {
                currentPolylines.append(polyline)
            }
        } catch {
            let alertController = UIAlertController.init(title: "Error", message: "Need to have valid direction in text field", preferredStyle: .Alert)
            let confirmationAction = UIAlertAction.init(title: "Okay", style: .Default, handler: nil)
            alertController.addAction(confirmationAction)
            presentViewController(alertController, animated: true, completion: nil)
        }
        
    }
    
    func textFieldDidEndEditing(textField: UITextField) {
        if textField === pointDisplacementTextField {
            if textField.text == "" { textField.text = "3.5" }
        }
        if textField === directionTextField {
            if textField.text == "" { textField.text = "North" }
        }
    }
}

