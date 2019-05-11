//
//  ViewController.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    var app : App!
    var mmView : MMView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mmView = view as? MMView
        app = App( mmView )
        
        (NSApplication.shared.delegate as! AppDelegate).app = app
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

import WebKit


class HelpViewController: NSViewController, WKUIDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let helpView = view.subviews[0] as? WKWebView
        if helpView != nil {
            let appDelegate = (NSApplication.shared.delegate as! AppDelegate)
            appDelegate.webView = helpView

             //let urlString = "http://www.youtube.com";
             //let request = URLRequest(url:URL(string: urlString)!)
             //helpView!.load(request)
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}

