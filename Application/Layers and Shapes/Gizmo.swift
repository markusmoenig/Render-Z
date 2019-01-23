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
class Gizmo
{
    enum GizmoMode : Float {
        case Inactive, CenterMoveHover
    }
    
    var hoverState      : GizmoMode = .Inactive
    
    let layerManager    : LayerManager
    let mmView          : MMView
    
    var state           : MTLRenderPipelineState!
    
    let width           : Float
    let height          : Float
    
    var object          : Object?
    var shape           : Shape?

    required init( _ view : MMView, layerManager: LayerManager )
    {
        let function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmo" )
        state = view.renderer.createNewPipelineState( function! )
        mmView = view
        self.layerManager = layerManager
        
        width = 40
        height = 40
    }
    
    func setObject(_ object:Object?)
    {
        self.object = object
        
        if object != nil {
            shape = object!.getCurrentShape()
        }
    }
    
    func draw(editorRect: MMRect)
    {
        if object == nil || shape == nil { hoverState = .Inactive; return }
        
        let mmRenderer = mmView.renderer!
        
        let scaleFactor : Float = mmView.scaleFactor
        
        let data: [Float] = [
            width, height,
            hoverState.rawValue, 0
        ];
        
        let x : Float = editorRect.x + editorRect.width / 2 + (shape?.properties["posX"])! - layerManager.camera[0]
        let y : Float = editorRect.y + editorRect.height / 2 + (shape?.properties["posY"])! - layerManager.camera[1]
        
        mmRenderer.setClipRect(editorRect)
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( x - width / 2, y - height / 2, width, height, scale: scaleFactor ) )
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
        if object == nil || shape == nil { return }

        let rect : MMRect =  MMRect()
        
        rect.x = editorRect.x + editorRect.width / 2 + (shape?.properties["posX"])! - layerManager.camera[0] - width / 2
        rect.y = editorRect.y + editorRect.height / 2 + (shape?.properties["posY"])! - layerManager.camera[1] - height / 2
        rect.width = width
        rect.height = height
        
//        print( event.x, event.y, rect.x, rect.y )
        
        if rect.contains( event.x, event.y ) {
            
            let x = event.x - rect.x
            let y = event.y - rect.y
            
            var center = simd_float2(x:x, y:y)
            center = center - simd_float2(x:width/2, y: height/2)
            
            let uv = center
            let dist = simd_length( uv ) - 15
            
            if dist < 0 {
                hoverState = .CenterMoveHover
                return
            }
        }
        
//        float2 uv = in.textureCoordinate * data->size;
//        uv -= float2( data->size / 2 );
        
//        float dist = length( uv ) - 15;
        

    }
}
