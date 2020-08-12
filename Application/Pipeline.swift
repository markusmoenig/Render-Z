//
//  Pipeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PipelineRenderSettings
{
    var reflections         : Int = 0
    var samples             : Int = 0
    
    var transparent         : Bool = false
    
    var cbProgress          : ((Int, Int)->())? = nil
    var cbFinished          : ((MTLTexture)->())? = nil
}

class Pipeline
{
    enum OutputType         : Int {
        case FinalImage, DepthMap, AO, Shadows, FogDensity
    }
    
    var outputType          : OutputType = .FinalImage
    
    var codeBuilder         : CodeBuilder
    var mmView              : MMView
    
    var finalTexture        : MTLTexture? = nil
    
    var samples             : Int = 0

    var textureMap          : [String:MTLTexture] = [:]
    
    // Ids of the hit geometry and their hierarchy
    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]
    
    init(_ mmView: MMView)
    {
        self.mmView = mmView
        self.codeBuilder = CodeBuilder(mmView)
    }
    
    // Build the pipeline elements
    func build(scene: Scene)
    {
    }
        
    // Render the pipeline
    func render(_ width: Float,_ height: Float, settings: PipelineRenderSettings? = nil)
    {
    }
    
    func renderIfResolutionChanged(_ width: Float,_ height: Float)
    {
        if Float(finalTexture!.width) != round(width) || Float(finalTexture!.height) != round(height) {
            render(width, height)
        }
    }
    
    /// Checks the texture size and if needed reallocate the texture
    func checkTextureSize(_ width: Float,_ height: Float,_ texture: MTLTexture? = nil,_ pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture?
    {
        var result  : MTLTexture? = texture
        
        if texture == nil || (Float(texture!.width) != width || Float(texture!.height) != height || texture?.pixelFormat != pixelFormat) {
            if texture != nil {
                texture!.setPurgeableState(.empty)
            }
            result = codeBuilder.compute.allocateTexture(width: width, height: height, output: true, pixelFormat: pixelFormat)
        }
        
        return result
    }
    
    func allocTextureId(_ id: String, _ width: Float,_ height: Float,_ pixelFormat: MTLPixelFormat = .rgba16Float)
    {
        textureMap[id] = checkTextureSize(width, height, textureMap[id], pixelFormat)
    }
    
    func allocTexturePair(_ id: String, _ width: Float,_ height: Float,_ pixelFormat: MTLPixelFormat = .rgba16Float)
    {
        textureMap[id + "_1"] = checkTextureSize(width, height, textureMap[id + "_1"], pixelFormat)
        textureMap[id + "_2"] = checkTextureSize(width, height, textureMap[id + "_2"], pixelFormat)
        textureMap[id + "_current"] = textureMap[id + "_1"]
    }
    
    func getTextureOfId(_ id: String) -> MTLTexture!
    {
        return textureMap[id]!
    }
    
    func getActiveOfPair(_ id: String) -> MTLTexture!
    {
        if textureMap[id + "_current"] === textureMap[id + "_1"] {
            return textureMap[id + "_1"]!
        } else {
            return textureMap[id + "_2"]!
        }
    }
    
    func getInactiveOfPair(_ id: String) -> MTLTexture!
    {
        if textureMap[id + "_current"] === textureMap[id + "_1"] {
            return textureMap[id + "_2"]!
        } else {
            return textureMap[id + "_1"]!
        }
    }
    
    func switchPair(_ id: String)
    {
        if textureMap[id + "_current"] === textureMap[id + "_1"] {
            textureMap[id + "_current"] = textureMap[id + "_2"]
        } else {
            textureMap[id + "_current"] = textureMap[id + "_1"]
        }
    }
    
    func freeTextureId(_ id: String)
    {
        textureMap[id] = nil
    }
    
    func freeTexturePair(_ id: String)
    {
        textureMap[id + "_1"] = nil
        textureMap[id + "_2"] = nil
        textureMap[id + "_current"] = nil
    }
    
    func setMinimalPreview(_ mode: Bool = false)
    {
    }
    
    func cancel()
    {
    }
    
    func resetIds()
    {
    }
}
