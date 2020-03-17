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
        case None, Compiling, Compiled, HitAndNormals, AO, ShadowsAndMaterials, Reflection
    }
    
    var currentStage        : Stage = .None
    var maxStage            : Stage = .Reflection

    var instanceMap         : [String:CodeBuilderInstance] = [:]
    
    var sampleCounter       : Int = 0
    
    var width               : Float = 0
    var height              : Float = 0
    
    var reflections         : Int = 0
    var maxReflections      : Int = 4
    
    var samples             : Int = 0
    var maxSamples          : Int = 4

    var renderId            : UInt = 0
    var justStarted         : Bool = true

    override init(_ mmView: MMView)
    {
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
    }
    
    override func setMinimalPreview(_ mode: Bool = false)
    {
        print("setMinimalPreview", mode)
        if mode == true {
            maxStage = .HitAndNormals
        } else {
            maxStage = .Reflection
        }
        globalApp!.currentEditor.updateOnNextDraw(compile: false)
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
        
        reflections = 0
        samples = 0
        
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

        allocTextureId("color", width, height, .rgba16Float)
        allocTextureId("mask", width, height, .rgba16Float)
        
        allocTextureId("id", width, height, .rgba16Float)

        if justStarted {
            checkFinalTexture(true)
            justStarted = false
        }
        
        resetSample()
        
        // Get Render Values
        if let renderComp = getComponent(name: "Renderer") {
            maxReflections = getComponentPropertyInt(component: renderComp, name: "reflections", defaultValue: 3)
            maxSamples = getComponentPropertyInt(component: renderComp, name: "antiAliasing", defaultValue: 4)
        }
        
        stage_HitAndNormals()
        currentStage = .HitAndNormals
    }
    
    func resetSample()
    {
        codeBuilder.renderClear(texture: getTextureOfId("color"), data: SIMD4<Float>(0, 0, 0, 1))
        codeBuilder.renderClear(texture: getTextureOfId("mask"), data: SIMD4<Float>(1, 1, 1, 1))
    }
    
    func checkFinalTexture(_ clear: Bool = false)
    {
        let needsResize = width != Float(finalTexture!.width) || height != Float(finalTexture!.height)
        finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
        if needsResize || clear {
            codeBuilder.renderClear(texture: finalTexture!, data: SIMD4<Float>(0, 0, 0, 1))
        }
    }
    
    func nextStage()
    {
        let startId = renderId
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if startId < self.renderId { return }

            print( "Stage Finished:", self.currentStage, "Samples", self.samples, "Reflections:", self.reflections, "Alloc", self.textureMap.count)

            let nextStage : Stage? = Stage(rawValue: self.currentStage.rawValue + 1)
            
            if let nextStage = nextStage {
                if nextStage == .AO {
                    self.stage_computeAO()
                    self.currentStage = .AO
                } else
                if nextStage == .ShadowsAndMaterials {
                    self.stage_computeShadowsAndMaterials()
                    self.currentStage = .ShadowsAndMaterials
                } else
                if nextStage == .Reflection {
                    self.reflections += 1
                    if self.reflections < self.maxReflections {
                        
                        self.stage_HitAndNormals()
                        self.currentStage = .HitAndNormals
                    } else {
                        self.checkFinalTexture()
                        //self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("result"))
                        
                        // Sampling
                        if self.samples == 0 { self.checkFinalTexture(true) }
                        self.codeBuilder.renderSample(sampleTexture: self.finalTexture!, resultTexture: self.getTextureOfId("result"), frame: self.samples + 1)
                        self.mmView.update()
                        
                        self.samples += 1
                        if self.samples < self.maxSamples {
                            self.reflections = 0
                            
                            self.resetSample()
                            
                            self.stage_HitAndNormals()
                            self.currentStage = .HitAndNormals
                        }
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
        
        if reflections == 0 {
            // Render the Camera Textures
            allocTextureId("rayOrigin", width, height, .rgba16Float)
            allocTextureId("rayDirection", width, height, .rgba16Float)
            if let inst = instanceMap["camera3D"] {
                codeBuilder.render(inst, getTextureOfId("rayOrigin"), outTextures: [getTextureOfId("rayDirection")])
                computeMonitor(inst)
            }
        }
        
        // Render the SkyDome into backTexture
        allocTextureId("back", width, height, .rgba16Float)
        if let inst = instanceMap["pre"] {
            codeBuilder.render(inst, getTextureOfId("back"), inTextures: [getTextureOfId("rayDirection")])
            computeMonitor(inst)
        }
        
        allocTextureId("depth", width, height, .rgba16Float)
        allocTextureId("normal", width, height, .rgba16Float)
        allocTextureId("meta", width, height, .rgba16Float)
        
        codeBuilder.renderClear(texture: getTextureOfId("depth"), data: SIMD4<Float>(10000, 1000000, -1, -1))
        codeBuilder.renderClear(texture: getTextureOfId("meta"), data: SIMD4<Float>(1, 1, 0, 0))

        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getTextureOfId("depth"), inTextures: [getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection")])

            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        if samples == 0 && reflections == 0 {
            // On first pass copy the depth buffer to id, which the UI can use for object selection
            self.codeBuilder.renderCopy(getTextureOfId("id"), getTextureOfId("depth"))
        }
        
        allocTextureId("result", width, height, .rgba16Float)
        if self.maxStage == .HitAndNormals {
            // Preview Render: Fake Lighting + AO
            codeBuilder.compute.run( codeBuilder.previewState!, outTexture: getTextureOfId("result"), inTextures: [getTextureOfId("depth")!, getTextureOfId("back"), getTextureOfId("normal"), getTextureOfId("meta")])
            codeBuilder.compute.commandBuffer.waitUntilCompleted()

            checkFinalTexture()
            codeBuilder.renderCopy(finalTexture!, getTextureOfId("result"))
            mmView.update()
        } else {
            nextStage()
        }
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
            
            codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection")], optionalState: "computeAO")
            
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        // Preview Render: Fake Lighting + AO
        // Not needed to render this right now
        //codeBuilder.compute.run( codeBuilder.previewState!, outTexture: getTextureOfId("result"), inTextures: [getActiveOfPair("depth")!, getTextureOfId("back"), getActiveOfPair("normal"), getActiveOfPair("meta")])
        //codeBuilder.compute.commandBuffer.waitUntilCompleted()
        
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
            
            codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection")], inBuffers: [lightBuffer], optionalState: "computeShadow")
            
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        // Materials
        //codeBuilder.renderClear(texture: getActiveOfPair("color"), data: SIMD4<Float>(0, 0, 0, 1))
        
        objectIndex = 0
        shapeText = "shape_" + String(objectIndex)
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getTextureOfId("color"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("mask")], inBuffers: [lightBuffer], optionalState: "computeMaterial")

            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        // Render it all
        if let inst = instanceMap["render"] {
            codeBuilder.render(inst, getTextureOfId("result"), inTextures: [getTextureOfId("color")])
            //computeMonitor(inst, inTextures: [depthTextureResult!, backTexture!])
        }
        
        nextStage()
    }
}
