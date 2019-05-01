//
//  ReportButton.swift
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

class ReportButton: UIButton {
    
    var navigationViewController:NavigationViewController!
    
    override init(frame: CGRect) {
        self.navigationViewController = nil
        super.init(frame: frame)
    }
    
    init(frame: CGRect, title: String, navigation: NavigationViewController) {
        super.init(frame: frame)
        self.navigationViewController = navigation
        setupButton(title: title)
    }
    
    init(frame: CGRect, title: String) {
        super.init(frame: frame)
        setupButton(title: title)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupButton(title: String) {
        setTitle(title, for: .normal)
        backgroundColor = .purple
        layer.cornerRadius = 25
        layer.masksToBounds = true
        setTitleColor(.white, for: .normal)
    }
    
}
