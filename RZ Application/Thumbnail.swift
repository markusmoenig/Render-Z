//
//  CodeThumbnail.swift
//  Shape-Z
//
//  Created by Markus Moenig on 21/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class Thumbnail
{
    var mmView          : MMView
    var codeBuilder     : CodeBuilder
    
    var thumbs          : [String:MTLTexture] = [:]

    var backTexture     : MTLTexture? = nil
    var depthTexture    : MTLTexture? = nil
    
    var componentMap    : [String:CodeComponent] = [:]

    init(_ view: MMView)
    {
        mmView = view
        codeBuilder = CodeBuilder(view)
        
        componentMap["render2D"] = decodeComponentFromJSON(defaultRender2D)!
    }
    
    func generate(_ comp: CodeComponent,_ width: Float = 200,_ height: Float = 200) -> MTLTexture?
    {
        let result = checkTextureSize(width, height)
        if comp.componentType == .SDF2D {
            depthTexture = checkTextureSize(width, height, depthTexture, .rgba16Float)
            backTexture = checkTextureSize(width, height, backTexture)
            codeBuilder.renderClear(texture: backTexture!, data: SIMD4<Float>(0,0,0,0))
            let instance = CodeBuilderInstance()
            instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
            codeBuilder.sdfStream.openStream(comp.componentType, instance, codeBuilder)
            codeBuilder.sdfStream.pushComponent(comp)
            codeBuilder.sdfStream.closeStream()
            
            codeBuilder.render(instance, depthTexture)
            
            let renderInstance = codeBuilder.build(componentMap["render2D"]!)
            codeBuilder.render(renderInstance, result, inTextures: [depthTexture!, backTexture!])
        }
        return result
    }
    
    func request(_ type: String,_ comp: CodeComponent,_ width: Float = 200,_ height: Float = 200) -> MTLTexture?
    {
        if let thumb = thumbs[type] {
            return thumb
        } else {
            thumbs[type] = generate(comp, width, height)
        }
        return thumbs[type]
    }
    
    /// Checks the texture size and if needed reallocate the texture
    func checkTextureSize(_ width: Float,_ height: Float,_ texture: MTLTexture? = nil,_ pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture?
    {
        var result  : MTLTexture? = texture
        
        if texture == nil || (Float(texture!.width) != width || Float(texture!.height) != height) {
            result = codeBuilder.compute.allocateTexture(width: width, height: height, output: true, pixelFormat: pixelFormat)
        }
        
        return result
    }
}
