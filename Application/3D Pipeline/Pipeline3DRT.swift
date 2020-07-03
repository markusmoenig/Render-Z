//
//  PipelineCloud3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PRTInstance {
    
    var fragmentUniforms    : String = """

    typedef struct {
        simd_float3         cameraOrigin;
        simd_float3         cameraLookAt;
        
        simd_float2         screenSize;
        float               maxDistance;
    } FragmentUniforms;

    typedef struct {
        int                 lightType;
        simd_float4         lightColor;
        simd_float4         directionToLight;
    } Light;

    typedef struct {
        int                 numberOfLights;
        Light               lights[10];
    } LightUniforms;

    """
    
    // Component Ids
    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]
    var idCounter           : Int = 0

    // Camera
    var cameraOrigin        : float3 = float3(0,0,0)
    var cameraLookAt        : float3 = float3(0,0,0)
    
    var screenSize          : float2 = float2(0,0)
    
    var projectionMatrix    : matrix_float4x4 = matrix_identity_float4x4
    var viewMatrix          : matrix_float4x4 = matrix_identity_float4x4

    var camOriginTexture    : MTLTexture? = nil
    var camDirTexture       : MTLTexture? = nil
    
    var reflDirTexture1     : MTLTexture? = nil
    var reflDirTexture2     : MTLTexture? = nil
    var currentReflDirTexture: MTLTexture? = nil
    var otherReflDirTexture : MTLTexture? = nil

    var depthTexture        : MTLTexture? = nil
    
    var localTexture        : MTLTexture? = nil
    
    var shapeTexture1       : MTLTexture? = nil
    var shapeTexture2       : MTLTexture? = nil
    var currentShapeTexture : MTLTexture? = nil
    var otherShapeTexture   : MTLTexture? = nil
    
    var shadowTexture1      : MTLTexture? = nil
    var shadowTexture2      : MTLTexture? = nil
    var currentShadowTexture: MTLTexture? = nil
    var otherShadowTexture  : MTLTexture? = nil
    
    var reflectionTexture1  : MTLTexture? = nil
    var reflectionTexture2  : MTLTexture? = nil
    var currentReflTexture  : MTLTexture? = nil
    var otherReflTexture    : MTLTexture? = nil

    var utilityShader       : UtilityShader!
}

class Pipeline3DRT          : Pipeline
{
    enum Stage : Int {
        case None, Compiling, Compiled, HitAndNormals, AO, ShadowsAndMaterials, Reflection
    }

    var currentStage        : Stage = .None
    var maxStage            : Stage = .Reflection
        
    var width               : Float = 0
    var height              : Float = 0
    
    var scene               : Scene!
    
    var dummyTerrainTexture : MTLTexture? = nil
    
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
        prtInstance.utilityShader = UtilityShader(instance: prtInstance, scene: scene, camera: cameraComponent)
        
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
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
        width = round(widthIn); height = round(heightIn)
        
        var shadersToTest = shaders
        if let background = backgroundShader {
            shadersToTest.append(background)
        }
        
        for shader in shadersToTest {
            for sh in shader.shaders {
                if sh.value.shaderState != .Compiled {
                    return
                }
            }
        }
        
        let camHelper = CamHelper3D()
        camHelper.initFromComponent(aspect: width / height, component: cameraComponent)
        camHelper.updateProjection()
        
        prtInstance.cameraOrigin = camHelper.eye
        prtInstance.cameraLookAt = camHelper.center

        prtInstance.screenSize = float2(width, height)

        prtInstance.projectionMatrix = camHelper.projMatrix
        prtInstance.viewMatrix = camHelper.getTransform().inverse

        prtInstance.camOriginTexture = checkTextureSize(width, height, prtInstance.camOriginTexture, .rgba16Float)
        prtInstance.camDirTexture = checkTextureSize(width, height, prtInstance.camDirTexture, .rgba16Float)

        prtInstance.depthTexture = checkTextureSize(width, height, prtInstance.depthTexture, .rgba16Float)
        
        // The texture objects use for their local distance estimations
        prtInstance.localTexture = checkTextureSize(width, height, prtInstance.localTexture, .rgba16Float)
        
        // The depth / shape textures which get ping ponged
        prtInstance.shapeTexture1 = checkTextureSize(width, height, prtInstance.shapeTexture1, .rgba16Float)
        prtInstance.shapeTexture2 = checkTextureSize(width, height, prtInstance.shapeTexture2, .rgba16Float)
        
        // The pointers to the current and the other depth / shape texture
        prtInstance.currentShapeTexture = prtInstance.shapeTexture1
        prtInstance.otherShapeTexture = prtInstance.shapeTexture2

        checkFinalTexture(true)
        
        prtInstance.utilityShader.cameraTextures()
        
        func swapShapeTextures()
        {
            if prtInstance.currentShapeTexture === prtInstance.shapeTexture1 {
                prtInstance.currentShapeTexture = prtInstance.shapeTexture2
                prtInstance.otherShapeTexture = prtInstance.shapeTexture1
            } else {
                prtInstance.currentShapeTexture = prtInstance.shapeTexture1
                prtInstance.otherShapeTexture = prtInstance.shapeTexture2
            }
        }
        
        print("Last Execution Time: ", globalApp!.executionTime * 1000)
        
        globalApp!.executionTime = 0
        
        if let background = backgroundShader {
            background.render(texture: finalTexture!)
        }
        
        // Get the depth
        for shader in shaders {
            shader.render(texture: finalTexture!)
            swapShapeTextures()
        }

        // Free the other shape texture
        if prtInstance.currentShapeTexture === prtInstance.shapeTexture1 {
            prtInstance.shapeTexture2 = nil
            prtInstance.otherShapeTexture = nil
        } else {
            prtInstance.shapeTexture1 = nil
            prtInstance.otherShapeTexture = nil
        }
        
