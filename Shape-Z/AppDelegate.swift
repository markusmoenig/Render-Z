//
//  AppDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Cocoa
import WebKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    weak var app: App!
    
    var helpWindowController: NSWindowController!
    var webView             : WKWebView!
    weak var gameView       : GameViewController!
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        
        let window = app.mmView.window!
        window.representedURL = app.mmFile.url()
        window.title = app.mmFile.name
        
        window.setFrameAutosaveName("MainWindow")
        
        //var windowFrame = window.frame
        //let width : Float = 1920; let height : Float = 1080
        //windowFrame.size = NSMakeSize(CGFloat(width / app.mmView.scaleFactor), CGFloat(height / app.mmView.scaleFactor))
        
        let mainStoryboard = NSStoryboard.init(name: "Main", bundle: nil)
        helpWindowController = (mainStoryboard.instantiateController(withIdentifier: "HelpWindow") as! NSWindowController)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func windowWillReturnUndoManager(window: NSWindow) -> UndoManager? {
        // Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
        //return persistentContainer.viewContext.undoManager
        return app!.mmView.undoManager
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }
}

