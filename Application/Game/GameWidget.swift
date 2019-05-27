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
    
    override func mouseDown(_ event: MMMouseEvent)
    {
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    override func pinchGesture(_ scale: Float)
    {
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    /// Drag and Drop Target
    override func dragEnded(event:MMMouseEvent, dragSource:MMDragSource)
    {
    }
}
