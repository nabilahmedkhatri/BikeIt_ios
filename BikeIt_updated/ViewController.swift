//
//  ViewController.swift
//  BikeIt_updated
//
//  Created by Nabil on 4/28/19.
//  Copyright © 2019 Nabil. All rights reserved.
//

import UIKit
import Mapbox
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import Foundation
import MapboxGeocoder
import Alamofire
import SwiftyJSON

class CustomStyle: DayStyle {
    required init() {
        super.init()
        mapStyleURL = URL(string: "mapbox://styles/qnzboy/cjuf0et6l33nh1flptx3p10u2")!
    }
}

class CustomPointAnnotation: NSObject, MGLAnnotation {
    // As a reimplementation of the MGLAnnotation protocol, we have to add mutable coordinate and (sub)title properties ourselves.
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var report_type: String!
    
    // Custom properties that we will use to customize the annotation's image.
    var image: UIImage?
    var reuseIdentifier: String?
    var detours : [CLLocationCoordinate2D]!
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
    }
}
    
class ViewController: UIViewController, MGLMapViewDelegate, CLLocationManagerDelegate, NavigationMapViewDelegate, NavigationViewControllerDelegate, UITextFieldDelegate, FeedbackViewControllerDelegate {
    
    var mapView: NavigationMapView?
    var currentRoute: Route? {
        get {
            return routes?.first
        }
        set {
            guard let selected = newValue else { routes?.remove(at: 0); return }
            guard let routes = routes else { self.routes = [selected]; return }
            self.routes = [selected] + routes.filter { $0 != selected }
        }
    }
    var routes: [Route]? {
        didSet {
            guard let routes = routes, let current = routes.first else { mapView?.removeRoutes(); return }
            mapView?.showRoutes(routes)
            mapView?.showWaypoints(current)
        }
    }
    var locationManager = CLLocationManager()
    private typealias RouteRequestSuccess = (([Route]) -> Void)
    private typealias RouteRequestFailure = ((NSError) -> Void)
    
    // pre-navigation screen
    let styleURL = URL(string: "mapbox://styles/qnzboy/cjuf0et6l33nh1flptx3p10u2")
    var searchButton: UIButton!
    var fromTextField: UITextField!
    var toTextField: UITextField!
    var startButton: UIButton!
    let geocoder = Geocoder.shared
    
    // navigation
    var navigationViewController:NavigationViewController!

    // markers
    var markers = [CustomPointAnnotation]()
    
    // from and to locations
    var coordinateFrom = CLLocationCoordinate2D(latitude: 40.820933, longitude: -73.952915)
    var coordinateTo = CLLocationCoordinate2D(latitude: 40.758896, longitude: -73.985130)
    
    // report
    var reportButton: ReportButton!
    var constructionButton: ReportButton!
    var poorLaneButton: ReportButton!
    var blockedLaneButton: ReportButton!
    var dangerousAreaButton: ReportButton!
    var policeButton: ReportButton!
    var currentNavLocation : CLLocationCoordinate2D!
    var detour_coordinates: [CLLocationCoordinate2D] = []
    var submitButton: UIButton!
    
    // detouring
    var currentDestination:Waypoint!
    // var saved_waypoints:[Waypoint]=[]
    var reportType:String!


    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        mapView = NavigationMapView(frame: view.bounds, styleURL: styleURL)
        mapView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView?.userTrackingMode = .follow
        mapView?.delegate = self
        mapView?.navigationMapViewDelegate = self
        view.addSubview(mapView!)
        preparePreNavScreen()
        getMarkers()
        NotificationCenter.default.addObserver(self, selector: #selector(self.progressDidChange(notification:)), name: .routeControllerProgressDidChange, object: nil)
        
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { (t) in
            self.updateMarkers()
            print("automatic")
        }
        
        
    }

    func updateMarkers() {
        getMarkers()
        if let annotations = mapView?.annotations {
            mapView?.removeAnnotations(annotations)
            for marker in markers {
                mapView?.addAnnotation(marker)
                }
            }
        
        if ((navigationViewController) != nil) {
            if let nav_annotations = navigationViewController.mapView?.annotations {
                navigationViewController.mapView?.removeAnnotations(nav_annotations)
                for marker in markers {
                    navigationViewController.mapView?.addAnnotation(marker)

                }
            }
        }
        
    }
    
