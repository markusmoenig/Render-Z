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
        let request = URLRequest(url:URL(string: "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/pages/5406721/Getting+Started")!)
        webView.load(request)
        
        //getSampleProject(view: app.mmView, title: "New Project", message: "Select the project type", sampleProjects: ["Empty Project"], cb: { (index) -> () in
        //    print("Result", index)
        //} )
        
        let dialog = MMTemplateChooser(app.mmView)
        app.mmView.showDialog(dialog)
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
                return .terminateCancel
            }
        }
        return .terminateNow
    }
    
    // new menu item
    @IBAction func newMenu(_ sender: Any)
    {
        app.topRegion!.newButton!._clicked(MMMouseEvent(0,0))
    }
    
    // Open menu item
    @IBAction func openMenu(_ sender: Any)
    {
        app.topRegion!.openButton!._clicked(MMMouseEvent(0,0))
    }
    
    // save menu item
    @IBAction func saveMenu(_ sender: Any)
    {
        app.topRegion!.saveButton!._clicked(MMMouseEvent(0,0))
    }
    
    // help menu item
    @IBAction func helpMenu(_ sender: Any)
    {
        showHelp()
    }
}

