//
//  TapGesture.swift
//  BikeIt_updated
//
//  Created by Nabil on 4/30/19.
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

class TapGesture: UITapGestureRecognizer {
    var navigationViewController:NavigationViewController!
    
    override init(target: Any?, action: Selector?) {
        self.navigationViewController = nil
        super.init(target:target, action: action)
    }
    
}
