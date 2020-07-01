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
    
    var metaTexture         : MTLTexture? = nil

    var resultTexture       : MTLTexture? = nil

    var instanceMap         : [String:CodeBuilderInstance] = [:]
    
    override init(_ mmView: MMView)
    {
        super.init(mmView)
    }
    
    // Build the pipeline elements
    override func build(scene: Scene)
    {
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
        let camera : CodeComponent = getFirstComponentOfType(preStage.children2D, .Camera2D)!

        for item in preStage.children2D {
            if let comp = item.components[item.defaultName], comp.componentType == .Pattern {
                dryRunComponent(comp)
                instanceMap["pre"] = codeBuilder.build(comp, camera: camera)
                break
            }
        }

        // Objects
        let shapeStage = scene.getStage(.ShapeStage)
        codeBuilder.sdfStream.reset()
        for item in shapeStage.children2D {
            if let shapes = item.componentLists["shapes2D"] {
                let instance = CodeBuilderInstance()
                instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                
                codeBuilder.sdfStream.openStream(.SDF2D, instance, codeBuilder, camera: camera)
                codeBuilder.sdfStream.pushStageItem(item)
                for shape in shapes {
                    codeBuilder.sdfStream.pushComponent(shape)
                }
                processChildren(item)
                codeBuilder.sdfStream.pullStageItem()
                instanceMap["shape"] = instance
                codeBuilder.sdfStream.closeStream()
                //print(instance.code)
            }
        }
        
        // Render
        let renderStage = scene.getStage(.RenderStage)
        let renderChildren = renderStage.children2D
        if renderChildren.count > 0 {
            let renderColor = renderChildren[0]
            let renderComp = renderColor.components[renderColor.defaultName]!
            dryRunComponent(renderComp)
            instanceMap["render"] = codeBuilder.build(renderComp)
        }
    }
        
    // Render the pipeline
    override func render(_ width: Float,_ height: Float, settings: PipelineRenderSettings? = nil)
    {
        // Render the background into backTexture
        backTexture = checkTextureSize(width, height, backTexture)

        var doBackground = true
        
        if let settings = settings {
            if settings.transparent {
                doBackground = false
                codeBuilder.renderClear(texture: backTexture!, data: SIMD4<Float>(0,0,0,0))
            }
        }
        
        if doBackground {
            if let inst = instanceMap["pre"] {
                codeBuilder.render(inst, backTexture)
            }
        }
        
        // Render the shape distance into depthTexture (float)
        depthTexture = checkTextureSize(width, height, depthTexture, .rgba16Float)
        if let inst = instanceMap["shape"] {
            codeBuilder.render(inst, depthTexture)
        } else {
            codeBuilder.renderClear(texture: depthTexture!, data: SIMD4<Float>(10000, 10000, 10000, 10000))
        }
                
        // Render it all
        if let inst = instanceMap["render"] {
            resultTexture = checkTextureSize(width, height, resultTexture)
            codeBuilder.render(inst, resultTexture, inTextures: [depthTexture!, backTexture!])
        } else {
            resultTexture = backTexture
        }
        
        finalTexture = resultTexture
    }
}
