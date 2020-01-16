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
    
    var backTexture         : MTLTexture? = nil
    var depthTexture        : MTLTexture? = nil
    var resultTexture       : MTLTexture? = nil
    
    var instanceMap         : [String:CodeBuilderInstance] = [:]

    init(_ mmView: MMView)
    {
        self.mmView = mmView
        self.codeBuilder = CodeBuilder(mmView)
    }
    
    // Build the pipeline elements
    func build(scene: Scene, upUntil: StageItem? = nil, monitor: CodeFragment? = nil)
    {
        let modeId : String = globalApp!.currentSceneMode == .TwoD ? "2D" : "3D"
        
        instanceMap = [:]
        
        // Background
        let preStage = scene.stages[0]
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName] {
                instanceMap["pre"] = codeBuilder.build(comp)
            }
        }

        // Objects
        let shapeStage = scene.stages[1]
        for item in shapeStage.getChildren() {
            if let shapes = item.componentLists["shapes" + modeId] {
                if shapes.count > 0 {
                    instanceMap["shape"] = codeBuilder.build(shapes[0])
                }
            }
        }
        
        // Render
        let renderStage = scene.stages[2]
        let renderChildren = renderStage.getChildren()
        if renderChildren.count > 0 {
            let renderColor = renderChildren[0]
            instanceMap["render"] = codeBuilder.build(renderColor.components[renderColor.defaultName]!)
        }
    }
    
    // Render the pipeline
    func render(_ width: Float,_ height: Float)
    {
        // Render the background into backTexture
        backTexture = checkTextureSize(width, height, backTexture)
        if let inst = instanceMap["pre"] {
            codeBuilder.render(inst, backTexture)
        }
        
        // Render the shape distance into depthTexture (float)
        depthTexture = checkTextureSize(width, height, depthTexture, true)
        if let inst = instanceMap["shape"] {
            codeBuilder.render(inst, depthTexture)
        }
        
        // Render it all
        if let inst = instanceMap["render"] {
            resultTexture = checkTextureSize(width, height, resultTexture)
            codeBuilder.render(inst, resultTexture, [depthTexture!, backTexture!])
        } else {
            resultTexture = backTexture
        }
    }
    
    func renderIfResolutionChanged(_ width: Float,_ height: Float)
    {
        if (Float(resultTexture!.width) != width || Float(resultTexture!.height) != height) {
            render(width, height)
        }
    }
    
    /// Checks the texture size and if needed reallocate the texture
    func checkTextureSize(_ width: Float,_ height: Float,_ texture: MTLTexture? = nil,_ isFloat: Bool = false) -> MTLTexture?
    {
        var result  : MTLTexture? = texture
        
        if texture == nil || (Float(texture!.width) != width || Float(texture!.height) != height) {
            if isFloat == false {
                result = codeBuilder.compute.allocateTexture(width: width, height: height)
            } else {
                result = codeBuilder.compute.allocateFloatTexture(width: width, height: height)
            }
        }
        
        return result
    }
}
