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
    var app             : App
    var region          : EditorRegion
    
    var dispatched      : Bool = false
    
    init(_ view: MMView, editorRegion: EditorRegion, app: App)
    {
        self.app = app
        region = editorRegion
        
        super.init(view)
        
        dropTargets.append( "ShapeSelectorItem" )
    }

    override func mouseDown(_ event: MMMouseEvent)
    {
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.mouseDown(event)
        } else {
            app.nodeGraph.maximizedNode!.maxDelegate!.mouseDown(event)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.mouseUp(event)
        } else {
            app.nodeGraph.maximizedNode!.maxDelegate!.mouseUp(event)
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.xOffset -= event.deltaX!
            app.nodeGraph.yOffset -= event.deltaY!
            
            if !dispatched {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.mmView.unlockFramerate()
                    self.dispatched = false
                }
                dispatched = true
            }
            
            if mmView.maxFramerateLocks == 0 {
                mmView.lockFramerate()
            }
        } else {
            app.nodeGraph.maximizedNode!.maxDelegate!.mouseScrolled(event)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.mouseMoved(event)
        } else {
            app.nodeGraph.maximizedNode!.maxDelegate!.mouseMoved(event)
        }
    }
    
    /// Drag and Drop Target
    override func dragEnded(event:MMMouseEvent, dragSource:MMDragSource)
    {
        if dragSource.id == "ShapeSelectorItem" {
            let drag = dragSource as! ShapeSelectorDrag
            
//            mmView.window!.undoManager!.registerUndo(withTarget: self) { target in
//                print( "undo" )
//            }
        
            let currentObject = app.nodeGraph.maximizedNode as? Object
            
            let addedShape = currentObject!.addShape(drag.shape!)
            currentObject!.selectedShapes = [addedShape.uuid]
            app.setChanged()
            
            if let shape = drag.shape {
                
                var xOff : Float = 0
                var yOff : Float = 0
                
                let deltaX = drag.pWidgetOffset!.x
                let deltaY = drag.pWidgetOffset!.y

                if shape.name == "Disk" {
                    xOff = shape.properties["radius"]! - deltaX + 2.5
                    yOff = shape.properties["radius"]! - deltaY + 2.5
                    
                    shape.properties["radius"] = shape.properties["radius"]! * 700 / rect.width
                } else
                if shape.name == "Box" {
                    xOff = shape.properties["width"]! - deltaX + 2.5
                    yOff = shape.properties["height"]! - deltaY + 2.5
                    
                    shape.properties["width"] = shape.properties["width"]! * 700 / rect.width
                    shape.properties["height"] = shape.properties["height"]! * 700 / rect.width
                }
                
                // --- Transform coordinates
                xOff = (event.x - rect.x + xOff) * 700 / rect.width
                yOff = (event.y - rect.y + yOff) * 700 / rect.width
                
                // --- Center
                xOff -= 350 - app.layerManager.camera[0]
                yOff += app.layerManager.camera[1]
                yOff -= 350 * rect.height / rect.width
                
                shape.properties["posX"] = xOff
                shape.properties["posY"] = yOff
            }
            
            app.layerManager.getCurrentLayer().build()
            app.gizmo.setObject(currentObject)
            region.result = nil
        }
    }
}
