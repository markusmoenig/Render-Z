//
//  PipelineCloud3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PFXInstance {
    
    var fragmentUniforms    : String = """

    typedef struct {
        simd_float3         cameraOrigin;
        simd_float3         cameraLookAt;
        
        simd_float2         screenSize;

        simd_float4         ambientColor;

        // bbox
        simd_float3         P;
        simd_float3         L;
        matrix_float3x3     F;

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

    typedef struct {
        int                 numberOfSpheres;
        simd_float3         position;
        simd_float3         rotation;
    } SphereUniforms;

    """
    
    // Component Ids
    var ids                 : [Int:(CodeComponent?)] = [:]

    // Camera
    var cameraOrigin        : float3 = float3(0,0,0)
    var cameraLookAt        : float3 = float3(0,0,0)
    
    var screenSize          : float2 = float2(0,0)
    
    var projectionMatrix    : matrix_float4x4 = matrix_identity_float4x4
    var viewMatrix          : matrix_float4x4 = matrix_identity_float4x4

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
    
    var maskTexture1        : MTLTexture? = nil
    var maskTexture2        : MTLTexture? = nil
    var currentMaskTexture  : MTLTexture? = nil
    var otherMaskTexture    : MTLTexture? = nil
    
    var utilityShader       : UtilityShader? = nil
    
    var commandQueue        : MTLCommandQueue? = nil
    var commandBuffer       : MTLCommandBuffer? = nil
    
    var quadVertexBuffer    : MTLBuffer? = nil
    var quadViewport        : MTLViewport? = nil
    
    var idSet               : [Int] = []
    
    init()
    {
        for i in 1...200 {
            idSet.append(i)
        }
    }
    
    func claimId() -> Int
    {
        return idSet.removeFirst()
    }
    
    func returnIds(_ arr: [Int])
    {
        for n in arr {
            idSet.insert(n, at: 0)
        }
    }
    
    func clean()
    {
        ids = [:]
    }
}

class PipelineFX            : Pipeline
{
    enum Stage : Int {
        case None, Compiling, Compiled, HitAndNormals, AO, ShadowsAndMaterials, Reflection
    }

    var ids                 : [Int:(CodeComponent?)] = [:]

    var currentStage        : Stage = .None
    var maxStage            : Stage = .Reflection
        
    var width               : Float = 0
    var height              : Float = 0
    
    var scene               : Scene!
        
    var cameraComponent     : CodeComponent!
    
    var shaders             : [BaseShader] = []
    var validShaders        : [BaseShader] = []

    var pFXInstance         : PFXInstance! = nil

    override init(_ mmView: MMView)
    {
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
        
        pFXInstance = PFXInstance()
    }
    
    override func setMinimalPreview(_ mode: Bool = false)
    {
        globalApp!.currentEditor.render()
    }
    
    // Build the pipeline elements
    override func build(scene: Scene)
    {
        self.scene = scene

        cameraComponent = nil
        
        if scene.items.isEmpty == false {
            if scene.items[0].componentType == .Camera3D {
                pFXInstance.utilityShader = nil
                cameraComponent = scene.items[0]
            }
        }
        
        if cameraComponent == nil {
            cameraComponent = CodeComponent(.Camera3D)
        }
        
        shaders = []
        validShaders = []
        
        pFXInstance.clean()
        
        if pFXInstance.utilityShader == nil {
            pFXInstance.utilityShader = UtilityShader(instance: pFXInstance, scene: scene, camera: cameraComponent)
        }

        validShaders.append(pFXInstance.utilityShader!)

        // Compile all shaders
        for item in scene.items {
            if item.shader == nil && item.componentType == .Shader {
                let shader = FXShader(instance: pFXInstance, scene: scene, uuid: item.uuid, camera: cameraComponent)
                item.shader = shader
                validShaders.append(item.shader!)
            }
        }
        
        /*
        if backgroundShader == nil || BackgroundShader.needsToCompile(scene: scene) == true {
            backgroundShader = nil
            backgroundShader = BackgroundShader(instance: pFXInstance, scene: scene, camera: cameraComponent)
            
            pFXInstance.utilityShader = nil
            pFXInstance.utilityShader = UtilityShader(instance: pFXInstance, scene: scene, camera: cameraComponent)
        } else {
            #if DEBUG
            print("reusing background")
            #endif
        }
        
        if postShader == nil || PostShader.needsToCompile(scene: scene) == true {
            postShader = nil
            postShader = PostShader(instance: pFXInstance, scene: scene)
        } else {
            #if DEBUG
            print("reusing postfx")
            #endif
        }*/
        
        //validShaders.append(pFXInstance.utilityShader!)
        //validShaders.append(backgroundShader!)
//        validShaders.append(postShader!)

        /*
        let shapeStage = scene.getStage(.ShapeStage)
        for item in shapeStage.getChildren() {
            
            if item.shader == nil {
                if item.getComponentList("shapes") != nil {
                    
                    #if DEBUG
                    print("compiling", item.name)
                    #endif
                    
                    // Object
                    if item.componentLists["nodes3D"] == nil || item.componentLists["nodes3D"]?.count == 0 {
                        item.addNodes3D()
                    }
                    
                    let shader = ObjectShader(instance: pFXInstance, scene: scene, object: item, camera: cameraComponent)
                    shaders.append(shader)
                    item.shader = shader
                    
                    // Check if we need to recompile the xray
                    if globalApp!.sceneGraph.maximizedObject === item {
                        globalApp!.sceneGraph.buildXray()
                    }
                } else {
                    let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                    if shapeStage.terrain != nil {
                        let shader = TerrainShader(instance: pFXInstance, scene: scene, object: item, camera: cameraComponent)
                        shaders.append(shader)
                        item.shader = shader
                    } else
                    if let ground = item.components[item.defaultName], ground.componentType == .Ground3D {
                        // Ground Object

                        let shader = GroundShader(instance: pFXInstance, scene: scene, object: item, camera: cameraComponent)
                        shaders.append(shader)
                        item.shader = shader
                    }
                }
            } else {
                shaders.append(item.shader!)
                
                #if DEBUG
                print("reusing", item.name)
                #endif

                /*
                instanceMap["shape_\(index)"] = item.builderInstance
                
                item.builderInstance!.ids.forEach { (key, value) in codeBuilder.sdfStream.ids[key] = value }

                #if DEBUG
                print("reusing", "shape_\(index)")
                #endif*/
            }
            
