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
        
    var width               : Float = 0
    var height              : Float = 0
    
    var reflections         : Int = 0
    var maxReflections      : Int = 4
    
    var maxSamples          : Int = 4

    var renderId            : UInt = 0
    var justStarted         : Bool = true
    var startedRender       : Bool = false
    
    var startId             : UInt = 0
    
    var settings            : PipelineRenderSettings? = nil
    
    var compiledSuccessfully: Bool = true
    
    var idCounter           : Int = 0
    
    var scene               : Scene!
    
    var dummyTerrainTexture : MTLTexture? = nil
    
    var lineNumber          : Float = 0
    var renderIsRunning     : Bool = false
    
    var renderIsRunning     : Bool = false
    var startedRender       : Bool = false

    override init(_ mmView: MMView)
    {
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
        dummyTerrainTexture = checkTextureSize(10, 10, nil, .rg8Sint)
    }
    
    override func setMinimalPreview(_ mode: Bool = false)
    {
        if mode == true {
            maxStage = .HitAndNormals
        } else {
            maxStage = .Reflection
        }
        globalApp!.currentEditor.render()
    }
    
    // Build the pipeline elements
    override func build(scene: Scene)
    {
        if globalApp!.hasValidScene == false {
            return
        }

        self.scene = scene
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
        var cameraComponent = result.1!
        
        if let globalCamera = globalApp!.globalCamera {
            cameraComponent = globalCamera
        }
        
        if let stageItem = result.0 {
            if stageItem.builderInstance == nil {
                stageItem.builderInstance = codeBuilder.build(cameraComponent, camera: cameraComponent)
                instanceMap["camera3D"] = stageItem.builderInstance
                #if DEBUG
                print("compile camera")
                #endif
            } else {
                instanceMap["camera3D"] = stageItem.builderInstance
                #if DEBUG
                print("reuse camera")
                #endif
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
                    #if DEBUG
                    print("compile background")
                    #endif
                } else {
                    instanceMap["pre"] = item.builderInstance
                    #if DEBUG
                    print("reuse background")
                    #endif
                }
                break
            }
        }
                
        // Objects
        let shapeStage = scene.getStage(.ShapeStage)
        codeBuilder.sdfStream.reset()
        for (index, item) in shapeStage.getChildren().enumerated() {
            
            // Insert default value for bounding box to the transform component if not present
            if let transform = item.components[item.defaultName] {
                if transform.values["_bb_x"] == nil {
                    transform.values["_bb_x"] = 5
                    transform.values["_bb_y"] = 5
                    transform.values["_bb_z"] = 5
                }
            }
            
            if item.builderInstance == nil {
                // Normal Object
                if let shapes = item.getComponentList("shapes") {
                    let instance = CodeBuilderInstance()
                    instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                    codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent, backgroundComponent: backComponent, idStart: idCounter, scene: scene)
                    codeBuilder.sdfStream.pushStageItem(item)
                    for shape in shapes {
                        codeBuilder.sdfStream.pushComponent(shape)
                    }
                    processChildren(item)
                    codeBuilder.sdfStream.pullStageItem()
                    instanceMap["shape_\(index)"] = instance
                    codeBuilder.sdfStream.closeStream(async: true)
                    
                    idCounter += codeBuilder.sdfStream.idCounter - idCounter + 1
                    item.builderInstance = instance
                    instance.rootObject = item
                } else
                if let ground = item.components[item.defaultName]
                {
                    // Ground Object
                    let instance = CodeBuilderInstance()
                    instance.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
                    codeBuilder.sdfStream.openStream(typeId, instance, codeBuilder, camera: cameraComponent, groundComponent: ground, backgroundComponent: backComponent, idStart: 0, scene: scene)
                    codeBuilder.sdfStream.pushStageItem(item)
                    //for shape in shapes {
                    //    codeBuilder.sdfStream.pushComponent(shape)
                    //}
                    codeBuilder.sdfStream.pullStageItem()
                    instanceMap["shape_\(index)"] = instance
                    codeBuilder.sdfStream.closeStream(async: true)
                    
                    idCounter += 10//codeBuilder.sdfStream.idCounter - idCounter + 1
                    item.builderInstance = instance
                    instance.rootObject = item
                }
            } else {
                instanceMap["shape_\(index)"] = item.builderInstance
                
                item.builderInstance!.ids.forEach { (key, value) in codeBuilder.sdfStream.ids[key] = value }

                #if DEBUG
                print("reusing", "shape_\(index)")
                #endif
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
        
        // PostFX
        let postStage = scene.getStage(.PostStage)
        if let item = postStage.children2D.first {
            if let list = item.componentLists["PostFX"] {
                for c in list {
                    if c.builderInstance == nil {
                        c.builderInstance = codeBuilder.build(c)
                    }
                }
            }
        }
        
        compiledSuccessfully = true

        // Check if we succeeded
        /*
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
        }*/
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
        if globalApp!.hasValidScene == false {
            return
        }
                
        // Finished compiling ?
        compiledSuccessfully = true
        for (_, instance) in instanceMap {
            if instance.finishedCompiling {
                if instance.computeState == nil {
                    compiledSuccessfully = false
                }
            } else {
                return
            }
            for (_, inst) in instance.additionalStates {
                if inst == nil {
                    compiledSuccessfully = false
                }
            }
        }
                
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
            
            func startRender()
            {
                self.startId = self.renderId

                self.allocTextureId("color", self.width, self.height, .rgba16Float)
                self.allocTextureId("mask", self.width, self.height, .rgba16Float)
                self.allocTextureId("id", self.width, self.height, .rgba16Float)

                self.allocTextureId("depth", self.width, self.height, .rgba16Float)

                self.renderIsRunning = true
                self.startedRender = false

                self.resetSample()

                self.lineNumber = 0;
                self.stage_HitAndNormals()
                self.currentStage = .HitAndNormals
            }
            
            func tryToStartRender()
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if self.renderIsRunning {
                        tryToStartRender()
                    } else {
                        startRender()
                    }
                }
            }
            
            tryToStartRender()
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
    
    func hasToFinish() -> Bool
    {
        if self.startId < self.renderId || self.samples >= self.maxSamples {
            renderIsRunning = false
            return true
        } else { return false }
    }
    
    func nextStage()
    {
        DispatchQueue.main.async {//After(deadline: .now() + 0.05) {

            //print( "Stage Finished:", self.currentStage, "Samples", self.samples, "Reflections:", self.reflections, "renderId", self.renderId)

            // Preview Render: Fake Lighting
            if self.maxStage == .HitAndNormals {
                
                if self.lineNumber + 50 < self.height {
                                        
                    self.lineNumber += 50
                    
                    self.stage_HitAndNormals()
                    self.currentStage = .HitAndNormals

                    return
                }
                
                self.codeBuilder.compute.run( self.codeBuilder.previewState!, outTexture: self.getTextureOfId("result"), inTextures: [self.getTextureOfId("depth")!, self.getTextureOfId("back"), self.getTextureOfId("normal"), self.getTextureOfId("meta")])
                self.codeBuilder.compute.commandBuffer.waitUntilCompleted()

                self.checkFinalTexture()
                self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("result"))
                self.mmView.update()
                
                self.lineNumber = 0
                self.renderIsRunning = false
                                                
                return
            }
            
            if self.outputType != .FinalImage {
                if self.lineNumber + 50 >= self.height {
                    if self.outputType == .DepthMap {
                        self.codeBuilder.renderDepthMap(self.finalTexture!, self.getTextureOfId("id"))

                        self.mmView.update()
                        self.samples = self.maxSamples
                        self.renderIsRunning = false
                        return
                    } else
                    if self.outputType == .AO {
                        self.codeBuilder.renderAO(self.finalTexture!, self.getTextureOfId("meta"))

                        self.mmView.update()
                        self.samples = self.maxSamples
                        self.renderIsRunning = false
                        return
                    } else
                    if self.outputType == .Shadows {
                        self.codeBuilder.renderShadow(self.finalTexture!, self.getTextureOfId("meta"))

                        self.mmView.update()
                        self.samples = self.maxSamples
                        self.renderIsRunning = false
                        return
                    } else
                    if self.outputType == .FogDensity {
                        self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("density"))

                        self.mmView.update()
                        self.samples = self.maxSamples
                        self.renderIsRunning = false
                        return
                    }
                }
            }
              
            if self.hasToFinish() { return }
            
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
                        if self.reflections > 0 {
                            self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("result"))
                            self.mmView.update()
                        }
                    }*/
                    
                    self.reflections += 1
                    if self.reflections < self.maxReflections {
                        self.stage_HitAndNormals()
                        self.currentStage = .HitAndNormals
                    } else {
                        self.checkFinalTexture()
                        
                        if self.lineNumber + 50 < self.height {
                            self.lineNumber += 50
                            self.reflections = 0
                                                 
                            self.stage_HitAndNormals()
                            self.currentStage = .HitAndNormals

                            return
                        }
                        
                        self.lineNumber = 0

                        // Sampling
                        if self.samples == 0 { self.checkFinalTexture(true) }
                        self.finish()
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
                            self.renderIsRunning = false
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
        allocTextureId("density", width, height, .rgba16Float)
        allocTextureId("result", width, height, .rgba16Float)
        
        codeBuilder.renderClear(texture: getTextureOfId("meta"), data: SIMD4<Float>(1, 1, 1, 0))

        if maxStage != .HitAndNormals || lineNumber == 0 {
            codeBuilder.renderClear(texture: getTextureOfId("depth"), data: SIMD4<Float>(1000, 1000, -1, -1))
        }
        
        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        let jitter : Bool = maxStage != .HitAndNormals
        while let inst = instanceMap[shapeText] {
            
            // Disabled ?
            if let object = inst.rootObject {
                if object.values["disabled"] == 1 {
                    objectIndex += 1
                    shapeText = "shape_" + String(objectIndex)
                    continue
                }
            }
            
            var terrainTexture : MTLTexture? = dummyTerrainTexture
            if let terrain = globalApp!.artistEditor.getTerrain(), objectIndex == 0 {
                terrainTexture = terrain.getTexture()
            }
            
            inst.lineNumber = lineNumber
            codeBuilder.render(inst, getTextureOfId("depth"), inTextures: [getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), terrainTexture!], jitter: jitter)

            objectIndex += 1
            shapeText = "shape_" + String(objectIndex)
        }
        
        if samples == 0 && reflections == 0 {
            // On first pass copy the depth buffer to id, which the UI can use for object selection
            self.codeBuilder.renderCopyLine(getTextureOfId("id"), getTextureOfId("depth"), lineNumber: lineNumber)
        }
        
        nextStage()
    }
    
    /// Compute the AO stage
    func stage_computeAO()
    {
        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            // Disabled ?
            if let object = inst.rootObject {
                if object.values["disabled"] == 1 {
                    objectIndex += 1
                    shapeText = "shape_" + String(objectIndex)
                    continue
                }
            }
            
            inst.lineNumber = lineNumber
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
            
            if lineNumber == 0 {
                codeBuilder.renderClearShadow(texture: getTextureOfId("meta"))
            }
            
            /*
            // Reset the fog density data
            var fogDensity : Float = 0.02
            if let fogVar = getGlobalVariableValue(withName: "World.worldFogDensity") {
                fogDensity = fogVar.x
            }
            if fogDensity > 0.0 && reflections == 0 {
                codeBuilder.renderClear(texture: getTextureOfId("density"), data: SIMD4<Float>(fogDensity,0,1,1))
            } else {
                codeBuilder.renderClear(texture: getTextureOfId("density"), data: SIMD4<Float>(0,0,0,1))
            }
            */

            objectIndex = 0
            shapeText = "shape_" + String(objectIndex)
            while let inst = instanceMap[shapeText] {
                
                // Disabled ?
                if let object = inst.rootObject {
                    if object.values["disabled"] == 1 {
                        objectIndex += 1
                        shapeText = "shape_" + String(objectIndex)
                        continue
                    }
                }
                
                inst.lineNumber = lineNumber
                codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("density")], inBuffers: [lightBuffer], optionalState: "computeShadow")
                
                objectIndex += 1
                shapeText = "shape_" + String(objectIndex)
            }
            /*
            if fogDensity > 0.0 && reflections == 0 {
                let data : [SIMD4<Float>] = [SIMD4<Float>(Float.random(in: 0.0...1.0),Float.random(in: 0.0...1.0),Float.random(in: 0.0...1.0),Float.random(in: 0.0...1.0))]
                let buffer = codeBuilder.compute.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
                
                codeBuilder.compute.run( codeBuilder.densityState!, outTexture: getTextureOfId("density"), inBuffer: buffer, inTextures: [getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("depth")], inBuffers: [lightBuffer])
                codeBuilder.compute.commandBuffer.waitUntilCompleted()
            }*/
            
            // Materials
            
            objectIndex = 0
            shapeText = "shape_" + String(objectIndex)
            
            while let inst = instanceMap[shapeText] {
                    
                // Disabled ?
                if let object = inst.rootObject {
                    if object.values["disabled"] == 1 {
                        objectIndex += 1
                        shapeText = "shape_" + String(objectIndex)
                        continue
                    }
                }
                
                inst.lineNumber = lineNumber
                codeBuilder.render(inst, getTextureOfId("color"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("mask"), getTextureOfId("density")], inBuffers: [lightBuffer], optionalState: "computeMaterial")

                objectIndex += 1
                shapeText = "shape_" + String(objectIndex)
            }
        }
        
        var sunDirection = getGlobalVariableValue(withName: "Sun.sunDirection")
        let sunStrength : Float = getGlobalVariableValue(withName: "Sun.sunStrength")!.x
        var sunColor : SIMD4<Float>? = getGlobalVariableValue(withName: "Sun.sunColor")
        if sunColor != nil {
            var norm = SIMD3<Float>(sunColor!.x, sunColor!.y, sunColor!.z)
            norm = normalize(norm)
            
            sunColor!.x = norm.x * sunStrength
            sunColor!.y = norm.y * sunStrength
            sunColor!.z = norm.z * sunStrength
        } else {
            sunColor = SIMD4<Float>(sunStrength,sunStrength,sunStrength,1)
        }
                
        // Setup the density, is passed as .w in the light position
        var fogDensity : Float = 0.0
        //if reflections == 0 {
            if let fogVar = getGlobalVariableValue(withName: "World.worldFogDensity") {
                fogDensity = fogVar.x
            }
        //}
        
        if lineNumber == 0 {
            codeBuilder.renderClear(texture: getTextureOfId("density"), data: SIMD4<Float>(0,0,0,1))
        }
        
        sunDirection!.w = fogDensity
        //
        
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

            lightdata = [SIMD4<Float>(t["_posX"]!, t["_posY"]!, t["_posZ"]!, fogDensity), SIMD4<Float>(1,1,Float(index+1), Float(lights.count)), lightColor]
            lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            
            sampleLightAndMaterial(lightBuffer: lightBuffer)
        }
        
        codeBuilder.renderCopyGammaLine(getTextureOfId("result"), getTextureOfId("color"), lineNumber: lineNumber)
        
        nextStage()
    }
    
    func finish()
    {
        // PostFX
        let postStage = scene.getStage(.PostStage)
        if let item = postStage.children2D.first {
            if let list = item.componentLists["PostFX"] {
                                
                let dest = getTextureOfId("result")!
                let source = getTextureOfId("color")!

                for c in list {
                    if let instance = c.builderInstance {
                        codeBuilder.render(instance, dest, inTextures: [source, source, getTextureOfId("id"), getTextureOfId("id")])
                        
                        // Copy the result back into color
                        codeBuilder.renderCopy(source, dest)
                    }
                }
            }
        }
                
        // Render it all
        if let inst = instanceMap["render"] {
            codeBuilder.render(inst, getTextureOfId("result"), inTextures: [getTextureOfId("color"), getTextureOfId("depth")])
        }
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