    func preparePreNavScreen() {
        fromTextField =  UITextField()
        fromTextField.placeholder = "📍 Current Location"
        fromTextField.font = UIFont.systemFont(ofSize: 15)
        fromTextField.borderStyle = UITextField.BorderStyle.roundedRect
        fromTextField.autocorrectionType = UITextAutocorrectionType.no
        fromTextField.keyboardType = UIKeyboardType.default
        fromTextField.returnKeyType = UIReturnKeyType.done
        fromTextField.clearButtonMode = UITextField.ViewMode.whileEditing;
        fromTextField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        fromTextField.delegate = self
        self.view.addSubview(fromTextField)
        
        // autolayout
        fromTextField.translatesAutoresizingMaskIntoConstraints = false
        fromTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        fromTextField.topAnchor.constraint(equalTo: view.topAnchor, constant: 25).isActive = true
        fromTextField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        fromTextField.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.95).isActive = true

        toTextField =  UITextField()
        toTextField.placeholder = "Destination"
        toTextField.font = UIFont.systemFont(ofSize: 15)
        toTextField.borderStyle = UITextField.BorderStyle.roundedRect
        toTextField.autocorrectionType = UITextAutocorrectionType.no
        toTextField.keyboardType = UIKeyboardType.default
        toTextField.returnKeyType = UIReturnKeyType.done
        toTextField.clearButtonMode = UITextField.ViewMode.whileEditing;
        toTextField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        toTextField.delegate = self
        self.view.addSubview(toTextField)
        
