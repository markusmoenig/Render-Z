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

    var scrolledMode    : Int? = nil
    
    var dispatched      : Bool = false
    
    init(_ view: MMView, editorRegion: EditorRegion, app: App)
    {
        self.app = app
        region = editorRegion
        
        super.init(view)
        
        dropTargets.append( "ShapeSelectorItem" )
        dropTargets.append( "MaterialSelectorItem" )
        dropTargets.append( "NodeItem" )
        dropTargets.append( "AvailableObjectItem" )
    }

    override func keyDown(_ event: MMKeyEvent)
    {
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.keyDown(event)
        } else {
            app.nodeGraph.maximizedNode!.maxDelegate!.keyDown(event)
        }
    }
    
    override func keyUp(_ event: MMKeyEvent)
    {
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.keyUp(event)
        } else {
            app.nodeGraph.maximizedNode!.maxDelegate!.keyUp(event)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        scrolledMode = nil
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
            if app.nodeGraph.hoverNode != nil && app.nodeGraph.nodeHoverMode == .Preview {
                
                #if os(iOS)
                // Prevent scrolling over several areas
                if scrolledMode == nil {
                    scrolledMode = 0
                } else {
                    if scrolledMode != 0 {
                        return
                    }
                }
                #endif
                
                // Node preview translation
                let node = app.nodeGraph.hoverNode!
                var prevOffX = node.properties["prevOffX"] != nil ? node.properties["prevOffX"]! : 0
                var prevOffY = node.properties["prevOffY"] != nil ? node.properties["prevOffY"]! : 0
                var prevScale = node.properties["prevScale"] != nil ? node.properties["prevScale"]! : 1
                
                #if os(OSX)
                if mmView.commandIsDown && event.deltaY! != 0 {
                    prevScale += event.deltaY! * 0.003
                    prevScale = max(0.2, prevScale)
                } else {
                    prevOffX += event.deltaX!
                    prevOffY += event.deltaY!
                }
                #else
                prevOffX -= event.deltaX!
                prevOffY -= event.deltaY!
                #endif
                
                node.properties["prevOffX"] = prevOffX
                node.properties["prevOffY"] = prevOffY
                node.properties["prevScale"] = prevScale
                node.updatePreview(nodeGraph: app.nodeGraph)
            } else
            if app.nodeGraph.nodeHoverMode == .None && app.nodeGraph.currentMaster != nil
            {
                // NodeGraph translation
                
                #if os(iOS)
                // Prevent scrolling over several areas
                if scrolledMode == nil {
                    scrolledMode = 1
                } else {
                    if scrolledMode != 1 {
                        return
                    }
                }
                #endif

                if let camera = app.nodeGraph.currentMaster!.camera {
                    #if os(OSX)
                    if mmView.commandIsDown && event.deltaY! != 0 {
                        camera.zoom += event.deltaY! * 0.003
                        camera.zoom = max(0.2, camera.zoom)
                        camera.zoom = min(1.5, camera.zoom)
                    } else {
                        camera.xPos -= event.deltaX!
                        camera.yPos -= event.deltaY!
                    }
                    #else
                    camera.xPos += event.deltaX!
                    camera.yPos += event.deltaY!
                    #endif
                }
            }
            
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
            // Object Editor, shape drag to editor
            let drag = dragSource as! ShapeSelectorDrag
            
//            mmView.window!.undoManager!.registerUndo(withTarget: self) { target in
//                print( "undo" )
//            }
        
            let currentObject = app.nodeGraph.maximizedNode as? Object
            let delegate = currentObject!.maxDelegate as! ObjectMaxDelegate
            let selObject = delegate.selObject!
            
            let addedShape = selObject.addShape(drag.shape!)
            selObject.selectedShapes = [addedShape.uuid]
            app.setChanged()
            
            if let shape = drag.shape {
                
                var xOff : Float = 0
                var yOff : Float = 0
                
                let deltaX = drag.pWidgetOffset!.x
                let deltaY = drag.pWidgetOffset!.y

                if shape.name == "Disk" {
                    xOff = shape.properties["radius"]! - deltaX + 2.5
                    yOff = shape.properties["radius"]! - deltaY + 2.5
                    
                    shape.properties["radius"] = shape.properties["radius"]!// * 700 / rect.width
                } else
                if shape.name == "Box" {
                    xOff = shape.properties["width"]! - deltaX + 2.5
                    yOff = shape.properties["height"]! - deltaY + 2.5
                    
                    shape.properties["width"] = shape.properties["width"]!// * 700 / rect.width
                    shape.properties["height"] = shape.properties["height"]!// * 700 / rect.width
                }
                
                // --- Transform coordinates
                xOff = (event.x - rect.x + xOff)// * 700 / rect.width
                yOff = (event.y - rect.y + yOff)// * 700 / rect.width
                
                // --- Center
                xOff -= rect.width / 2 - currentObject!.maxDelegate!.getCamera()!.xPos
                yOff += currentObject!.maxDelegate!.getCamera()!.yPos
                yOff -= rect.width / 2 * rect.height / rect.width
                
                shape.properties["posX"] = xOff
                shape.properties["posY"] = -yOff
                
                if shape.pointCount == 1 {
                    shape.properties["point_0_y"] = -shape.properties["point_0_y"]!
                } else
                if shape.pointCount == 2 {
                    shape.properties["point_0_y"] = -shape.properties["point_0_y"]!
                    shape.properties["point_1_y"] = -shape.properties["point_1_y"]!
                } else
                if shape.pointCount == 3 {
                    shape.properties["point_0_y"] = -shape.properties["point_0_y"]!
                    shape.properties["point_1_y"] = -shape.properties["point_1_y"]!
                    shape.properties["point_2_y"] = -shape.properties["point_2_y"]!
                }
            }
            
            currentObject!.maxDelegate?.update(true)
        } else
        if dragSource.id == "MaterialSelectorItem" {
            // Object Editor, shape drag to editor
            let drag = dragSource as! MaterialSelectorDrag
            
            let currentObject = app.nodeGraph.maximizedNode as? Object
            let delegate = currentObject!.maxDelegate as! ObjectMaxDelegate
            let selObject = delegate.selObject!
            
            if delegate.materialType == .Body {
                selObject.bodyMaterials.append(drag.material!)
                selObject.selectedBodyMaterials = [drag.material!.uuid]
            } else {
                selObject.borderMaterials.append(drag.material!)
                selObject.selectedBorderMaterials = [drag.material!.uuid]
            }
            app.setChanged()
            
            if let material = drag.material {
                
                var xOff : Float = 0
                var yOff : Float = 0
                
                //let deltaX = drag.pWidgetOffset!.x
                //let deltaY = drag.pWidgetOffset!.y
                
                // --- Transform coordinates
                xOff = (event.x - rect.x + xOff)// * 700 / rect.width
                yOff = (event.y - rect.y + yOff)// * 700 / rect.width
                
                // --- Center
                xOff -= rect.width / 2 - currentObject!.maxDelegate!.getCamera()!.xPos
                yOff += currentObject!.maxDelegate!.getCamera()!.yPos
                yOff -= rect.width / 2 * rect.height / rect.width
                
                material.properties["posX"] = xOff
                material.properties["posY"] = -yOff
            }
            currentObject!.maxDelegate?.update(true)
        } else

            
        if dragSource.id == "NodeItem"
        {
            // NodeGraph, node drag to editor

            let drag = dragSource as! NodeListDrag
            let node = drag.node!
            
            if app.nodeGraph.currentMaster != nil {
                if let camera = app.nodeGraph.currentMaster!.camera {

                    node.xPos = event.x - rect.x - camera.xPos - drag.pWidgetOffset!.x
                    node.yPos = event.y - rect.y - camera.yPos - drag.pWidgetOffset!.y

                    if node.type == "Object" {
                        let object = node as! Object
                        
                        node.name = "New " + node.type

                        object.sequences.append( MMTlSequence() )
                        object.currentSequence = object.sequences[0]
                    }
                    node.setupTerminals()

                    if app.nodeGraph.currentMaster != nil {
                        app.nodeGraph.nodes.append(node)
                        app.nodeGraph.currentMaster?.subset!.append(node.uuid)
                        app.nodeGraph.setCurrentNode(node)
        //                app.nodeGraph.updateNode(node)
                        app.nodeGraph.updateMasterNodes(app.nodeGraph.currentMaster!)
                    }
                }
            }
        } else
        if dragSource.id == "AvailableObjectItem"
        {
            // Layer editor, available object drag to editor
            
            let drag = dragSource as! AvailableObjectListItemDrag
            let node = drag.node!
            
            if node.type == "Object" {
                let currentLayer = app.nodeGraph.maximizedNode as? Layer
                if currentLayer != nil {
                    let instance = ObjectInstance(name: node.name + " Instance", objectUUID: node.uuid, properties: [:])
                    currentLayer!.objectInstances.append(instance)
                    
                    let layerDelegate = app.nodeGraph.maximizedNode!.maxDelegate as! LayerMaxDelegate
                    layerDelegate.objectList!.rebuildList()
                    currentLayer!.selectedObjects = [instance.uuid]
                    currentLayer!.maxDelegate?.update(true)
                }
            }
        }
    }
}
