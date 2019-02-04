//
//  Gizmo.swift
//  Shape-Z
//
//  Created by Markus Moenig on 23/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

/// Draws a sphere
class Gizmo : MMWidget
{
    enum GizmoMode : Float {
        case Inactive, CenterMove, xAxisMove, yAxisMove, Rotate
    }
    
    var hoverState      : GizmoMode = .Inactive
    var dragState       : GizmoMode = .Inactive

    let layerManager    : LayerManager
    
    var state           : MTLRenderPipelineState!
    
    let width           : Float
    let height          : Float
    
    var object          : Object?
    
    var dragStartOffset : float2?
    var gizmoCenter     : float2 = float2()
    
    var startRotate     : Float = 0
    
    var initialValues   : [UUID:[String:Float]] = [:]

    required init( _ view : MMView, layerManager: LayerManager )
    {
        let function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmo" )
        state = view.renderer.createNewPipelineState( function! )
        self.layerManager = layerManager
        
        width = 260
        height = 260
        
        super.init(view)
    }
    
    func setObject(_ object:Object?)
    {
        self.object = object
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
//        #if os(iOS) || os(watchOS) || os(tvOS)
            updateHoverState(editorRect: rect, event: event)
//        #endif
        
        if hoverState != .Inactive {
            mmView.mouseTrackWidget = self
            dragState = hoverState
            mmView.lockFramerate()
            
            dragStartOffset = convertToSceneSpace(x: event.x, y: event.y)
            startRotate = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)

            initialValues = [:]
            for shape in object!.getSelectedShapes() {
                let transformed = getTransformedProperties(shape)
                
                initialValues[shape.uuid] = [:]
                initialValues[shape.uuid]!["posX"] = transformed["posX"]!
                initialValues[shape.uuid]!["posY"] = transformed["posY"]!
                initialValues[shape.uuid]!["rotate"] = transformed["rotate"]!
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if dragState != .Inactive {
            mmView.unlockFramerate()
        }
        mmView.mouseTrackWidget = nil
        hoverState = .Inactive
        dragState = .Inactive
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if dragState == .Inactive {
            updateHoverState(editorRect: rect, event: event)
        } else {
            let pos = convertToSceneSpace(x: event.x, y: event.y)
            let selectedShapeObjects = object!.getSelectedShapes()
            layerManager.app!.editorRegion?.result = nil

            if dragState == .CenterMove {
                for shape in selectedShapeObjects {
                    let properties : [String:Float] = [
                        "posX" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x),
                        "posY" : initialValues[shape.uuid]!["posY"]! + (pos.y - dragStartOffset!.y),
                    ]
                    processGizmoProperties(properties, shape: shape)
                    layerManager.getCurrentLayer().updateShape(shape)
                }
            } else
            if dragState == .xAxisMove {
                for shape in selectedShapeObjects {
                    let properties : [String:Float] = [
                        "posX" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x),
                        ]
                    processGizmoProperties(properties, shape: shape)
                    layerManager.getCurrentLayer().updateShape(shape)
                }
            } else
            if dragState == .yAxisMove {
                for shape in selectedShapeObjects {
                    let properties : [String:Float] = [
                        "posY" : initialValues[shape.uuid]!["posY"]! + (pos.y - dragStartOffset!.y),
                        ]
                    processGizmoProperties(properties, shape: shape)
                    layerManager.getCurrentLayer().updateShape(shape)
                }
            } else
            if dragState == .Rotate {
                let angle = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
                for shape in selectedShapeObjects {
                    let initialValue = initialValues[shape.uuid]!["rotate"]!
                    let properties : [String:Float] = [
                        "rotate" : initialValue + ((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                    ]
                    processGizmoProperties(properties, shape: shape)
                    layerManager.getCurrentLayer().updateShape(shape)
                }
            }
        }
    }
    
    /// Processes the new values for the properties of the given shape, either as a keyframe or a global change
    func processGizmoProperties(_ properties: [String:Float], shape: Shape)
    {
        if !isRecording() {
            
            for(name, value) in properties {
                shape.properties[name] = value
            }
            
        } else {
            let timeline = layerManager.app!.bottomRegion!.timeline
            let uuid = shape.uuid//shape != nil ? shape!.uuid : object!.uuid
            timeline.addKeyProperties(sequence: layerManager.getCurrentLayer().sequence, uuid: uuid, properties: properties)
        }
    }
    
    override func draw()
    {
        if object == nil { hoverState = .Inactive; return }
        
        let editorRect = rect
        
        let mmRenderer = mmView.renderer!
        
        let scaleFactor : Float = mmView.scaleFactor
        
        let data: [Float] = [
            width, height,
            hoverState.rawValue, 0
        ];
        
        let attributes = getCurrentGizmoAttributes()
        let posX : Float = attributes["posX"]!
        let posY : Float = attributes["posY"]!
        
        let screenSpace = convertToScreenSpace(x: posX, y: posY )

        mmRenderer.setClipRect(editorRect)

        // --- Render Bound Box
        
        let margin : Float = 50
        mmView.drawBox.draw(x: attributes["sizeMinX"]! - margin, y: attributes["sizeMinY"]! - margin, width: attributes["sizeMaxX"]! - attributes["sizeMinX"]! + 2*margin, height: attributes["sizeMaxY"]! - attributes["sizeMinY"]! + 2*margin, round: 0, borderSize: 2, fillColor: float4(0), borderColor: float4(0.5, 0.5, 0.5, 1))
        
        // --- Render Gizmo
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( screenSpace.x - width / 2, screenSpace.y - height / 2, width, height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( state! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        mmRenderer.setClipRect()
    }
    
    func updateHoverState(editorRect: MMRect, event: MMMouseEvent)
    {
        hoverState = .Inactive
        if object == nil { return }

        let attributes = getCurrentGizmoAttributes()
        let posX : Float = attributes["posX"]!
        let posY : Float = attributes["posY"]!
        
        gizmoCenter = convertToScreenSpace(x: posX, y: posY)

        let gizmoRect : MMRect =  MMRect()
        
        gizmoRect.x = gizmoCenter.x - width / 2
        gizmoRect.y = gizmoCenter.y - height / 2
        gizmoRect.width = width
        gizmoRect.height = height
        
        if gizmoRect.contains( event.x, event.y ) {
        
            func sdTriangleIsosceles(_ uv : float2, q : float2) -> Float
            {
                var p : float2 = uv
                p.x = abs(p.x)
                
                let a : float2 = p - q * simd_clamp( dot(p,q)/dot(q,q), 0.0, 1.0 )
                let b : float2 = p - q*float2( simd_clamp( p.x/q.x, 0.0, 1.0 ), 1.0 )
                let s : Float = -sign( q.y )
                let d : float2 = min( float2( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                                float2( dot(b,b), s*(p.y-q.y)  ));
                
                return -sqrt(d.x)*sign(d.y);
            }
            
            func rotateCW(_ pos : float2, angle: Float) -> float2
            {
                let ca : Float = cos(angle), sa = sin(angle)
                return pos * float2x2(float2(ca, -sa), float2(sa, ca))
            }
            
            let x = event.x - gizmoRect.x
            let y = event.y - gizmoRect.y
            
            var center = simd_float2(x:x, y:y)
            center = center - simd_float2(x:width/2, y: height/2)
            
            var uv = center
            var dist = simd_length( uv ) - 15
            
            if dist < 0 {
                hoverState = .CenterMove
                return
            }
            
            // Right Arrow
            uv -= float2(50,0);
            var d : float2 = simd_abs( uv ) - float2( 50, 3)
            dist = simd_length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            uv = center - float2(110,0);
            uv = rotateCW(uv, angle: 1.5708 );
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,-20)))
            
            if dist < 0 {
                hoverState = .xAxisMove
                return
            }
            
            // Up Arrow
            uv = center + float2(0,50);
            d = simd_abs( uv ) - float2( 3, 50)
            dist = simd_length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            uv = center + float2(0,110);
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,20)))
            