            item.shader!.ids.forEach { (key, value) in pFXInstance!.ids[key] = value }
        }*/
        
        ids = pFXInstance.ids
        validShaders += shaders
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
        width = round(widthIn); height = round(heightIn)
        
        //let startTime = Double(Date().timeIntervalSince1970)
        
        for shader in validShaders {
            for all in shader.allShaders {
                if shader.shaders[all.id] == nil {
                    return
                }
            }
        }
                        
        if pFXInstance.quadVertexBuffer != nil {
            //pFXInstance.quadVertexBuffer!.setPurgeableState(.empty)
        }
        
        pFXInstance.commandQueue = nil
        pFXInstance.commandBuffer = nil
        pFXInstance.quadVertexBuffer = nil
        pFXInstance.quadViewport = nil
        
        pFXInstance.commandQueue = mmView.device!.makeCommandQueue()
        pFXInstance.commandBuffer = pFXInstance.commandQueue!.makeCommandBuffer()
        pFXInstance.quadVertexBuffer = getQuadVertexBuffer(MMRect(0, 0, width, height ) )
        pFXInstance.quadViewport = MTLViewport( originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0 )
                
        //let camHelper = CamHelper3D()
        //camHelper.initFromComponent(aspect: width / height, component: cameraComponent)
        //camHelper.updateProjection()
                
        let origin = getTransformedComponentProperty(cameraComponent, "origin")
        let lookAt = getTransformedComponentProperty(cameraComponent, "lookAt")
                
        pFXInstance.cameraOrigin = SIMD3<Float>(origin.x, origin.y, origin.z)
        pFXInstance.cameraLookAt = SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z)
        pFXInstance.screenSize = float2(width, height)
        
        //pFXInstance.projectionMatrix = camHelper.projMatrix
        //pFXInstance.projectionMatrix = float4x4(projectionFov: camHelper.fov, near: 1, far: 100, aspect: width / height, lhs: false)// camHelper.projMatrix
        //pFXInstance.viewMatrix = float4x4(eye: camHelper.eye, center: camHelper.center, up: camHelper.up)//camHelper.getTransform().inverse//float4x4(eye: camHelper.eye, center: camHelper.center, up: camHelper.up)
        //pFXInstance.viewMatrix = camHelper.getTransform().inverse

        pFXInstance.camDirTexture = checkTextureSize(width, height, pFXInstance.camDirTexture, .rgba16Float)
        pFXInstance.depthTexture = checkTextureSize(width, height, pFXInstance.depthTexture, .rgba16Float)
        
        // The texture objects use for their local distance estimations
        //pFXInstance.localTexture = checkTextureSize(width, height, pFXInstance.localTexture, .rgba16Float)
        
        // The depth / shape textures which get ping ponged
        pFXInstance.shapeTexture1 = checkTextureSize(width, height, pFXInstance.shapeTexture1, .rgba16Float)
        pFXInstance.shapeTexture2 = checkTextureSize(width, height, pFXInstance.shapeTexture2, .rgba16Float)
        
        // The pointers to the current and the other depth / shape texture
        pFXInstance.currentShapeTexture = pFXInstance.shapeTexture1
        pFXInstance.otherShapeTexture = pFXInstance.shapeTexture2

        finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
        //pFXInstance.utilityShader.clear(texture: finalTexture!, data: SIMD4<Float>(0, 0, 1, 1))
        
        pFXInstance.utilityShader!.cameraTextures()
        
        for item in globalApp!.project.selected!.items {
            if item.componentType == .Shader {
                if let shader = item.shader {
                    shader.render(texture: finalTexture!)
                }
            }
        }
        
        /*
        func swapShapeTextures()
        {
            if pFXInstance.currentShapeTexture === pFXInstance.shapeTexture1 {
                pFXInstance.currentShapeTexture = pFXInstance.shapeTexture2
                pFXInstance.otherShapeTexture = pFXInstance.shapeTexture1
            } else {
                pFXInstance.currentShapeTexture = pFXInstance.shapeTexture1
                pFXInstance.otherShapeTexture = pFXInstance.shapeTexture2
            }
        }
        
        func isDisabled(shader: BaseShader) -> Bool
        {
            var disabled = false
            return disabled
        }
        
        //print("Last Execution Time: ", globalApp!.executionTime * 1000)
        
        globalApp!.executionTime = 0
        
//        if let background = backgroundShader {
//            background.render(texture: finalTexture!)
//        }
//
        // Get the depth
        /*
        for shader in shaders {
            if isDisabled(shader: shader) == false {
                shader.render(texture: finalTexture!)
                swapShapeTextures()
            }
        }*/
        
        /*
        // Free the other shape texture
        if pFXInstance.currentShapeTexture === pFXInstance.shapeTexture1 {
            pFXInstance.shapeTexture2 = nil
            pFXInstance.otherShapeTexture = nil
        } else {
            pFXInstance.shapeTexture1 = nil
            pFXInstance.otherShapeTexture = nil
        }*/
        
        // The ao / shadow textures which get ping ponged
        //pFXInstance.shadowTexture1 = checkTextureSize(width, height, pFXInstance.shadowTexture1, .rg16Float)
        //pFXInstance.shadowTexture2 = checkTextureSize(width, height, pFXInstance.shadowTexture2, .rg16Float)
        
        // The pointers to the current and the other ao / shadow texture
        //pFXInstance.currentShadowTexture = pFXInstance.shadowTexture1
        //pFXInstance.otherShadowTexture = pFXInstance.shadowTexture2
        
        func swapShadowTextures()
        {
            if pFXInstance.currentShadowTexture === pFXInstance.shadowTexture1 {
                pFXInstance.currentShadowTexture = pFXInstance.shadowTexture2
                pFXInstance.otherShadowTexture = pFXInstance.shadowTexture1
            } else {
                pFXInstance.currentShadowTexture = pFXInstance.shadowTexture1
                pFXInstance.otherShadowTexture = pFXInstance.shadowTexture2
            }
        }
        
        //pFXInstance.utilityShader!.clearShadow(shadowTexture: pFXInstance.shadowTexture1!)
        
        // Calculate the shadows
        /*
        for shader in shaders {
            if let object = shader as? ObjectShader {
                if isDisabled(shader: shader) == false {
                    object.shadowPass(texture: finalTexture!)
                    swapShadowTextures()
                }
            }
        }*/
        
        // Calculate the materials
        
        // The reflection textures which get ping ponged
        pFXInstance.reflectionTexture1 = checkTextureSize(width, height, pFXInstance.reflectionTexture1, .rgba16Float)
        pFXInstance.reflectionTexture2 = checkTextureSize(width, height, pFXInstance.reflectionTexture2, .rgba16Float)
        pFXInstance.currentReflTexture = pFXInstance.reflectionTexture1
        pFXInstance.otherReflTexture = pFXInstance.reflectionTexture2
        
        // Reflection direction textures
        pFXInstance.reflDirTexture1 = checkTextureSize(width, height, pFXInstance.reflDirTexture1, .rgba16Float)
        pFXInstance.reflDirTexture2 = checkTextureSize(width, height, pFXInstance.reflDirTexture2, .rgba16Float)
        pFXInstance.currentReflDirTexture = pFXInstance.reflDirTexture1
        pFXInstance.otherReflDirTexture = pFXInstance.reflDirTexture2
        
        func swapReflectionTextures()
        {
            if pFXInstance.currentReflTexture === pFXInstance.reflectionTexture1 {
                pFXInstance.currentReflTexture = pFXInstance.reflectionTexture2
                pFXInstance.otherReflTexture = pFXInstance.reflectionTexture1
            } else {
                pFXInstance.currentReflTexture = pFXInstance.reflectionTexture1
                pFXInstance.otherReflTexture = pFXInstance.reflectionTexture2
            }
        }
        
        func swapReflectionDirTextures()
        {
            if pFXInstance.currentReflDirTexture === pFXInstance.reflDirTexture1 {
                pFXInstance.currentReflDirTexture = pFXInstance.reflDirTexture2
                pFXInstance.otherReflDirTexture = pFXInstance.reflDirTexture1
            } else {
                pFXInstance.currentReflDirTexture = pFXInstance.reflDirTexture1
                pFXInstance.otherReflDirTexture = pFXInstance.reflDirTexture2
            }
        }
        
        // Setup the mask textures
        
        pFXInstance.maskTexture1 = pFXInstance.otherShapeTexture
        pFXInstance.maskTexture2 = checkTextureSize(width, height, pFXInstance.maskTexture2, .rgba16Float)//pFXInstance.otherShadowTexture
        pFXInstance.currentMaskTexture = pFXInstance.maskTexture1
        pFXInstance.otherMaskTexture = pFXInstance.maskTexture2
        
        func swapMaskTextures()
        {
            if pFXInstance.currentMaskTexture === pFXInstance.maskTexture1 {
                pFXInstance.currentMaskTexture = pFXInstance.maskTexture2
                pFXInstance.otherMaskTexture = pFXInstance.maskTexture1
            } else {
                pFXInstance.currentMaskTexture = pFXInstance.maskTexture1
                pFXInstance.otherMaskTexture = pFXInstance.maskTexture2
            }
        }
        
        //pFXInstance.utilityShader!.clear(texture: pFXInstance.maskTexture1!, data: SIMD4<Float>(1,1,1,1))

        // Calculate the materials
        /*
        for shader in shaders {
            if isDisabled(shader: shader) == false {
                shader.materialPass(texture: finalTexture!)
                swapReflectionDirTextures()
                swapMaskTextures()
            }
        }*/
        
        /*
        // Free the other reflection dir texture
        if pFXInstance.currentReflDirTexture === pFXInstance.reflDirTexture1 {
            pFXInstance.reflDirTexture2 = nil
            pFXInstance.otherReflDirTexture = nil
        } else {
            pFXInstance.reflDirTexture1 = nil
            pFXInstance.otherReflDirTexture = nil
        }
        
        pFXInstance.shadowTexture1 = nil
        pFXInstance.shadowTexture2 = nil
        pFXInstance.currentShadowTexture = nil
        pFXInstance.otherShadowTexture = nil
        */
        
        
        // Calculate the reflection hits
        for shader in shaders {
            if isDisabled(shader: shader) == false {
                shader.reflectionPass(texture: finalTexture!)
                swapReflectionTextures()
            }
        }
        
        // Calculate the reflection material colors and blend them in
        for shader in shaders {
            if isDisabled(shader: shader) == false {
                shader.reflectionMaterialPass(texture: finalTexture!)
            }
        }
        
        // SKY REFLECTIONS
        if let background = backgroundShader {
            background.reflectionMaterialPass(texture: finalTexture!)
        }
        
        // BBOX DEBUG
        
        #if false
        for shader in shaders {
            if let object = shader as? ObjectShader {
                object.bbox(texture: finalTexture!)
            }
        }
        #endif

        
        if let post = postShader {
            post.render(texture: finalTexture!, otherTexture: pFXInstance.currentReflDirTexture!)
        }
         
        */

        // RUN IT
        
        pFXInstance.commandBuffer!.addCompletedHandler { cb in
//            print("Rendering Time:", (cb.gpuEndTime - cb.gpuStartTime) * 1000)
        }
        pFXInstance.commandBuffer!.commit()
        
        // DONE
        textureMap["shape"] = pFXInstance.currentShapeTexture!

        #if DEBUG
//        print("Setup Time: ", (Double(Date().timeIntervalSince1970) - startTime) * 1000)
        #endif
    }
    
    /// Creates a vertex buffer for a quad shader
    func getQuadVertexBuffer(_ rect: MMRect ) -> MTLBuffer?
    {
        let left = -rect.width / 2 + rect.x
        let right = left + rect.width//self.width / 2 - x
        
        let top = rect.height / 2 - rect.y
        let bottom = top - rect.height
        
        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
            ]
        
        return mmView.device!.makeBuffer(bytes: quadVertices, length: quadVertices.count * MemoryLayout<Float>.stride, options: [])!
    }
}
