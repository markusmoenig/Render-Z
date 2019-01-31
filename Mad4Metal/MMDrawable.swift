//
//  MMDrawable.swift
//  Framework
//
//  Created by Markus Moenig on 04.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

protocol MMDrawable
{
//    static func size() -> Int
    
    var state : MTLRenderPipelineState! { get set }
    
    init( _ renderer : MMRenderer )
}

/// Draws a sphere
class MMDrawSphere : MMDrawable
{
    let mmRenderer : MMRenderer
    var state : MTLRenderPipelineState!

    required init( _ renderer : MMRenderer )
    {
        let function = renderer.defaultLibrary.makeFunction( name: "m4mSphereDrawable" )
        state = renderer.createNewPipelineState( function! )
        mmRenderer = renderer
    }
    
    func draw( x: Float, y: Float, radius: Float, borderSize: Float, fillColor: vector_float4, borderColor: vector_float4 )
    {
        let scaleFactor : Float = mmRenderer.mmView.scaleFactor
        let settings: [Float] = [
            fillColor.x, fillColor.y, fillColor.z, fillColor.w,
            borderColor.x, borderColor.y, borderColor.z, borderColor.w,
            radius * scaleFactor, borderSize,
            0, 0
        ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( x - borderSize / 2, y - borderSize / 2, radius * 2 + borderSize, radius * 2 + borderSize, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( state! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}

/// Draws a Box
class MMDrawBox : MMDrawable
{
    let mmRenderer : MMRenderer
    var state : MTLRenderPipelineState!
    
    required init( _ renderer : MMRenderer )
    {
        let function = renderer.defaultLibrary.makeFunction( name: "m4mBoxDrawable" )
        state = renderer.createNewPipelineState( function! )
        mmRenderer = renderer
    }
    
    func draw( x: Float, y: Float, width: Float, height: Float, round: Float = 0, borderSize: Float = 0, fillColor: float4, borderColor: float4 = float4(0) )
    {
        let scaleFactor : Float = mmRenderer.mmView.scaleFactor
        let settings: [Float] = [
            width * scaleFactor, height * scaleFactor,
            round, borderSize,
            fillColor.x, fillColor.y, fillColor.z, fillColor.w,
            borderColor.x, borderColor.y, borderColor.z, borderColor.w
        ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( x - borderSize / 2, y - borderSize / 2, width + borderSize, height + borderSize, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( state! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}

/// Draws a box gradient
class MMDrawBoxGradient : MMDrawable
{
    let mmRenderer : MMRenderer
    var state : MTLRenderPipelineState!
    
    required init( _ renderer : MMRenderer )
    {
        let function = renderer.defaultLibrary.makeFunction( name: "m4mBoxGradientDrawable" )
        state = renderer.createNewPipelineState( function! )
        mmRenderer = renderer
    }
    
    func draw( x: Float, y: Float, width: Float, height: Float, round: Float, borderSize: Float, uv1: vector_float2, uv2: vector_float2, gradientColor1: vector_float4, gradientColor2: vector_float4, borderColor: vector_float4 )
    {
        let scaleFactor : Float = mmRenderer.mmView.scaleFactor
        let settings: [Float] = [
            width * scaleFactor, height * scaleFactor,
            round, borderSize,
            uv1.x, uv1.y,
            uv2.x, uv2.y,
            gradientColor1.x, gradientColor1.y, gradientColor1.z, 1,
            gradientColor2.x, gradientColor2.y, gradientColor2.z, 1,
            borderColor.x, borderColor.y, borderColor.z, borderColor.w
        ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( x - borderSize / 2, y - borderSize / 2, width + borderSize, height + borderSize, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( state! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}

/// Draws a box with three lines inside representing a menu
class MMDrawBoxedMenu : MMDrawable
{
    let mmRenderer : MMRenderer
    var state : MTLRenderPipelineState!
    
    required init( _ renderer : MMRenderer )
    {
        let function = renderer.defaultLibrary.makeFunction( name: "m4mBoxedMenuDrawable" )
        state = renderer.createNewPipelineState( function! )
        mmRenderer = renderer
    }
    
    func draw( x: Float, y: Float, width: Float, height: Float, round: Float, borderSize: Float, fillColor: vector_float4, borderColor: vector_float4 )
    {
        let scaleFactor : Float = mmRenderer.mmView.scaleFactor
        let settings: [Float] = [
            width * scaleFactor, height * scaleFactor,
            round, borderSize,
            fillColor.x, fillColor.y, fillColor.z, fillColor.w,
            borderColor.x, borderColor.y, borderColor.z, borderColor.w
        ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( x - borderSize / 2, y - borderSize / 2, width + borderSize, height + borderSize, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( state! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}

/// Draws a texture
class MMDrawTexture : MMDrawable
{
    let mmRenderer : MMRenderer
    var state : MTLRenderPipelineState!
    
    required init( _ renderer : MMRenderer )
    {
        let function = renderer.defaultLibrary.makeFunction( name: "m4mTextureDrawable" )
        state = renderer.createNewPipelineState( function! )
        mmRenderer = renderer
    }
    
    func draw( _ texture: MTLTexture, x: Float, y: Float, zoom: Float = 1 )
    {
        let scaleFactor : Float = mmRenderer.mmView.scaleFactor
        let width : Float = Float(texture.width)
        let height: Float = Float(texture.height)

        let settings: [Float] = [
            mmRenderer.width, mmRenderer.height,
            x, y,
            width * scaleFactor, height * scaleFactor
        ];
        
        let renderEncoder = mmRenderer.renderEncoder!

        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( x, y, width/zoom, height/zoom, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture, index: 1)
        
        renderEncoder.setRenderPipelineState( state! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
}

/// Class for storing the MTLBuffers for a single char
class MMCharBuffer
{
    let vertexBuffer    : MTLBuffer
    let dataBuffer      : MTLBuffer
    
    init( vertexBuffer: MTLBuffer, dataBuffer: MTLBuffer )
    {
        self.vertexBuffer = vertexBuffer
        self.dataBuffer = dataBuffer
    }
}

/// Class for storing a textbuffer which consists of an array of MMCharBuffers and the text position
class MMTextBuffer
{
    var chars                   : [MMCharBuffer]
    var x, y                    : Float
    var viewWidth, viewHeight   : Float

    init(chars: [MMCharBuffer], x: Float, y: Float, viewWidth: Float, viewHeight: Float)
    {
        self.chars = chars
        self.x = x
        self.y = y
        self.viewWidth = viewWidth
        self.viewHeight = viewHeight
    }
}

/// Draws text
class MMDrawText : MMDrawable
{
    let mmRenderer : MMRenderer
    var state : MTLRenderPipelineState!
    
    required init( _ renderer : MMRenderer )
    {
        let function = renderer.defaultLibrary.makeFunction( name: "m4mTextDrawable" )
        state = renderer.createNewPipelineState( function! )
        mmRenderer = renderer
    }
    
    @discardableResult func drawChar( _ font: MMFont, char: BMChar, x: Float, y: Float, color: float4, scale: Float = 1.0, fragment: MMFragment? = nil ) -> MMCharBuffer
    {
        let scaleFactor : Float = fragment == nil ? mmRenderer.mmView.scaleFactor : 2
        
        let textSettings: [Float] = [
            Float(font.atlas!.width) * scaleFactor, Float(font.atlas!.height) * scaleFactor,
            char.x * scaleFactor, char.y * scaleFactor,
            char.width * scaleFactor, char.height * scaleFactor,
            0,0,
            color.x, color.y, color.z, color.w,
        ];
                    
        let renderEncoder = fragment == nil ? mmRenderer.renderEncoder! : fragment!.renderEncoder!

        let vertexBuffer = fragment == nil ?
            mmRenderer.createVertexBuffer( MMRect( x, y, char.width * scale, char.height * scale, scale: scaleFactor) )
            : fragment!.createVertexBuffer( MMRect( x, y, char.width * scale, char.height * scale, scale: scaleFactor) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let textData = mmRenderer.device.makeBuffer(bytes: textSettings, length: textSettings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(textData, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(font.atlas, index: 1)
        
        renderEncoder.setRenderPipelineState( state! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        return MMCharBuffer(vertexBuffer: vertexBuffer!, dataBuffer: textData)
    }
    
    @discardableResult func drawText( _ font: MMFont, text: String, x: Float, y: Float, scale: Float = 1.0, color: float4 = float4(1), textBuffer: MMTextBuffer? = nil, fragment: MMFragment? = nil ) -> MMTextBuffer?
    {
        if textBuffer != nil && textBuffer!.x == x && textBuffer!.y == y && textBuffer!.viewWidth == mmRenderer.width && textBuffer!.viewHeight == mmRenderer.height {
            let renderEncoder = mmRenderer.renderEncoder!
            renderEncoder.setRenderPipelineState( state! )
            renderEncoder.setFragmentTexture(font.atlas, index: 1)
            for c in textBuffer!.chars {
                renderEncoder.setVertexBuffer(c.vertexBuffer, offset: 0, index: 0)
                renderEncoder.setFragmentBuffer(c.dataBuffer, offset: 0, index: 0)
                
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            }
            return textBuffer
        } else {
            var posX = x
            var array : [MMCharBuffer] = []

            for c in text {
                let bmChar = font.getItemForChar( c )
                if bmChar != nil {
                    let char = drawChar( font, char: bmChar!, x: posX + bmChar!.xoffset * scale, y: y + bmChar!.yoffset * scale, color: color, scale: scale, fragment: fragment)
                    array.append(char)
                    posX += bmChar!.xadvance * scale;
                
                }
            }
        
            return MMTextBuffer(chars:array, x: x, y: y, viewWidth: mmRenderer.width, viewHeight: mmRenderer.height)
        }
    }
}
