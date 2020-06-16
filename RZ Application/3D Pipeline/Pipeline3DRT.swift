//
//  PipelineCloud3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PRTInstance {
    
    var cameraOrigin        : float3 = float3(0,0,0)
    var cameraLookAt        : float3 = float3(0,0,0)
    
    var screenSize          : float2 = float2(0,0)
    
    var projectionMatrix    : matrix_float4x4 = matrix_identity_float4x4
    var viewMatrix          : matrix_float4x4 = matrix_identity_float4x4

    var depthTexture        : MTLTexture? = nil
    
}

class Pipeline3DRT          : Pipeline
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
    
    var cameraComponent     : CodeComponent!
    
    var backgroundShader    : BackgroundShader? = nil
    var shaders             : [BaseShader] = []
    
    var prtInstance         : PRTInstance!

    override init(_ mmView: MMView)
    {
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
        dummyTerrainTexture = checkTextureSize(10, 10, nil, .rg8Sint)
    }
    
    override func setMinimalPreview(_ mode: Bool = false)
    {
        /*
        if mode == true {
            maxStage = .HitAndNormals
        } else {
            maxStage = .Reflection
        }*/
        globalApp!.currentEditor.render()
    }
    
    // Build the pipeline elements
    override func build(scene: Scene)
    {
        self.scene = scene
        let preStage = scene.getStage(.PreStage)
        let result = getFirstItemOfType(preStage.getChildren(), .Camera3D)
        cameraComponent = result.1!
        
        shaders = []
        
        prtInstance = PRTInstance()
        
        backgroundShader = BackgroundShader(instance: prtInstance, scene: scene, camera: cameraComponent)
        
        let shapeStage = scene.getStage(.ShapeStage)
        for item in shapeStage.getChildren() {
            
            if 1 > 0 { //item.builderInstance == nil {
                // Object
                if item.getComponentList("shapes") != nil {

                    let shader = ObjectShader(instance: prtInstance, scene: scene, object: item, camera: cameraComponent)
                    shaders.append(shader)

                    //item.builderInstance = instance
                    //instance.rootObject = item
                } else
                if let ground = item.components[item.defaultName], ground.componentType == .Ground3D {
                    // Ground Object

                    let shader = GroundShader(instance: prtInstance, scene: scene, object: item, camera: cameraComponent)
                    shaders.append(shader)
                }
            } else {
                /*
                instanceMap["shape_\(index)"] = item.builderInstance
                
                item.builderInstance!.ids.forEach { (key, value) in codeBuilder.sdfStream.ids[key] = value }

                #if DEBUG
                print("reusing", "shape_\(index)")
                #endif*/
            }
        }
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
        width = round(widthIn); height = round(heightIn)
        
        let camHelper = CamHelper3D()
        camHelper.initFromComponent(aspect: width / height, component: cameraComponent)
        camHelper.updateProjection()
        
        prtInstance.cameraOrigin = camHelper.eye
        prtInstance.cameraLookAt = camHelper.center

        prtInstance.screenSize = float2(width, height)

        prtInstance.projectionMatrix = camHelper.projMatrix
        prtInstance.viewMatrix = camHelper.getTransform().inverse

        prtInstance.depthTexture = checkTextureSize(width, height, prtInstance.depthTexture, .rgba16Float)
        
        checkFinalTexture(true)
        
        globalApp!.executionTime = 0
        
        if let background = backgroundShader, background.shaderState == .Compiled {
            background.render(texture: finalTexture!)
        }
        
        for shader in shaders {
            if shader.shaderState == .Compiled {
                shader.render(texture: finalTexture!)
            }
        }

        #if DEBUG
        //print("Execution Time: ", globalApp!.executionTime * 1000)
        #endif
        //var points : [Float] = []
        //pointCloudBuilder.render(points: points, texture: finalTexture!, camera: cameraComponent)
    }
    
    func checkFinalTexture(_ clear: Bool = false)
    {
        let needsResize = width != Float(finalTexture!.width) || height != Float(finalTexture!.height)
        finalTexture = checkTextureSize(width, height, finalTexture, .bgra8Unorm)
        if needsResize || clear {
            codeBuilder.renderClear(texture: finalTexture!, data: SIMD4<Float>(0, 0, 0, 1))
        }
    }
}
