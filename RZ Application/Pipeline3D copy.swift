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
        case None, Compiling, Compiled, HitAndNormals, AO, Shadows, Materials, Reflection
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
    
    var objectCounter       : Int = -1
    var lightCounter        : Int = -1

    var renderIsRunning     : Bool = false
    
    let waitTime            : Double = 0.05
    
    var lineNumber          : Float = 0

    override init(_ mmView: MMView)
    {
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
        dummyTerrainTexture = checkTextureSize(10, 10, nil, .r8Sint)
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
        if globalApp!.hasValidScene == false || globalApp!.viewsAreAnimating == true {
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
                if transform.values["_bbox"] == nil {
                    transform.values["_bbox"] = 5
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
        if globalApp!.hasValidScene == false || globalApp!.viewsAreAnimating == true {
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
                print("started")
                self.startId = self.renderId
                self.resetSample()

                self.allocTextureId("color", self.width, self.height, .rgba16Float)
                self.allocTextureId("mask", self.width, self.height, .rgba16Float)
                self.allocTextureId("id", self.width, self.height, .rgba16Float)
                
                self.renderIsRunning = true
                self.lineNumber = 0
                self.objectCounter = 0
                self.stage_HitAndNormals()
                self.currentStage = .HitAndNormals
                self.startedRender = false
            }
            
            func tryToStartRender()
            {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    print("try to start")
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
            print("renderer forced to stop")
            return true
        } else { return false }
    }
    
    func nextStage()
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            if self.hasToFinish() { return }

            print( "Stage Finished:", self.currentStage, "Samples", self.samples, "Reflections:", self.reflections, "renderId", self.renderId)

            let nextStage : Stage? = Stage(rawValue: self.currentStage.rawValue + 1)
            
            if let nextStage = nextStage {
                self.objectCounter = 0
                self.lightCounter = 0
                if nextStage == .AO {
                    self.stage_computeAO()
                    self.currentStage = .AO
                } else
                if nextStage == .Shadows {
                    self.currentStage = .Shadows
                    self.stage_computeShadowsAndMaterials()
                } else
                if nextStage == .Materials {
                    self.currentStage = .Materials
                    self.stage_computeShadowsAndMaterials()
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
                    } else
                    if self.outputType == .FogDensity {
                        self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("density"))

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
                            print("render is finished")
                        }
                    }
                }
            }
        }
    }
    
    /// Compute the hitpoints and normals
    func stage_HitAndNormals()
    {
        if objectCounter == 0 {
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

            codeBuilder.renderClear(texture: getTextureOfId("depth"), data: SIMD4<Float>(1000, 1000, -1, -1))
            codeBuilder.renderClear(texture: getTextureOfId("meta"), data: SIMD4<Float>(1, 1, 0, 0))
        }

        let objectIndex : Int = objectCounter
        let shapeText : String = "shape_" + String(objectIndex)
        
        let jitter : Bool = maxStage != .HitAndNormals
        if let inst = instanceMap[shapeText] {
            
            var terrainTexture : MTLTexture? = dummyTerrainTexture
            if let terrain = globalApp!.artistEditor.getTerrain(), objectIndex == 0 {
                terrainTexture = terrain.getTexture()
            }

            inst.lineNumber = lineNumber
            codeBuilder.render(inst, getTextureOfId("depth"), inTextures: [getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), terrainTexture!], jitter: jitter, finishedCB: { (timer) in

                if self.hasToFinish() == false {
                    
                    self.objectCounter += 1
                    let shapeText : String = "shape_" + String(self.objectCounter)
                    
                    if self.instanceMap[shapeText] != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.waitTime) {
                            self.stage_HitAndNormals()
                        }
                    } else {
                        if self.samples == 0 && self.reflections == 0 {
                            // On first pass copy the depth buffer to id, which the UI can use for object selection
                            self.codeBuilder.renderCopy(self.getTextureOfId("id"), self.getTextureOfId("depth"))
                        }
                        
                        self.allocTextureId("result", self.width, self.height, .rgba16Float)
                        if self.maxStage == .HitAndNormals {
                            // Preview Render: Fake Lighting + AO
                            self.codeBuilder.compute.run( self.codeBuilder.previewState!, outTexture: self.getTextureOfId("result"), inTextures: [self.getTextureOfId("depth")!, self.getTextureOfId("back"), self.getTextureOfId("normal"), self.getTextureOfId("meta")], finishedCB: { (timer) in

                                self.checkFinalTexture()
                                self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("result"))
                                self.mmView.update()
                                self.renderIsRunning = false
                            } )
                        } else {
                            self.nextStage()
                        }
                    }
                }
            } )
        }
    }
    
    /// Compute the AO stage
    func stage_computeAO()
    {
        let objectIndex : Int = 0
        let shapeText : String = "shape_" + String(objectIndex)
        
        if let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection")], optionalState: "computeAO", finishedCB: { (timer) in
            
                if self.hasToFinish() == false {
                    self.objectCounter += 1
                    let shapeText : String = "shape_" + String(self.objectCounter)

                    if self.instanceMap[shapeText] != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.waitTime) {
                            self.stage_computeAO()
                        }
                    } else {
                        self.nextStage()
                    }
                }
            } )
        }
    }
    
    /// Compute shadows and materials
    func stage_computeShadowsAndMaterials()
    {
        print("stage_computeShadowsAndMaterials", lightCounter, objectCounter, currentStage)
        func sampleLightAndMaterial(lightBuffer: MTLBuffer)
        {
            if currentStage == .Shadows {
                // Shadows
                
                if objectCounter == 0 {
                    // Reset the shadow data to 1.0 in the meta data while not touching anything else (ambient etc).
                    codeBuilder.renderClearShadow(texture: getTextureOfId("meta"))
                    codeBuilder.renderClear(texture: getTextureOfId("density"), data: SIMD4<Float>(0,0,0,1))
                }

                let shapeText = "shape_" + String(objectCounter)
                if let inst = instanceMap[shapeText] {
                    
                    print("render", objectCounter)
                    codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("density")], inBuffers: [lightBuffer], optionalState: "computeShadow", finishedCB: { (timer) in
                    
                        if self.hasToFinish() == false {

                            self.objectCounter += 1
                            let shapeText : String = "shape_" + String(self.objectCounter)

                            if self.instanceMap[shapeText] == nil {
                                self.lightCounter += 1
                                self.objectCounter = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + self.waitTime) {
                                self.stage_computeShadowsAndMaterials()
                            }
                        }
                    } )
                }
            } else
            if currentStage == .Materials {
                // Materials
                
                let shapeText = "shape_" + String(objectCounter)
                if let inst = instanceMap[shapeText] {
                        
                    codeBuilder.render(inst, getTextureOfId("color"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("mask"), getTextureOfId("density")], inBuffers: [lightBuffer], optionalState: "computeMaterial", finishedCB: { (timer) in
                        
                        if self.hasToFinish() == false {
                            self.objectCounter += 1
                            let shapeText : String = "shape_" + String(self.objectCounter)

                            if self.instanceMap[shapeText] == nil {
                                self.lightCounter += 1
                                self.objectCounter = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + self.waitTime) {
                                self.stage_computeShadowsAndMaterials()
                            }
                        }
                    } )
                }
            }
        }
        
        let stage = globalApp!.project.selected!.getStage(.LightStage)
        let lights = stage.getChildren()
        
        // Setup the density, is passed as .w in the light position
        var fogDensity : Float = 0.0
        //if reflections == 0 {
            if let fogVar = getGlobalVariableValue(withName: "World.worldFogDensity") {
                fogDensity = fogVar.x
            }
        //}
        
        if lightCounter == 0 {
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
                        
            sunDirection!.w = fogDensity
            //

            // X: Key Light
            // Y: Directional, Spherical
            // Z: Current Light Index
            // W: Maximum Light Index

            let lightdata : [SIMD4<Float>] = [sunDirection!, SIMD4<Float>(0,0,0,Float(lights.count)), sunColor!]
            let lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            
            // Sample the sun
            sampleLightAndMaterial(lightBuffer: lightBuffer)
        } else {
            // Sample the light sources
            
            let index : Int = lightCounter - 1
            if index < lights.count {
                         
                let lightItem = lights[index]
                
                let component = lightItem.components[lightItem.defaultName]!
                let t = getTransformedComponentValues(component)
                
                var lightColor = getTransformedComponentProperty(component, "lightColor")
                let lightStrength = getTransformedComponentProperty(component, "lightStrength")
                lightColor.x *= lightStrength.x
                lightColor.y *= lightStrength.x
                lightColor.z *= lightStrength.x

                let lightdata = [SIMD4<Float>(t["_posX"]!, t["_posY"]!, t["_posZ"]!, fogDensity), SIMD4<Float>(1,1,Float(index+1), Float(lights.count)), lightColor]
                let lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
                
                sampleLightAndMaterial(lightBuffer: lightBuffer)
            } else {
                if currentStage == .Materials {
                    codeBuilder.renderCopyGamma(getTextureOfId("result"), getTextureOfId("color"))
                }
                nextStage()
            }
        }
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
