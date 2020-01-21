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
    func build(scene: Scene, upUntil: StageItem? = nil, monitor: CodeFragment? = nil)
    {
        let modeId : String = globalApp!.currentSceneMode == .TwoD ? "2D" : "3D"
        let typeId : CodeComponent.ComponentType = globalApp!.currentSceneMode == .TwoD ? .SDF2D : .SDF3D

        instanceMap = [:]
        
        // Background
        let preStage = scene.getStage(.PreStage)
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName] {
                dryRunComponent(comp)
                instanceMap["pre"] = codeBuilder.build(comp)
            }
        }

        // Objects
        let shapeStage = scene.getStage(.ShapeStage)
        for item in shapeStage.getChildren() {
            if let shapes = item.componentLists["shapes" + modeId] {
                let instance = CodeBuilderInstance()
                instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder)
                for shape in shapes {
                    codeBuilder.sdfStream.pushComponent(shape)
                    //dryRunComponent(shapes[0])
                    //instanceMap["shape"] = codeBuilder.build(shapes[0])
                }
                instanceMap["shape"] = instance
                codeBuilder.sdfStream.closeStream()
            }
        }
        
        // Render
        let renderStage = scene.getStage(.RenderStage)
        let renderChildren = renderStage.getChildren()
        if renderChildren.count > 0 {
            let renderColor = renderChildren[0]
            let renderComp = renderColor.components[renderColor.defaultName]!
            dryRunComponent(renderComp)
            instanceMap["render"] = codeBuilder.build(renderComp)
        }
    }
    
    // Render the pipeline
    func render(_ width: Float,_ height: Float)
    {
        // Monitor
        func computeMonitor(_ inst: CodeBuilderInstance, inTextures: [MTLTexture] = [])
        {
            // Monitor
            if inst.component != nil && inst.component === monitorComponent {
                monitorTexture = checkTextureSize(width, height, monitorTexture, true)
                if monitorInstance == nil {
                    monitorInstance = codeBuilder.build(monitorComponent!, monitorFragment)
                }
                if let mInstance = monitorInstance {
                    codeBuilder.render(mInstance, monitorTexture!, inTextures, syncronize: true)
                    if let monitorUI = globalApp!.developerEditor.codeProperties.nodeUIMonitor {
                        monitorUI.setTexture(monitorTexture!)
                    }
                }
            }
        }
        
        
        // Render the background into backTexture
        backTexture = checkTextureSize(width, height, backTexture)
        if let inst = instanceMap["pre"] {
            codeBuilder.render(inst, backTexture)
            computeMonitor(inst)
        }
        
        // Render the shape distance into depthTexture (float)
        depthTexture = checkTextureSize(width, height, depthTexture, true)
        if let inst = instanceMap["shape"] {
            codeBuilder.render(inst, depthTexture)
            computeMonitor(inst)
        } else {
            codeBuilder.renderClear(texture: depthTexture!, data: SIMD4<Float>(10000, 10000, 10000, 10000))
        }
                
        // Render it all
        if let inst = instanceMap["render"] {
            resultTexture = checkTextureSize(width, height, resultTexture)
            codeBuilder.render(inst, resultTexture, [depthTexture!, backTexture!])
            computeMonitor(inst, inTextures: [depthTexture!, backTexture!])
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
