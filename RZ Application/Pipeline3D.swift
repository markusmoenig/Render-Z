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
    var startedRender       : Bool = false
    
    var startId             : UInt = 0
    
    var settings            : PipelineRenderSettings? = nil
    
    var compiledSuccessfully: Bool = true
    
    var idCounter           : Int = 0

    override init(_ mmView: MMView)
    {
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
    }
    
    override func setMinimalPreview(_ mode: Bool = false)
    {
        if mode == true {
            maxStage = .HitAndNormals
        } else {
            maxStage = .Reflection
        }
        globalApp!.currentEditor.updateOnNextDraw(compile: false)
    }
    
    // Build the pipeline elements
    override func build(scene: Scene)
    {
        renderId += 1
        
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
        
        // Camera
        let preStage = scene.getStage(.PreStage)
        let result = getFirstItemOfType(preStage.getChildren(), .Camera3D)
        let cameraComponent = result.1!
        if let stageItem = result.0 {
            if stageItem.builderInstance == nil {
                stageItem.builderInstance = codeBuilder.build(result.1!, camera: result.1!)
                instanceMap["camera3D"] = stageItem.builderInstance
                print("compile camera")
            } else {
                instanceMap["camera3D"] = stageItem.builderInstance
                print("reuse camera")
            }
        }
        
        var backComponent : CodeComponent? = nil

        // SkyDome
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome || comp.componentType == .Pattern {
                backComponent = comp
                if item.builderInstance == nil {
                    item.builderInstance = codeBuilder.build(comp, camera: cameraComponent)
                    instanceMap["pre"] = item.builderInstance
                    print("compile background")
                } else {
                    instanceMap["pre"] = item.builderInstance
                    print("reuse background")
                }
                break
            }
        }
                
        // Objects
        let shapeStage = scene.getStage(.ShapeStage)
        codeBuilder.sdfStream.reset()
        for (index, item) in shapeStage.getChildren().enumerated() {
            
            if item.builderInstance == nil {
                // Normal Object
                if let shapes = item.getComponentList("shapes") {
                    let instance = CodeBuilderInstance()
                    instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                    codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent, backgroundComponent: backComponent, idStart: idCounter)
                    codeBuilder.sdfStream.pushStageItem(item)
                    for shape in shapes {
                        codeBuilder.sdfStream.pushComponent(shape)
                    }
                    processChildren(item)
                    codeBuilder.sdfStream.pullStageItem()
                    instanceMap["shape_\(index)"] = instance
                    codeBuilder.sdfStream.closeStream()
                    
                    idCounter += codeBuilder.sdfStream.idCounter - idCounter + 1
                    item.builderInstance = instance
                } else
                if let ground = item.components[item.defaultName]
                {
                    // Ground Object
                    let instance = CodeBuilderInstance()
                    instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                    codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent, groundComponent: ground, backgroundComponent: backComponent, idStart: 0)
                    codeBuilder.sdfStream.pushStageItem(item)
                    //for shape in shapes {
                    //    codeBuilder.sdfStream.pushComponent(shape)
                    //}
                    codeBuilder.sdfStream.pullStageItem()
                    instanceMap["shape_\(index)"] = instance
                    codeBuilder.sdfStream.closeStream()
                    
                    idCounter += codeBuilder.sdfStream.idCounter - idCounter + 1
                    item.builderInstance = instance
                }
            } else {
                instanceMap["shape_\(index)"] = item.builderInstance
                
                item.builderInstance!.ids.forEach { (key, value) in codeBuilder.sdfStream.ids[key] = value }

                print("reusing", "shape_\(index)")
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
        
        // Check if we succeeded
        
        compiledSuccessfully = true
        for (_, instance) in instanceMap {
            if instance.computeState == nil {
                compiledSuccessfully = false
                break
            }
            for (_, instance) in instance.additionalStates {
                if instance == nil {
                    compiledSuccessfully = false
                    break
                }
            }
        }
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
        width = round(widthIn); height = round(heightIn)

        // Return a red texture if compilation failed
        if compiledSuccessfully == false {
            finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
            codeBuilder.renderClear(texture: finalTexture!, data: SIMD4<Float>(1,0,0,1))
            return
        }
        
        self.settings = settings
        
        renderId += 1
            
        reflections = 0
        samples = 0

        allocTextureId("color", width, height, .rgba16Float)
        allocTextureId("mask", width, height, .rgba16Float)
        allocTextureId("id", width, height, .rgba16Float)

        if justStarted {
            checkFinalTexture(true)
            justStarted = false
        }
        
        if startedRender == false {
            
            // Get Render Values
            if settings == nil {
                if let renderComp = getComponent(name: "Renderer") {
                    maxReflections = getComponentPropertyInt(component: renderComp, name: "reflections", defaultValue: 2)
                    maxSamples = getComponentPropertyInt(component: renderComp, name: "antiAliasing", defaultValue: 4)
                }
            } else {
                maxReflections = settings!.reflections
                maxSamples = settings!.samples
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.startId = self.renderId
                self.resetSample()

                self.allocTextureId("color", self.width, self.height, .rgba16Float)
                self.allocTextureId("mask", self.width, self.height, .rgba16Float)
                self.allocTextureId("id", self.width, self.height, .rgba16Float)
                
                self.stage_HitAndNormals()
                self.currentStage = .HitAndNormals
                self.startedRender = false
            }
            startedRender = true
        }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if self.startId < self.renderId { return }

            //print( "Stage Finished:", self.currentStage, "Samples", self.samples, "Reflections:", self.reflections, "renderId", self.renderId)

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
                    
                    // Show reflection updates for sample 0
                    /*
                    if self.samples == 0 {
                        if self.reflections == 0 { self.checkFinalTexture(true) }
                        self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("result"))
                        self.mmView.update()
                    }*/
                    
                    if self.outputType == .DepthMap {
                        self.codeBuilder.renderDepthMap(self.finalTexture!, self.getTextureOfId("id"))

                        self.mmView.update()
                        self.samples = self.maxSamples
                        return
                    } else
                    if self.outputType == .AO {
                        self.codeBuilder.renderAO(self.finalTexture!, self.getTextureOfId("meta"))

                        self.mmView.update()
                        self.samples = self.maxSamples
                        return
                    } else
                    if self.outputType == .Shadows {
                        self.codeBuilder.renderShadow(self.finalTexture!, self.getTextureOfId("meta"))

                        self.mmView.update()
                        self.samples = self.maxSamples
                        return
                    }
                    
                    self.reflections += 1
                    if self.reflections < self.maxReflections {
                        
                        self.stage_HitAndNormals()
                        self.currentStage = .HitAndNormals
                    } else {
                        self.checkFinalTexture()
                        
                        // Sampling
                        if self.samples == 0 { self.checkFinalTexture(true) }
                        self.codeBuilder.renderSample(sampleTexture: self.finalTexture!, resultTexture: self.getTextureOfId("result"), frame: self.samples + 1)
                        self.mmView.update()
                        
                        self.samples += 1
                        
                        // Progress Callback
                        if let settings = self.settings {
                            if let cbProgress = settings.cbProgress {
                                cbProgress(self.samples, self.maxSamples)
                            }
                        }
                        
                        // Finished ?
                        if self.samples < self.maxSamples {
                            self.reflections = 0
                            
                            self.resetSample()
                            
                            self.stage_HitAndNormals()
                            self.currentStage = .HitAndNormals
                        } else {
                            // Finished
                            if let settings = self.settings {
                                if let cbFinished = settings.cbFinished {
                                    cbFinished(self.finalTexture!)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Compute the hitpoints and normals
    func stage_HitAndNormals()
    {
        if reflections == 0 {
            // Render the Camera Textures
            allocTextureId("rayOrigin", width, height, .rgba16Float)
            allocTextureId("rayDirection", width, height, .rgba16Float)
            if let inst = instanceMap["camera3D"] {
                codeBuilder.render(inst, getTextureOfId("rayOrigin"), outTextures: [getTextureOfId("rayDirection")])
            }
        }
        
        // Render the SkyDome into backTexture
        allocTextureId("back", width, height, .rgba16Float)
        if let inst = instanceMap["pre"] {
            codeBuilder.render(inst, getTextureOfId("back"), inTextures: [getTextureOfId("rayDirection")])
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
        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection")], optionalState: "computeAO")
            
            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        nextStage()
    }
    
    /// Compute shadows and materials
    func stage_computeShadowsAndMaterials()
    {
        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
     
        func sampleLightAndMaterial(lightBuffer: MTLBuffer)
        {
            // Shadows
            
            // Reset the shadow data to 1.0 in the meta data while not touching anything else (ambient etc).
            codeBuilder.renderClearShadow(texture: getTextureOfId("meta"))

            objectIndex = 0
            shapeText = "shape_" + String(objectIndex)
            while let inst = instanceMap[shapeText] {
                
                codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection")], inBuffers: [lightBuffer], optionalState: "computeShadow")
                
                objectIndex += 1
                shapeText = "shape_" + String(objectIndex)
            }
            
            // Materials
            
            objectIndex = 0
            shapeText = "shape_" + String(objectIndex)
            
            while let inst = instanceMap[shapeText] {
                    
                codeBuilder.render(inst, getTextureOfId("color"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("mask")], inBuffers: [lightBuffer], optionalState: "computeMaterial")

                objectIndex += 1
                shapeText = "shape_" + String(objectIndex)
            }
        }
        
        
        let sunDirection = getGlobalVariableValue(withName: "Sun.sunDirection")
        let sunStrength : Float = getGlobalVariableValue(withName: "Sun.sunStrength")!.x
        var sunColor : SIMD4<Float>? = getGlobalVariableValue(withName: "Sun.sunColor")
        if sunColor != nil {
            sunColor!.x *= sunStrength
            sunColor!.y *= sunStrength
            sunColor!.z *= sunStrength
        } else {
            sunColor = SIMD4<Float>(sunStrength,sunStrength,sunStrength,1)
        }
        
        let stage = globalApp!.project.selected!.getStage(.LightStage)
        let lights = stage.getChildren()

        // X: Key Light
        // Y: Directional, Spherical
        // Z: Current Light Index
        // W: Maximum Light Index

        var lightdata : [SIMD4<Float>] = [sunDirection!, SIMD4<Float>(0,0,0,Float(lights.count)), sunColor!]
        var lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        
        // Sample the sun
        sampleLightAndMaterial(lightBuffer: lightBuffer)
        
        // Sample the light sources
        
        for (index, lightItem) in lights.enumerated() {
            
            let component = lightItem.components[lightItem.defaultName]!
            let t = getTransformedComponentValues(component)
            
            var lightColor = getTransformedComponentProperty(component, "lightColor")
            let lightStrength = getTransformedComponentProperty(component, "lightStrength")
            lightColor.x *= lightStrength.x
            lightColor.y *= lightStrength.x
            lightColor.z *= lightStrength.x

            lightdata = [SIMD4<Float>(t["_posX"]!, t["_posY"]!, t["_posZ"]!, 0), SIMD4<Float>(1,1,Float(index+1), Float(lights.count)), lightColor]
            lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            
            sampleLightAndMaterial(lightBuffer: lightBuffer)
        }
        
        // Render it all
        if let inst = instanceMap["render"] {
            codeBuilder.render(inst, getTextureOfId("result"), inTextures: [getTextureOfId("color")])
        }
        
        nextStage()
    }
    
    override func cancel()
    {
        renderId += 1
    }
    
    override func resetIds()
    {
        idCounter = 0
    }
}
