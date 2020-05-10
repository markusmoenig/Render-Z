//
//  Gizmo3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 19/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

class GizmoCombo3D          : GizmoBase
{
    var state               : MTLRenderPipelineState!
    var idState             : MTLComputePipelineState!
    var cameraState         : MTLComputePipelineState!
    
    var statePoint          : MTLRenderPipelineState!
    var idStatePoint        : MTLComputePipelineState!

    let width               : Float = 260
    let height              : Float = 260
    
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
    
    var moveButton          : MMButtonWidget
    var scaleButton         : MMButtonWidget
    var rotateButton        : MMButtonWidget
    var xAxisButton         : MMButtonWidget
    var yAxisButton         : MMButtonWidget
    var zAxisButton         : MMButtonWidget

    var hoverButton         : MMButtonWidget? = nil
    var activeButton        : MMButtonWidget? = nil
    
    var hoverAxisButton     : MMButtonWidget? = nil
    var activeAxisButton    : MMButtonWidget? = nil

    var undoComponent       : CodeUndoComponent? = nil
    
    var dispatched          : Bool = false
    var zoomBuffer          : SIMD3<Float> = SIMD3<Float>(0,0,0)
    
    var planeCenter         : SIMD3<Float> = SIMD3<Float>(0,0,0)

    let gizmoXAxisNormal    : SIMD3<Float> = SIMD3<Float>(0,1,0)
    let gizmoYAxisNormal    : SIMD3<Float> = SIMD3<Float>(0,0,1)
    let gizmoZAxisNormal    : SIMD3<Float> = SIMD3<Float>(1,0,0)
    
    var gizmoDistance       : Float = 0
    var gizmoDragLocked     : Int = 0

    var compute             : MMCompute
    
    //var camera3D            : CamHelper3D = CamHelper3D()
    var mouseIsDown         : Bool = false
    var scaleAllAxis        : Bool = false
    
    var isPoint             : Bool = false
    
    var isTransform         : Bool = false
    
    override init(_ view: MMView)
    {
        var function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmoCombo3D" )
        state = view.renderer.createNewPipelineState( function! )
        
        function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmoCombo3DPoint" )
        statePoint = view.renderer.createNewPipelineState( function! )

        compute = MMCompute()
        idStatePoint = compute.createState(name: "idsGizmoCombo3DPoint")

        idState = compute.createState(name: "idsGizmoCombo3D")
        cameraState = compute.createState(name: "cameraGizmoCombo3D")

        var smallButtonSkin = MMSkinButton()
        smallButtonSkin.round = 50
        smallButtonSkin.borderColor = SIMD4<Float>(0,0,0,0)
        smallButtonSkin.hoverColor = SIMD4<Float>(1.0,1.0,1.0,0.3)

        moveButton = MMButtonWidget(view, skinToUse: smallButtonSkin, iconName: "move" )
        moveButton.iconZoom = 2
        moveButton.rect.width = 50
        moveButton.rect.height = 50
        rotateButton = MMButtonWidget(view, skinToUse: smallButtonSkin, iconName: "rotate" )
        rotateButton.iconZoom = 2
        rotateButton.rect.width = 50
        rotateButton.rect.height = 50
        scaleButton = MMButtonWidget(view, skinToUse: smallButtonSkin, iconName: "scale" )
        scaleButton.iconZoom = 2
        scaleButton.rect.width = 50
        scaleButton.rect.height = 50
        xAxisButton = MMButtonWidget(view, skinToUse: smallButtonSkin, iconName: "X_blue_ring" )
        xAxisButton.iconZoom = 2
        xAxisButton.rect.width = 50
        xAxisButton.rect.height = 50
        xAxisButton.textYOffset = 1
        activeAxisButton = xAxisButton
        xAxisButton.addState(.Hover)
        yAxisButton = MMButtonWidget(view, skinToUse: smallButtonSkin, iconName: "Y_red_ring" )
        yAxisButton.iconZoom = 2
        yAxisButton.rect.width = 50
        yAxisButton.rect.height = 50
        yAxisButton.textYOffset = 1
        zAxisButton = MMButtonWidget(view, skinToUse: smallButtonSkin, iconName: "Z_green_ring" )
        zAxisButton.iconZoom = 2
        zAxisButton.rect.width = 50
        zAxisButton.rect.height = 50
        zAxisButton.textYOffset = 1
        
        super.init(view)
    }
    
