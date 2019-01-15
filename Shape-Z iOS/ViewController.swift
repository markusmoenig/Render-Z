//
//  ViewController.swift
//  Shape-Z iOS
//
//  Created by Markus Moenig on 13/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var app : App!
    var mmView : MMView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mmView = view as? MMView
        app = App( mmView )
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
}
