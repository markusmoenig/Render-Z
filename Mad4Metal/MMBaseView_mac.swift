//
//  MMBaseView_mac.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class MMBaseView : MTKView
{
    var trackingArea    : NSTrackingArea?

    var widgets         = [MMWidget]()
    var hoverWidget     : MMWidget?
    var focusWidget     : MMWidget?
    
    var scaleFactor     : Float!
    
    var mousePos        : float2 = float2()
    
    var mouseTrackWidget: MMWidget? = nil

    // --- Drag And Drop
    var dragSource      : MMDragSource? = nil
    
    // --- Key States
    var shiftIsDown     : Bool = false
    var commandIsDown   : Bool = false
    
    var keysDown        : [Float] = []
    
    // For pinch gesture
    var zoom            : Float = 1

    func update()
    {
        let rect : NSRect = NSRect()
        setNeedsDisplay(rect)
    }
    
    func platformInit()
    {
        scaleFactor = Float(NSScreen.main!.backingScaleFactor)
    }
    
    override var acceptsFirstResponder: Bool { return true }

    override func updateTrackingAreas()
    {
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
        let options : NSTrackingArea.Options =
            [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options,
                                      owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }
    
    /// Mouse has been clicked
    override func mouseDown(with event: NSEvent) {
        let event = MMMouseEvent( Float(event.locationInWindow.x ), Float( frame.height ) - Float(event.locationInWindow.y ) )
        
        if hoverWidget != nil {
            
            if focusWidget != nil {
                focusWidget!.removeState( .Focus )
            }
            
            focusWidget = hoverWidget
            focusWidget!.addState( .Clicked )
            focusWidget!.addState( .Focus )
            focusWidget!._clicked(event)
            focusWidget!.mouseDown(event)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        let event = MMMouseEvent( Float(event.locationInWindow.x ), Float( frame.height ) - Float(event.locationInWindow.y ) )

        // --- Drag and Drop
        if hoverWidget != nil && dragSource != nil {
            if hoverWidget!.dropTargets.contains(dragSource!.id) {
                hoverWidget!.dragEnded(event: event, dragSource: dragSource!)
                focusWidget = hoverWidget
                update()
            }
        }
        
        if dragSource != nil {
            dragSource!.sourceWidget?.dragTerminated()
            dragSource = nil
            update()
        }
        // ---
        
        if let widget = focusWidget {
            widget.removeState( .Clicked )
            widget.mouseUp(event)
        }
    }
    
    /// Mouse has moved
    override func mouseMoved(with event: NSEvent) {
        let event = MMMouseEvent( Float(event.locationInWindow.x ), Float( frame.height ) - Float(event.locationInWindow.y ) )
        
        mousePos.x = event.x
        mousePos.y = event.y
        
//        if hoverWidget != nil {
//            hoverWidget!.removeState(.Hover)
//            hoverWidget!.mouseLeave(event)
//        }
        
        if mouseTrackWidget != nil {
            mouseTrackWidget!.mouseMoved(event)
        } else {
            let oldHoverWidget = hoverWidget
            hoverWidget = nil

            for widget in widgets {
                if widget.rect.contains( event.x, event.y ) {
                    hoverWidget = widget
                    if hoverWidget !== oldHoverWidget {
                        hoverWidget!.addState(.Hover)
                        hoverWidget!.mouseEnter(event)
                    }
                    hoverWidget!.mouseMoved(event)
                    break;
                }
            }
            
            if oldHoverWidget !== hoverWidget {
                if oldHoverWidget != nil {
                    oldHoverWidget!.removeState(.Hover)
                    oldHoverWidget!.mouseLeave(event)
                }
            }
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        mouseMoved(with: event)
    }
    
    // Mouse scroll wheel
    override func scrollWheel(with event: NSEvent) {
        let scrollEvent = MMMouseEvent( Float(event.locationInWindow.x ), Float( frame.height ) - Float(event.locationInWindow.y ) )
        scrollEvent.deltaX = Float(event.deltaX)
        scrollEvent.deltaY = Float(event.deltaY)
        scrollEvent.deltaZ = Float(event.deltaZ)
                
        if let widget = hoverWidget {
            widget.mouseScrolled(scrollEvent)
        }
    }
    
    /// Zoom
    override func magnify(with event: NSEvent) {
        if let hover = hoverWidget {
            if(event.phase == .changed) {
                zoom += Float(event.magnification)
            } else
            if(event.phase == .began) {
                zoom = 1
            }
            hover.pinchGesture(zoom)
        }
    }
    
    // Currently only used for checking modifier keys
    
    override func keyDown(with event: NSEvent)
    {
        keysDown.append(Float(event.keyCode))
        if focusWidget != nil {
            let keyEvent = MMKeyEvent(event.characters, event.keyCode)
            focusWidget!.keyDown(keyEvent)
        }
        //super.keyDown(with: event)
    }
    
    override func keyUp(with event: NSEvent)
    {
        keysDown.removeAll{$0 == Float(event.keyCode)}
        if focusWidget != nil {
            let keyEvent = MMKeyEvent(event.characters, event.keyCode)
            focusWidget!.keyUp(keyEvent)
        }
        //super.keyUp(with: event)
    }
    
    override func flagsChanged(with event: NSEvent) {
        //https://stackoverflow.com/questions/9268045/how-can-i-detect-that-the-shift-key-has-been-pressed
        if event.modifierFlags.contains(.shift) {
            shiftIsDown = true
        } else {
            shiftIsDown = false
        }
        
        if event.modifierFlags.contains(.command) {
            commandIsDown = true
        } else {
            commandIsDown = false
        }
    }
}

func getStringDialog(view: MMView, title: String, message: String, defaultValue: String, cb: @escaping (String)->())
{
    let msg = NSAlert()
    msg.addButton(withTitle: "OK")      // 1st button
    msg.addButton(withTitle: "Cancel")  // 2nd button
    msg.messageText = title
    msg.informativeText = message
    
    let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    txt.stringValue = defaultValue
    
    msg.window.initialFirstResponder = txt
    msg.accessoryView = txt
//    let response: NSApplication.ModalResponse = msg.runModal()
    
//    if (response == NSApplication.ModalResponse.alertFirstButtonReturn) {
//        cb( txt.stringValue )
//    }
    
    msg.beginSheetModal(for: view.window!, completionHandler: { (modalResponse) -> Void in
        if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
            cb(txt.stringValue)
        }
    })
}

func getNumberDialog(view: MMView, title: String, message: String, defaultValue: Float, cb: @escaping (Float)->())
{
    let msg = NSAlert()
    msg.addButton(withTitle: "OK")      // 1st button
    msg.addButton(withTitle: "Cancel")  // 2nd button
    msg.messageText = title
    msg.informativeText = message
    
    let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
    txt.doubleValue = Double(defaultValue)
    
    msg.window.initialFirstResponder = txt
    msg.accessoryView = txt
    //    let response: NSApplication.ModalResponse = msg.runModal()
    
    //    if (response == NSApplication.ModalResponse.alertFirstButtonReturn) {
    //        cb( txt.stringValue )
    //    }
    
    msg.beginSheetModal(for: view.window!, completionHandler: { (modalResponse) -> Void in
        if modalResponse == NSApplication.ModalResponse.alertFirstButtonReturn {
            cb(Float(txt.doubleValue))
        }
    })
}

/// Show help window
func showHelp(_ urlString: String? = nil)
{
    if urlString == nil { return }
    
    let appDelegate = (NSApplication.shared.delegate as! AppDelegate)
    
    appDelegate.helpWindowController.showWindow(appDelegate)
    appDelegate.helpWindowController.window!.makeKeyAndOrderFront(appDelegate)
    
    let request = URLRequest(url:URL(string: urlString!)!)
    appDelegate.webView.load(request)
}
