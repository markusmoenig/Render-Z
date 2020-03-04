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
    var depthTexture2       : MTLTexture? = nil
    var resultTexture       : MTLTexture? = nil
    var finalTexture       : MTLTexture? = nil

    var depthTextureResult  : MTLTexture? = nil
    
    var rayOriginTexture    : MTLTexture? = nil
    var rayDirectionTexture : MTLTexture? = nil

    var normalTexture       : MTLTexture? = nil
    var normalTexture2      : MTLTexture? = nil
    var normalTextureResult : MTLTexture? = nil

    var instanceMap         : [String:CodeBuilderInstance] = [:]

    var monitorInstance     : CodeBuilderInstance? = nil
    var monitorComponent    : CodeComponent? = nil
    var monitorFragment     : CodeFragment? = nil

    var monitorTexture      : MTLTexture? = nil
    
    var sampleCounter       : Int = 0

    init(_ mmView: MMView)
    {
        self.mmView = mmView
        self.codeBuilder = CodeBuilder(mmView)
    }
    
    // Build the pipeline elements
    func build(scene: Scene, monitor: CodeFragment? = nil)
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
        
        if globalApp!.currentSceneMode == .TwoD {
            
            // 2D
            
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
        } else {
            // 3D
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
    }
        
    // Render the pipeline
    func render(_ width: Float,_ height: Float)
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
        
        if globalApp!.currentSceneMode == .TwoD {
            // 2D
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
        } else {
            // 3D

            finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
            sampleCounter = 2
            
            createRender3DSample(width, height)
            codeBuilder.compute.copyTexture(finalTexture!, resultTexture!)
            //codeBuilder.renderCopyNearest(texture: finalTexture!, inTexture:  resultTexture!)

            
            for i in 0...20 {
                createRender3DSample(width, height)
                codeBuilder.compute.copyTexture(normalTexture!, finalTexture!)
                codeBuilder.renderSample(texture: finalTexture!, sampleTexture: normalTexture!, resultTexture: resultTexture!, frame: sampleCounter)
                sampleCounter += 1
            }
        }
    }
    
    func createRender3DSample(_ width: Float,_ height: Float)
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
        depthTexture2 = checkTextureSize(width, height, depthTexture, .rgba16Float)
        normalTexture = checkTextureSize(width, height, normalTexture, .rgba16Float)
        normalTexture2 = checkTextureSize(width, height, normalTexture, .rgba16Float)

        codeBuilder.renderClear(texture: depthTexture!, data: SIMD4<Float>(10000, 1000000, 1, -1))

        depthTextureResult = depthTexture
        normalTextureResult = normalTexture

        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            if depthTextureResult === depthTexture {
                codeBuilder.render(inst, depthTexture2, inTextures: [depthTexture!, normalTexture!, rayOriginTexture!, rayDirectionTexture!], outTextures: [normalTexture2!])
                depthTextureResult = depthTexture2
                normalTextureResult = normalTexture2
                //computeMonitor(inst, inTextures: [rayOriginTexture!, rayDirectionTexture!])
            } else
            if depthTextureResult === depthTexture2 {
                codeBuilder.render(inst, depthTexture, inTextures: [depthTexture2!, normalTexture2!, rayOriginTexture!, rayDirectionTexture!], outTextures: [normalTexture!])
                depthTextureResult = depthTexture
                normalTextureResult = normalTexture
                //computeMonitor(inst, inTextures: [rayOriginTexture!, rayDirectionTexture!])
            }
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }

        // Render it all
        if let inst = instanceMap["render"] {
            resultTexture = checkTextureSize(width, height, resultTexture, .rgba16Float)
            codeBuilder.render(inst, resultTexture, inTextures: [depthTextureResult!, backTexture!, normalTextureResult!])
            computeMonitor(inst, inTextures: [depthTextureResult!, backTexture!])
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
    func checkTextureSize(_ width: Float,_ height: Float,_ texture: MTLTexture? = nil,_ pixelFormat: MTLPixelFormat = .bgra8Unorm) -> MTLTexture?
    {
        var result  : MTLTexture? = texture
        
        if texture == nil || (Float(texture!.width) != width || Float(texture!.height) != height || texture?.pixelFormat != pixelFormat) {
            result = codeBuilder.compute.allocateTexture(width: width, height: height, output: true, pixelFormat: pixelFormat)
        }
        
        return result
    }
}
