//
//  EditorWidget.swift
//  Shape-Z
//
//  Created by Markus Moenig on 15/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class EditorWidget      : MMWidget
{
    enum EditorState {
        case Lazy, DragCreation
    }
    
    var editorState     : EditorState = .Lazy
    
    var app             : App
    var region          : EditorRegion
    
    var mouseIsDown     : Bool = false
    var dragStartPos    : float2 = float2(0)
    var dragShape       : MM2DShape?
    
    init(_ view: MMView, editorRegion: EditorRegion, app: App)
    {
        self.app = app
        region = editorRegion
        
        super.init(view)
    }

    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        dragStartPos.x = event.x - rect.x
        dragStartPos.y = event.y - rect.y
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
        editorState = .Lazy
        mmView.preferredFramesPerSecond = mmView.defaultFramerate
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if (mouseIsDown && editorState == .Lazy)
        {
            dragShape = app.leftRegion!.shapeSelector.selectedShape.instance()

            app.layerManager.currentLayer.addShape(dragShape!)
            
            editorState = .DragCreation
        }

        if editorState == .DragCreation {

            mmView.preferredFramesPerSecond = mmView.maxFramerate

            var x, y, width, height : Float
            let x1 = dragStartPos.x
            let y1 = dragStartPos.y
            
            let x2 = event.x - rect.x
            let y2 = event.y - rect.y
            
            if x1 <= x2 {
                x = x1
                width = x2 - x1
            } else {
                x = x2
                width = (x1 - x2)
            }
            
            if y1 <= y2 {
                y = y1
                height = y2 - y1
            } else {
                y = y2
                height = (y1 - y2)
            }
            
            var posX, posY : Float
            
            if dragShape!.properties["radius"] != nil {
                let radius : Float = (width + height) / 4
                
                posX = (x+radius-rect.width/2) * 700 / rect.width
                posY = (y+radius-rect.height/2) * 700 / rect.width
                
                dragShape!.properties["posX"] = posX
                dragShape!.properties["posY"] = posY
                
                dragShape!.properties["radius"] = radius
            } else
            if dragShape!.properties["width"] != nil && dragShape!.properties["height"] != nil {
                posX = (x+width/2-rect.width/2) * 700 / rect.width
                posY = (y+height/2-rect.height/2) * 700 / rect.width
                
                dragShape!.properties["posX"] = posX
                dragShape!.properties["posY"] = posY
                
                dragShape!.properties["width"] = width/2
                dragShape!.properties["height"] = height/2
            }
            
            app.layerManager.currentLayer.build()
            region.result = nil
        }
    }
}
