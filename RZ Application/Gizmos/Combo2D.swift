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

    override init(_ view: MMView)
    {
        let function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmoCombo2D" )
        state = view.renderer.createNewPipelineState( function! )
        
        super.init(view)
    }
    
    override func setComponent(_ comp: CodeComponent)
    {
        component = comp
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
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
                if let gizmoMap = component.propertyGizmoMap[prop] {
                    if gizmoMap != .None {
                        let rc = component.getPropertyOfUUID(prop)
                        if let frag = rc.0, rc.1 != nil {
                            if gizmoMap == .AllScale || gizmoMap == .XScale {
                                scaleXFragmentName = frag.name
                                scaleXFragment = rc.1!
                                initialValues["_scaleX"] = rc.1!.values["value"]!
                            }
                            if gizmoMap == .AllScale || gizmoMap == .YScale {
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

            if dragState == .CenterMove {
                let properties : [String:Float] = [
                    "_posX" : initialValues["_posX"]! + (pos.x - dragStartOffset!.x),
                    "_posY" : initialValues["_posY"]! - (pos.y - dragStartOffset!.y),
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .xAxisMove {
                let properties : [String:Float] = [
                    "_posX" : initialValues["_posX"]! + (pos.x - dragStartOffset!.x),
                ]
                processGizmoProperties(properties)
            } else
            if dragState == .yAxisMove {
                let properties : [String:Float] = [
                    "_posY" : initialValues["_posY"]! - (pos.y - dragStartOffset!.y),
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
                    processProperty(fragment, name: scaleXFragmentName!, value: max(initialValues["_scaleX"]! + (pos.x - dragStartOffset!.x), 0.001))
                }
            } else
            if dragState == .yAxisScale {
                if let fragment = scaleYFragment {
                    processProperty(fragment, name: scaleYFragmentName!, value: max(initialValues["_scaleY"]! - (pos.y - dragStartOffset!.y), 0.001))
                }
            }
            
            if undoComponent == nil {
                undoComponent = globalApp!.currentEditor.undoStart("Gizmo Action")
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        dragState = .Inactive
        if undoComponent != nil {
            globalApp!.currentEditor.undoEnd(undoComponent!)
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

    /// Update the hover state fo
     func updateHoverState(_ event: MMMouseEvent)
     {
         hoverState = .Inactive

         // --- Core Gizmo
         //let attributes = getCurrentGizmoAttributes()
        var posX : Float = component.values["_posX"]!
        var posY : Float = -component.values["_posY"]!
         
        gizmoCenter = convertToScreenSpace(x: posX, y: posY)

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
        
        let screenSpace = convertToScreenSpace(x: component.values["_posX"]!, y: -component.values["_posY"]!)
        
        let mmRenderer = mmView.renderer!
        let renderEncoder = mmRenderer.renderEncoder!

        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( screenSpace.x - width / 2, screenSpace.y - height / 2, width, height, scale: mmView.scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState(state!)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    /// Converts the coordinate from scene space to screen space
    func convertToScreenSpace(x: Float, y: Float) -> SIMD2<Float>
    {
        var result : SIMD2<Float> = SIMD2<Float>()
        
        //let camera = maxDelegate!.getCamera()!
        
        result.x = (x - /*camera.xPos*/ 0.0 + 0.5)// / 700 * rect.width
        result.y = (y - /*camera.yPos*/ 0.0 + 0.5)// / 700 * rect.width
        
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
        
        result.x = (x - rect.x)// * 700 / rect.width
        result.y = (y - rect.y)// * 700 / rect.width
        
        //let camera = maxDelegate!.getCamera()!

        // --- Center
        result.x -= rect.width / 2 - 0.0//camera.xPos
        result.y += 0.0//camera.yPos
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
