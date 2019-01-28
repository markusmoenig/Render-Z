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
    
    
    func platformInit()
    {
        scaleFactor = Float(NSScreen.main!.backingScaleFactor)
    }
    
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
            }
        }
        
        if dragSource != nil {
            dragSource!.sourceWidget?.dragTerminated()
            dragSource = nil
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
                
        if hoverWidget != nil {
            hoverWidget!.removeState(.Hover)
        }
        
        hoverWidget = nil
        
        if mouseTrackWidget != nil {
            mouseTrackWidget!.mouseMoved(event)
        } else {
            for widget in widgets {
                if widget.rect.contains( event.x, event.y ) {
                    hoverWidget = widget
                    hoverWidget!.addState(.Hover)
                    hoverWidget!.mouseMoved(event)
                    break;
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