            if dist < 0 {
                hoverState = .yAxisMove
                return
            }
            
            // Rotate
            
            dist = simd_length( center ) - 73
            let ringSize : Float = 6
            
            let border = simd_clamp(dist + ringSize, 0.0, 1.0) - simd_clamp(dist, 0.0, 1.0)
            if ( border > 0.0 ) {
                hoverState = .Rotate
                return
            }
        }
    }
    
    /// Converts the coordinate from scene space to screen space
    func convertToScreenSpace(x: Float, y: Float) -> float2
    {
        var result : float2 = float2()
        
        result.x = (x - layerManager.camera[0] - 0.5) / 700 * rect.width
        result.y = (y - layerManager.camera[1] - 0.5) / 700 * rect.width
        
        result.x += rect.width/2
        result.y += rect.width/2 * rect.height / rect.width
        
        result.x += rect.x
        result.y += rect.y
        
        return result
    }
    
    /// Converts the coordinate from screen space to scene space
    func convertToSceneSpace(x: Float, y: Float) -> float2
    {
        var result : float2 = float2()
        
        result.x = (x - rect.x) * 700 / rect.width
        result.y = (y - rect.y) * 700 / rect.width
        
        // --- Center
        result.x -= 350 - layerManager.camera[0]
        result.y += layerManager.camera[1]
        result.y -= 350 * rect.height / rect.width
        
        return result
    }
    
    /// Returns true if the timeline is currently recording
    func isRecording() -> Bool
    {
        return layerManager.app!.bottomRegion!.timeline.isRecording
    }
    
    /// Get transformed properties
    func getTransformedProperties(_ shape: Shape) -> [String:Float]
    {
        let sequence = layerManager.getCurrentLayer().sequence
        let timeline = layerManager.app!.bottomRegion!.timeline
        let transformed = timeline.transformProperties(sequence:sequence, uuid: shape.uuid, properties:shape.properties)
        return transformed
    }
    
    /// Returns the angle between the start / end points
    func getAngle(cx : Float, cy : Float, ex : Float, ey : Float, degree : Bool ) -> Float
    {
        var a : Float = atan2(ey - cy, ex - cx);
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
    
    /// Gets the attributes of the current Gizmo, i.e. its position and possibly further info
    func getCurrentGizmoAttributes() -> [String:Float]
    {
        var attributes : [String:Float] = [:]

        attributes["posX"] = 0
        attributes["posY"] = 0
        attributes["scaleX"] = 0
        attributes["scaleY"] = 0
        attributes["rotate"] = 0

        var sizeMinX : Float = 10000
        var sizeMinY : Float = 10000

        var sizeMaxX : Float = -10000
        var sizeMaxY : Float = -10000
        
        let selectedShapeObjects = object!.getSelectedShapes()
        if !selectedShapeObjects.isEmpty {
            
            for shape in selectedShapeObjects {
                
                let transformed = getTransformedProperties(shape)
                
                let posX = transformed["posX"]!
                let posY = transformed["posY"]!
                let scaleX = transformed["scaleX"]!
                let scaleY = transformed["scaleY"]!
                let rotate = transformed["rotate"]!

                let size = shape.getCurrentSize(transformed)
                
                if posX - size.x / 2 < sizeMinX {
                    sizeMinX = posX - size.x / 2
                }
                if posY - size.y / 2 < sizeMinY {
                    sizeMinY = posY - size.y / 2
                }
                if posX + size.x / 2 > sizeMaxX {
                    sizeMaxX = posX + size.x / 2
                }
                if posY + size.y / 2 > sizeMaxY {
                    sizeMaxY = posY + size.y / 2
                }

                attributes["posX"]! += posX
                attributes["posY"]! += posY
                attributes["scaleX"]! += scaleX
                attributes["scaleY"]! += scaleY
                attributes["rotate"]! += rotate
            }
            
            attributes["posX"]! /= Float(selectedShapeObjects.count)
            attributes["posY"]! /= Float(selectedShapeObjects.count)
            attributes["scaleX"]! /= Float(selectedShapeObjects.count)
            attributes["scaleY"]! /= Float(selectedShapeObjects.count)
            attributes["rotate"]! /= Float(selectedShapeObjects.count)
        }
        
        let minScreen = convertToScreenSpace(x: sizeMinX, y: sizeMinY)
        let maxScreen = convertToScreenSpace(x: sizeMaxX, y: sizeMaxY)
        
        attributes["sizeMinX"] = minScreen.x
        attributes["sizeMinY"] = minScreen.y
        attributes["sizeMaxX"] = maxScreen.x
        attributes["sizeMaxY"] = maxScreen.y

        return attributes
    }
}