    override func setComponent(_ comp: CodeComponent)
    {
        component = comp
        isPoint = false
        isTransform = false
        
        if comp.componentType == .Light3D {
            isPoint = true
        }
        if comp.componentType == .Transform3D {
            isTransform = true
        }
        
        // Show the supported transform values
        let designEditor = globalApp!.artistEditor.designEditor
        let designProperties = globalApp!.artistEditor.designProperties

        if let tNode = designProperties.c2Node, component.componentType != .Dummy {
            
            let posVar = NodeUINumber3(tNode, variable: "_pos", title: "Position", value: SIMD3<Float>(comp.values["_posX"]!, comp.values["_posY"]!, comp.values["_posZ"]!), precision: 3)
            
            posVar.titleShadows = true
            tNode.uiItems.append(posVar)
            
            if isPoint == false {
                
                let rotateVar = NodeUINumber3(tNode, variable: "_rotate", title: "Rotate", value: SIMD3<Float>(comp.values["_rotateX"]!, comp.values["_rotateY"]!, comp.values["_rotateZ"]!), precision: 3)
                
                rotateVar.titleShadows = true
                tNode.uiItems.append(rotateVar)
            }
            
            if isTransform {
                let scaleVar = NodeUINumber(tNode, variable: "_scale", title: "Scale", range: SIMD2<Float>(0.001,5), value: comp.values["_scale"]!,  precision: 3, halfWidthValue: 1)
                scaleVar.titleShadows = true
                scaleVar.autoAdjustMargin = true
                tNode.uiItems.append(scaleVar)
            }
            
            if comp.values["2DIn3D"] == 1 {
                let extrusionVar = NodeUINumber(tNode, variable: "_extrusion", title: "Extrusion", range: SIMD2<Float>(0,5), value: comp.values["_extrusion"]!,  precision: 3)
                extrusionVar.titleShadows = true
                extrusionVar.autoAdjustMargin = true
                tNode.uiItems.append(extrusionVar)
                
                let revolutionVar = NodeUINumber(tNode, variable: "_revolution", title: "Revolution", range: SIMD2<Float>(0,5), value: comp.values["_revolution"]!,  precision: 3)
                revolutionVar.titleShadows = true
                revolutionVar.autoAdjustMargin = true
                tNode.uiItems.append(revolutionVar)
            }

            tNode.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                comp.values[variable] = oldValue
                let codeUndo : CodeUndoComponent? = continous == false ? designEditor.undoStart("Value Changed") : nil
                comp.values[variable] = newValue
                
                designProperties.updatePreview()
                designProperties.addKey([variable:newValue])
                if let undo = codeUndo { designEditor.undoEnd(undo) }
            }
            
            tNode.float3ChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                comp.values[variable + "X"] = oldValue.x
                comp.values[variable + "Y"] = oldValue.y
                comp.values[variable + "Z"] = oldValue.z
                let codeUndo : CodeUndoComponent? = continous == false ? designEditor.undoStart("Value Changed") : nil
                comp.values[variable + "X"] = newValue.x
                comp.values[variable + "Y"] = newValue.y
                comp.values[variable + "Z"] = newValue.z
                
                designProperties.updatePreview()
                var props : [String:Float] = [:]
                props[variable + "X"] = newValue.x
                props[variable + "Y"] = newValue.y
                props[variable + "Z"] = newValue.z
                designProperties.addKey(props)
                if let undo = codeUndo { designEditor.undoEnd(undo) }
            }
            tNode.setupUI(mmView: mmView)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if component.componentType == .Dummy { return }
        mouseIsDown = true
        
