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
    override func build(scene: Scene, monitor: CodeFragment? = nil)
    {
        renderId += 1
        
        let modeId : String = getCurrentModeId()
        let typeId : CodeComponent.ComponentType = globalApp!.currentSceneMode == .TwoD ? .SDF2D : .SDF3D

        instanceMap = [:]
        computeMonitorComponents(monitorFragment)
        
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
        instanceMap["camera3D"] = codeBuilder.build(cameraComponent, camera: cameraComponent, monitor: monitorFragment)
        
        var backComponent : CodeComponent? = nil

        // SkyDome
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome {
                backComponent = comp
                instanceMap["pre"] = codeBuilder.build(comp, camera: cameraComponent, monitor: monitorFragment)
                break
            }
        }
        
        codeBuilder.sdfStream.monitor = monitorFragment
        
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
    override func render(_ widthIn: Float,_ heightIn: Float)
    {
        renderId += 1
        width = round(widthIn); height = round(heightIn)
            
        reflections = 0
        samples = 0

        monitorTexture = checkTextureSize(width, height, monitorTexture, .rgba16Float)

        allocTextureId("color", width, height, .rgba16Float)
        allocTextureId("mask", width, height, .rgba16Float)
        allocTextureId("id", width, height, .rgba16Float)

        if justStarted {
            checkFinalTexture(true)
            justStarted = false
        }
        
        if startedRender == false {
            
            // Get Render Values
            if let renderComp = getComponent(name: "Renderer") {
                maxReflections = getComponentPropertyInt(component: renderComp, name: "reflections", defaultValue: 2)
                maxSamples = getComponentPropertyInt(component: renderComp, name: "antiAliasing", defaultValue: 4)
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
        codeBuilder.renderClear(texture: monitorTexture!, data: SIMD4<Float>(0, 0, 0, 0))
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
                    
                    // Write the monitor data after the first reflection and pass
                    if self.monitorFragment != nil && self.samples == 0 && self.reflections == 0 {
                        if let monitorUI = globalApp!.developerEditor.codeProperties.nodeUIMonitor {
                            self.monitorTextureFinal = self.checkTextureSize(self.width, self.height, self.monitorTextureFinal, .rgba32Float)
                            self.codeBuilder.renderCopy(self.monitorTextureFinal!, self.monitorTexture!, syncronize: true)
                            monitorUI.setTexture(self.monitorTextureFinal!)
                        }
                    }
                    
                    // Show reflection updates for sample 0
                    /*
                    if self.samples == 0 {
                        if self.reflections == 0 { self.checkFinalTexture(true) }
                        self.codeBuilder.renderCopy(self.finalTexture!, self.getTextureOfId("result"))
                        self.mmView.update()
                    }*/
                    
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
        if reflections == 0 {
            // Render the Camera Textures
            allocTextureId("rayOrigin", width, height, .rgba16Float)
            allocTextureId("rayDirection", width, height, .rgba16Float)
            if let inst = instanceMap["camera3D"] {
                codeBuilder.render(inst, getTextureOfId("rayOrigin"), outTextures: [getTextureOfId("rayDirection"), monitorTexture!])
            }
        }
        
        // Render the SkyDome into backTexture
        allocTextureId("back", width, height, .rgba16Float)
        if let inst = instanceMap["pre"] {
            codeBuilder.render(inst, getTextureOfId("back"), inTextures: [getTextureOfId("rayDirection"), monitorTexture!])
        }
        
        allocTextureId("depth", width, height, .rgba16Float)
        allocTextureId("normal", width, height, .rgba16Float)
        allocTextureId("meta", width, height, .rgba16Float)
        
        codeBuilder.renderClear(texture: getTextureOfId("depth"), data: SIMD4<Float>(10000, 1000000, -1, -1))
        codeBuilder.renderClear(texture: getTextureOfId("meta"), data: SIMD4<Float>(1, 1, 0, 0))

        var objectIndex : Int = 0
        var shapeText : String = "shape_" + String(objectIndex)
        
        while let inst = instanceMap[shapeText] {
            
            codeBuilder.render(inst, getTextureOfId("depth"), inTextures: [getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), monitorTexture!])

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
            
            codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), monitorTexture!], optionalState: "computeAO")
            
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
            
            objectIndex = 0
            shapeText = "shape_" + String(objectIndex)
            while let inst = instanceMap[shapeText] {
                
                codeBuilder.render(inst, getTextureOfId("meta"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), monitorTexture!], inBuffers: [lightBuffer], optionalState: "computeShadow")
                
                objectIndex += 1
                shapeText = "shape_" + String(objectIndex)
            }
            
            // Materials
            
            objectIndex = 0
            shapeText = "shape_" + String(objectIndex)
            while let inst = instanceMap[shapeText] {
                
                codeBuilder.render(inst, getTextureOfId("color"), inTextures: [getTextureOfId("depth"), getTextureOfId("normal"), getTextureOfId("meta"), getTextureOfId("rayOrigin"), getTextureOfId("rayDirection"), getTextureOfId("mask"), monitorTexture!], inBuffers: [lightBuffer], optionalState: "computeMaterial")

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
        
        // X: Key Light
        // Y: Directional, Spherical
        // Z: Attenuation
        // W: Light Count

        var lightdata : [SIMD4<Float>] = [sunDirection!, SIMD4<Float>(0,0,0,0), sunColor!]
        var lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        
        // Sample the sun
        sampleLightAndMaterial(lightBuffer: lightBuffer)
        
        // Sample the light sources
        
        let stage = globalApp!.project.selected!.getStage(.LightStage)
        let lights = stage.getChildren()

        for (index, lightItem) in lights.enumerated() {
            
            let component = lightItem.components[lightItem.defaultName]!
            let t = getTransformedComponentValues(component)
            
            var lightColor = getTransformedComponentProperty(component, "lightColor")
            let lightStrength = getTransformedComponentProperty(component, "lightStrength")
            lightColor.x *= lightStrength.x
            lightColor.y *= lightStrength.x
            lightColor.z *= lightStrength.x

            lightdata = [SIMD4<Float>(t["_posX"]!, t["_posY"]!, t["_posZ"]!, 0), SIMD4<Float>(1,1,0,Float(index+1)), lightColor]
            lightBuffer = codeBuilder.compute.device.makeBuffer(bytes: lightdata, length: lightdata.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            
            sampleLightAndMaterial(lightBuffer: lightBuffer)
        }
        
        // Render it all
        if let inst = instanceMap["render"] {
            codeBuilder.render(inst, getTextureOfId("result"), inTextures: [getTextureOfId("color")])
        }
        
        nextStage()
    }
}
