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
        
    var dispatched      : Bool = false
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
        
        app.layerManager.getShapeAt(x: event.x - rect.x, y: event.y - rect.y)
        app.gizmo.mouseDown(event)
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
        editorState = .Lazy
        
        app.gizmo.mouseUp(event)
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS) || os(watchOS) || os(tvOS)
        // If there is a selected shape, don't scroll
        if app.layerManager.getCurrentObject()?.getCurrentShape() != nil {
            return
        }
        app.layerManager.camera[0] -= event.deltaX! * 2
        app.layerManager.camera[1] -= event.deltaY! * 2
        #elseif os(OSX)
        app.layerManager.camera[0] += event.deltaX! * 2
        app.layerManager.camera[1] += event.deltaY! * 2
        #endif

        region.compute()
        
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
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        app.gizmo.mouseMoved(event)
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
            
            mmView.window!.undoManager!.registerUndo(withTarget: self) { target in
                print( "undo" )
            }
        
            let addedShape = app.layerManager.getCurrentLayer().getCurrentObject()?.addShape(drag.shape!)
            app.layerManager.getCurrentLayer().getCurrentObject()?.selectedShapes = [addedShape!.uuid]
            app.setChanged()
            
//            app.undoManager.registerRedo(withTarget: self) { target in
//                print( "redo" )
//            }
            
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
            app.gizmo.setObject(app.layerManager.getCurrentObject())
            region.result = nil
        }
    }
}