        // autolayout
        toTextField.translatesAutoresizingMaskIntoConstraints = false
        toTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        toTextField.topAnchor.constraint(equalTo: fromTextField.bottomAnchor, constant: 10).isActive = true
        toTextField.heightAnchor.constraint(equalToConstant: 40).isActive = true
        toTextField.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.95).isActive = true
        
        searchButton = UIButton()
        searchButton.setTitle("Search", for: .normal)
        searchButton.backgroundColor = .purple
        searchButton.setTitleColor(.white, for: .normal)
        searchButton.layer.cornerRadius = 10
        searchButton.addTarget(self, action: #selector(searchButtonWasPressed(_ :)), for: .touchUpInside)
        
        // autolayout
        view.addSubview(searchButton)
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        searchButton.topAnchor.constraint(equalTo: toTextField.bottomAnchor, constant: 15).isActive = true
        searchButton.widthAnchor.constraint(equalToConstant: 100).isActive = true
        searchButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
    }
    
    func addStartButton() {
        startButton = UIButton()
        startButton.setTitle("Start Navigation", for: .normal)
        startButton.backgroundColor = .purple
        startButton.setTitleColor(.white, for: .normal)
        startButton.layer.cornerRadius = 10
        startButton.addTarget(self, action: #selector(startButtonWasPressed(_ :)), for: .touchUpInside)
        view.addSubview(startButton)
        
        // autolayout
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        startButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -25).isActive = true
        startButton.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.95).isActive = true
        startButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    func makeReportButtons(navigationViewController: NavigationViewController) {
        var x_distance = 10
        var y_distance = 125
        constructionButton = ReportButton(frame: CGRect(x: x_distance, y: y_distance+1*(50+5), width: 50, height: 50), title: "🚧", navigation: navigationViewController)
        constructionButton.tag = 100
        constructionButton.addTarget(self, action: #selector(reportWasSelected(_:)), for: .touchUpInside)
        
        poorLaneButton =  ReportButton(frame: CGRect(x:  x_distance,  y: y_distance+2*(50+5), width: 50, height: 50), title: "👎", navigation: navigationViewController)
        poorLaneButton.tag = 101
        poorLaneButton.addTarget(self, action: #selector(reportWasSelected(_:)), for: .touchUpInside)

        
        blockedLaneButton =  ReportButton(frame: CGRect(x:  x_distance,  y: y_distance+3*(50+5), width: 50, height: 50), title: "⚠️", navigation: navigationViewController)
        blockedLaneButton.tag = 102
        blockedLaneButton.addTarget(self, action: #selector(reportWasSelected(_:)), for: .touchUpInside)

        
        dangerousAreaButton =  ReportButton(frame: CGRect(x:  x_distance,  y: y_distance+4*(50+5), width: 50, height: 50), title: "☠️", navigation: navigationViewController)
        dangerousAreaButton.tag = 103
        dangerousAreaButton.addTarget(self, action: #selector(reportWasSelected(_:)), for: .touchUpInside)

        
        policeButton =  ReportButton(frame: CGRect(x:  x_distance, y: y_distance+5*(50+5), width: 50, height: 50), title: "🚓", navigation: navigationViewController)
        policeButton.tag = 104
        policeButton.addTarget(self, action: #selector(reportWasSelected(_:)), for: .touchUpInside)

    }
    
    func imageWith(name: String?) -> UIImage? {
        let frame = CGRect(x: 0, y: 0, width: 25, height: 25)
        let nameLabel = UILabel(frame: frame)
        nameLabel.textAlignment = .center
        nameLabel.backgroundColor = .clear
        nameLabel.textColor = .white
        nameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        nameLabel.text = name
        UIGraphicsBeginImageContext(frame.size)
        if let currentContext = UIGraphicsGetCurrentContext() {
            nameLabel.layer.render(in: currentContext)
            let nameImage = UIGraphicsGetImageFromCurrentImageContext()
            return nameImage
        }
        return nil
    }

    
    @objc func reportWasSelected(_ sender: ReportButton) {
        print(sender.currentTitle)
        let alert = UIAlertController(title: "Did you want to provide a detour?", message: "Other cyclists can use the detour.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Yes", style: .default, handler: { action in
            let gesture = TapGesture(target: self, action: #selector(self.handleTapPress(_:)))
            gesture.navigationViewController = sender.navigationViewController
            sender.navigationViewController.mapView?.addGestureRecognizer(gesture)
            self.reportType = sender.titleLabel?.text
            self.addSubmitButton()
        }))
        
        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { action in
            let postsURLEndPoint: String = "http://nabil.co/detour"
            let post_parameters: Parameters = [
                "lat": self.currentNavLocation.latitude,
                "long": self.currentNavLocation.longitude,
                "type": sender.titleLabel?.text
            ]
            AF.request(postsURLEndPoint, method: .post, parameters: post_parameters, encoding: JSONEncoding.default).responseJSON {
                response in
                print(response)
            }
            self.removeButtons()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Change `2.0` to the desired number of seconds.
                self.updateMarkers()
            }
            
            self.showToast(message : "Submitted successfully")

            
            
        } ))
        
        sender.navigationViewController.present(alert, animated: true)
    }
    
    @objc func searchButtonWasPressed(_ sender: UIButton) {
        toTextField.resignFirstResponder()
        for marker in markers {
            mapView?.addAnnotation(marker)
        }
        
        var from : String!
        var to = toTextField.text
        if (!fromTextField.hasText) {
            geoCoder(to: to!)
        }
        else {
            from = fromTextField.text
            geoCoder(from: from!, to: to!)
        }
        
    }
    
    func geoCoder(to: String) {
        let options = ForwardGeocodeOptions(query: to)
        
        // To refine the search, you can set various properties on the options object.
        options.allowedISOCountryCodes = ["US"]
        //options.focalLocation = CLLocation(latitude: 45.3, longitude: -66.1)
        options.allowedScopes = [.address, .pointOfInterest]
        
        let task = geocoder.geocode(options) { (placemarks, attribution, error) in
            guard let placemark = placemarks?.first else {
                return
            }
            self.coordinateTo = CLLocationCoordinate2D(latitude: (placemark.location?.coordinate.latitude)!, longitude: (placemark.location?.coordinate.longitude)!)
            self.toTextField.text = placemark.qualifiedName
            self.requestRoute(destination: self.coordinateTo)
            
        }
    }
    
    func geoCoder(from: String, to: String) {
        let options = ForwardGeocodeOptions(query: from)
        
        // To refine the search, you can set various properties on the options object.
        options.allowedISOCountryCodes = ["US"]
        //options.focalLocation = CLLocation(latitude: 45.3, longitude: -66.1)
        options.allowedScopes = [.address, .pointOfInterest]
        
        let task = geocoder.geocode(options) { (placemarks, attribution, error) in
            guard let placemark = placemarks?.first else {
                return
            }
            self.coordinateFrom = CLLocationCoordinate2D(latitude: (placemark.location?.coordinate.latitude)!, longitude: (placemark.location?.coordinate.longitude)!)
            self.fromTextField.text = placemark.qualifiedName
            self.geoCoder(to: to)
        }
    }
    
    
    func requestRoute(destination: CLLocationCoordinate2D) {
        var fromWaypoint : Waypoint
        if (!fromTextField.hasText) {
            guard let userLocation = mapView?.userLocation!.location else { return }
            fromWaypoint = Waypoint(location: userLocation, heading: mapView?.userLocation?.heading, name: "user")
        }
        
        else {
            fromWaypoint = Waypoint(coordinate: self.coordinateFrom, name: "from")
        }
        
        let destinationWaypoint = Waypoint(coordinate: destination)
        self.currentDestination = destinationWaypoint
        
        let options = NavigationRouteOptions(waypoints: [fromWaypoint, destinationWaypoint], profileIdentifier: .cycling)

        Directions.shared.calculate(options) { (waypoints, routes, error) in
            guard let routes = routes else { return }
            self.addStartButton()
            self.routes = routes
            self.startButton?.isHidden = false
            self.mapView?.showRoutes(routes)
            self.mapView?.showWaypoints(self.currentRoute!)
        }
    }
    
    @objc func startButtonWasPressed(_ sender: UIButton) {
        guard let route = currentRoute else { return }
        // For demonstration purposes, simulate locations if the Simulate Navigation option is on.
        let navigationService = MapboxNavigationService(route: route, simulating: .always)
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        self.navigationViewController = NavigationViewController(for: route, options: navigationOptions)
        navigationViewController.delegate = self
//
//        for marker in markers {
//            navigationViewController.mapView?.addAnnotation(marker)
//        }
        
        navigationViewController.mapView?.delegate = self
        navigationViewController.showsReportFeedback = false
        reportButton = ReportButton(frame: CGRect(x: 10, y: 125, width: 50, height: 50), title: "📝", navigation: navigationViewController)
        reportButton.addTarget(self, action: #selector(addReportButtonWasPressed(_:)), for: .touchUpInside)
        reportButton.titleEdgeInsets = UIEdgeInsets(top: -5.0, left: 0.0, bottom: 0.0, right: 0.0)

        makeReportButtons(navigationViewController: navigationViewController)
        
        navigationViewController.mapView?.addSubview(reportButton)
        navigationViewController.mapView?.addAnnotations(markers)
        present(navigationViewController, animated: true, completion: nil)
        updateMarkers()
        
        
    }
    
    @objc func addReportButtonWasPressed(_ sender: ReportButton) {
        navigationViewController.mapView?.addSubview(constructionButton)
        navigationViewController.mapView?.addSubview(poorLaneButton)
        navigationViewController.mapView?.addSubview(blockedLaneButton)
        navigationViewController.mapView?.addSubview(dangerousAreaButton)
        navigationViewController.mapView?.addSubview(policeButton)
        
        
        reportButton.removeTarget(self, action: #selector(addReportButtonWasPressed(_:)), for: .touchUpInside)
        reportButton.addTarget(self, action: #selector(reportDone(_:)), for: .touchUpInside)
        
    }
    
    @objc func removeButtons() {
        if let subview = self.navigationViewController.mapView?.viewWithTag(100) {
            subview.removeFromSuperview()
            self.navigationViewController.mapView?.viewWithTag(101)?.removeFromSuperview()
            self.navigationViewController.mapView?.viewWithTag(102)?.removeFromSuperview()
            self.navigationViewController.mapView?.viewWithTag(103)?.removeFromSuperview()
            self.navigationViewController.mapView?.viewWithTag(104)?.removeFromSuperview()
            self.navigationViewController.mapView?.viewWithTag(105)?.removeFromSuperview()
        }
        reportButton.removeTarget(self, action: #selector(reportDone(_:)), for: .touchUpInside)
        reportButton.addTarget(self, action: #selector(addReportButtonWasPressed(_:)), for: .touchUpInside)
    }
    
    @objc func reportDone(_ sender: ReportButton) {
        removeButtons()
        sender.navigationViewController.mapView?.removeGestureRecognizer(sender.navigationViewController.mapView?.gestureRecognizers?.last as! UIGestureRecognizer)
        reportButton.removeTarget(self, action: #selector(reportDone(_:)), for: .touchUpInside)
        reportButton.addTarget(self, action: #selector(addReportButtonWasPressed(_:)), for: .touchUpInside)

    }
    
    @objc func handleTapPress(_ gesture: TapGesture) {
        guard gesture.state == .ended else { return }
        let spot = gesture.location(in: gesture.navigationViewController.mapView)
        guard let location = gesture.navigationViewController.mapView?.convert(spot, toCoordinateFrom: gesture.navigationViewController.mapView) else { return }
        detour_coordinates.append(location)
        
        let polyline = MGLPolylineFeature(coordinates: detour_coordinates, count: UInt(detour_coordinates.count))
        
        if (gesture.navigationViewController.mapView?.annotations?.first?.title == "Detour") {
            gesture.navigationViewController.mapView?.removeAnnotation((gesture.navigationViewController.mapView?.annotations?.first ?? nil)!)
        }
        
        polyline.title = "Detour"
        gesture.navigationViewController.mapView?.addAnnotation(polyline)
        
        
        
    }
    
    func addSubmitButton() {
        submitButton = UIButton()
        submitButton.setTitle("Submit Detour", for: .normal)
        submitButton.backgroundColor = .purple
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = 10
        submitButton.addTarget(self, action: #selector(submitButtonWasPressed(_ :)), for: .touchUpInside)
        navigationViewController.view.addSubview(submitButton)

        // autolayout
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.centerXAnchor.constraint(equalTo: navigationViewController.view.centerXAnchor).isActive = true
        submitButton.bottomAnchor.constraint(equalTo: navigationViewController.view.bottomAnchor, constant: -25).isActive = true
        submitButton.widthAnchor.constraint(equalTo: navigationViewController.view.widthAnchor, multiplier: 0.95).isActive = true
        submitButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
    }
    
    @objc func submitButtonWasPressed(_ sender: UIButton) {
        removeButtons()
        
        if (self.navigationViewController.mapView?.annotations?.first?.title == "Detour") {
            self.navigationViewController.mapView?.removeAnnotation((self.navigationViewController.mapView?.annotations?.first ?? nil)!)
        }
        
        sender.removeFromSuperview()
        navigationViewController.mapView?.removeGestureRecognizer(navigationViewController.mapView?.gestureRecognizers?.last as! UIGestureRecognizer)

        
        
        var coordinates:[ [Double] ] = []
        for detours in detour_coordinates {
            var waypoint:[Double] = []
            waypoint.append(Double(detours.latitude))
            waypoint.append(Double(detours.longitude))
            coordinates.append(waypoint)
        }
        
        let postsURLEndPoint: String = "http://nabil.co/detour"
        let post_parameters: Parameters = [
            "lat": self.currentNavLocation.latitude,
            "long": self.currentNavLocation.longitude,
            "type": self.reportType,
            "waypoints" : [
                "type": "LineString",
                "coordinates": coordinates
                
                
            ]
        ]
        
        AF.request(postsURLEndPoint, method: .post, parameters: post_parameters, encoding: JSONEncoding.default).responseJSON {
            response in
            print(response)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Change `2.0` to the desired number of seconds.
            self.updateMarkers()
        }
        self.showToast(message : "Submitted successfully")
    }
    
    func mapView(_ mapView: MGLMapView, lineWidthForPolylineAnnotation annotation: MGLPolyline) -> CGFloat {
        // Set the line width for polyline annotations
        return 5.0
    }
    
    func mapView(_ mapView: MGLMapView, strokeColorForShapeAnnotation annotation: MGLShape) -> UIColor {
        return UIColor.purple
    }
    
    func mapView(_ mapView: MGLMapView, strokeColorForPolylineAnnotation annotation: MGLPolyline) -> CGColor {
        return UIColor.red.cgColor
    }
    
    
    func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        self.currentRoute = route
    }
    
    func getMarkers() {
        let postsURLEndPoint: String = "http://nabil.co/detour"
        
        AF.request(postsURLEndPoint,encoding: URLEncoding(destination: .queryString)).responseJSON { response in
            
            switch response.result {
            case let .success(value):
                    let json = JSON(value)
                
                    for (index,subJson):(String, JSON) in json {
                    let lat = Double(subJson["lat"].stringValue)
                    let long = Double(subJson["long"].stringValue)
                    let coordinates = subJson["waypoints"]["coordinates"]
                    var waypoints:[CLLocationCoordinate2D] = []
                        for (subindex, subJson2):(String, JSON) in coordinates {
                            let w_lat = Double(subJson2[0].stringValue)
                            let w_long =  Double(subJson2[1].stringValue)
                            let waypoint = CLLocationCoordinate2D(latitude: w_lat!, longitude: w_long!)
                            waypoints.append(waypoint)
                        }
                    
                        let report_type = subJson["type"].stringValue
                    let marker = CustomPointAnnotation(coordinate: CLLocationCoordinate2D(latitude: lat!, longitude:  long!),
                        title: report_type,
                        subtitle: nil)
                        marker.report_type = report_type
                        if (!waypoints.isEmpty) {
                            marker.detours = waypoints
                            marker.title = "Detour available"
                        }
                    marker.reuseIdentifier = report_type
                    marker.image = self.dot(size: 15)
                        
                        switch marker.report_type {
                        case "☠️":
                            marker.title = "Dangerous Area"
                        case "🚓":
                             marker.title = "Police Presence"
                        case "👎":
                            marker.title = "Bad Route"
                        case "🚧":
                            marker.title = "Construction"
                        default:
                             marker.title = "Lane Warning/Obstruction"
                        }
                        
                    
                    
                    self.markers.append(marker)
                    }
    
                case let .failure(error): print("error")
            }
        }

    }
    
    func dot(size: Int) -> UIImage {
        let floatSize = CGFloat(size)
        let rect = CGRect(x: 0, y: 0, width: floatSize, height: floatSize)
        let strokeWidth: CGFloat = 1
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.main.scale)
        
        let ovalPath = UIBezierPath(ovalIn: rect.insetBy(dx: strokeWidth, dy: strokeWidth))
        UIColor.red.setFill()
        ovalPath.fill()
        
        UIColor.white.setStroke()
        ovalPath.lineWidth = strokeWidth
        ovalPath.stroke()
        
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return image
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        if let point = annotation as? CustomPointAnnotation,
            var image = self.imageWith(name: point.report_type),
            let reuseIdentifier = point.reuseIdentifier {
            if let annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
                // The annotatation image has already been cached, just reuse it.
                return annotationImage
            } else {
                
                switch point.report_type {
                case "☠️":
                    image = UIImage.scale(image: UIImage(named: "skull")!, by: 0.35)!
                case "🚓":
                    image = UIImage.scale(image: UIImage(named: "police")!, by: 0.35)!
                case "👎":
                    image = UIImage.scale(image: UIImage(named: "thumbs")!, by: 0.35)!
                case "🚧":
                    image = UIImage.scale(image: UIImage(named: "construction")!, by: 0.35)!
                    default:
                     image = UIImage.scale(image: UIImage(named: "warning")!, by: 0.35)!
                }
                
                return MGLAnnotationImage(image: image, reuseIdentifier: reuseIdentifier)
            }
        }
        
        // Fallback to the default marker image.
        return nil
    }
    
//    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
//
//        if let point = annotation as? CustomPointAnnotation {
//            let image = self.imageWith(name: point.report_type)
//            let reuseIdentifier = point.reuseIdentifier {
//
//
//            // The anchor point of an annotation is currently always the center. To
//            // shift the anchor point to the bottom of the annotation, the image
//            // asset includes transparent bottom padding equal to the original image
//            // height.
//            //
//            // To make this padding non-interactive, we create another image object
//            // with a custom alignment rect that excludes the padding.
//            //image = image!.withAlignmentRectInsets(UIEdgeInsets(top: 0, left: 0, bottom: image?.size.height / 2, right: 0))
//
//            // Initialize the ‘pisa’ annotation image with the UIImage we just loaded.
//            return MGLAnnotationImage(image: image, reuseIdentifier: "Detour")
//
////            if let annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: reuseIdentifier) {
////                // The annotatation image has already been cached, just reuse it.
////                return annotationImage
////            } else {
////                // Create a new annotation image.
////                return MGLAnnotationImage(image: image, reuseIdentifier: reuseIdentifier)
////            }
//
//
//        }
//
//        // Fallback to the default marker image.
//        return nil
//    }
    
    
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        // Only show callouts for `Hello world!` annotation.

        return annotation.responds(to: #selector(getter: MGLAnnotation.title)) //&& annotation.title! == "Hello world!"
    }
//
//    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
//        // Only show callouts for `Hello world!` annotation.
//        return (self.navigationViewController != nil && annotation.title! == "Detour available")
//    }
    
    func mapView(_ mapView: MGLMapView, calloutViewFor annotation: MGLAnnotation) -> MGLCalloutView? {
        // Instantiate and return our custom callout view.
        return CustomCalloutView(representedObject: annotation)
    }
    
   
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        // Optionally handle taps on the callout.
        print("Tapped the callout for: \(annotation.coordinate)")
         guard let point = annotation as? CustomPointAnnotation
        
            else { return }
        
        print("We got here \(annotation.coordinate)")
        mapView.deselectAnnotation(annotation, animated: true)
        if (self.navigationViewController != nil) {
        let origin = Waypoint(coordinate: self.currentNavLocation, name: "User")
        let destination = self.currentDestination
        
        var saved_waypoints : [Waypoint] = []
        
        saved_waypoints.append(origin)
        for coords in point.detours {
            print(coords)
            let current = Waypoint(coordinate: coords)
            current.separatesLegs = false
            saved_waypoints.append(current)
        }
        saved_waypoints.append(destination!)

        let options = NavigationRouteOptions(waypoints: saved_waypoints, profileIdentifier: .cycling)
        
        Directions.shared.calculate(options) { (waypoints, routes, error) in
            guard let newRoute = routes?.first else { return }
            
            let instruction = SpokenInstruction(
                distanceAlongStep: 0,
                text: "Taking the detour.",
                ssmlText: "<speak>Taking the <prosody pitch='high'>detour</prosody> </speak>")
            self.navigationViewController.voiceController.speak(instruction)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Change `2.0` to the desired number of seconds.
                self.navigationViewController.route = newRoute
                print("NEW ROUTEEEEEEE", newRoute)
            }   // Code you want to be delayed
            
            }
            
        }
        
        
        
    }
    
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    
    @objc
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        navigationViewController.navigationService.stop()
        dismiss(animated: true, completion: nil)

    }
    
    @objc func progressDidChange(notification: NSNotification) {
        let routeProgress = notification.userInfo![RouteControllerNotificationUserInfoKey.routeProgressKey] as! RouteProgress
        let location = notification.userInfo![RouteControllerNotificationUserInfoKey.locationKey] as! CLLocation
        let currentLocation = location.coordinate
        // let locb = timesquare.distance(to: currentLocation)
        self.currentNavLocation = currentLocation
    }
    
    func showToast(message : String) {
        
        let toastLabel = UILabel(frame: CGRect(x: self.view.frame.size.width/2 - 150, y: self.view.frame.size.height-100, width: 300, height: 35))
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.navigationViewController.view.addSubview(toastLabel)
        UIView.animate(withDuration: 0.5, delay: 3.0, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
    
    

}

