//
//  Pipeline.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class Pipeline3D            : Pipeline
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
        let cameraComponent : CodeComponent = getFirstComponentOfType(preStage.getChildren(), .Camera3D)!
        
        // Build 3D Camera (Initialization of rayOrigin and rayDirection Textures)
        dryRunComponent(cameraComponent)
        instanceMap["camera3D"] = codeBuilder.build(cameraComponent, camera: cameraComponent)
        
        // SkyDome
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome {
                dryRunComponent(comp)
                instanceMap["pre"] = codeBuilder.build(comp, camera: cameraComponent)
                break
            }
        }
        
        // Objects
        let shapeStage = scene.getStage(.ShapeStage)
        codeBuilder.sdfStream.reset()
        for (index, item) in shapeStage.getChildren().enumerated() {
            
            // Normal Object
            if let shapes = item.getComponentList("shapes") {
                let instance = CodeBuilderInstance()
                instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent)
                codeBuilder.sdfStream.pushStageItem(item)
                for shape in shapes {
                    codeBuilder.sdfStream.pushComponent(shape)
                }
                processChildren(item)
                codeBuilder.sdfStream.pullStageItem()
                instanceMap["shape_\(index)"] = instance
                codeBuilder.sdfStream.closeStream()
            } else
            if let ground = item.components[item.defaultName]
            {
                // Ground Object
                let instance = CodeBuilderInstance()
                instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent, groundComponent: ground)
                codeBuilder.sdfStream.pushStageItem(item)
                //for shape in shapes {
                //    codeBuilder.sdfStream.pushComponent(shape)
                //}
                codeBuilder.sdfStream.pullStageItem()
                instanceMap["shape_\(index)"] = instance
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
 
        stage_HitAndNormals(width, height)
        finalTexture = resultTexture

        currentStage = .HitAndNormals

        /*
        finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
        sampleCounter = 1
        
        //createRender3DSample(width, height)
        //codeBuilder.compute.copyTexture(finalTexture!, resultTexture!)
        
        for _ in 0..<10 {
            createRender3DSample(width, height)
            codeBuilder.compute.copyTexture(normalTexture!, finalTexture!)
            codeBuilder.renderSample(texture: finalTexture!, sampleTexture: normalTexture!, resultTexture: resultTexture!, frame: sampleCounter)
            sampleCounter += 1
        }*/
    }
    
    func nextStage()
    {
        if currentStage.rawValue < maxStage.rawValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                let nextStage : Stage = Stage(rawValue: self.currentStage.rawValue + 1)!
                
                if nextStage == .AO {
                    
                }
            }
        }
    }
    
    func stage_HitAndNormals(_ width: Float,_ height: Float)
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
        
        // Render the Camera Textures
        rayOriginTexture = checkTextureSize(width, height, rayOriginTexture, .rgba16Float)
        rayDirectionTexture = checkTextureSize(width, height, rayDirectionTexture, .rgba16Float)
        if let inst = instanceMap["camera3D"] {
            codeBuilder.render(inst, rayOriginTexture, outTextures: [rayDirectionTexture!])
            computeMonitor(inst)
        }
        
        // Render the SkyDome into backTexture
        backTexture = checkTextureSize(width, height, backTexture, .rgba16Float)
        if let inst = instanceMap["pre"] {
            codeBuilder.render(inst, backTexture, inTextures: [rayDirectionTexture!])
            computeMonitor(inst)
        }
        
        // Render the shape distance into depthTexture (float)
        depthTexture = checkTextureSize(width, height, depthTexture, .rgba16Float)
        depthTexture2 = checkTextureSize(width, height, depthTexture2, .rgba16Float)
        normalTexture = checkTextureSize(width, height, normalTexture, .rgba16Float)
        normalTexture2 = checkTextureSize(width, height, normalTexture2, .rgba16Float)
        metaTexture = checkTextureSize(width, height, metaTexture, .rgba16Float)
        metaTexture2 = checkTextureSize(width, height, metaTexture2, .rgba16Float)
        
        codeBuilder.renderClear(texture: depthTexture!, data: SIMD4<Float>(10000, 1000000, -1, -1))
        codeBuilder.renderClear(texture: metaTexture!, data: SIMD4<Float>(1, 1, 0, 0))

        depthTextureResult = depthTexture
        normalTextureResult = normalTexture
        metaTextureResult = metaTexture

        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            if depthTextureResult === depthTexture {
                codeBuilder.render(inst, depthTexture2, inTextures: [depthTexture!, normalTexture!, metaTexture!, rayOriginTexture!, rayDirectionTexture!], outTextures: [normalTexture2!, metaTexture2!])
                depthTextureResult = depthTexture2
                normalTextureResult = normalTexture2
                metaTextureResult = metaTexture2
                //computeMonitor(inst, inTextures: [rayOriginTexture!, rayDirectionTexture!])
            } else
            if depthTextureResult === depthTexture2 {
                codeBuilder.render(inst, depthTexture, inTextures: [depthTexture2!, normalTexture2!, metaTexture2!, rayOriginTexture!, rayDirectionTexture!], outTextures: [normalTexture!, metaTexture!])
                depthTextureResult = depthTexture
                normalTextureResult = normalTexture
                metaTextureResult = metaTexture
                //computeMonitor(inst, inTextures: [rayOriginTexture!, rayDirectionTexture!])
            }
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }

        // Render it all
        if let inst = instanceMap["render"] {
            resultTexture = checkTextureSize(width, height, resultTexture, .rgba16Float)
            codeBuilder.render(inst, resultTexture, inTextures: [depthTextureResult!, backTexture!, normalTextureResult!, metaTextureResult!])
            computeMonitor(inst, inTextures: [depthTextureResult!, backTexture!])
        } else {
            resultTexture = backTexture
        }
    }
}
