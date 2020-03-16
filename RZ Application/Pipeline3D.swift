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
        case None, Compiling, Compiled, HitAndNormals, AO, ShadowsAndMaterials
    }
    
    var currentStage        : Stage = .None
    var maxStage            : Stage = .AO

    var instanceMap         : [String:CodeBuilderInstance] = [:]
    
    var sampleCounter       : Int = 0
    
    var width               : Float = 0
    var height              : Float = 0
    
    var renderId            : UInt = 0

    override init(_ mmView: MMView)
    {
        super.init(mmView)
    }
    
    // Build the pipeline elements
    override func build(scene: Scene, monitor: CodeFragment? = nil)
    {
        renderId += 1
        
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
        
        var backComponent : CodeComponent? = nil

        // SkyDome
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome {
                backComponent = comp
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
                codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent, backgroundComponent: backComponent)
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
                codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent, groundComponent: ground, backgroundComponent: backComponent)
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
        renderId += 1
        self.width = width; self.height = height
        
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
        
        allocTexturePair("color", width, height, .rgba16Float)
        codeBuilder.renderClear(texture: getActiveOfPair("color"), data: SIMD4<Float>(0, 0, 0, 1))

        stage_HitAndNormals()
        currentStage = .HitAndNormals
        
        nextStage()

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
            let startId = renderId
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if startId < self.renderId { return }
                
                print( "Stage Finished:", self.currentStage, "Alloc", self.textureMap.count)
                
                let nextStage : Stage? = Stage(rawValue: self.currentStage.rawValue + 1)
                
                if let nextStage = nextStage {
                    if nextStage == .AO {
                        self.stage_computeAO()
                        self.currentStage = .AO
                        //self.mmView.update()
                    } else
                    if nextStage == .ShadowsAndMaterials {
                        self.stage_computeShadowsAndMaterials()
                        self.currentStage = .ShadowsAndMaterials
                        self.mmView.update()
                    }
                }
            }
        }
    }
    
    /// Compute the hitpoints and normals
    func stage_HitAndNormals()
    {
        // Monitor
        func computeMonitor(_ inst: CodeBuilderInstance, inTextures: [MTLTexture] = [])
        {
            // Monitor
            if inst.component != nil && inst.component === monitorComponent {
                monitorTexture = checkTextureSize(width, height, monitorTexture, .rgba16Float)
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
        allocTexturePair("rayOrigin", width, height, .rgba16Float)
        allocTexturePair("rayDirection", width, height, .rgba16Float)
        if let inst = instanceMap["camera3D"] {
            codeBuilder.render(inst, getActiveOfPair("rayOrigin"), outTextures: [getActiveOfPair("rayDirection")])
            computeMonitor(inst)
        }
        
        // Render the SkyDome into backTexture
        allocTextureId("back", width, height, .rgba16Float)
        if let inst = instanceMap["pre"] {
            codeBuilder.render(inst, getTextureOfId("back"), inTextures: [getActiveOfPair("rayDirection")])
            computeMonitor(inst)
        }
        
        allocTexturePair("depth", width, height, .rgba16Float)
        allocTexturePair("normal", width, height, .rgba16Float)
        allocTexturePair("meta", width, height, .rgba16Float)
        
        codeBuilder.renderClear(texture: getActiveOfPair("depth"), data: SIMD4<Float>(10000, 1000000, -1, -1))
        codeBuilder.renderClear(texture: getActiveOfPair("meta"), data: SIMD4<Float>(1, 1, 0, 0))

        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getInactiveOfPair("depth"), inTextures: [getActiveOfPair("depth"), getActiveOfPair("normal"), getActiveOfPair("meta"), getActiveOfPair("rayOrigin"), getActiveOfPair("rayDirection")], outTextures: [getInactiveOfPair("normal"), getInactiveOfPair("meta")])
            
            switchPair("depth")
            switchPair("normal")
            switchPair("meta")

            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        // Preview Render: Fake Lighting + AO
        allocTextureId("result", width, height, .rgba16Float)
        codeBuilder.compute.run( codeBuilder.previewState!, outTexture: getTextureOfId("result"), inTextures: [getActiveOfPair("depth")!, getTextureOfId("back"), getActiveOfPair("normal"), getActiveOfPair("meta")])
        codeBuilder.compute.commandBuffer.waitUntilCompleted()
        finalTexture = getTextureOfId("result")
    }
    
    /// Compute the AO stage
    func stage_computeAO()
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

        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getInactiveOfPair("meta"), inTextures: [getActiveOfPair("depth"), getActiveOfPair("normal"), getActiveOfPair("meta"), getActiveOfPair("rayOrigin"), getActiveOfPair("rayDirection")], optionalState: "computeAO")
            switchPair("meta")
            
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        // Preview Render: Fake Lighting + AO
        codeBuilder.compute.run( codeBuilder.previewState!, outTexture: getTextureOfId("result"), inTextures: [getActiveOfPair("depth")!, getTextureOfId("back"), getActiveOfPair("normal"), getActiveOfPair("meta")])
        codeBuilder.compute.commandBuffer.waitUntilCompleted()
        finalTexture = getTextureOfId("result")
        
        nextStage()
    }
    
    /// Compute shadows and materials
    func stage_computeShadowsAndMaterials()
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

        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        let sunDirection = getGlobalVariableValue(withName: "Sun.sunDirection")

        let lightdata : [SIMD4<Float>] = [sunDirection!, SIMD4<Float>(0,0,0,0), SIMD4<Float>(1,1,1,1)]
        let lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        
        // Shadows
                
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getInactiveOfPair("meta"), inTextures: [getActiveOfPair("depth"), getActiveOfPair("normal"), getActiveOfPair("meta"), getActiveOfPair("rayOrigin"), getActiveOfPair("rayDirection")], inBuffers: [lightBuffer], optionalState: "computeShadow")
            switchPair("meta")
            
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        // Materials
        
        codeBuilder.renderClear(texture: getActiveOfPair("color"), data: SIMD4<Float>(0, 0, 0, 1))
        
        objectIndex = 0
        shapeText = "shape_" + String(objectIndex)
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getInactiveOfPair("color"), inTextures: [getActiveOfPair("color"), getActiveOfPair("depth"), getActiveOfPair("normal"), getActiveOfPair("meta"), getActiveOfPair("rayOrigin"), getActiveOfPair("rayDirection")], inBuffers: [lightBuffer], optionalState: "computeMaterial")
            switchPair("color")
            
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        // Render it all
        if let inst = instanceMap["render"] {
            codeBuilder.render(inst, getTextureOfId("result"), inTextures: [getActiveOfPair("color")])
            //computeMonitor(inst, inTextures: [depthTextureResult!, backTexture!])
        }
        finalTexture = getTextureOfId("result")
    }
}
