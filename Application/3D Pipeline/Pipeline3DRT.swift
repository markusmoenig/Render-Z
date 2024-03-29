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
    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]

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
        
    var cameraComponent     : CodeComponent!
    
    var backgroundShader    : BackgroundShader? = nil
    var postShader          : PostShader? = nil
    
    var shaders             : [BaseShader] = []
    var validShaders        : [BaseShader] = []

    var prtInstance         : PRTInstance! = nil

    override init(_ mmView: MMView)
    {
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
        
        prtInstance = PRTInstance()
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
        validShaders = []
        
        prtInstance.clean()
        
        if backgroundShader == nil || BackgroundShader.needsToCompile(scene: scene) == true {
            backgroundShader = nil
            backgroundShader = BackgroundShader(instance: prtInstance, scene: scene, camera: cameraComponent)
            
            prtInstance.utilityShader = nil
            prtInstance.utilityShader = UtilityShader(instance: prtInstance, scene: scene, camera: cameraComponent)
        } else {
            #if DEBUG
            print("reusing background")
            #endif
        }
        
        if postShader == nil || PostShader.needsToCompile(scene: scene) == true {
            postShader = nil
            postShader = PostShader(instance: prtInstance, scene: scene)
        } else {
            #if DEBUG
            print("reusing postfx")
            #endif
        }
        
        validShaders.append(prtInstance.utilityShader!)
        validShaders.append(backgroundShader!)
        validShaders.append(postShader!)

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
                    
                    let shader = ObjectShader(instance: prtInstance, scene: scene, object: item, camera: cameraComponent)
                    shaders.append(shader)
                    item.shader = shader
                    
                    // Check if we need to recompile the xray
                    if globalApp!.sceneGraph.maximizedObject === item {
                        globalApp!.sceneGraph.buildXray()
                    }
                } else {
                    let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                    if shapeStage.terrain != nil {
                        let shader = TerrainShader(instance: prtInstance, scene: scene, object: item, camera: cameraComponent)
                        shaders.append(shader)
                        item.shader = shader
                    } else
                    if let ground = item.components[item.defaultName], ground.componentType == .Ground3D {
                        // Ground Object

                        let shader = GroundShader(instance: prtInstance, scene: scene, object: item, camera: cameraComponent)
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
            
            item.shader!.ids.forEach { (key, value) in prtInstance!.ids[key] = value }
        }
        
        ids = prtInstance.ids
        validShaders += shaders
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
        width = round(widthIn); height = round(heightIn)
        
        // Update xray if no over time animation is running
        if globalApp!.sceneGraph.maximizedObject != nil {
            if mmView.maxHardLocks == 0 {
                globalApp!.sceneGraph.xrayNeedsUpdate = true
            }
        }
        
        //let startTime = Double(Date().timeIntervalSince1970)
        
        for shader in validShaders {
            for all in shader.allShaders {
                if shader.shaders[all.id] == nil {
                    return
                }
            }
        }
                        
        if prtInstance.quadVertexBuffer != nil {
            //prtInstance.quadVertexBuffer!.setPurgeableState(.empty)
        }
        
        prtInstance.commandQueue = nil
        prtInstance.commandBuffer = nil
        prtInstance.quadVertexBuffer = nil
        prtInstance.quadViewport = nil
        
        prtInstance.commandQueue = mmView.device!.makeCommandQueue()
        prtInstance.commandBuffer = prtInstance.commandQueue!.makeCommandBuffer()
        prtInstance.quadVertexBuffer = getQuadVertexBuffer(MMRect(0, 0, width, height ) )
        prtInstance.quadViewport = MTLViewport( originX: 0.0, originY: 0.0, width: Double(width), height: Double(height), znear: 0.0, zfar: 1.0 )
                
        //let camHelper = CamHelper3D()
        //camHelper.initFromComponent(aspect: width / height, component: cameraComponent)
        //camHelper.updateProjection()
                
        let origin = getTransformedComponentProperty(cameraComponent, "origin")
        let lookAt = getTransformedComponentProperty(cameraComponent, "lookAt")
        
        prtInstance.cameraOrigin = SIMD3<Float>(origin.x, origin.y, origin.z)
        prtInstance.cameraLookAt = SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z)
        prtInstance.screenSize = float2(width, height)

        //prtInstance.projectionMatrix = camHelper.projMatrix
        //prtInstance.projectionMatrix = float4x4(projectionFov: camHelper.fov, near: 1, far: 100, aspect: width / height, lhs: false)// camHelper.projMatrix
        //prtInstance.viewMatrix = float4x4(eye: camHelper.eye, center: camHelper.center, up: camHelper.up)//camHelper.getTransform().inverse//float4x4(eye: camHelper.eye, center: camHelper.center, up: camHelper.up)
        //prtInstance.viewMatrix = camHelper.getTransform().inverse

        prtInstance.camDirTexture = checkTextureSize(width, height, prtInstance.camDirTexture, .rgba16Float)
        prtInstance.depthTexture = checkTextureSize(width, height, prtInstance.depthTexture, .rgba16Float)
        
        // The texture objects use for their local distance estimations
        //prtInstance.localTexture = checkTextureSize(width, height, prtInstance.localTexture, .rgba16Float)
        
        // The depth / shape textures which get ping ponged
        prtInstance.shapeTexture1 = checkTextureSize(width, height, prtInstance.shapeTexture1, .rgba16Float)
        prtInstance.shapeTexture2 = checkTextureSize(width, height, prtInstance.shapeTexture2, .rgba16Float)
        
        // The pointers to the current and the other depth / shape texture
        prtInstance.currentShapeTexture = prtInstance.shapeTexture1
        prtInstance.otherShapeTexture = prtInstance.shapeTexture2

        finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
        //prtInstance.utilityShader.clear(texture: finalTexture!, data: SIMD4<Float>(0, 0, 1, 1))
        
        prtInstance.utilityShader!.cameraTextures()
        
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
        
        func isDisabled(shader: BaseShader) -> Bool
        {
            var disabled = false
            if let root = shader.rootItem {
                if root.values["disabled"] == 1 {
                    disabled = true
                }
            }
            return disabled
        }
        
        //print("Last Execution Time: ", globalApp!.executionTime * 1000)
        
        globalApp!.executionTime = 0
        
        if let background = backgroundShader {
            background.render(texture: finalTexture!)
        }
        
        // Get the depth
        for shader in shaders {
            if isDisabled(shader: shader) == false {
                shader.render(texture: finalTexture!)
                swapShapeTextures()
            }
        }
        
        /*
        // Free the other shape texture
        if prtInstance.currentShapeTexture === prtInstance.shapeTexture1 {
            prtInstance.shapeTexture2 = nil
            prtInstance.otherShapeTexture = nil
        } else {
            prtInstance.shapeTexture1 = nil
            prtInstance.otherShapeTexture = nil
        }*/
        
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
        
        prtInstance.utilityShader!.clearShadow(shadowTexture: prtInstance.shadowTexture1!)
        
        // Calculate the shadows
        for shader in shaders {
            if let object = shader as? ObjectShader {
                if isDisabled(shader: shader) == false {
                    object.shadowPass(texture: finalTexture!)
                    swapShadowTextures()
                }
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
        
        // Setup the mask textures
        
        prtInstance.maskTexture1 = prtInstance.otherShapeTexture
        prtInstance.maskTexture2 = checkTextureSize(width, height, prtInstance.maskTexture2, .rgba16Float)//prtInstance.otherShadowTexture
        prtInstance.currentMaskTexture = prtInstance.maskTexture1
        prtInstance.otherMaskTexture = prtInstance.maskTexture2
        
        func swapMaskTextures()
        {
            if prtInstance.currentMaskTexture === prtInstance.maskTexture1 {
                prtInstance.currentMaskTexture = prtInstance.maskTexture2
                prtInstance.otherMaskTexture = prtInstance.maskTexture1
            } else {
                prtInstance.currentMaskTexture = prtInstance.maskTexture1
                prtInstance.otherMaskTexture = prtInstance.maskTexture2
            }
        }
        
        //prtInstance.utilityShader!.clear(texture: prtInstance.maskTexture1!, data: SIMD4<Float>(1,1,1,1))

        // Calculate the materials
        for shader in shaders {
            if isDisabled(shader: shader) == false {
                shader.materialPass(texture: finalTexture!)
                swapReflectionDirTextures()
                swapMaskTextures()
            }
        }
        
        /*
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
            post.render(texture: finalTexture!, otherTexture: prtInstance.currentReflDirTexture!)
        }

        // RUN IT
        
        prtInstance.commandBuffer!.addCompletedHandler { cb in
            //print("Rendering Time:", (cb.gpuEndTime - cb.gpuStartTime) * 1000)
        }
        prtInstance.commandBuffer!.commit()
        
        // DONE
        textureMap["shape"] = prtInstance.currentShapeTexture!

        #if DEBUG
        //print("Setup Time: ", (Double(Date().timeIntervalSince1970) - startTime) * 1000)
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
