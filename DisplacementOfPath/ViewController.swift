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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let notificationCenter = NotificationCenter.default
        notificationCenter.removeObserver(self)
    }
    
    fileprivate func addNotifications() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(keyboardWasShown), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(keyboardWillBeHidden), name: NSNotification.Name.UIKeyboardDidHide, object: nil)
    }
    
    @objc fileprivate func keyboardWasShown(_ notification:Notification) {
        if isKeyboardshown { return }
        if let info: NSDictionary = notification.userInfo as NSDictionary? {
            if let keyboardValue = info.object(forKey: UIKeyboardFrameBeginUserInfoKey) as? NSValue {
                let keyboardSize = keyboardValue.cgRectValue
                var viewFrame = scrollContainerView.frame
                viewFrame.size.height -= keyboardSize.height
                UIView.animate(withDuration: 0.3, animations: {
                    self.scrollContainerView.frame = viewFrame
                })
                isKeyboardshown = true
            }
        }
    }
    
    @objc fileprivate func keyboardWillBeHidden(_ notification:Notification) {
        if let info: NSDictionary = notification.userInfo as NSDictionary? {
            if let keyboardValue = info.object(forKey: UIKeyboardFrameBeginUserInfoKey) as? NSValue {
                let keyboardSize = keyboardValue.cgRectValue
                var viewFrame = scrollContainerView.frame
                viewFrame.size.height += keyboardSize.height
                UIView.animate(withDuration: 0.3, animations: {
                    self.scrollContainerView.frame = viewFrame
                })
                isKeyboardshown = false
            }
        }
    }
    
    
    fileprivate func addGestures() {
        let tapGesture = UITapGestureRecognizer.init(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc fileprivate func dismissKeyboard() {
        view.endEditing(true)
    }
    
    
    fileprivate func setUpMap() {
        mapView.camera = GMSCameraPosition.camera(withTarget: CLLocationCoordinate2DMake(40.7688031, -73.960618), zoom: 14.0)
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.consumesGesturesInView = false
        mapView.delegate = self
    }
    
    @IBAction func createTestPolylines(_ sender: UIButton) {
        hide(currentPolylines)
        currentPolylines = mapView.testPolylines
        show(currentPolylines)
    }
    
    fileprivate func hide(_ polylines:[GMSPolyline]) {
        if polylines.count != 0 {
            for polyline in polylines {
                polyline.map = nil
            }
        }
    }
    
    fileprivate func show(_ polylines:[GMSPolyline]) {
        if polylines.count != 0 {
            for polyline in polylines {
                polyline.map = mapView
            }
        }
    }

    @IBAction func displacePolylines(_ sender: UIButton)  {
        displacePolylines()
    }
    
    fileprivate func displacePolylines() {
        if currentPolylines.count == 0 { return }
        let zoom = Double(mapView.camera.zoom)
        guard let points = Double(pointDisplacementTextField.text!) else {
            let alertController = UIAlertController.init(title: "Error", message: "Need to have valid number in text field", preferredStyle: .alert)
            let confirmationAction = UIAlertAction.init(title: "Okay", style: .default, handler: nil)
            alertController.addAction(confirmationAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        
        guard let direction = Direction.init(withString: directionTextField.text!) else {
            let alertController = UIAlertController.init(title: "Error", message: "Need to have valid direction in text field", preferredStyle: .alert)
            let confirmationAction = UIAlertAction.init(title: "Okay", style: .default, handler: nil)
            alertController.addAction(confirmationAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        
        let newPolylines = currentPolylines.flatMap { try? $0.displaced(xPoints: points, zoom: zoom, direction: direction) }
        show(newPolylines)
        
        for polyline in newPolylines {
            currentPolylines.append(polyline)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField === pointDisplacementTextField {
            if textField.text == "" { textField.text = "3.5" }
        }
        if textField === directionTextField {
            if textField.text == "" { textField.text = "North" }
        }
    }
}

