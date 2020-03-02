//
//  ViewController.swift
//  Render-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSWindowDelegate {

    var app : App!
    var mmView : MMView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mmView = view as? MMView
        app = App( mmView )
        
        (NSApplication.shared.delegate as! AppDelegate).app = app
        
        //authenticateLocalPlayer()
    }

    override func viewDidAppear() {
        self.view.window?.delegate = self
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool
    {
        if app.mmView.undoManager!.canUndo {
            let question = NSLocalizedString("You have unsaved changes. Quit anyway?", comment: "Quit without saves error question message")
            let info = NSLocalizedString("Quitting now will lose any changes you have made since the last successful save", comment: "Quit without saves error question info");
            let quitButton = NSLocalizedString("Quit anyway", comment: "Quit anyway button title")
            let cancelButton = NSLocalizedString("Cancel", comment: "Cancel button title")
            let alert = NSAlert()
            alert.messageText = question
            alert.informativeText = info
            alert.addButton(withTitle: quitButton)
            alert.addButton(withTitle: cancelButton)
            
            let answer = alert.runModal()
            if answer == .alertSecondButtonReturn {
                return false
            }
        }
        app!.mmView.undoManager!.removeAllActions()
        return true
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
