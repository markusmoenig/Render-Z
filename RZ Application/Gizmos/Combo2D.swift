//
//  Gizmo2D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 17/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class GizmoCombo2D          : GizmoBase
{
    var state               : MTLRenderPipelineState!
    
    let width               : Float = 260
    let height              : Float = 260
    
    var dragStartOffset     : SIMD2<Float>?
    var gizmoCenter         : SIMD2<Float> = SIMD2<Float>()
    var initialValues       : [String:Float] = [:]
    var startRotate         : Float = 0

    var scaleXFragmentName  : String? = nil
    var scaleYFragmentName  : String? = nil
    var scaleXFragment      : CodeFragment? = nil
    var scaleYFragment      : CodeFragment? = nil
    
    var undoComponent       : CodeUndoComponent? = nil
    
    var dispatched          : Bool = false
    var zoomBuffer          : Float = 0
    
    var customUpdateCB      : (()->())? = nil
    
    override init(_ view: MMView)
    {
        let function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmoCombo2D" )
        state = view.renderer.createNewPipelineState( function! )
        
        super.init(view)
    }
    
    override func setComponent(_ comp: CodeComponent)
    {
        component = comp
        
        // Show the supported transform values
        let designEditor = globalApp!.artistEditor.designEditor
        let designProperties = globalApp!.artistEditor.designProperties

        if let tNode = designProperties.c2Node, customUpdateCB == nil {
            
            let xVar = NodeUINumber(tNode, variable: "_posX", title: "X", range: SIMD2<Float>(-10000, 10000), value: comp.values["_posX"]!, precision: 1)
            let yVar = NodeUINumber(tNode, variable: "_posY", title: "Y", range: SIMD2<Float>(-10000, 10000), value: comp.values["_posY"]!, precision: 1)
            let rotateVar = NodeUINumber(tNode, variable: "_rotate", title: "Rotate", range: SIMD2<Float>(0, 360), value: comp.values["_rotate"]!, precision: 1)
            tNode.uiItems.append(xVar)
            tNode.uiItems.append(yVar)
            tNode.uiItems.append(rotateVar)

            tNode.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                comp.values[variable] = oldValue
                let codeUndo : CodeUndoComponent? = continous == false ? designEditor.undoStart("Value Changed") : nil
                comp.values[variable] = newValue
                designProperties.updatePreview()
                designProperties.addKey([variable:newValue])
                if let undo = codeUndo { designEditor.undoEnd(undo) }
            }
            tNode.setupUI(mmView: mmView)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
            mouseMoved(event)
        #endif
        if hoverState != .Inactive {
            dragState = hoverState
            
            dragStartOffset = convertToSceneSpace(x: event.x, y: event.y)
            initialValues = component.values
            startRotate = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
            
            scaleXFragmentName = nil
            scaleYFragmentName = nil
            scaleXFragment = nil
            scaleYFragment = nil
            
            // Get the scale gizmo mapping for the properties
            for prop in component.properties {
                if let gizmoName = component.propertyGizmoName[prop] {
                    if gizmoName != "No" {
                        let rc = component.getPropertyOfUUID(prop)
                        if let frag = rc.0, rc.1 != nil {
                            if gizmoName == "Scale (All)" || gizmoName == "Scale X" {
                                scaleXFragmentName = frag.name
                                scaleXFragment = rc.1!
                                initialValues["_scaleX"] = rc.1!.values["value"]!
                            }
                            if gizmoName == "Scale (All)" || gizmoName == "Scale Y" {
                                scaleYFragmentName = frag.name
                                scaleYFragment = rc.1!
                                initialValues["_scaleY"] = rc.1!.values["value"]!
                            }
                        }
                    }
                }
            }
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if dragState == .Inactive {
            let oldState = hoverState
            updateHoverState(event)
            if oldState != hoverState {
                mmView.update()
            }
        } else {
            let pos = convertToSceneSpace(x: event.x, y: event.y)
            let scale : Float = getCameraPropertyValue("scale", defaultValue: 1)

            if dragState == .CenterMove {
                let properties : [String:Float] = [
                    "_posX" : initialValues["_posX"]! + (pos.x - dragStartOffset!.x) * scale,
                    "_posY" : initialValues["_posY"]! - (pos.y - dragStartOffset!.y) * scale,
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .xAxisMove {
                let properties : [String:Float] = [
                    "_posX" : initialValues["_posX"]! + (pos.x - dragStartOffset!.x) * scale,
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .yAxisMove {
                let properties : [String:Float] = [
                    "_posY" : initialValues["_posY"]! - (pos.y - dragStartOffset!.y) * scale,
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .Rotate {
                let angle = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
                var value = initialValues["_rotate"]! + ((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                if value < 0 {
                    value = 360 + value
                }
                let properties : [String:Float] = [
                    "_rotate" : value
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .xAxisScale {
                if let fragment = scaleXFragment {
                    processProperty(fragment, name: scaleXFragmentName!, value: max(initialValues["_scaleX"]! + (pos.x - dragStartOffset!.x) * scale, 0.001))
                }
            } else
            if dragState == .yAxisScale {
                if let fragment = scaleYFragment {
                    processProperty(fragment, name: scaleYFragmentName!, value: max(initialValues["_scaleY"]! - (pos.y - dragStartOffset!.y) * scale, 0.001))
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
        dragState = .Inactive
        #if os(iOS)
        hoverState = .Inactive
        #endif
        if undoComponent != nil {
            globalApp!.currentEditor.undoComponentEnd(undoComponent!)
            undoComponent = nil
        }
        mmView.update()
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        let camera : CodeComponent = getFirstComponentOfType(globalApp!.project.selected!.getStage(.PreStage).getChildren(), globalApp!.currentSceneMode == .TwoD ? .Camera2D : .Camera3D)!

        var xFrag : CodeFragment? = nil
        var yFrag : CodeFragment? = nil
        var scale : CodeFragment? = nil

        for uuid in camera.properties {
            let rc = camera.getPropertyOfUUID(uuid)
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
        
        #if os(iOS)
        if let frag = xFrag {
            frag.values["value"]! -= event.deltaX!
        }
        if let frag = yFrag {
            frag.values["value"]! += event.deltaY!
        }
        #elseif os(OSX)
        if mmView.commandIsDown && event.deltaY! != 0 {
            if let frag = scale {
                frag.values["value"]! -= event.deltaY! * 0.03
                frag.values["value"]! = max(0.001, frag.values["value"]!)
                frag.values["value"]! = min(20, frag.values["value"]!)
            }
        } else {
            if let frag = xFrag {
                frag.values["value"]! += event.deltaX! * 2
            }
            if let frag = yFrag {
                frag.values["value"]! -= event.deltaY! * 2
            }
        }
        #endif
        
        if let updateCB = customUpdateCB {
            updateCB()
        } else {
            globalApp!.currentEditor.updateOnNextDraw(compile: false)
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
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        let camera : CodeComponent = getFirstComponentOfType(globalApp!.project.selected!.getStage(.PreStage).getChildren(), globalApp!.currentSceneMode == .TwoD ? .Camera2D : .Camera3D)!

        var scaleFrag : CodeFragment? = nil

        for uuid in camera.properties {
            let rc = camera.getPropertyOfUUID(uuid)
            if let frag = rc.0 {
                if frag.name == "scale" {
                    scaleFrag = rc.1
                }
            }
        }
        
        if let frag = scaleFrag {
            if firstTouch == true {
                zoomBuffer = frag.values["value"]!
            }
            
            frag.values["value"]! = zoomBuffer / scale
            frag.values["value"]! = max(0.001, frag.values["value"]!)
            frag.values["value"]! = min(20, frag.values["value"]!)
            
            if let updateCB = customUpdateCB {
                updateCB()
            } else {
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
            }
        }
    }
    
    /// Updates the UI properties
    func updateUIProperties()
    {
        if customUpdateCB != nil {
            return
        }
        
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
        
        if let updateCB = customUpdateCB {
            updateCB()
        } else {
            globalApp!.currentEditor.updateOnNextDraw(compile: false)
        }
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
        
        if let updateCB = customUpdateCB {
            updateCB()
        } else {
            globalApp!.currentEditor.updateOnNextDraw(compile: false)
        }
    }

    /// Update the hover state fo
     func updateHoverState(_ event: MMMouseEvent)
     {
         hoverState = .Inactive
         
        let scale : Float = getCameraPropertyValue("scale", defaultValue: 1)

        var properties : [String:Float] = [:]
        properties["_posX"] = (component.values["_posX"]! + getHierarchyValue(component, "_posX")) / scale
        properties["_posY"] = (component.values["_posY"]! + getHierarchyValue(component, "_posY")) / scale

        let timeline = globalApp!.artistEditor.timeline
        let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
        
        gizmoCenter = convertToScreenSpace(x: transformed["_posX"]!, y: -transformed["_posY"]!)
        
        //gizmoCenter = convertToScreenSpace(x: posX, y: posY)

        let gizmoRect : MMRect =  MMRect()
         
        gizmoRect.x = gizmoCenter.x - width / 2
        gizmoRect.y = gizmoCenter.y - height / 2
        gizmoRect.width = width
        gizmoRect.height = height

        if gizmoRect.contains( event.x, event.y ) {
         
            func sdTriangleIsosceles(_ uv : SIMD2<Float>, q : SIMD2<Float>) -> Float
            {
                var p : SIMD2<Float> = uv
                p.x = abs(p.x)
                 
                let a : SIMD2<Float> = p - q * simd_clamp( dot(p,q)/dot(q,q), 0.0, 1.0 )
                let b : SIMD2<Float> = p - q*SIMD2<Float>( simd_clamp( p.x/q.x, 0.0, 1.0 ), 1.0 )
                let s : Float = -sign( q.y )
                let d : SIMD2<Float> = min( SIMD2<Float>( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                                 SIMD2<Float>( dot(b,b), s*(p.y-q.y)  ));
                 
                return -sqrt(d.x)*sign(d.y);
            }
             
            func rotateCW(_ pos : SIMD2<Float>, angle: Float) -> SIMD2<Float>
            {
                let ca : Float = cos(angle), sa = sin(angle)
                return pos * float2x2(SIMD2<Float>(ca, -sa), SIMD2<Float>(sa, ca))
            }
             
            let x = event.x - gizmoRect.x
            let y = event.y - gizmoRect.y
             
            var center = simd_float2(x:x, y:y)
            center = center - simd_float2(x:width/2, y: height/2)
             
            var uv = center
            var dist = simd_length( uv ) - 15
             
            if dist < 4 {
                hoverState = .CenterMove
                return
            }
             
            // Right Arrow - Move
            uv -= SIMD2<Float>(75,0);
            var d : SIMD2<Float> = simd_abs( uv ) - SIMD2<Float>( 18, 3)
            dist = simd_length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0);
            uv = center - SIMD2<Float>(110,0);
            uv = rotateCW(uv, angle: 1.5708 );
            dist = min( dist, sdTriangleIsosceles(uv, q: SIMD2<Float>(10,-20)))
             
            if dist < 4 {
                hoverState = .xAxisMove
                return
            }
             
            // Right Arrow - Scale
            uv = center - SIMD2<Float>(25,0);
            d = simd_abs( uv ) - SIMD2<Float>( 25, 3)
            dist = simd_length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0);
             
            uv = center - SIMD2<Float>(50,0.4);
            d = simd_abs( uv ) - SIMD2<Float>( 8, 7)
            dist = min( dist, length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0) );
             
            if dist < 4 {
                hoverState = .xAxisScale
                return
            }
             
            // Up Arrow - Move
            uv = center + SIMD2<Float>(0,75);
            d = simd_abs( uv ) - SIMD2<Float>( 3, 18)
            dist = simd_length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0);
            uv = center + SIMD2<Float>(0,110);
            dist = min( dist, sdTriangleIsosceles(uv, q: SIMD2<Float>(10,20)))
             
            if dist < 4 {
                hoverState = .yAxisMove
                return
            }
             
            // Up Arrow - Scale
            uv = center + SIMD2<Float>(0,25);
            d = simd_abs( uv ) - SIMD2<Float>( 3, 25)
            dist = simd_length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0);

            uv = center + SIMD2<Float>(0.4,50);
            d = simd_abs( uv ) - SIMD2<Float>( 7, 8)
            dist = min( dist, length(max(d,SIMD2<Float>(repeating: 0))) + min(max(d.x,d.y),0.0) );
             
            if dist < 4 {
                hoverState = .yAxisScale
                return
            }
             
            // Rotate
            dist = simd_length( center ) - 73
            let ringSize : Float = 10//6
             
            let border = simd_clamp(dist + ringSize, 0.0, 1.0) - simd_clamp(dist, 0.0, 1.0)
            if ( border > 0.0 ) {
                hoverState = .Rotate
                return
            }
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        // --- Render Gizmo
        
        let data: [Float] = [
            width, height,
            hoverState.rawValue, 0
        ];
        
        mmView.renderer.setClipRect(rect)
        
        let scale : Float = getCameraPropertyValue("scale", defaultValue: 1)

        var properties : [String:Float] = [:]
        properties["_posX"] = (component.values["_posX"]! + getHierarchyValue(component, "_posX")) / scale
        properties["_posY"] = (component.values["_posY"]! + getHierarchyValue(component, "_posY")) / scale

        let timeline = globalApp!.artistEditor.timeline
        let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
        
        let screenSpace = convertToScreenSpace(x: transformed["_posX"]!, y: -transformed["_posY"]!)
        
        let mmRenderer = mmView.renderer!
        let renderEncoder = mmRenderer.renderEncoder!

        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( screenSpace.x - width / 2, screenSpace.y - height / 2, width, height, scale: mmView.scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState(state!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        mmView.renderer.setClipRect()
    }
    
    /// Converts the coordinate from scene space to screen space
    func convertToScreenSpace(x: Float, y: Float) -> SIMD2<Float>
    {
        var result : SIMD2<Float> = SIMD2<Float>()
                
        result.x = x - getCameraPropertyValue("cameraX") + 0.5
        result.y = y + getCameraPropertyValue("cameraY") + 0.5
        
        result.x += rect.width/2
        result.y += rect.width/2 * rect.height / rect.width
        
        result.x += rect.x
        result.y += rect.y
        
        return result
    }
    
    /// Converts the coordinate from screen space to scene space
    func convertToSceneSpace(x: Float, y: Float) -> SIMD2<Float>
    {
        var result : SIMD2<Float> = SIMD2<Float>()
        
        result.x = x - rect.x
        result.y = y - rect.y
        
        // --- Center
        result.x -= rect.width / 2 - getCameraPropertyValue("cameraX")
        result.y += getCameraPropertyValue("cameraY")
        result.y -= rect.width / 2 * rect.height / rect.width
        
        return result
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
}
