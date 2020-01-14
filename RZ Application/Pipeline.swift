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
    
    var result              : MTLTexture? = nil
    
    var instance            : CodeBuilderInstance? = nil
    
    init(_ mmView: MMView)
    {
        self.mmView = mmView
        self.codeBuilder = CodeBuilder(mmView)
    }
    
    func build(scene: Scene, selected: CodeComponent? = nil, monitor: CodeFragment? = nil)
    {
        // Background
        
        let preStage = scene.stages[0]
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName] {
                instance = codeBuilder.build(comp)
                if comp === selected {
                    return
                }
            }
        }
        
        // Background

        let shapeStage = scene.stages[1]
        for item in shapeStage.getChildren() {
            if let comp = item.components[item.defaultName] {
                instance = codeBuilder.build(comp)
                if comp === selected {
                    return
                }
            }
        }
    }
    
    func render(_ width: Float,_ height: Float)
    {
        if let inst = instance {
            result = checkTextureSize(width, height, result)
            codeBuilder.render(inst, result)
        }
    }
    
    func renderIfResolutionChanged(_ width: Float,_ height: Float)
    {
        if (Float(result!.width) != width || Float(result!.height) != height) {
            render(width, height)
        }
    }
    
    func start(_ width: Float,_ height: Float)
    {
        let component = CodeComponent(.SDF2D)
        
        let inst = codeBuilder.build(component)
        let test = codeBuilder.compute.allocateFloatTexture(width: width, height: height, output: false)
        
        codeBuilder.render(inst, test)
        
        let test2 = codeBuilder.compute.allocateTexture(width: width, height: height, output: false)

        let component2 = CodeComponent(.Render)
        let inst2 = codeBuilder.build(component2)

        codeBuilder.render(inst2, test2, test)

        result = test2
    }
    
    func checkTextureSize(_ width: Float,_ height: Float,_ texture: MTLTexture? = nil) -> MTLTexture?
    {
        var result  : MTLTexture? = texture
        
        if texture == nil || (Float(texture!.width) != width || Float(texture!.height) != height) {
            result = codeBuilder.compute.allocateTexture(width: width, height: height)
        }
        
        return result
    }
    
    func draw()
    {
        
    }
}
