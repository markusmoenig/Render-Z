//
//  ViewController.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Cocoa
//import GameKit

class ViewController: NSViewController, NSWindowDelegate /*, GKGameCenterControllerDelegate*/ {
    
    //func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
    //}
    
    var app : App!
    var mmView : MMView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mmView = view as? MMView
        app = App( mmView )
        
        (NSApplication.shared.delegate as! AppDelegate).app = app
        
        //authenticateLocalPlayer()
    }
    
    /*
    // MARK: - AUTHENTICATE LOCAL PLAYER
    func authenticateLocalPlayer() {
        let localPlayer: GKLocalPlayer = GKLocalPlayer.local
             
        localPlayer.authenticateHandler = {(ViewController, error) -> Void in
            if((ViewController) != nil) {
                // 1. Show login if player is not logged in
                //self.present(ViewController!, animated: true, completion: nil)
            } else if (localPlayer.isAuthenticated) {
                // 2. Player is already authenticated & logged in, load game center
                //self.gcEnabled = true
                
                print("auth")
                     
                // Get the default leaderboard ID
                localPlayer.loadDefaultLeaderboardIdentifier(completionHandler: { (leaderboardIdentifer, error) in
                    if error != nil { //print(error)
                    } else { /*self.gcDefaultLeaderBoard = leaderboardIdentifer!*/ }
                })
                 
            } else {
                // 3. Game center is not enabled on the users device
                //self.gcEnabled = false
                print("Local player could not be authenticated!")
                //print(error)
            }
        }
    }*/
    
    override func viewDidAppear() {
        self.view.window?.delegate = self
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

class GameViewController: NSViewController, NSWindowDelegate {
    
    var app         : GameApp!
    var mmView      : MMView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mmView = view as? MMView
        app = GameApp( mmView )
        
        let appDelegate = (NSApplication.shared.delegate as! AppDelegate)
        appDelegate.gameView = self
    }
    
    override func viewDidAppear() {
        self.view.window?.delegate = self
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool
    {
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        if let delegate = NSApplication.shared.delegate as? AppDelegate {
            delegate.app.topRegion!.playButton.isDisabled = false
            delegate.app.mmView.update()
        }
    }
    
    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
}
