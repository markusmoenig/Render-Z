//
//  GameWidget.swift
//  Shape-Z
//
//  Created by Markus Moenig on 15/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class GameWidget      : MMWidget
{
    var app             : GameApp
    var region          : GameRegion
    
    init(_ view: MMView, gameRegion: GameRegion, app: GameApp)
    {
        self.app = app
        region = gameRegion
        
        super.init(view)
    }

    override func keyDown(_ event: MMKeyEvent)
    {
    }
    
    override func keyUp(_ event: MMKeyEvent)
    {
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if let screen = region.nodeGraph.mmScreen {
            screen.mousePos.x = event.x
            screen.mousePos.y = event.y
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        if app.embeddedCB != nil {
            if app.closeButton!.rect.contains(event.x, event.y) {
                app.closeButton!.clicked!(event)
            }
        }
        #endif
        if let screen = region.nodeGraph.mmScreen {
            screen.mouseDownPos.x = event.x
            screen.mouseDownPos.y = event.y
            screen.mouseDown = true
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if let screen = region.nodeGraph.mmScreen {
            screen.mouseDown = false
        }
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
    }
    
    /// Drag and Drop Target
    override func dragEnded(event:MMMouseEvent, dragSource:MMDragSource)
    {
    }
}
