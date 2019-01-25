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
        case Inactive, CenterMove
    }
    
    var hoverState      : GizmoMode = .Inactive
    var dragState       : GizmoMode = .Inactive

    let layerManager    : LayerManager
    
    var state           : MTLRenderPipelineState!
    
    let width           : Float
    let height          : Float
    
    var object          : Object?
    var shape           : Shape?
    
    var dragStartOffset : float2?

    required init( _ view : MMView, layerManager: LayerManager )
    {
        let function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmo" )
        state = view.renderer.createNewPipelineState( function! )
        self.layerManager = layerManager
        
        width = 40
        height = 40
        
        super.init(view)
    }
    
    func setObject(_ object:Object?)
    {
        self.object = object
        
        if object != nil {
            shape = object!.getCurrentShape()
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS) || os(watchOS) || os(tvOS)
            updateHoverState(editorRect: rect, event: event)
        #endif
        
        if hoverState != .Inactive {
            mmView.mouseTrackWidget = self
            dragState = hoverState
            mmView.lockFramerate()
            
            dragStartOffset = convertToSceneSpace(x: event.x, y: event.y)
            
            dragStartOffset!.x -= shape!.properties["posX"]!
            dragStartOffset!.y -= shape!.properties["posY"]!
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
        } else
        if dragState == .CenterMove {
            
            let pos = convertToSceneSpace(x: event.x, y: event.y)
            
            shape!.properties["posX"] = pos.x - dragStartOffset!.x
            shape!.properties["posY"] = pos.y - dragStartOffset!.y
            
            layerManager.getCurrentLayer().updateShape(shape!)
            layerManager.app!.editorRegion?.result = nil
        }
    }
    
    override func draw()
    {
        if object == nil || shape == nil { hoverState = .Inactive; return }
        
        let editorRect = rect
        
        let mmRenderer = mmView.renderer!
        
        let scaleFactor : Float = mmView.scaleFactor
        
        let data: [Float] = [
            width, height,
            hoverState.rawValue, 0
        ];
        
        let screenSpace = convertToScreenSpace(x: (shape?.properties["posX"])!, y: (shape?.properties["posY"])! )
        
        mmRenderer.setClipRect(editorRect)
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
        if object == nil || shape == nil { return }

        let screenSpace = convertToScreenSpace(x: (shape?.properties["posX"])!, y: (shape?.properties["posY"])! )

        let gizmoRect : MMRect =  MMRect()
        
        gizmoRect.x = screenSpace.x - width / 2
        gizmoRect.y = screenSpace.y - height / 2
        gizmoRect.width = width
        gizmoRect.height = height
        
        if gizmoRect.contains( event.x, event.y ) {
            
            let x = event.x - gizmoRect.x
            let y = event.y - gizmoRect.y
            
            var center = simd_float2(x:x, y:y)
            center = center - simd_float2(x:width/2, y: height/2)
            
            let uv = center
            let dist = simd_length( uv ) - 15
            
            if dist < 0 {
                hoverState = .CenterMove
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
}