        #if os(iOS)
            mouseMoved(event)
        #endif
        if hoverState != .Inactive {
            dragState = hoverState
                        
            /*
            var properties : [String:Float] = [:]
            properties["_posX"] = (component.values["_posX"]! + getHierarchyValue(component, "_posX"))
            properties["_posY"] = (component.values["_posY"]! + getHierarchyValue(component, "_posY"))
            properties["_posZ"] = (component.values["_posZ"]! + getHierarchyValue(component, "_posZ"))

            let timeline = globalApp!.artistEditor.timeline
            let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
            
            planeCenter = SIMD3<Float>(transformed["_posX"]!, -transformed["_posY"]!, transformed["_posZ"]!)
            
            let camera = getScreenCameraDir(event)

            if dragState == .xAxisMove || dragState == .xAxisScale {
                let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                dragStartOffset = SIMD2<Float>(hit.x, 0)
            }
            if dragState == .yAxisMove || dragState == .yAxisScale {
                let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoYAxisNormal, planeCenter: planeCenter)
                dragStartOffset = SIMD2<Float>(hit.y, 0)
            }
            if dragState == .zAxisMove || dragState == .zAxisScale  {
                let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoZAxisNormal, planeCenter: planeCenter)
                dragStartOffset = SIMD2<Float>(hit.z, 0)
            }*/
            
            dragStartOffset = SIMD2<Float>(event.x - rect.x, event.y - rect.y)
            gizmoDragLocked = 0

            initialValues = component.values
            //startRotate = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
            
            scaleXFragmentName = nil
            scaleYFragmentName = nil
            scaleZFragmentName = nil
            scaleXFragment = nil
            scaleYFragment = nil
            scaleZFragment = nil
            scaleAllAxis = false

            // Get the scale gizmo mapping for the properties
            for prop in component.properties {
                if let gizmoName = component.propertyGizmoName[prop] {
                    if gizmoName != "No" {
                        let rc = component.getPropertyOfUUID(prop)
                        if let frag = rc.0, rc.1 != nil {
                            if gizmoName == "Scale (All)" {
                                scaleAllAxis = true
                            }
                            if gizmoName == "Scale (All)" || gizmoName == "Scale X" {
                                scaleXFragmentName = frag.name
                                scaleXFragment = rc.1!
                                initialValues["_scaleX"] = rc.1!.values["value"]!
                            } else
                            if gizmoName == "Scale (All)" || gizmoName == "Scale Y" {
                                scaleYFragmentName = frag.name
                                scaleYFragment = rc.1!
                                initialValues["_scaleY"] = rc.1!.values["value"]!
                            } else
                            if gizmoName == "Scale (All)" || gizmoName == "Scale Z" {
                                scaleZFragmentName = frag.name
                                scaleZFragment = rc.1!
                                initialValues["_scaleZ"] = rc.1!.values["value"]!
                            }
                        }
                    }
                }
            }
            globalApp!.currentPipeline?.setMinimalPreview(true)
        } else {
            if let hoverAxis = hoverAxisButton {
                if let activeAxis = activeAxisButton {
                    activeAxis.removeState(.Hover)
                }
                activeAxisButton = hoverAxis
                activeAxisButton!.addState(.Hover)
                clickWasConsumed = true
            }
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if component.componentType == .Dummy { return }
        
        if dragState == .Inactive {
            
            if compute.texture == nil || compute.texture.width != Int(rect.width) || compute.texture.height != Int(rect.height) {
                compute.texture = compute.allocateTexture(width: rect.width, height: rect.height, pixelFormat: .r32Float)
            }
            
            let origin = getCameraPropertyValue3("origin")
            let lookAt = getCameraPropertyValue3("lookAt")
            let fov = getCameraPropertyValue("fov")

            let pivotX : Float = getHierarchyValue(component, "_posX")
            let pivotY : Float = getHierarchyValue(component, "_posY")
            let pivotZ : Float = getHierarchyValue(component, "_posZ")
            
            let rotateX : Float = getHierarchyValue(component, "_rotateX", includeSelf: false)
            let rotateY : Float = getHierarchyValue(component, "_rotateY", includeSelf: false)
            let rotateZ : Float = getHierarchyValue(component, "_rotateZ", includeSelf: false)

            var properties : [String:Float] = [:]
            properties["_posX"] = component.values["_posX"]!
            properties["_posY"] = component.values["_posY"]!
            properties["_posZ"] = component.values["_posZ"]!
            
            //properties["_rotateX"] = getHierarchyValue(component, "_rotateX")
            //properties["_rotateY"] = getHierarchyValue(component, "_rotateY")
            //properties["_rotateZ"] = getHierarchyValue(component, "_rotateZ")

            let timeline = globalApp!.artistEditor.timeline
            let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
            
            // --- Render Gizmo
            let data: [Float] = [
                rect.width, rect.height,
                hoverState.rawValue, 0,
                origin.x, origin.y, origin.z, fov,
                lookAt.x, lookAt.y, lookAt.z, 0,
                transformed["_posX"]!, transformed["_posY"]!, transformed["_posZ"]!, 0,
                rotateX, rotateY, rotateZ, 0,
                pivotX, pivotY, pivotZ, 0
            ];
                        
            let buffer = compute.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
            
            if isPoint == false {
                compute.run(idState, outTexture: compute.texture, inBuffer: buffer, syncronize: true)
            } else {
                compute.run(idStatePoint, outTexture: compute.texture, inBuffer: buffer, syncronize: true)
            }
                        
            let region = MTLRegionMake2D(min(Int(event.x - rect.x), compute.texture!.width-1), min(Int(rect.height - (event.y - rect.y)), compute.texture!.height-1), 1, 1)

            var texArray = Array<Float>(repeating: Float(0), count: 1)
            //compute.texture!.getBytes(UnsafeMutableRawPointer(mutating: texArray), bytesPerRow: (MemoryLayout<Float>.size * compute.texture!.width), from: region, mipmapLevel: 0)
            texArray.withUnsafeMutableBytes { texArrayPtr in
                compute.texture!.getBytes(texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * compute.texture!.width), from: region, mipmapLevel: 0)
            }
            let value = texArray[0]
            //print(value)

            let oldState = hoverState
            hoverState = .Inactive
            if let state = GizmoState(rawValue: value) {
                hoverState = state
            }
            if oldState != hoverState {
                mmView.update()
            }
            
            // If still inactive test the buttons
            
            if let hover = hoverButton {
                hover.removeState(.Hover)
            }
            hoverButton = nil
            if hoverState == .Inactive {
                let oldState = hoverState
                
                // Action Buttons

                if moveButton.rect.contains(event.x, event.y) {
                    hoverButton = moveButton
                    if activeAxisButton === xAxisButton { hoverState = .xAxisMove }
                    else if activeAxisButton === yAxisButton { hoverState = .yAxisMove }
                    else if activeAxisButton === zAxisButton { hoverState = .zAxisMove }
                    moveButton.addState(.Hover)
                } else
                if rotateButton.rect.contains(event.x, event.y) {
                    hoverButton = rotateButton
                    if activeAxisButton === xAxisButton { hoverState = .xAxisRotate }
                    else if activeAxisButton === yAxisButton { hoverState = .yAxisRotate }
                    else if activeAxisButton === zAxisButton { hoverState = .zAxisRotate }
                    rotateButton.addState(.Hover)
                } else
                if scaleButton.rect.contains(event.x, event.y) {
                    hoverButton = scaleButton
                    if activeAxisButton === xAxisButton { hoverState = .xAxisScale }
                    else if activeAxisButton === yAxisButton { hoverState = .yAxisScale }
                    else if activeAxisButton === zAxisButton { hoverState = .zAxisScale }
                    scaleButton.addState(.Hover)
                }
                
                // Axis Buttons
                
                if let hover = hoverAxisButton {
                    if hover !== activeAxisButton {
                        hover.removeState(.Hover)
                    }
                }
                
                hoverAxisButton = nil
                if xAxisButton.rect.contains(event.x, event.y) {
                    hoverAxisButton = xAxisButton
                    xAxisButton.addState(.Hover)
                } else
                if yAxisButton.rect.contains(event.x, event.y) {
                    hoverAxisButton = yAxisButton
                    yAxisButton.addState(.Hover)
                } else
                if zAxisButton.rect.contains(event.x, event.y) {
                    hoverAxisButton = zAxisButton
                    zAxisButton.addState(.Hover)
                }
                
                if oldState != hoverState {
                    mmView.update()
                }
            }
        } else {
            //let camera = getScreenCameraDir(event)
            let div : Float = rect.width / gizmoDistance
            let p = SIMD2<Float>(event.x - rect.x, event.y - rect.y)
            var diff : Float

            // Figure out the drag direction and calculate the diff
            if gizmoDragLocked == 0 {
                var dx = p.x - dragStartOffset!.x; dx *= dx
                var dy = p.y - dragStartOffset!.y; dy *= dy
                
                if dx > dy {
                    diff = (p.x - dragStartOffset!.x) / div
                    if dx > 10 {
                        gizmoDragLocked = 1
                    }
                } else {
                    diff = (p.y - dragStartOffset!.y) / div
                    if dy > 10 {
                        gizmoDragLocked = 2
                    }
                }
            } else
            if gizmoDragLocked == 1 {
                diff = (p.x - dragStartOffset!.x) / div
            } else {
                diff = (p.y - dragStartOffset!.y) / div
            }

            if dragState == .xAxisMove {
                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    //"_posX" : initialValues["_posX"]! + (hit.x - dragStartOffset!.x),
                    "_posX" : initialValues["_posX"]! + diff
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .yAxisMove {
                //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoYAxisNormal, planeCenter: planeCenter)
                let properties : [String:Float] = [
                    //"_posY" : initialValues["_posY"]! + (hit.y - dragStartOffset!.x),
                    "_posY" : initialValues["_posY"]! - diff
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
            } else
            if dragState == .xAxisRotate {
                var value = initialValues["_rotateX"]! + diff * 50
                if value < 0 {
                    value = 360 + value
                }
                let properties : [String:Float] = [
                    "_rotateX" : value
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .yAxisRotate {
                var value = initialValues["_rotateY"]! + diff * 50
                if value < 0 {
                    value = 360 + value
                }
                let properties : [String:Float] = [
                    "_rotateY" : value
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .zAxisRotate {
                //let angle = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
                var value = initialValues["_rotateZ"]! + diff * 50//((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                if value < 0 {
                    value = 360 + value
                }
                let properties : [String:Float] = [
                    "_rotateZ" : value
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .xAxisScale || scaleAllAxis {
                if isTransform {
                    let properties : [String:Float] = [
                        "_scale" : initialValues["_scale"]! + diff
                    ]
                    processGizmoProperties(properties)
                } else
                if let fragment = scaleXFragment {
                    //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoXAxisNormal, planeCenter: planeCenter)
                    //processProperty(fragment, name: scaleXFragmentName!, value: max(initialValues["_scaleX"]! + (hit.x - dragStartOffset!.x), 0.001))
                    processProperty(fragment, name: scaleXFragmentName!, value: max(initialValues["_scaleX"]! + diff, 0.001))
                }
            } else
            if dragState == .yAxisScale || scaleAllAxis {
                if isTransform {
                    let properties : [String:Float] = [
                        "_scale" : initialValues["_scale"]! + diff
                    ]
                    processGizmoProperties(properties)
                } else
                if let fragment = scaleYFragment {
                    //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoYAxisNormal, planeCenter: planeCenter)
                    //processProperty(fragment, name: scaleYFragmentName!, value: max(initialValues["_scaleY"]! - (hit.y - dragStartOffset!.x), 0.001))
                    processProperty(fragment, name: scaleYFragmentName!, value: max(initialValues["_scaleY"]! - diff, 0.001))
                }
            } else
            if dragState == .zAxisScale || scaleAllAxis {
                if isTransform {
                    let properties : [String:Float] = [
                        "_scale" : initialValues["_scale"]! + diff
                    ]
                    processGizmoProperties(properties)
                } else
                if let fragment = scaleZFragment {
                    //let hit = getPlaneIntersection(camera: camera, planeNormal: gizmoZAxisNormal, planeCenter: planeCenter)
                    //processProperty(fragment, name: scaleZFragmentName!, value: max(initialValues["_scaleZ"]! + (hit.z - dragStartOffset!.x), 0.001))
                    processProperty(fragment, name: scaleZFragmentName!, value: max(initialValues["_scaleZ"]! + diff, 0.001))
                }
            }
            
            if undoComponent == nil {
                undoComponent = globalApp!.currentEditor.undoComponentStart("Gizmo Action")
            }
            
            updateUIProperties()
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if component.componentType == .Dummy { return }

        if hoverState != .Inactive {
            globalApp!.currentPipeline?.setMinimalPreview()
        }
        
        if let hb = hoverButton {
            hb.removeState(.Hover)
        }
        
        dragState = .Inactive
        #if os(iOS)
        hoverState = .Inactive
        #endif
        if undoComponent != nil {
            globalApp!.currentEditor.undoComponentEnd(undoComponent!)
            undoComponent = nil
        }
        mmView.update()
        mouseIsDown = false
        clickWasConsumed = false
        activeButton = nil
    }
    
    /*
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        let camera : CodeComponent = getFirstComponentOfType(globalApp!.project.selected!.getStage(.PreStage).getChildren(), globalApp!.currentSceneMode == .TwoD ? .Camera2D : .Camera3D)!

        var originFrag  : CodeFragment? = nil
        var lookAtFrag  : CodeFragment? = nil
        var fovFrag     : CodeFragment? = nil

        for uuid in camera.properties {
            let rc = camera.getPropertyOfUUID(uuid)
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
        
        camera3D.initFromCamera(aspect: rect.width/rect.height, originFrag: originFrag, lookAtFrag: lookAtFrag, fovFrag: fovFrag)
        
        #if os(iOS)
        if mmView.numberOfTouches > 1 {
            camera3D.rotate(dx: event.deltaX! * 0.003, dy: event.deltaY! * 0.03)
        } else {
            camera3D.pan(dx: event.deltaX! * 0.003, dy: event.deltaY! * 0.03)
        }
        #elseif os(OSX)
        if mmView.commandIsDown {
            if event.deltaY! != 0 {
                camera3D.zoom(dx: 0, dy: event.deltaY! * 0.03)
            }
        } else {
            if mmView.shiftIsDown {
                camera3D.rotate(dx: event.deltaX! * 0.003, dy: event.deltaY! * 0.03)
            } else {
                camera3D.pan(dx: event.deltaX! * 0.003, dy: event.deltaY! * 0.03)
            }
        }
        #endif
        
        globalApp!.currentEditor.updateOnNextDraw(compile: false)
        
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
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        let camera : CodeComponent = getFirstComponentOfType(globalApp!.project.selected!.getStage(.PreStage).getChildren(), globalApp!.currentSceneMode == .TwoD ? .Camera2D : .Camera3D)!

        var originFrag  : CodeFragment? = nil
        var lookAtFrag  : CodeFragment? = nil
        var fovFrag     : CodeFragment? = nil

        for uuid in camera.properties {
            let rc = camera.getPropertyOfUUID(uuid)
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
    
        camera3D.initFromCamera(aspect: rect.width/rect.height, originFrag: originFrag, lookAtFrag: lookAtFrag, fovFrag: fovFrag)

        if let origin = originFrag {
            if let lookAt = lookAtFrag {
                if firstTouch == true {
                    zoomBuffer = extractValueFromFragment3(origin) - extractValueFromFragment3(lookAt)
                }
                camera3D.zoomRelative(dx: 0, dy: scale, start: zoomBuffer)
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
            }
        }
    }*/
    
    /// Updates the UI properties
    func updateUIProperties()
    {
        let designProperties = globalApp!.artistEditor.designProperties
        
        if let tNode = designProperties.c2Node {
            for item in tNode.uiItems {
                if item.brand == .Number {
                    if let number = item as? NodeUINumber {
                        number.value = component.values[item.variable]!
                    } else
                    if let number = item as? NodeUINumber3 {
                        number.value = SIMD3<Float>(component.values[item.variable + "X"]!, component.values[item.variable + "Y"]!, component.values[item.variable + "Z"]!)
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

        let origin = getCameraPropertyValue3("origin")
        let lookAt = getCameraPropertyValue3("lookAt")
        let fov = getCameraPropertyValue("fov")

        let pivotX : Float = getHierarchyValue(component, "_posX")
        let pivotY : Float = getHierarchyValue(component, "_posY")
        let pivotZ : Float = getHierarchyValue(component, "_posZ")
        
        let rotateX : Float = getHierarchyValue(component, "_rotateX", includeSelf: false)
        let rotateY : Float = getHierarchyValue(component, "_rotateY", includeSelf: false)
        let rotateZ : Float = getHierarchyValue(component, "_rotateZ", includeSelf: false)

        var properties : [String:Float] = [:]
        properties["_posX"] = component.values["_posX"]!
        properties["_posY"] = component.values["_posY"]!
        properties["_posZ"] = component.values["_posZ"]!
        
        //properties["_rotateX"] = component.values["_rotateX"]!
        //properties["_rotateY"] = component.values["_rotateY"]!
        //properties["_rotateZ"] = component.values["_rotateZ"]!

        let timeline = globalApp!.artistEditor.timeline
        let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
        
        // --- Render Gizmo
        let data: [Float] = [
            rect.width, rect.height,
            hoverState.rawValue, 0,
            origin.x, origin.y, origin.z, fov,
            lookAt.x, lookAt.y, lookAt.z, 0,
            transformed["_posX"]!, transformed["_posY"]!, transformed["_posZ"]!, 0,
            rotateX, rotateY, rotateZ, 0,
            pivotX, pivotY, pivotZ, 0
        ];
        
        print("pos", transformed["_posX"]!, transformed["_posY"]!, transformed["_posZ"]!)
        print("rotate", rotateX, rotateY, rotateZ)
        print("pivot", pivotX, pivotY, pivotZ)
                
        gizmoDistance = simd_distance(origin, SIMD3<Float>(transformed["_posX"]!, transformed["_posY"]!, transformed["_posZ"]!))
        mmView.renderer.setClipRect(rect)

        let mmRenderer = mmView.renderer!
        let renderEncoder = mmRenderer.renderEncoder!

        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( rect.x, rect.y, rect.width, rect.height, scale: mmView.scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        if isPoint == false {
            renderEncoder.setRenderPipelineState(state!)
        } else {
            renderEncoder.setRenderPipelineState(statePoint!)
        }
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        mmView.renderer.setClipRect()
        
        let margin : Float = 20
        
        xAxisButton.rect.x = rect.x + (rect.width - xAxisButton.rect.width) / 2 + (xAxisButton.rect.width * 3 + 3 * 20) / 2
        xAxisButton.rect.y = rect.y + (rect.height - 70)
        xAxisButton.draw()
        
        yAxisButton.rect.x = xAxisButton.rect.x
        yAxisButton.rect.y = xAxisButton.rect.y - xAxisButton.rect.height - margin / 2
        yAxisButton.draw()
        
        zAxisButton.rect.x = xAxisButton.rect.x
        zAxisButton.rect.y = yAxisButton.rect.y - yAxisButton.rect.height - margin / 2
        zAxisButton.draw()
        
        if isPoint == false {
            scaleButton.rect.x = xAxisButton.rect.x - scaleButton.rect.width - margin
            scaleButton.rect.y = xAxisButton.rect.y
            scaleButton.draw()
            
            rotateButton.rect.x = scaleButton.rect.x - scaleButton.rect.width - margin
            rotateButton.rect.y = xAxisButton.rect.y
            rotateButton.draw()
            
            moveButton.rect.x = rotateButton.rect.x - rotateButton.rect.width - margin
            moveButton.rect.y = xAxisButton.rect.y
            moveButton.draw()
        } else {
            moveButton.rect.x = xAxisButton.rect.x - moveButton.rect.width - margin
            moveButton.rect.y = xAxisButton.rect.y
            moveButton.draw()
        }
    }
    
    /// Returns the angle between the start / end points
    func getAngle(cx : Float, cy : Float, ex : Float, ey : Float, degree : Bool ) -> Float
    {
        var a : Float = atan2(-ey - -cy, ex - cx);
        if a < 0 {
            a += 2 * Float.pi; //angle is now in radians
        }
        
        a -= (Float.pi/2); //shift by 90deg
        //restore value in range 0-2pi instead of -pi/2-3pi/2
        if a < 0 {
            a += 2 * Float.pi;
        }
        if a < 0 {
            a += 2 * Float.pi;
        }
        a = abs((Float.pi * 2) - a); //invert rotate
        
        if degree {
            a = a*180/Float.pi; //convert to deg
        }
        return a;
    }
    
    func getPlaneIntersection(camera: (SIMD3<Float>, SIMD3<Float>), planeNormal: SIMD3<Float>, planeCenter: SIMD3<Float> = SIMD3<Float>(0,0,0)) -> SIMD3<Float>
    {
        let denom : Float = simd_dot(camera.1, planeNormal)
        if denom != 0 {
            let t : Float = -(simd_dot(camera.0 - planeCenter, planeNormal)) / denom
            //print("t", t)
            if t >= 0 {
                let hit = camera.0 + camera.1 * t
                //print("hit", hit)
                return hit
            }
        }
        return SIMD3<Float>(0,0,0)
    }
    
    func getScreenCameraDir(_ event: MMMouseEvent) -> (SIMD3<Float>, SIMD3<Float>)
    {
        let origin = getCameraPropertyValue3("origin")
        let lookAt = getCameraPropertyValue3("lookAt")
        let fov = getCameraPropertyValue("fov")

        // --- Render Gizmo
        let data: [Float] = [
            rect.width, rect.height,
            hoverState.rawValue, 0,
            origin.x, origin.y, origin.z, fov,
            lookAt.x, lookAt.y, lookAt.z, 0,
            (event.x - rect.x), (event.y - rect.y), 0, 0
        ];
        
        let buffer = compute.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        let outBuffer = compute.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride, options: [])!

        compute.runBuffer(cameraState, outBuffer: outBuffer, inBuffer: buffer, wait: true)
        let result = outBuffer.contents().bindMemory(to: Float.self, capacity: 4)

        return (origin, SIMD3<Float>(result[0], result[1], result[2]))
    }
}
