//
//  Pipeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class Pipeline
{
    var codeBuilder         : CodeBuilder
    var mmView              : MMView
    
    var depthTextureResult  : MTLTexture? = nil

    var finalTexture        : MTLTexture? = nil
    
    var monitorInstance     : CodeBuilderInstance? = nil
    var monitorComponent    : CodeComponent? = nil
    var monitorFragment     : CodeFragment? = nil

    var monitorTexture      : MTLTexture? = nil
    
    init(_ mmView: MMView)
    {
        self.mmView = mmView
        self.codeBuilder = CodeBuilder(mmView)
    }
    
    // Build the pipeline elements
    func build(scene: Scene, monitor: CodeFragment? = nil)
    {
    }
        
    // Render the pipeline
    func render(_ width: Float,_ height: Float)
    {
    }
    
    func renderIfResolutionChanged(_ width: Float,_ height: Float)
    {
        if (Float(finalTexture!.width) != width || Float(finalTexture!.height) != height) {
            render(width, height)
        }
    }
    
    /// Checks the texture size and if needed reallocate the texture
    func checkTextureSize(_ width: Float,_ height: Float,_ texture: MTLTexture? = nil,_ pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture?
    {
        var result  : MTLTexture? = texture
        
        if texture == nil || (Float(texture!.width) != width || Float(texture!.height) != height || texture?.pixelFormat != pixelFormat) {
            result = codeBuilder.compute.allocateTexture(width: width, height: height, output: true, pixelFormat: pixelFormat)
        }
        
        return result
    }
}
