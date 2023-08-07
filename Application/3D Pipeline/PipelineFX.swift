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
        int                 samples;

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
    var ids                         : [Int:(CodeComponent?)] = [:]

    // Camera
    var cameraOrigin                : float3 = float3(0,0,0)
    var cameraLookAt                : float3 = float3(0,0,0)
    
    var screenSize                  : float2 = float2(0,0)
    
    var projectionMatrix            : matrix_float4x4 = matrix_identity_float4x4
    var viewMatrix                  : matrix_float4x4 = matrix_identity_float4x4

    var camOriginTexture            : MTLTexture? = nil
    var camDirTexture               : MTLTexture? = nil
    var distanceNormalTexture       : MTLTexture? = nil
    var singlePassTexture           : MTLTexture? = nil

    var utilityShader               : UtilityShader? = nil
    
    var commandQueue                : MTLCommandQueue? = nil
    var commandBuffer               : MTLCommandBuffer? = nil
    
    var quadVertexBuffer            : MTLBuffer? = nil
    var quadViewport                : MTLViewport? = nil
    
    var idSet                       : [Int] = []

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
    
    var settings            : PipelineRenderSettings? = nil

    var maxSamples          : Int = 100
    
    var startId             : UInt = 0
    var renderId            : UInt = 0
    
    var renderIsRunning     : Bool = false
    var startedRender       : Bool = false
    
    var singlePass          : Bool = false
    
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
        
        renderId += 1

        cameraComponent = nil

        singlePass = true
        if scene.items.isEmpty == false {
            if scene.items[0].componentType == .Camera3D {
                pFXInstance.utilityShader = nil
                cameraComponent = scene.items[0]
                singlePass = false
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
            } else
            if item.shader == nil && item.componentType == .Shape {
                let shader = FXShape(instance: pFXInstance, scene: scene, uuid: item.uuid, camera: cameraComponent)
                item.shader = shader
                validShaders.append(item.shader!)
            }
        }
        
        ids = pFXInstance.ids
        validShaders += shaders
        
        samples = 0
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
//        for item in scene.items {
//            if item.componentType == .Shader && item.shader == nil {
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
//                    self.render(widthIn, heightIn, settings: settings)
//                }
//                return
//            }
//        }

        renderId += 1

        func checkTextures(_ widthIn: Float,_ heightIn: Float) {
            self.width = round(widthIn); self.height = round(heightIn)
            self.pFXInstance.camOriginTexture = self.checkTextureSize(self.width, self.height, self.pFXInstance.camOriginTexture, .rgba16Float)
            self.pFXInstance.camDirTexture = self.checkTextureSize(self.width, self.height, self.pFXInstance.camDirTexture, .rgba16Float)
            self.pFXInstance.distanceNormalTexture = self.checkTextureSize(self.width, self.height, self.pFXInstance.distanceNormalTexture, .rgba16Float)
            self.pFXInstance.singlePassTexture = self.checkTextureSize(self.width, self.height, self.pFXInstance.singlePassTexture, .rgba16Float)
            self.finalTexture = self.checkTextureSize(self.width, self.height, self.finalTexture, .rgba16Float)
        }
        
        if singlePass == true {
            self.settings = settings
            self.startId = self.renderId
            checkTextures(widthIn, heightIn)
            
            self.samples = 0
            self.renderIsRunning = true
            self.startedRender = false
            self.render_main()
        } else
        if self.startedRender == false {
            
            func startRender()
            {
                self.settings = settings
                self.startId = self.renderId
                checkTextures(widthIn, heightIn)
                
                self.samples = 0
                self.renderIsRunning = true
                self.startedRender = false
                self.render_main()
            }
            
            func tryToStartRender()
            {
//                DispatchQueue.main.async {
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
    
    func hasToFinish() -> Bool
    {
        if self.startId < self.renderId || self.samples >= self.maxSamples {
            renderIsRunning = false
            return true
        } else { return false }
    }
    
    // Render the pipeline
    func render_main()
    {
        for shader in self.validShaders {
            for all in shader.allShaders {
                if shader.shaders[all.id] == nil {
                    return
                }
            }
        }
        
        self.pFXInstance.quadVertexBuffer = nil
        self.pFXInstance.quadViewport = nil
        self.pFXInstance.commandQueue = nil

        self.pFXInstance.commandQueue = self.mmView.device!.makeCommandQueue()
        self.pFXInstance.quadVertexBuffer = self.getQuadVertexBuffer(MMRect(0, 0, self.width, self.height ) )
        self.pFXInstance.quadViewport = MTLViewport( originX: 0.0, originY: 0.0, width: Double(self.width), height: Double(self.height), znear: 0.0, zfar: 1.0 )

        let origin = getTransformedComponentProperty(self.cameraComponent, "origin")
        let lookAt = getTransformedComponentProperty(self.cameraComponent, "lookAt")
        
        self.pFXInstance.cameraOrigin = SIMD3<Float>(origin.x, origin.y, origin.z)
        self.pFXInstance.cameraLookAt = SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z)
        self.pFXInstance.screenSize = float2(self.width, self.height)
                                        
        //print(self.samples)

        if self.hasToFinish() {
            return
        }
        
        self.pFXInstance.commandBuffer = nil
        self.pFXInstance.commandBuffer = self.pFXInstance.commandQueue!.makeCommandBuffer()
                
        if self.samples == 0 {
            self.pFXInstance.utilityShader!.clear(texture: self.finalTexture!, data: SIMD4<Float>(0, 0, 0, 0))
        }
        
        self.pFXInstance.utilityShader!.cameraTextures()
        
        for item in scene.items {
            if item.componentType == .Shader {
                if let shader = item.shader {
                    shader.prtInstance = self.pFXInstance
                    shader.render(texture: self.pFXInstance.singlePassTexture!)
                }
            }
        }
        
        // Merge into final
        
        self.pFXInstance.utilityShader!.accum(samples: Int32(self.samples), final: self.finalTexture!)
        
        // RUN IT
        
        self.pFXInstance.commandBuffer!.addCompletedHandler { cb in
            // print("Rendering Time:", (cb.gpuEndTime - cb.gpuStartTime) * 1000)
        }
        self.pFXInstance.commandBuffer!.commit()
        self.pFXInstance.commandBuffer!.waitUntilCompleted()

        self.samples += 1
        
        if let settings = self.settings {
            if let cbProgress = settings.cbProgress {
                cbProgress(self.samples, self.maxSamples)
            }
        }
        
        if self.singlePass == false {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.003) {
                if self.samples < self.maxSamples {
                    self.render_main()
                } else {
                    if let settings = self.settings {
                        if let cbFinished = settings.cbFinished {
                            cbFinished(self.finalTexture!)
                        }
                    }
                    self.renderIsRunning = false
                    globalApp!.mmView.update()
                }
            }
        } else {
            if let settings = self.settings {
                if let cbFinished = settings.cbFinished {
                    cbFinished(self.finalTexture!)
                }
            }
            self.renderIsRunning = false
        }
        globalApp!.mmView.update()
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
