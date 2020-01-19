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
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        let oldState = hoverState
        updateHoverState(event)
        if oldState != hoverState {
            mmView.update()
        }
    }
    
    /// Update the hover state fo
     func updateHoverState(_ event: MMMouseEvent)
     {
         hoverState = .Inactive

         // --- Core Gizmo
         //let attributes = getCurrentGizmoAttributes()
        var posX : Float = component.values["_posX"]!
        var posY : Float = component.values["_posY"]!
         
        /*
         if context == .ShapeEditor {
             if selectedShapes.count == 1 {
                 
                 for shape in selectedShapes {
                     
                     // --- Check for point hover
                     for index in 0..<shape.pointCount {
                         
                         var pX = posX + attributes["point_\(index)_x"]!
                         var pY = posY + attributes["point_\(index)_y"]!
                         
                         let ptConn = object!.getPointConnections(shape: shape, index: index)
                         
                         if ptConn.0 != nil {
                             // The point controls other point(s)
                             ptConn.0!.valueX = pX
                             ptConn.0!.valueY = pY
                         }
                         
                         if ptConn.1 != nil {
                             // The point is being controlled by another point
                             pX = ptConn.1!.valueX
                             pY = -ptConn.1!.valueY
                         }
                         
                         let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                         
                         var pFillColor = float4(repeating: 1)
                         var pBorderColor = float4( 0, 0, 0, 1)
                         let radius : Float = 10
                         let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                         if rect.contains(event.x, event.y) {
                             hoverState = .PointHover
                         }
                     }
                 }
                 
                 // Correct Gizmo position via points
                 for shape in selectedShapes {

                     if shape.pointCount > 0 {
                         var offX : Float = 0
                         var offY : Float = 0

                         for i in 0..<shape.pointCount {
                             offX += attributes["point_\(i)_x"]!
                             offY += attributes["point_\(i)_y"]!
                         }
                         offX /= Float(shape.pointCount)
                         offY /= Float(shape.pointCount)
                         
                         posX += offX
                         posY += offY
                     }
                 }
             }
         }*/
         
         let gizmoCenter = convertToScreenSpace(x: posX, y: posY)

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
        
        let screenSpace = convertToScreenSpace(x: component.values["_posX"]!, y: component.values["_posY"]!)
        
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
}
