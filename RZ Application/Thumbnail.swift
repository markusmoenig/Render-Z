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
    
    var normalTexture   : MTLTexture? = nil
    var metaTexture     : MTLTexture? = nil

    var rayOriginTexture : MTLTexture? = nil
    var rayDirectionTexture : MTLTexture? = nil

    var componentMap    : [String:CodeComponent] = [:]

    init(_ view: MMView)
    {
        mmView = view
        codeBuilder = CodeBuilder(view)
        
        componentMap["camera3D"] = decodeComponentFromJSON(defaultCamera3D)!
        componentMap["render2D"] = decodeComponentFromJSON(defaultRender2D)!
        
        //setPropertyValue3(component: componentMap["camera3D"]!, name: "origin", value: SIMD3<Float>(0,0,3))
        //setPropertyValue3(component: componentMap["camera3D"]!, name: "lookAt", value: SIMD3<Float>(0,0,0))
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
        } else
        if comp.componentType == .SDF3D {
            depthTexture = checkTextureSize(width, height, depthTexture)
            backTexture = checkTextureSize(width, height, backTexture)
            
            rayOriginTexture = checkTextureSize(width, height, rayOriginTexture)
            rayDirectionTexture = checkTextureSize(width, height, rayDirectionTexture)

            normalTexture = checkTextureSize(width, height, normalTexture)
            metaTexture = checkTextureSize(width, height, metaTexture)

            codeBuilder.renderClear(texture: backTexture!, data: SIMD4<Float>(0,0,0,0))
            codeBuilder.renderClear(texture: depthTexture!, data: SIMD4<Float>(10000, 1000000, -1, -1))
            codeBuilder.renderClear(texture: metaTexture!, data: SIMD4<Float>(1, 1, 0, 0))

            let instance = CodeBuilderInstance()
            instance.data.append( SIMD4<Float>( 0, 0, 1, 1 ) )
            
            let cameraInstance = codeBuilder.build(componentMap["camera3D"]!, camera: componentMap["camera3D"]!)
            codeBuilder.render(cameraInstance, rayOriginTexture, outTextures: [rayDirectionTexture!])
            
            codeBuilder.sdfStream.openStream(comp.componentType, instance, codeBuilder, camera: componentMap["camera3D"]! )
            codeBuilder.sdfStream.pushComponent(comp)
            codeBuilder.sdfStream.closeStream()
            
            codeBuilder.render(instance, depthTexture, inTextures: [normalTexture!, metaTexture!, rayOriginTexture!, rayDirectionTexture!])
            
            // Render
            codeBuilder.compute.run( codeBuilder.previewState!, outTexture: result, inTextures: [depthTexture!, backTexture!, normalTexture!, metaTexture!])
            codeBuilder.compute.commandBuffer.waitUntilCompleted()
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
    func checkTextureSize(_ width: Float,_ height: Float,_ texture: MTLTexture? = nil,_ pixelFormat: MTLPixelFormat = .rgba16Float) -> MTLTexture?
    {
        var result  : MTLTexture? = texture
        
        if texture == nil || (Float(texture!.width) != width || Float(texture!.height) != height) {
            result = codeBuilder.compute.allocateTexture(width: width, height: height, output: true, pixelFormat: pixelFormat)
        }
        
        return result
    }
}