        // The ao / shadow textures which get ping ponged
        prtInstance.shadowTexture1 = checkTextureSize(width, height, prtInstance.shadowTexture1, .rg16Float)
        prtInstance.shadowTexture2 = checkTextureSize(width, height, prtInstance.shadowTexture2, .rg16Float)
        
        // The pointers to the current and the other ao / shadow texture
        prtInstance.currentShadowTexture = prtInstance.shadowTexture1
        prtInstance.otherShadowTexture = prtInstance.shadowTexture2
        
        func swapShadowTextures()
        {
            if prtInstance.currentShadowTexture === prtInstance.shadowTexture1 {
                prtInstance.currentShadowTexture = prtInstance.shadowTexture2
                prtInstance.otherShadowTexture = prtInstance.shadowTexture1
            } else {
                prtInstance.currentShadowTexture = prtInstance.shadowTexture1
                prtInstance.otherShadowTexture = prtInstance.shadowTexture2
            }
        }
        
        prtInstance.utilityShader.clearShadow(shadowTexture: prtInstance.shadowTexture1!)
        
        // Calculate the shadows
        for shader in shaders {
            if let object = shader as? ObjectShader {
                object.shadowPass(texture: finalTexture!)
                swapShadowTextures()
            }
        }
        
        // Calculate the materials
        
        // The reflection textures which get ping ponged
        prtInstance.reflectionTexture1 = checkTextureSize(width, height, prtInstance.reflectionTexture1, .rgba16Float)
        prtInstance.reflectionTexture2 = checkTextureSize(width, height, prtInstance.reflectionTexture2, .rgba16Float)
        prtInstance.currentReflTexture = prtInstance.reflectionTexture1
        prtInstance.otherReflTexture = prtInstance.reflectionTexture2
        
        // Reflection direction textures
        prtInstance.reflDirTexture1 = checkTextureSize(width, height, prtInstance.reflDirTexture1, .rgba16Float)
        prtInstance.reflDirTexture2 = checkTextureSize(width, height, prtInstance.reflDirTexture2, .rgba16Float)
        prtInstance.currentReflDirTexture = prtInstance.reflDirTexture1
        prtInstance.otherReflDirTexture = prtInstance.reflDirTexture2
        
        func swapReflectionTextures()
        {
            if prtInstance.currentReflTexture === prtInstance.reflectionTexture1 {
                prtInstance.currentReflTexture = prtInstance.reflectionTexture2
                prtInstance.otherReflTexture = prtInstance.reflectionTexture1
            } else {
                prtInstance.currentReflTexture = prtInstance.reflectionTexture1
                prtInstance.otherReflTexture = prtInstance.reflectionTexture2
            }
        }
        
        func swapReflectionDirTextures()
        {
            if prtInstance.currentReflDirTexture === prtInstance.reflDirTexture1 {
                prtInstance.currentReflDirTexture = prtInstance.reflDirTexture2
                prtInstance.otherReflDirTexture = prtInstance.reflDirTexture1
            } else {
                prtInstance.currentReflDirTexture = prtInstance.reflDirTexture1
                prtInstance.otherReflDirTexture = prtInstance.reflDirTexture2
            }
        }
                
        // Calculate the materials
        for shader in shaders {
            shader.materialPass(texture: finalTexture!)
            swapReflectionDirTextures()
        }
        
        // Free the other reflection dir texture
        if prtInstance.currentReflDirTexture === prtInstance.reflDirTexture1 {
            prtInstance.reflDirTexture2 = nil
            prtInstance.otherReflDirTexture = nil
        } else {
            prtInstance.reflDirTexture1 = nil
            prtInstance.otherReflDirTexture = nil
        }
        
        prtInstance.shadowTexture1 = nil
        prtInstance.shadowTexture2 = nil
        prtInstance.currentShadowTexture = nil
        prtInstance.otherShadowTexture = nil
        
        // Calculate the reflection hits
        for shader in shaders {
            //if let ground = shader as? GroundShader {
                shader.reflectionPass(texture: finalTexture!)
                swapReflectionTextures()
            //}
        }
        
        // Calculate the reflection material colors and blend them in
        for shader in shaders {
            shader.reflectionMaterialPass(texture: finalTexture!)
        }
        
        // DONE

        textureMap["shape"] = prtInstance.currentShapeTexture!
        ids = prtInstance.ids
        
        postFX()
        
        #if DEBUG
        //print("Execution Time: ", globalApp!.executionTime * 1000)
        #endif
        //var points : [Float] = []
        //pointCloudBuilder.render(points: points, texture: finalTexture!, camera: cameraComponent)
    }

    // Post FX
    func postFX()
    {
        let postStage = scene.getStage(.PostStage)
        if let item = postStage.children2D.first {
            if let list = item.componentLists["PostFX"] {
                                
                let source = finalTexture!
                let dest = prtInstance.reflectionTexture1!
                
                for c in list {
                    if let instance = c.builderInstance {
                        codeBuilder.render(instance, dest, inTextures: [source, source, getTextureOfId("shape"), getTextureOfId("shape")])
                        
                        // Copy the result back into final
                        codeBuilder.renderCopy(source, dest)
                    }
                }
            }
        }
    }
    
    func checkFinalTexture(_ clear: Bool = false)
    {
        let needsResize = width != Float(finalTexture!.width) || height != Float(finalTexture!.height)
        finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
        if needsResize || clear {
            codeBuilder.renderClear(texture: finalTexture!, data: SIMD4<Float>(0, 0, 0, 1))
        }
    }
}
