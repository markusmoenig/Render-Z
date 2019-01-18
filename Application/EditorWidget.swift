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
//    var dragShape       : Shape?
    
    init(_ view: MMView, editorRegion: EditorRegion, app: App)
    {
        self.app = app
        region = editorRegion
        
        super.init(view)
        
        dropTargets.append( "ShapeSelectorItem" )
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
        /*
        if (mouseIsDown && editorState == .Lazy)
        {
            dragShape = app.leftRegion!.shapeSelector.createSelected()
            
            app.layerManager.currentLayer.addShape(dragShape!)
            
            dragShape!.properties["posX"] = (dragStartPos.x/*-rect.width/2*/) * 700 / rect.width
            dragShape!.properties["posY"] = (dragStartPos.y/*-rect.height/2*/) * 700 / rect.width
            
            editorState = .DragCreation
        }

        if editorState == .DragCreation {

            mmView.preferredFramesPerSecond = mmView.maxFramerate

            var width, height : Float
            let x1 = dragStartPos.x
            let y1 = dragStartPos.y
            
            let x2 = event.x - rect.x
            let y2 = event.y - rect.y
            
            if x1 <= x2 {
                width = x2 - x1
            } else {
                width = (x1 - x2)
            }
            
            if y1 <= y2 {
                height = y2 - y1
            } else {
                height = y1 - y2
            }
                        
            if dragShape!.properties["radius"] != nil {
                dragShape!.properties["radius"] = max(width, height)
            } else
            if dragShape!.properties["width"] != nil && dragShape!.properties["height"] != nil {
                dragShape!.properties["width"] = width
                dragShape!.properties["height"] = height
            }
            
            app.layerManager.currentLayer.build()
            region.result = nil
        }
        */
    }
    
    /// Drag and Drop Target
    override func dragEnded(event:MMMouseEvent, dragSource:MMDragSource)
    {
        if dragSource.id == "ShapeSelectorItem" {
            let drag = dragSource as! ShapeSelectorDrag
            
            app.layerManager.currentLayer.currentObject.addShape(drag.shape!)
            app.setChanged()
            
            if let shape = drag.shape {
                
                var xOff : Float = 0
                var yOff : Float = 0
                
                if shape.name == "Disk" {
                    xOff = shape.properties["radius"]! - drag.pWidgetOffset!.x + 2.5
                    yOff = shape.properties["radius"]! - drag.pWidgetOffset!.y + 2.5
                    
                    shape.properties["radius"] = shape.properties["radius"]! * 700 / rect.width
                } else
                if shape.name == "Box" {
                    xOff = shape.properties["width"]! - drag.pWidgetOffset!.x + 2.5
                    yOff = shape.properties["height"]! - drag.pWidgetOffset!.y + 2.5
                    
                    shape.properties["width"] = shape.properties["width"]! * 700 / rect.width
                    shape.properties["height"] = shape.properties["height"]! * 700 / rect.width
                }
                
                shape.properties["posX"] = (event.x - rect.x + xOff) * 700 / rect.width
                shape.properties["posY"] = (event.y - rect.y + yOff) * 700 / rect.width
            }
            
            app.layerManager.currentLayer.build()
            region.result = nil
        }
    }
}
