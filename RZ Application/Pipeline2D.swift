//
//  Pipeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class Pipeline2D            : Pipeline
{
    enum Stage : Int {
        case None, Compiling, Compiled, HitAndNormals, AO
    }
    
    var currentStage        : Stage = .None
    var maxStage            : Stage = .AO

    var backTexture         : MTLTexture? = nil
    var depthTexture        : MTLTexture? = nil
    var depthTexture2       : MTLTexture? = nil
    
    var rayOriginTexture    : MTLTexture? = nil
    var rayDirectionTexture : MTLTexture? = nil

    var normalTexture       : MTLTexture? = nil
    var normalTexture2      : MTLTexture? = nil
    var normalTextureResult : MTLTexture? = nil
    
    var metaTexture         : MTLTexture? = nil
    var metaTexture2        : MTLTexture? = nil
    var metaTextureResult   : MTLTexture? = nil

    var resultTexture       : MTLTexture? = nil

    var instanceMap         : [String:CodeBuilderInstance] = [:]
    
    var sampleCounter       : Int = 0

    override init(_ mmView: MMView)
    {
        super.init(mmView)
    }
    
    // Build the pipeline elements
    override func build(scene: Scene, monitor: CodeFragment? = nil)
    {
        let modeId : String = getCurrentModeId()
        let typeId : CodeComponent.ComponentType = globalApp!.currentSceneMode == .TwoD ? .SDF2D : .SDF3D

        instanceMap = [:]
        
        /// Recursively iterate the object hierarchy
        func processChildren(_ stageItem: StageItem)
        {
            for child in stageItem.children {
                if let shapes = child.getComponentList("shapes") {
                    codeBuilder.sdfStream.pushStageItem(child)
                    for shape in shapes {
                        codeBuilder.sdfStream.pushComponent(shape)
                    }
                    processChildren(child)
                    codeBuilder.sdfStream.pullStageItem()
                }
            }
        }
        
        // Background
        let preStage = scene.getStage(.PreStage)
        let camera : CodeComponent = getFirstComponentOfType(preStage.getChildren(), typeId == .SDF2D ? .Camera2D : .Camera3D)!

        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .Colorize {
                dryRunComponent(comp)
                instanceMap["pre"] = codeBuilder.build(comp, camera: camera)
                break
            }
        }

        // Objects
        let shapeStage = scene.getStage(.ShapeStage)
        codeBuilder.sdfStream.reset()
        for item in shapeStage.getChildren() {
            if let shapes = item.getComponentList("shapes") {
                let instance = CodeBuilderInstance()
                instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                
                codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: camera)
                codeBuilder.sdfStream.pushStageItem(item)
                for shape in shapes {
                    codeBuilder.sdfStream.pushComponent(shape)
                }
                processChildren(item)
                codeBuilder.sdfStream.pullStageItem()
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
    override func render(_ width: Float,_ height: Float)
    {
        // Monitor
        func computeMonitor(_ inst: CodeBuilderInstance, inTextures: [MTLTexture] = [])
        {
            // Monitor
            if (inst.component != nil && inst.component === monitorComponent) || (monitorComponent != nil && monitorComponent?.componentType == .SDF2D) {
                monitorTexture = checkTextureSize(width, height, monitorTexture, .rgba32Float)
                if monitorInstance == nil {
                    monitorInstance = codeBuilder.build(monitorComponent!, monitor: monitorFragment)
                }
                if let mInstance = monitorInstance {
                    codeBuilder.render(mInstance, monitorTexture!, inTextures: inTextures, syncronize: true)
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
        depthTexture = checkTextureSize(width, height, depthTexture, .rgba16Float)
        if let inst = instanceMap["shape"] {
            codeBuilder.render(inst, depthTexture)
            computeMonitor(inst)
        } else {
            codeBuilder.renderClear(texture: depthTexture!, data: SIMD4<Float>(10000, 10000, 10000, 10000))
        }
                
        // Render it all
        if let inst = instanceMap["render"] {
            resultTexture = checkTextureSize(width, height, resultTexture)
            codeBuilder.render(inst, resultTexture, inTextures: [depthTexture!, backTexture!])
            computeMonitor(inst, inTextures: [depthTexture!, backTexture!])
        } else {
            resultTexture = backTexture
        }
        
        depthTextureResult = depthTexture
        finalTexture = resultTexture
    }
}
