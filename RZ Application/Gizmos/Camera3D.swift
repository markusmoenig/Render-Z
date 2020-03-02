//
//  Gizmo3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 19/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

class GizmoCamera3D         : GizmoBase
{
    var dragStartOffset     : SIMD2<Float>?
    var gizmoCenter         : SIMD2<Float> = SIMD2<Float>()
    var initialValues       : [String:Float] = [:]
    var startRotate         : Float = 0

    var scaleXFragmentName  : String? = nil
    var scaleYFragmentName  : String? = nil
    var scaleZFragmentName  : String? = nil
    var scaleXFragment      : CodeFragment? = nil
    var scaleYFragment      : CodeFragment? = nil
    var scaleZFragment      : CodeFragment? = nil

    var undoComponent       : CodeUndoComponent? = nil
    
    var dispatched          : Bool = false
    
    var gizmoDistance       : Float = 0
    var gizmoDragLocked     : Int = 0

    var mouseIsDown         : Bool = false
    
    var camera3D            : CamHelper3D = CamHelper3D()

    var moveButton          : MMButtonWidget
    var panButton           : MMButtonWidget
    var rotateButton          : MMButtonWidget
    var zoomButton           : MMButtonWidget
    
    var hoverButton         : MMButtonWidget? = nil
    var activeButton        : MMButtonWidget? = nil
    
    var originFrag          : CodeFragment? = nil
    var lookAtFrag          : CodeFragment? = nil
    var fovFrag             : CodeFragment? = nil
    
    var camIsValid          : Bool = false

    override init(_ view: MMView)
    {
        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.height = view.skin.Button.height
        smallButtonSkin.round = view.skin.Button.round
        smallButtonSkin.fontScale = view.skin.Button.fontScale

        moveButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Move" )
        panButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Pan" )
        rotateButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Rotate" )
        zoomButton = MMButtonWidget(view, skinToUse: smallButtonSkin, text: "Zoom" )
        
        moveButton.rect.width = rotateButton.rect.width
        panButton.rect.width = rotateButton.rect.width
        rotateButton.rect.width = rotateButton.rect.width
        zoomButton.rect.width = rotateButton.rect.width

        super.init(view)
    }
    
