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
    enum GizmoMode {
        case Normal, Point
    }
    
    enum GizmoState : Float {
        case Inactive, CenterMove, xAxisMove, yAxisMove, Rotate, xAxisScale, yAxisScale, xyAxisScale
    }
    
    var mode            : GizmoMode = .Normal
    
    var hoverState      : GizmoState = .Inactive
    var dragState       : GizmoState = .Inactive

    let layerManager    : LayerManager
    
    var normalState     : MTLRenderPipelineState!
    var pointState      : MTLRenderPipelineState!

    let width           : Float
    let height          : Float
    
    var object          : Object?
    
    var dragStartOffset : float2?
    var gizmoCenter     : float2 = float2()
    
    var startRotate     : Float = 0
    
    var initialValues   : [UUID:[String:Float]] = [:]
    
    // --- For the point based gizmo
    
    var pointShape      : Shape? = nil
    var pointIndex      : Int = 0

    required init( _ view : MMView, layerManager: LayerManager )
    {
        var function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmo" )
        normalState = view.renderer.createNewPipelineState( function! )
        function = view.renderer.defaultLibrary.makeFunction( name: "drawPointGizmo" )
        pointState = view.renderer.createNewPipelineState( function! )
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
        if mode == .Normal {
            updateNormalHoverState(editorRect: rect, event: event)
        } else {
            updatePointHoverState(editorRect: rect, event: event)
        }
//        #endif
        
        if hoverState == .Inactive && object != nil {
            // --- Check if a point was clicked (including the center point for the normal gizmo)
            
            pointShape = nil
            
            let attributes = getCurrentGizmoAttributes()
            let posX : Float = attributes["posX"]!
            let posY : Float = attributes["posY"]!
            
            // --- Points
            let selectedShapes = object!.getSelectedShapes()
            if selectedShapes.count == 1 {
                for shape in selectedShapes {
                    
                    for index in 0..<shape.pointCount {
                        
                        let pX = posX + attributes["point_\(index)_x"]!
                        let pY = posY + attributes["point_\(index)_y"]!
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        let radius : Float = 10
                        #if os(OSX)
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(mmView.mousePos.x, mmView.mousePos.y) {
                            pointShape = shape
                            pointIndex = index
                            mode = .Point
                            hoverState = .CenterMove
                        }
                        #endif
                    }
                }
            }
        }
        
        // --- Gizmo Action
        if hoverState != .Inactive {
            mmView.mouseTrackWidget = self
            dragState = hoverState
            mmView.lockFramerate()
            
            dragStartOffset = convertToSceneSpace(x: event.x, y: event.y)
            startRotate = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)

            initialValues = [:]
            
            if mode == .Normal {
                for shape in object!.getSelectedShapes() {
                    let transformed = getTransformedProperties(shape)
                    
                    initialValues[shape.uuid] = [:]
                    initialValues[shape.uuid]!["posX"] = transformed["posX"]!
                    initialValues[shape.uuid]!["posY"] = transformed["posY"]!
                    initialValues[shape.uuid]!["rotate"] = transformed["rotate"]!
                    
                    initialValues[shape.uuid]![shape.widthProperty] = transformed[shape.widthProperty]!
                    initialValues[shape.uuid]![shape.heightProperty] = transformed[shape.heightProperty]!
                }
            } else {
                // Save the point position
                let shape = pointShape!
                
                let transformed = getTransformedProperties(shape)
                
                initialValues[shape.uuid] = [:]
                initialValues[shape.uuid]!["posX"] = transformed["point_\(pointIndex)_x"]!
                initialValues[shape.uuid]!["posY"] = transformed["point_\(pointIndex)_y"]!
            }
        }
        
        // --- If no point selected switch to normal mode
        if mode == .Point && pointShape == nil {
            mode = .Normal
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
            if mode == .Normal {
                updateNormalHoverState(editorRect: rect, event: event)
            } else {
                updatePointHoverState(editorRect: rect, event: event)
            }
        } else {
            let pos = convertToSceneSpace(x: event.x, y: event.y)
            let selectedShapeObjects = object!.getSelectedShapes()
            layerManager.app!.editorRegion?.result = nil

            if dragState == .CenterMove {
                if mode == .Normal {
                    for shape in selectedShapeObjects {
                        let properties : [String:Float] = [
                            "posX" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x),
                            "posY" : initialValues[shape.uuid]!["posY"]! + (pos.y - dragStartOffset!.y),
                        ]
                        processGizmoProperties(properties, shape: shape)
                    }
                } else {
                    let shape = pointShape!
                    let properties : [String:Float] = [
                        "point_\(pointIndex)_x" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x),
                        "point_\(pointIndex)_y" : initialValues[shape.uuid]!["posY"]! + (pos.y - dragStartOffset!.y),
                        ]
                    processGizmoProperties(properties, shape: shape)
                }
            } else
            if dragState == .xAxisMove {
                if mode == .Normal {
                    for shape in selectedShapeObjects {
                        let properties : [String:Float] = [
                            "posX" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x),
                            ]
                        processGizmoProperties(properties, shape: shape)
                    }
                } else {
                    let shape = pointShape!
                    let properties : [String:Float] = [
                        "point_\(pointIndex)_x" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x),
                        ]
                    processGizmoProperties(properties, shape: shape)
                }
            } else
            if dragState == .yAxisMove {
                if  mode == .Normal {
                    for shape in selectedShapeObjects {
                        let properties : [String:Float] = [
                            "posY" : initialValues[shape.uuid]!["posY"]! + (pos.y - dragStartOffset!.y),
                            ]
                        processGizmoProperties(properties, shape: shape)
                    }
                } else {
                    let shape = pointShape!
                    let properties : [String:Float] = [
                        "point_\(pointIndex)_y" : initialValues[shape.uuid]!["posY"]! + (pos.y - dragStartOffset!.y),
                        ]
                    processGizmoProperties(properties, shape: shape)
                }
            } else
            if dragState == .xAxisScale {
                for shape in selectedShapeObjects {
                    let propName : String = shape.widthProperty
                    let properties : [String:Float] = [
                        propName : initialValues[shape.uuid]![propName]! + (pos.x - dragStartOffset!.x),
                        ]
                    processGizmoProperties(properties, shape: shape)
                }
            } else
            if dragState == .yAxisScale {
                for shape in selectedShapeObjects {
                    let propName : String = shape.heightProperty
                    let properties : [String:Float] = [
                        propName : initialValues[shape.uuid]![propName]! - (pos.y - dragStartOffset!.y),
                        ]
                    processGizmoProperties(properties, shape: shape)
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
        
        var data: [Float] = [
            width, height,
            hoverState.rawValue, 0
        ];
        
        var attributes = getCurrentGizmoAttributes()
        let posX : Float = attributes["posX"]!
        let posY : Float = attributes["posY"]!
        
        var screenSpace = convertToScreenSpace(x: posX, y: posY )

        mmRenderer.setClipRect(editorRect)

        let renderEncoder = mmRenderer.renderEncoder!
        if mode == .Normal {
            // --- Points
            let selectedShapes = object!.getSelectedShapes()
            if selectedShapes.count == 1 {
                // Points only get drawn when only one shape is selected
                for shape in selectedShapes {
                    for index in 0..<shape.pointCount {
                        
                        let pX = posX + attributes["point_\(index)_x"]!
                        let pY = posY + attributes["point_\(index)_y"]!

                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)

                        var pFillColor = float4(1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        #if os(OSX)
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(mmView.mousePos.x, mmView.mousePos.y) {
                            let temp = pBorderColor
                            pBorderColor = pFillColor
                            pFillColor = temp
                        }
                        #endif

                        mmView.drawSphere.draw(x: pointInScreen.x - radius, y: pointInScreen.y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
                    }
                    
                    // --- Correct the gizmo position to be between the first two points
                    if shape.pointCount >= 2 {
                        let offX : Float = (attributes["point_0_x"]! + attributes["point_1_x"]!) / 2
                        let offY : Float = (attributes["point_0_y"]! + attributes["point_1_y"]!) / 2
                        let pX = posX + offX
                        let pY = posY + offY
                        screenSpace = convertToScreenSpace(x: pX, y: pY )
                    
                        attributes["sizeMinX"]! += offX
                        attributes["sizeMinY"]! += offY
                        attributes["sizeMaxX"]! += offX
                        attributes["sizeMaxY"]! += offY
                    }
                    
                    // --- Test if we have to hover highlight both scale axes
                    if selectedShapes.count == 1 && (hoverState == .xAxisScale || hoverState == .yAxisScale) {
                        if shape.widthProperty == shape.heightProperty {
                            data[3] = 1
                        }
                    }
                }
            }
            
            // --- Render Bound Box
            
            let margin : Float = 50
            mmView.drawBox.draw(x: attributes["sizeMinX"]! - margin, y: attributes["sizeMinY"]! - margin, width: attributes["sizeMaxX"]! - attributes["sizeMinX"]! + 2*margin, height: attributes["sizeMaxY"]! - attributes["sizeMinY"]! + 2*margin, round: 0, borderSize: 2, fillColor: float4(0), borderColor: float4(0.5, 0.5, 0.5, 1))
            
            // --- Render Gizmo
            let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( screenSpace.x - width / 2, screenSpace.y - height / 2, width, height, scale: scaleFactor ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            
            renderEncoder.setRenderPipelineState(normalState!)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        } else {
            // Point Mode
            
            // --- Draw all other points
            
            // --- Points
            
            for shape in object!.getSelectedShapes() {
                
                for index in 0..<shape.pointCount {
                    
                    if shape === pointShape! && index == pointIndex {
                        continue
                    }
                    
                    let pX = posX + attributes["point_\(index)_x"]!
                    let pY = posY + attributes["point_\(index)_y"]!
                    
                    let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                    
                    var pFillColor = float4(1)
                    var pBorderColor = float4( 0, 0, 0, 1)
                    let radius : Float = 10
                    #if os(OSX)
                    let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                    if rect.contains(mmView.mousePos.x, mmView.mousePos.y) {
                        let temp = pBorderColor
                        pBorderColor = pFillColor
                        pFillColor = temp
                    }
                    #endif
                    
                    mmView.drawSphere.draw(x: pointInScreen.x - radius, y: pointInScreen.y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
                }
            }
            
            let pX = posX + attributes["point_\(pointIndex)_x"]!
            let pY = posY + attributes["point_\(pointIndex)_y"]!
            
            screenSpace = convertToScreenSpace(x: pX, y: pY)
            
            // --- Render Gizmo
            let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( screenSpace.x - width / 2, screenSpace.y - height / 2, width, height, scale: scaleFactor ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            
            renderEncoder.setRenderPipelineState(pointState)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        
        mmRenderer.setClipRect()
    }
    
    /// Update the hover state for the normal gizmo
    func updateNormalHoverState(editorRect: MMRect, event: MMMouseEvent)
    {
        hoverState = .Inactive
        if object == nil { return }

        let attributes = getCurrentGizmoAttributes()
        var posX : Float = attributes["posX"]!
        var posY : Float = attributes["posY"]!
        
        let selectedShapes = object!.getSelectedShapes()
        if selectedShapes.count == 1 {
            for shape in selectedShapes {
                // --- Correct the gizmo position to be between the first two points
                if shape.pointCount >= 2 {
                    posX += (attributes["point_0_x"]! + attributes["point_1_x"]!) / 2
                    posY += (attributes["point_0_y"]! + attributes["point_1_y"]!) / 2
                }
            }
        }
        
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
            
            // Right Arrow - Move
            uv -= float2(75,0);
            var d : float2 = simd_abs( uv ) - float2( 18, 3)
            dist = simd_length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            uv = center - float2(110,0);
            uv = rotateCW(uv, angle: 1.5708 );
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,-20)))
            
            if dist < 0 {
                hoverState = .xAxisMove
                return
            }
            
            // Right Arrow - Scale
            uv = center - float2(25,0);
            d = simd_abs( uv ) - float2( 25, 3)
            dist = simd_length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            
            uv = center - float2(50,0.4);
            d = simd_abs( uv ) - float2( 8, 7)
            dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) );
            
            if dist < 0 {
                hoverState = .xAxisScale
                return
            }
            
            // Up Arrow - Move
            uv = center + float2(0,75);
            d = simd_abs( uv ) - float2( 3, 18)
            dist = simd_length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            uv = center + float2(0,110);
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,20)))
            
            if dist < 0 {
                hoverState = .yAxisMove
                return
            }
            
            // Up Arrow - Scale
            uv = center + float2(0,25);
            d = simd_abs( uv ) - float2( 3, 25)
            dist = simd_length(max(d,float2(0))) + min(max(d.x,d.y),0.0);

            uv = center + float2(0.4,50);
            d = simd_abs( uv ) - float2( 7, 8)
            dist = min( dist, length(max(d,float2(0))) + min(max(d.x,d.y),0.0) );
            
            if dist < 0 {
                hoverState = .yAxisScale
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
    
    /// Update the hover state for the point gizmo
    func updatePointHoverState(editorRect: MMRect, event: MMMouseEvent)
    {
        hoverState = .Inactive
        if object == nil { return }
        
        let attributes = getCurrentGizmoAttributes()
        let posX : Float = attributes["posX"]! + attributes["point_\(pointIndex)_x"]!
        let posY : Float = attributes["posY"]! + attributes["point_\(pointIndex)_y"]!
        
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
            
            // Right Arrow - Move
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
            
            // Up Arrow - Move
            uv = center + float2(0,50);
            d = simd_abs( uv ) - float2( 3, 50)
            dist = simd_length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            uv = center + float2(0,110);
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,20)))
            
            if dist < 0 {
                hoverState = .yAxisMove
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
                attributes["rotate"]! += rotate
                
                if selectedShapeObjects.count == 1 {
                    if shape.pointCount == 1 {
                        attributes["point_0_x"] = transformed["point_0_x"]
                        attributes["point_0_y"] = transformed["point_0_y"]
                    } else
                    if shape.pointCount == 2 {
                        attributes["point_0_x"] = transformed["point_0_x"]
                        attributes["point_0_y"] = transformed["point_0_y"]
                        attributes["point_1_x"] = transformed["point_1_x"]
                        attributes["point_1_y"] = transformed["point_1_y"]
                    } else
                    if shape.pointCount == 3 {
                        attributes["point_0_x"] = transformed["point_0_x"]
                        attributes["point_0_y"] = transformed["point_0_y"]
                        attributes["point_1_x"] = transformed["point_1_x"]
                        attributes["point_1_y"] = transformed["point_1_y"]
                        attributes["point_2_x"] = transformed["point_2_x"]
                        attributes["point_2_y"] = transformed["point_2_y"]
                    }
                }
            }
            
            attributes["posX"]! /= Float(selectedShapeObjects.count)
            attributes["posY"]! /= Float(selectedShapeObjects.count)
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
