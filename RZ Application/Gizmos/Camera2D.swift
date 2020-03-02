//
//  Gizmo3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 19/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

class GizmoCamera2D         : GizmoBase
{
    var dragStartOffset     : SIMD2<Float>?
    var gizmoCenter         : SIMD2<Float> = SIMD2<Float>()
    var initialValues       : [String:Float] = [:]
    var startRotate         : Float = 0

    var undoComponent       : CodeUndoComponent? = nil
    
    var dispatched          : Bool = false
    
    var gizmoDragLocked     : Int = 0

    var mouseIsDown         : Bool = false
    
    var camera3D            : CamHelper3D = CamHelper3D()

    var moveButton          : MMButtonWidget
    //var rotateButton        : MMButtonWidget
    var zoomButton          : MMButtonWidget
    
    var hoverButton         : MMButtonWidget? = nil
    var activeButton        : MMButtonWidget? = nil
    
    var xFrag               : CodeFragment? = nil
    var yFrag               : CodeFragment? = nil
    var scale               : CodeFragment? = nil
    
    var camIsValid          : Bool = false

    override init(_ view: MMView)
    {
        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.height = view.skin.Button.height
        smallButtonSkin.round = view.skin.Button.round
        smallButtonSkin.fontScale = view.skin.Button.fontScale

        moveButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Move" )
        //rotateButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Rotate" )
        zoomButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Zoom" )
        
        moveButton.rect.width = moveButton.rect.width
        //rotateButton.rect.width = rotateButton.rect.width
        zoomButton.rect.width = moveButton.rect.width

        super.init(view)
    }
    
    override func setComponent(_ comp: CodeComponent)
    {
        component = comp

        for uuid in comp.properties {
            let rc = comp.getPropertyOfUUID(uuid)
            if let frag = rc.0 {
                if frag.name == "cameraX" {
                    xFrag = rc.1
                } else
                if frag.name == "cameraY" {
                    yFrag = rc.1
                } else
                if frag.name == "scale" {
                    scale = rc.1
                }
            }
        }
        
        if xFrag != nil && yFrag != nil && scale != nil {
            camIsValid = true
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if component.componentType == .Dummy { return }
        mouseIsDown = true
        
        #if os(iOS)
            mouseMoved(event)
        #endif

        if camIsValid {
            activeButton = hoverButton
            dragState = hoverState
            dragStartOffset = SIMD2<Float>(event.x, event.y)
            gizmoDragLocked = 0
            
            if camIsValid {
                initialValues = [:]
                initialValues["cameraX"] = xFrag!.values["value"]!
                initialValues["cameraY"] = yFrag!.values["value"]!
                initialValues["scale"] = scale!.values["value"]!
            }
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if component.componentType == .Dummy { return }

        if dragState == .Inactive {
            let oldHoverButton = hoverButton
            if let hover = hoverButton {
                hover.removeState(.Hover)
            }
            hoverButton = nil
            hoverState = .Inactive
            if moveButton.rect.contains(event.x, event.y) {
                hoverButton = moveButton
                hoverState = .CameraMove
                moveButton.addState(.Hover)
            } else
            /*
            if rotateButton.rect.contains(event.x, event.y) {
                hoverButton = rotateButton
                hoverState = .CameraRotate
                rotateButton.addState(.Hover)
            } else*/
            if zoomButton.rect.contains(event.x, event.y) {
                hoverButton = zoomButton
                hoverState = .CameraZoom
                zoomButton.addState(.Hover)
            }
            if oldHoverButton !== hoverButton {
                mmView.update()
            }
        }
        if dragState != .Inactive && camIsValid {
    
            let p = SIMD2<Float>(event.x, event.y)
            var diff : Float

            // Figure out the drag direction and calculate the diff
            if gizmoDragLocked == 0 {
                var dx = p.x - dragStartOffset!.x; dx *= dx
                var dy = p.y - dragStartOffset!.y; dy *= dy
                
                if dx > dy {
                    diff = (p.x - dragStartOffset!.x)
                    if dx > 10 {
                        gizmoDragLocked = 1
                    }
                } else {
                    diff = (p.y - dragStartOffset!.y)
                    if dy > 10 {
                        gizmoDragLocked = 2
                    }
                }
            } else
            if gizmoDragLocked == 1 {
                diff = (p.x - dragStartOffset!.x)
            } else {
                diff = (p.y - dragStartOffset!.y)
            }

            if dragState == .CameraMove {
                
                if let frag = xFrag {
                    frag.values["value"]! = initialValues["cameraX"]! + (p.x - dragStartOffset!.x)
                }
                if let frag = yFrag {
                    frag.values["value"]! = initialValues["cameraY"]! + (p.y - dragStartOffset!.y)
                }
                
                let properties : [String:Float] = [
                    "cameraX" : initialValues["cameraX"]! + (p.x - dragStartOffset!.x),
                    "cameraY" : initialValues["cameraY"]! + (p.y - dragStartOffset!.y),
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .CameraZoom {
                
                var value = initialValues["scale"]! + diff * 0.03
                value = max(0.001, value)
                value = min(20, value)
                
                if let frag = scale {
                    frag.values["value"]! = value
                }
                
                let properties : [String:Float] = [
                    "scale" : value,
                ]
                processGizmoProperties(properties)
            }
            
            if undoComponent == nil {
                undoComponent = globalApp!.currentEditor.undoComponentStart("Camera Change")
            }
            
            globalApp!.artistEditor.designProperties.setSelected(component)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if component.componentType == .Dummy { return }

        if let hover = hoverButton {
            hover.removeState(.Hover)
        }
        
        dragState = .Inactive
        activeButton = nil
        hoverButton = nil
        #if os(iOS)
        hoverState = .Inactive
        #endif
        if undoComponent != nil {
            globalApp!.currentEditor.undoComponentEnd(undoComponent!)
            undoComponent = nil
        }
        mmView.update()
        mouseIsDown = false
    }
    
    /// Updates the UI properties
    func updateUIProperties()
    {
        let designProperties = globalApp!.artistEditor.designProperties
        
        if let tNode = designProperties.c2Node {
            for item in tNode.uiItems {
                if item.brand == .Number {
                    if let number = item as? NodeUINumber {
                        number.value = component.values[item.variable]!
                    }
                }
            }
        }
    }
    
    ///
    func processGizmoProperties(_ properties: [String:Float])
    {
        let timeline = globalApp!.artistEditor.timeline
        
        if timeline.isRecording {
            timeline.addKeyProperties(sequence: component.sequence, uuid: component.uuid, properties: properties)
        }
        globalApp!.currentEditor.updateOnNextDraw(compile: false)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if component.componentType == .Dummy { return }

        moveButton.rect.x = rect.x + (rect.width - moveButton.rect.width) / 2
        moveButton.rect.y = rect.y + (rect.height - moveButton.rect.height) / 2 - 40
        moveButton.draw()
        
        /*
        rotateButton.rect.x = rect.x + (rect.width - rotateButton.rect.width) / 2 + 40
        rotateButton.rect.y = rect.y + (rect.height - rotateButton.rect.height) / 2
        rotateButton.draw()*/
        
        zoomButton.rect.x = rect.x + (rect.width - moveButton.rect.width) / 2
        zoomButton.rect.y = rect.y + (rect.height - moveButton.rect.height) / 2 + 40
        zoomButton.draw()
    }
}