    override func setComponent(_ comp: CodeComponent)
    {
        component = comp
        
        originFrag = nil
        lookAtFrag = nil
        fovFrag = nil

        for uuid in comp.properties {
            let rc = comp.getPropertyOfUUID(uuid)
            if let frag = rc.0 {
                if frag.name == "origin" {
                    originFrag = rc.1
                } else
                if frag.name == "lookAt" {
                    lookAtFrag = rc.1
                } else
                if frag.name == "fov" {
                    fovFrag = rc.1
                }
            }
        }
        
        if originFrag != nil && lookAtFrag != nil && fovFrag != nil {
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

            camera3D.initFromCamera(aspect: rect.width/rect.height, originFrag: originFrag, lookAtFrag: lookAtFrag, fovFrag: fovFrag)
            
            initialValues = [:]
            initialValues["origin"] = originFrag!.values["value"]!
            initialValues["lookAt"] = lookAtFrag!.values["value"]!
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
            if panButton.rect.contains(event.x, event.y) {
                hoverButton = panButton
                hoverState = .CameraPan
                panButton.addState(.Hover)
            } else
            if rotateButton.rect.contains(event.x, event.y) {
                hoverButton = rotateButton
                hoverState = .CameraRotate
                rotateButton.addState(.Hover)
            } else
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
                
                let diffX : Float = (p.x - dragStartOffset!.x) * 0.0006
                let diffY : Float = (p.y - dragStartOffset!.y) * 0.0006
                
                camera3D.move(dx: diffX, dy: diffY)
                dragStartOffset!.x = p.x
                dragStartOffset!.y = p.y

                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    "origin" : camera3D.originFrag!.values["value"]!,
                    "lookAt" : camera3D.lookAtFrag!.values["value"]!
                ]
                //print(camera3D.originFrag!.values["value"]!, camera3D.lookAtFrag!.values["value"]!)
                //processGizmoProperties(properties)
                globalApp!.currentEditor.updateOnNextDraw(compile: false)

            } else
            if dragState == .CameraPan {
                
                let diffX : Float = (p.x - dragStartOffset!.x) * 0.003
                let diffY : Float = (p.y - dragStartOffset!.y) * 0.003
                
                camera3D.pan(dx: diffX, dy: diffY)
                dragStartOffset!.x = p.x
                dragStartOffset!.y = p.y

                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    "origin" : camera3D.originFrag!.values["value"]!,
                    "lookAt" : camera3D.lookAtFrag!.values["value"]!
                ]
                //print(camera3D.originFrag!.values["value"]!, camera3D.lookAtFrag!.values["value"]!)
                //processGizmoProperties(properties)
                globalApp!.currentEditor.updateOnNextDraw(compile: false)

            }
            
            if dragState == .CameraRotate {
                
                let diffX : Float = (p.x - dragStartOffset!.x) * 0.003
                let diffY : Float = (p.y - dragStartOffset!.y) * 0.003
                
                camera3D.rotate(dx: diffX, dy: diffY)
                dragStartOffset!.x = p.x
                dragStartOffset!.y = p.y

                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    "origin" : camera3D.originFrag!.values["value"]!,
                    "lookAt" : camera3D.lookAtFrag!.values["value"]!
                ]
                //print(camera3D.originFrag!.values["value"]!, camera3D.lookAtFrag!.values["value"]!)
                //processGizmoProperties(properties)
                globalApp!.currentEditor.updateOnNextDraw(compile: false)

            }
            
            if dragState == .CameraZoom {
                
                camera3D.zoom(dx: diff * 0.003, dy: diff * 0.003)
                dragStartOffset!.x = p.x
                dragStartOffset!.y = p.y

                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    "origin" : camera3D.originFrag!.values["value"]!,
                    "lookAt" : camera3D.lookAtFrag!.values["value"]!
                ]
                //print(camera3D.originFrag!.values["value"]!, camera3D.lookAtFrag!.values["value"]!)
                //processGizmoProperties(properties)
                globalApp!.currentEditor.updateOnNextDraw(compile: false)

            } else
                
            if dragState == .yAxisMove {
                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoYAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    //"_posY" : initialValues["_posY"]! + (hit.y - dragStartOffset!.x),
                    "_posY" : initialValues["_posY"]! + diff
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .zAxisMove {
                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoZAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    //"_posZ" : initialValues["_posZ"]! + (hit.z - dragStartOffset!.x),
                    "_posZ" : initialValues["_posZ"]! + diff,
                ]
                processGizmoProperties(properties)
            }
            
            else
            if dragState == .Rotate {
                /*
                let angle = 0//getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
                var value = 0//initialValues["_rotateX"]! + ((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                if value < 0 {
                    value = 360 + value
                }
                let properties : [String:Float] = [
                    "_rotateX" : value
                ]
                processGizmoProperties(properties)
                */
            } else
            if dragState == .xAxisScale {
                if let fragment = scaleXFragment {
                    //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                    //processProperty(fragment, name: scaleXFragmentName!, value: max(initialValues["_scaleX"]! + (hit.x - dragStartOffset!.x), 0.001))
                    processProperty(fragment, name: scaleXFragmentName!, value: max(initialValues["_scaleX"]! + diff, 0.001))
                }
            } else
            if dragState == .yAxisScale {
                if let fragment = scaleYFragment {
                    //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoYAxisNormal, planeCenter: planeCenter)
                    //processProperty(fragment, name: scaleYFragmentName!, value: max(initialValues["_scaleY"]! - (hit.y - dragStartOffset!.x), 0.001))
                    processProperty(fragment, name: scaleYFragmentName!, value: max(initialValues["_scaleY"]! - diff, 0.001))
                }
            } else
            if dragState == .zAxisScale {
                if let fragment = scaleZFragment {
                    //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoZAxisNormal, planeCenter: planeCenter)
                    //processProperty(fragment, name: scaleZFragmentName!, value: max(initialValues["_scaleZ"]! + (hit.z - dragStartOffset!.x), 0.001))
                    processProperty(fragment, name: scaleZFragmentName!, value: max(initialValues["_scaleZ"]! + diff, 0.001))
                }
            }
            
            if undoComponent == nil {
                //undoComponent = globalApp!.currentEditor.undoComponentStart("Gizmo Action")
            }
            
            //updateUIProperties()
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
            //globalApp!.currentEditor.undoComponentEnd(undoComponent!)
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
        
        if !timeline.isRecording {
            for(name, value) in properties {
                component.values[name] = value
            }
        } else {
            timeline.addKeyProperties(sequence: component.sequence, uuid: component.uuid, properties: properties)
        }
        globalApp!.currentEditor.updateOnNextDraw(compile: false)
    }
    
    ///
    func processProperty(_ fragment: CodeFragment, name: String, value: Float)
    {
        let timeline = globalApp!.artistEditor.timeline
        
        if !timeline.isRecording {
            fragment.values["value"] = value
        } else {
            let properties : [String:Float] = [name:value]
            timeline.addKeyProperties(sequence: component.sequence, uuid: component.uuid, properties: properties)
        }
        globalApp!.currentEditor.updateOnNextDraw(compile: false)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if component.componentType == .Dummy { return }

        moveButton.rect.x = rect.x + (rect.width - rotateButton.rect.width) / 2
        moveButton.rect.y = rect.y + (rect.height - rotateButton.rect.height) / 2 - 40
        moveButton.draw()
        
        panButton.rect.x = rect.x + (rect.width - rotateButton.rect.width) / 2
        panButton.rect.y = rect.y + (rect.height - rotateButton.rect.height) / 2 + 40
        panButton.draw()
        
        rotateButton.rect.x = rect.x + (rect.width - rotateButton.rect.width) / 2 + 40
        rotateButton.rect.y = rect.y + (rect.height - rotateButton.rect.height) / 2
        rotateButton.draw()
        
        zoomButton.rect.x = rect.x + (rect.width - rotateButton.rect.width) / 2 - 60
        zoomButton.rect.y = rect.y + (rect.height - rotateButton.rect.height) / 2
        zoomButton.draw()
    }
}
