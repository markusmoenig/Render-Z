//
//  AppDelegate.swift
//  Render-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Cocoa
import WebKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    weak var app: App!
    
    var helpWindowController: NSWindowController!
    var webView             : WKWebView!
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let window = app.mmView.window!

        window.setFrameAutosaveName("MainWindow")
        //let mainStoryboard = NSStoryboard.init(name: "Main", bundle: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

