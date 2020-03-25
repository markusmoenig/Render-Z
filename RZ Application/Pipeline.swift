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
    
    var cbProgress          : (Int, Int)? = nil
    var cbFinished          : ((MTLTexture)->())? = nil
}

class Pipeline
{
    var codeBuilder         : CodeBuilder
    var mmView              : MMView
    
    var finalTexture        : MTLTexture? = nil
    var monitorTexture      : MTLTexture? = nil
    var monitorTextureFinal : MTLTexture? = nil

    var monitorComponent    : CodeComponent? = nil
    var monitorFragment     : CodeFragment? = nil
    
    var monitorComponents   : Int = 0
    
    var textureMap          : [String:MTLTexture] = [:]
    
    init(_ mmView: MMView)
    {
        self.mmView = mmView
        self.codeBuilder = CodeBuilder(mmView)
    }
    
    func computeMonitorComponents(_ monitor: CodeFragment? = nil) {
        if let fragment = monitor {
            if fragment.name == "out" {
                // Correct the out fragment return type
                fragment.typeName = fragment.parentBlock!.parentFunction!.header.fragment.typeName
            }
            monitorComponents = 1
            if fragment.typeName.contains("2") {
                monitorComponents = 2
            } else
            if fragment.typeName.contains("3") {
                monitorComponents = 3
            }
            if fragment.typeName.contains("4") {
                monitorComponents = 4
            }
        }
    }
    
    // Build the pipeline elements
    func build(scene: Scene, monitor: CodeFragment? = nil)
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
    
    func clearMonitor()
    {
        monitorComponent = nil
        monitorFragment = nil
    }
}
