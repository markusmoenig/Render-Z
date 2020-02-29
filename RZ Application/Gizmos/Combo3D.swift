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
    
    var camera3D            : Camera3D = Camera3D()
    var mouseIsDown         : Bool = false
    
    override init(_ view: MMView)
    {
        let function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmoCombo3D" )
        state = view.renderer.createNewPipelineState( function! )
       
        compute = MMCompute()
        idState = compute.createState(name: "idsGizmoCombo3D")
        cameraState = compute.createState(name: "cameraGizmoCombo3D")

        super.init(view)
    }
    
    override func setComponent(_ comp: CodeComponent)
    {
        component = comp

        // Show the supported transform values
        let designEditor = globalApp!.artistEditor.designEditor
        let designProperties = globalApp!.artistEditor.designProperties

        if let tNode = designProperties.c2Node, component.componentType != .Dummy {
            
            let xVar = NodeUINumber(tNode, variable: "_posX", title: "X", range: SIMD2<Float>(-1000, 1000), value: comp.values["_posX"]!, precision: 3)
            let yVar = NodeUINumber(tNode, variable: "_posY", title: "Y", range: SIMD2<Float>(-1000, 1000), value: comp.values["_posY"]!, precision: 3)
            let zVar = NodeUINumber(tNode, variable: "_posZ", title: "Z", range: SIMD2<Float>(-1000, 1000), value: comp.values["_posZ"]!, precision: 3)
            //let rotateVar = NodeUINumber(tNode, variable: "_rotateX", title: "Rotate", range: SIMD2<Float>(0, 360), value: comp.values["_rotateX"]!, precision: 1)
            tNode.uiItems.append(xVar)
            tNode.uiItems.append(yVar)
            tNode.uiItems.append(zVar)

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
            startRotate = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
            
            scaleXFragmentName = nil
            scaleYFragmentName = nil
            scaleZFragmentName = nil
            scaleXFragment = nil
            scaleYFragment = nil
            scaleZFragment = nil

            // Get the scale gizmo mapping for the properties
            for prop in component.properties {
                if let gizmoMap = component.propertyGizmoMap[prop] {
                    if gizmoMap != .None {
                        let rc = component.getPropertyOfUUID(prop)
                        if let frag = rc.0, rc.1 != nil {
                            if gizmoMap == .AllScale || gizmoMap == .XScale {
                                scaleXFragmentName = frag.name
                                scaleXFragment = rc.1!
                                initialValues["_scaleX"] = rc.1!.values["value"]!
                            } else
                            if gizmoMap == .AllScale || gizmoMap == .YScale {
                                scaleYFragmentName = frag.name
                                scaleYFragment = rc.1!
                                initialValues["_scaleY"] = rc.1!.values["value"]!
                            } else
                            if gizmoMap == .AllScale || gizmoMap == .ZScale {
                                scaleZFragmentName = frag.name
                                scaleZFragment = rc.1!
                                initialValues["_scaleZ"] = rc.1!.values["value"]!
                            }
                        }
                    }
                }
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

            var properties : [String:Float] = [:]
            properties["_posX"] = (component.values["_posX"]! + getHierarchyValue(component, "_posX"))
            properties["_posY"] = (component.values["_posY"]! + getHierarchyValue(component, "_posY"))
            properties["_posZ"] = (component.values["_posZ"]! + getHierarchyValue(component, "_posZ"))

            let timeline = globalApp!.artistEditor.timeline
            let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
            
            // --- Render Gizmo
            let data: [Float] = [
                rect.width, rect.height,
                hoverState.rawValue, 0,
                origin.x, origin.y, origin.z, fov,
                lookAt.x, lookAt.y, lookAt.z, 0,
                transformed["_posX"]!, -transformed["_posY"]!, transformed["_posZ"]!, 0
            ];
                        
            let buffer = compute.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
            
            compute.run(idState, outTexture: compute.texture, inBuffer: buffer, syncronize: true)
                        
            let region = MTLRegionMake2D(min(Int(event.x - rect.x), compute.texture!.width-1), min(Int(rect.height - (event.y - rect.y)), compute.texture!.height-1), 1, 1)

            let texArray = Array<Float>(repeating: Float(0), count: 1)
            compute.texture!.getBytes(UnsafeMutableRawPointer(mutating: texArray), bytesPerRow: (MemoryLayout<Float>.size * compute.texture!.width), from: region, mipmapLevel: 0)
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
                let angle = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
                var value = initialValues["_rotateX"]! + ((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                if value < 0 {
                    value = 360 + value
                }
                let properties : [String:Float] = [
                    "_rotateX" : value
                ]
                processGizmoProperties(properties)
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
                undoComponent = globalApp!.currentEditor.undoComponentStart("Gizmo Action")
            }
            
            updateUIProperties()
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if component.componentType == .Dummy { return }

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
    }
    
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

        let origin = getCameraPropertyValue3("origin")
        let lookAt = getCameraPropertyValue3("lookAt")
        let fov = getCameraPropertyValue("fov")

        var properties : [String:Float] = [:]
        properties["_posX"] = (component.values["_posX"]! + getHierarchyValue(component, "_posX"))
        properties["_posY"] = (component.values["_posY"]! + getHierarchyValue(component, "_posY"))
        properties["_posZ"] = (component.values["_posZ"]! + getHierarchyValue(component, "_posZ"))

        let timeline = globalApp!.artistEditor.timeline
        let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
        
        // --- Render Gizmo
        let data: [Float] = [
            rect.width, rect.height,
            hoverState.rawValue, 0,
            origin.x, origin.y, origin.z, fov,
            lookAt.x, lookAt.y, lookAt.z, 0,
            transformed["_posX"]!, -transformed["_posY"]!, transformed["_posZ"]!, 0
        ];
                
        gizmoDistance = simd_distance(origin, SIMD3<Float>(transformed["_posX"]!, -transformed["_posY"]!, transformed["_posZ"]!))
        mmView.renderer.setClipRect(rect)

        let mmRenderer = mmView.renderer!
        let renderEncoder = mmRenderer.renderEncoder!

        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( rect.x, rect.y, rect.width, rect.height, scale: mmView.scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState(state!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        mmView.renderer.setClipRect()
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