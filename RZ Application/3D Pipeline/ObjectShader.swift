//
//  ObjectShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import simd
import MetalKit

class ObjectShader      : BaseShader
{
    var scene           : Scene
    var object          : StageItem
    var camera          : CodeComponent

    var materialCode    = ""

    var bbTriangles : [Float] = []
    
    init(instance: PRTInstance, scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
        
        super.init(instance: instance)
        
        buildShader()
    }
    
    func buildShader()
    {
        let vertexShader =
        """
        
        \(prtInstance.fragmentUniforms)

        typedef struct {
            matrix_float4x4     modelMatrix;
            matrix_float4x4     viewMatrix;
            matrix_float4x4     projectionMatrix;
        } ObjectVertexUniforms;

        struct VertexOut{
            float4              position[[position]];
            float3              worldPosition;;
            //float3              screenPosition;
        };

        vertex VertexOut procVertex(const device packed_float4 *triangles [[ buffer(0) ]],
                                    constant ObjectVertexUniforms &uniforms [[ buffer(1) ]],
                                    unsigned int vid [[ vertex_id ]] )
        {
            VertexOut out;

            out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(triangles[vid]);
            out.worldPosition = (uniforms.modelMatrix * float4(triangles[vid])).xyz;

            return out;
        }

        """
        
        var headerCode = ""
        
        dryRunComponent(camera, data.count)
        collectProperties(camera)
        
        idStart = Float(prtInstance.idCounter)
        let mapCode = createMapCode()
        idEnd = Float(prtInstance.idCounter)
                
        // Raymarch
        let rayMarch = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .RayMarch3D)!
        dryRunComponent(rayMarch, data.count)
        collectProperties(rayMarch)
        if let globalCode = rayMarch.globalCode {
            headerCode += globalCode
        }
        
        // Normals
        let normal = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Normal3D)!
        dryRunComponent(normal, data.count)
        collectProperties(normal)
        if let globalCode = normal.globalCode {
            headerCode += globalCode
        }
                
        // --- Create Soft Shadow Function Code
        var softShadowCode =
        """
        float calcSoftShadow( float3 ro, float3 rd, thread struct FuncData *__funcData)
        {
            float outShadow = 1.;
            float3 position = ro;
            float3 direction = rd;

        """
        if let shadows = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Shadows3D) {
            dryRunComponent(shadows, data.count)
            collectProperties(shadows)
            if let globalCode = shadows.globalCode {
                headerCode += globalCode
            }
            if let code = shadows.code {
                softShadowCode += code
            }
        }
        softShadowCode +=
        """

            return outShadow;
        }

        """
        
        // --- Create Light Sampling Material Code
        var lightSamplingCode = ""
        let stage = globalApp!.project.selected!.getStage(.LightStage)
        let lights = stage.getChildren()
        
        for (index, _) in lights.enumerated()
        {
            lightSamplingCode +=
            """
            
                {
                    Light light = lights.lights[\(index+1)];
                    float3 lightDir = float3(0);

                    if (light.lightType == 0) lightDir = normalize(light.directionToLight.xyz);
                    else lightDir = normalize(light.directionToLight.xyz - position);
                    
                    struct MaterialOut __materialOut;
                    __materialOut.color = float4(0,0,0,1);
                    __materialOut.mask = float3(0);
                    
                    float3 incomingDirection = rayDirection;
                    float3 hitPosition = position;
                    float3 hitNormal = outNormal;
                    float3 directionToLight = lightDir;
                    float4 lightType = float4(0);
                    float4 lightColor = light\(index)(light.directionToLight.xyz, position, __funcData);
                    float shadow = shadows.y;
                    float occlusion = shadows.x;
                    float3 mask = float3(1);

                    \(materialCode)
                    
                    outColor += __materialOut.color;
                }
            
            """
        }
        
        
        let fragmentShader =
        """
        
        \(camera.globalCode!)
        \(mapCode)
        \(createLightCode(scene: scene))

        fragment half4 procFragment(VertexOut vertexIn [[stage_in]],
                                    __MAIN_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]])
        {
            __MAIN_INITIALIZE_FUNC_DATA__
        
            float2 size = uniforms.screenSize;
            float3 position = vertexIn.worldPosition.xyz;

            float3 rayOrigin = position;//uniforms.cameraOrigin;//position;
            float3 rayDirection = normalize(position - uniforms.cameraOrigin);

            float4 inShape = float4(1000, 1000, -1, -1);
            float4 outShape = float4(1000, 1000, -1, -1);
            float maxDistance = uniforms.maxDistance;

            //__funcData->inShape = float4(1000, 1000, -1, -1);
            //__funcData->inHitPoint = rayOrigin + rayDirection * outShape.y;

            \(rayMarch.code!)
        
            if (isNotEqual(outShape.w, inShape.w)) {
                outShape.y += distance(position, uniforms.cameraOrigin);
            }
            return half4(outShape);
        }
        
        \(BaseShader.getQuadVertexSource(name: "quadVertex"))
        
        fragment float4 materialFragment(RasterizerData vertexIn [[stage_in]],
                                    __MATERIAL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> depthTexture [[texture(3)]],
                                    texture2d<half, access::read> shadowTexture [[texture(4)]])
        {
            __MATERIAL_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;

            float4 outColor = float4(0);
            float4 shape = float4(depthTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)));
        
            if (shape.w >= \(idStart - 0.1) && shape.w <= \(idEnd + 0.1))
            {
                float2 shadows = float2(shadowTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)).xy);

                float2 jitter = float2(0.5);
                float3 outPosition = float3(0,0,0);
                float3 outDirection = float3(0,0,0);
        
                float3 position = float3(uv.x, uv.y, 0);

                \(camera.code!)
        
                float3 rayOrigin = outPosition;
                float3 rayDirection = outDirection;
        
                position = rayOrigin + shape.y * rayDirection;
                float3 outNormal = float3(0);
        
                \(normal.code!)
        
                // Sun
                {
                    struct MaterialOut __materialOut;
                    __materialOut.color = float4(0,0,0,1);
                    __materialOut.mask = float3(0);
                    
                    float3 incomingDirection = rayDirection;
                    float3 hitPosition = position;
                    float3 hitNormal = outNormal;
                    float3 directionToLight = normalize(lights.lights[0].directionToLight.xyz);
                    float4 lightType = float4(0);
                    float4 lightColor = lights.lights[0].lightColor;
                    float shadow = shadows.y;
                    float occlusion = shadows.x;
                    float3 mask = float3(1);

                    \(materialCode)
        
                    outColor += __materialOut.color;
                }
        
                \(lightSamplingCode)
            }
        
            return outColor;
        }
        
        \(softShadowCode)
        
        float smin( float a, float b, float k )
        {
            float h = clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
            return mix( b, a, h ) - k*h*(1.0-h);
        }
        
        fragment float2 shadowFragment(RasterizerData vertexIn [[stage_in]],
                                    __MATERIAL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> shadowTexture [[texture(3)]],
                                    texture2d<half, access::read> shapeTexture [[texture(4)]])
        {
            __SHADOW_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;

            float4 shape = float4(shapeTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)));
            float2 shadows = float2(shadowTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)).xy);
        
            if (shape.w > -0.5 && (shape.w < \(idStart - 0.1) || shape.w > \(idEnd + 0.1)))
            {
                float2 jitter = float2(0.5);
                float3 outPosition = float3(0,0,0);
                float3 outDirection = float3(0,0,0);
        
                float3 position = float3(uv.x, uv.y, 0);

                \(camera.code!)
        
                float3 rayOrigin = outPosition;
                float3 rayDirection = outDirection;
        
                position = rayOrigin + shape.y * rayDirection;
                
                // Calculate shadows
                float shadow = calcSoftShadow(position, normalize(lights.lights[0].directionToLight.xyz), __funcData);

                float3 lightDir = float3(0);
                for (int i = 1; i < lights.numberOfLights; ++i)
                {
                    Light light = lights.lights[i];
                    if (light.lightType == 0) lightDir = normalize(light.directionToLight.xyz);
                    else lightDir = normalize(light.directionToLight.xyz - position);
        
                    shadow = max(calcSoftShadow(position, lightDir, __funcData), shadow);
                }
        
                shadows.y = min(shape.y, shadow);
            }
            return shadows;
        }

        """
        
        //print(fragmentShader)
                        
        compile(code: vertexShader + fragmentShader, shaders: [
            Shader(id: "MAIN", textureOffset: 4, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "MATERIAL", vertexName: "quadVertex", fragmentName: "materialFragment", textureOffset: 5, blending: true),
            Shader(id: "SHADOW", vertexName: "quadVertex", fragmentName: "shadowFragment", textureOffset: 5, pixelFormat: .rg16Float, blending: false)
        ])

        //compile(vertexCode: vertexShader, fragmentCode: fragmentShader, textureOffset: 4, pixelFormat: .rgba16Float, blending: false)
        buildTriangles()
    }

    override func render(texture: MTLTexture)
    {
        updateData()
    
        if let mainShader = shaders["MAIN"] {

            if bbTriangles.count == 0 { return }
            let dataSize = bbTriangles.count * MemoryLayout<Float>.size
            let vertexBuffer = device.makeBuffer(bytes: bbTriangles, length: dataSize, options: [])

            var mTranslation = matrix_identity_float4x4
            var mRotation = matrix_identity_float4x4
            var mScale = matrix_identity_float4x4
            
            var maxDistance : Float = 100

            if let transform = self.object.components[self.object.defaultName] {
                let scale = transform.values["_scale"]!
                
                mTranslation = float4x4(translation: [transform.values["_posX"]!, transform.values["_posY"]!, transform.values["_posZ"]!])
                mRotation = float4x4(rotation: [transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians])
                
                let bbX : Float
                let bbY : Float
                let bbZ : Float

                if transform.values["_bb_x"] == nil {
                    bbX = 1
                    bbY = 1
                    bbZ = 1
                } else {
                    bbX = transform.values["_bb_x"]!
                    bbY = transform.values["_bb_y"]!
                    bbZ = transform.values["_bb_z"]!
                }
                
                maxDistance = sqrt( bbX * bbX + bbY * bbY + bbZ * bbZ)
                mScale = float4x4(scaling: [(bbX * scale), (bbY * scale), (bbZ * scale)])
            }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.localTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 0.0)

            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            //renderEncoder.setDepthStencilState(buildDepthStencilState())
            
            // Vertex Uniforms
            
            var vertexUniforms = ObjectVertexUniforms()
            vertexUniforms.projectionMatrix = prtInstance.projectionMatrix
            vertexUniforms.modelMatrix = mTranslation * mRotation * mScale
            vertexUniforms.viewMatrix = prtInstance.viewMatrix
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<ObjectVertexUniforms>.stride, index: 1)
            
            // Fragment Uniforms
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize
            fragmentUniforms.maxDistance = maxDistance
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            
            renderEncoder.setCullMode(.back)
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setDepthClipMode(.clamp)
            
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: bbTriangles.count / 4)
            renderEncoder.endEncoding()
            
            commandBuffer.commit()
            
            // --- Merge the result
            prtInstance.utilityShader.mergeShapes()
        }
    }
    
    override func shadowPass(texture: MTLTexture)
    {
        if let shader = shaders["SHADOW"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShadowTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let commandBuffer = shader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(prtInstance.screenSize.x), Float(prtInstance.screenSize.y) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            var lightUniforms = prtInstance.utilityShader.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentTexture(prtInstance.currentShadowTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 4)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
        }
    }
    
    override func materialPass(texture: MTLTexture)
    {
        if let shader = shaders["MATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let commandBuffer = shader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(prtInstance.screenSize.x), Float(prtInstance.screenSize.y) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            var lightUniforms = prtInstance.utilityShader.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentShadowTexture!, index: 4)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
        }
    }
    
    func createMapCode() -> String
    {
        var hierarchy           : [StageItem] = []
        
        var globalsAddedFor     : [UUID] = []
        
        var componentCounter    : Int = 0

        var materialIdCounter   : Int = 0
        var currentMaterialId   : Int = 0
        
        var materialFuncCode    = ""

        var headerCode = ""
        var mapCode = """

        float4 sceneMap( float3 __origin, thread struct FuncData *__funcData )
        {
            float3 __originBackupForScaling = __origin;
            float3 __objectPosition = float3(0);
            float outDistance = 10;
            float bump = 0;
            float scale = 1;

            //float4 outShape = __funcData->inShape;
            //outShape.x = length(__origin - __funcData->inHitPoint) + 0.5;

            float4 outShape = float4(1000, 1000, -1, -1);

            constant float4 *__data = __funcData->__data;
            float GlobalTime = __funcData->GlobalTime;
            float GlobalSeed = __funcData->GlobalSeed;

        """
                        
        func pushComponent(_ component: CodeComponent)
        {
            dryRunComponent(component, data.count)
            collectProperties(component, hierarchy)
             
            if let globalCode = component.globalCode {
                headerCode += globalCode
            }
             
            var code = ""
             
            let posX = getTransformPropertyIndex(component, "_posX")
            let posY = getTransformPropertyIndex(component, "_posY")
            let posZ = getTransformPropertyIndex(component, "_posZ")
                 
            let rotateX = getTransformPropertyIndex(component, "_rotateX")
            let rotateY = getTransformPropertyIndex(component, "_rotateY")
            let rotateZ = getTransformPropertyIndex(component, "_rotateZ")

            code +=
            """
                {
                    float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    float3 position = __translate(__origin, __originalPosition);
                    float3 __offsetFromCenter = __objectPosition - __originalPosition;

                    position.yz = rotatePivot( position.yz, radians(__data[\(rotateX)].x\(getInstantiationModifier("_rotateRandomX", component.values))), __offsetFromCenter.yz );
                    position.xz = rotatePivot( position.xz, radians(-__data[\(rotateY)].x\(getInstantiationModifier("_rotateRandomY", component.values))), __offsetFromCenter.xz );
                    position.xy = rotatePivot( position.xy, radians(__data[\(rotateZ)].x\(getInstantiationModifier("_rotateRandomZ", component.values))), __offsetFromCenter.xy );

            """
                 
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["domain3D"] {
                    for domain in list {
                             
                        var firstRun = false
                        if globalsAddedFor.contains(domain.uuid) == false {
                            dryRunComponent(domain, data.count)
                            collectProperties(domain)
                            globalsAddedFor.append(domain.uuid)
                            firstRun = true
                        }
                             
                        if let globalCode = domain.globalCode {
                            if firstRun == true {
                                headerCode += globalCode
                            }
                        }
                             
                        code +=
                        """
                        {
                        float3 outPosition = position;
                             
                        """
                        code += domain.code!
                        code +=
                        """
                             
                        position = outPosition;
                        }
                        """
                    }
                }
            }
             
            if component.componentType == .SDF3D {
                code += component.code!
            } else
            if component.componentType == .SDF2D {
                // 2D Component in a 3D World, needs extrusion code
                  
                let extrusion = getTransformPropertyIndex(component, "_extrusion")
                let revolution = getTransformPropertyIndex(component, "_revolution")
                let rounding = getTransformPropertyIndex(component, "_rounding")

                code +=
                """
                {
                    float3 originalPos = position;
                    float2 position = originalPos.xy;
                     
                    if (__data[\(revolution)].x > 0.)
                        position = float2( length(originalPos.xz) - __data[\(revolution)].x, originalPos.y );
                     
                    \(component.code!)
                    __funcData->distance2D = outDistance;
                    if (__data[\(revolution)].x == 0.)
                    {
                        float2 w = float2( outDistance, abs(originalPos.z) - __data[\(extrusion)].x );
                        outDistance = min(max(w.x,w.y),0.0) + length(max(w,0.0)) - __data[\(rounding)].x;
                    }
                }
                """
            }
             
            // Modifier 3D
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["modifier3D"] {
                    if list.count > 0 {
                             
                        let rotateX = getTransformPropertyIndex(component, "_rotateX")
                        let rotateY = getTransformPropertyIndex(component, "_rotateY")
                        let rotateZ = getTransformPropertyIndex(component, "_rotateZ")
                             
                        code +=
                        """
                        {
                        float3 offsetFromCenter = __origin - __originalPosition;
                        offsetFromCenter.yz = rotate( offsetFromCenter.yz, radians(__data[\(rotateX)].x) );
                        offsetFromCenter.xz = rotate( offsetFromCenter.xz, radians(__data[\(rotateY)].x) );
                        offsetFromCenter.xy = rotate( offsetFromCenter.xy, radians(__data[\(rotateZ)].x) );
                        float distance = outDistance;
                             
                        """

                        for modifier in list {
                                 
                            var firstRun = false
                            if globalsAddedFor.contains(modifier.uuid) == false {
                                dryRunComponent(modifier, data.count)
                                collectProperties(modifier)
                                globalsAddedFor.append(modifier.uuid)
                                firstRun = true
                            }

                            code += modifier.code!
                            if let globalCode = modifier.globalCode {
                                if firstRun {
                                    headerCode += globalCode
                                }
                            }
                                 
                            code +=
                            """
                                 
                            distance = outDistance;

                            """
                        }
                             
                        code +=
                        """
                             
                        }
                        """
                    }
                }
            }


            code +=
            """
             
                float4 shapeA = outShape;
                float4 shapeB = float4((outDistance - bump) * scale, -1, \(currentMaterialId), \(prtInstance.idCounter));
             
            """
             
            if let subComponent = component.subComponent {
                dryRunComponent(subComponent, data.count)
                collectProperties(subComponent)
                code += subComponent.code!
            }
         
            code += "\n    }\n"
            mapCode += code
             
            // If we have a stageItem, store the id
            if hierarchy.count > 0 {
                prtInstance.ids[prtInstance.idCounter] = (hierarchy, component)
            }
            prtInstance.idCounter += 1
            componentCounter += 1
        }
        
        func pushStageItem(_ stageItem: StageItem)
        {
            hierarchy.append(stageItem)
            // Handle the materials
            if let material = getFirstComponentOfType(stageItem.children, .Material3D) {
                // If this item has a material, generate the material function code and push it on the stack
                
                // Material Function Code
                
                materialFuncCode +=
                """
                
                void material\(materialIdCounter)(float3 incomingDirection, float3 hitPosition, float3 hitNormal, float3 directionToLight, float4 lightType,
                float4 lightColor, float shadow, float occlusion, thread struct MaterialOut *__materialOut, thread struct FuncData *__funcData)
                {
                    float2 uv = float2(0);
                    constant float4 *__data = __funcData->__data;
                    float GlobalTime = __funcData->GlobalTime;
                    float GlobalSeed = __funcData->GlobalSeed;
                    __CREATE_TEXTURE_DEFINITIONS__

                    float4 outColor = __materialOut->color;
                    float3 outMask = __materialOut->mask;
                    float3 outReflectionDir = float3(0);
                    float outReflectionBlur = 0.;
                    float outReflectionDist = 0.;
                
                    float3 localPosition = hitPosition;
                
                """
                
                if let transform = stageItem.components[stageItem.defaultName], transform.componentType == .Transform3D {
                    
                    dryRunComponent(transform, data.count)
                    collectProperties(transform, hierarchy)
                    
                    let posX = getTransformPropertyIndex(transform, "_posX")
                    let posY = getTransformPropertyIndex(transform, "_posY")
                    let posZ = getTransformPropertyIndex(transform, "_posZ")
                                    
                    let rotateX = getTransformPropertyIndex(transform, "_rotateX")
                    let rotateY = getTransformPropertyIndex(transform, "_rotateY")
                    let rotateZ = getTransformPropertyIndex(transform, "_rotateZ")
                    
                    let scale = getTransformPropertyIndex(transform, "_scale")
                                    
                    // Handle scaling the object
                    if hierarchy.count == 1 {
                        mapCode +=
                        """
                        
                        __objectPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x ) / scale;
                        scale = __data[\(scale)].x\(getInstantiationModifier("_scaleRandom", transform.values));
                        __origin = __originBackupForScaling / scale;
                        
                        """
                    } else {
                        mapCode +=
                        """
                        
                        __objectPosition += float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x  ) / scale;
                        scale *= __data[\(scale)].x;
                        __origin = __originBackupForScaling / scale;

                        """
                    }
                    
                    materialFuncCode +=
                    """
                    
                        float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                        localPosition = __translate(hitPosition, __originalPosition);
                    
                        localPosition.yz = rotate( localPosition.yz, radians(__data[\(rotateX)].x\(getInstantiationModifier("_rotateRandomX", transform.values))) );
                        localPosition.xz = rotate( localPosition.xz, radians(__data[\(rotateY)].x\(getInstantiationModifier("_rotateRandomY", transform.values))) );
                        localPosition.xy = rotate( localPosition.xy, radians(__data[\(rotateZ)].x\(getInstantiationModifier("_rotateRandomZ", transform.values))) );
                    
                    """
                }
                    
                // Create the UVMapping for this material
                
                // In case we need to reuse it for displacement bumps
                var uvMappingCode = ""
                
                if let uvMap = getFirstComponentOfType(stageItem.children, .UVMAP3D) {
                    
                    materialFuncCode +=
                    """
                    
                    {
                    float3 position = localPosition; float3 normal = hitNormal;
                    float2 outUV = float2(0);
                    
                    """
                        
                    dryRunComponent(uvMap, data.count)
                    collectProperties(uvMap)
                    if let globalCode = uvMap.globalCode {
                        headerCode += globalCode
                    }
                    if let code = uvMap.code {
                        materialFuncCode += code
                        uvMappingCode = code
                    }
                    
                    materialFuncCode +=
                    """
                    
                        uv = outUV;
                        }
                    
                    """
                }
                
                // Get the patterns of the material if any
                var patterns : [CodeComponent] = []
                if let materialStageItem = getFirstStageItemOfComponentOfType(stageItem.children, .Material3D) {
                    if materialStageItem.componentLists["patterns"] != nil {
                        patterns = materialStageItem.componentLists["patterns"]!
                    }
                }
                
                dryRunComponent(material, data.count, patternList: patterns)
                collectProperties(material)
                if let globalCode = material.globalCode {
                    headerCode += globalCode
                }
                if let code = material.code {
                    materialFuncCode += code
                }
        
                // Check if material has a bump
                var hasBump = false
                for (_, conn) in material.propertyConnections {
                    let fragment = conn.2
                    if fragment.name == "bump" && material.properties.contains(fragment.uuid) {
                        
                        // First, insert the uvmapping code
                        mapCode +=
                        """
                        
                        {
                        float3 position = __origin; float3 normal = float3(0);
                        float2 outUV = float2(0);
                        
                        """
                        
                        mapCode += uvMappingCode
                        
                        // Than call the pattern and assign it to the output of the bump terminal
                        mapCode +=
                        """
                        
                        struct PatternOut data;
                        \(conn.3)(outUV, position, normal, float3(0), &data, __funcData );
                        bump = data.\(conn.1) * 0.02;
                        }
                        
                        """
                        
                        hasBump = true
                    }
                }
                
                // If material has no bump, reset it
                if hasBump == false {
                    mapCode +=
                    """
                    
                    bump = 0;
                    
                    """
                }

                materialFuncCode +=
                """
                    
                    __materialOut->color = outColor;
                    __materialOut->mask = outMask;
                    __materialOut->reflectionDir = outReflectionDir;
                    __materialOut->reflectionDist = outReflectionDist;
                }
                
                """

                materialCode +=
                """
                
                if (shape.z > \(Float(materialIdCounter) - 0.5) && shape.z < \(Float(materialIdCounter) + 0.5))
                {
                """
                
                materialCode +=
                    
                """
                
                    material\(materialIdCounter)(incomingDirection, hitPosition, hitNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);
                
                    //if (lightType.z == lightType.w) {
                    //    rayDirection = __materialOut.reflectionDir;
                    //    rayOrigin = hitPosition + 0.001 * rayDirection * shape.y + __materialOut.reflectionDist * rayDirection;
                    //}
                    //color.xyz = color.xyz + __materialOut.color.xyz * mask;
                    //color = clamp(color, 0.0, 1.0);
                    //if (lightType.z == lightType.w) {
                    //    mask *= __materialOut.mask;
                    //}
                }

                """
                
                // Push it on the stack
                
                materialIdHierarchy.append(materialIdCounter)
                materialIds[materialIdCounter] = stageItem
                currentMaterialId = materialIdCounter
                materialIdCounter += 1
            } else
            if let transform = stageItem.components[stageItem.defaultName], transform.componentType == .Transform2D || transform.componentType == .Transform3D {
                
                dryRunComponent(transform, data.count)
                collectProperties(transform, hierarchy)
                
                let posX = getTransformPropertyIndex(transform, "_posX")
                let posY = getTransformPropertyIndex(transform, "_posY")
                let posZ = getTransformPropertyIndex(transform, "_posZ")
                
                let scale = getTransformPropertyIndex(transform, "_scale")

                // Handle scaling the object here if it has no material
                if hierarchy.count == 1 {
                    mapCode +=
                    """
                    
                    __objectPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x ) / scale;
                    scale = __data[\(scale)].x;
                    __origin = __originBackupForScaling / scale;
                    
                    """
                } else {
                    mapCode +=
                    """
                    
                    __objectPosition += float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x ) / scale;
                    scale *= __data[\(scale)].x;
                    __origin = __originBackupForScaling / scale;

                    """
                }
            }
        }
        
        func pullStageItem()
        {
            let stageItem = hierarchy.removeLast()
            
            // If object had a material, pop the materialHierarchy
            if getFirstComponentOfType(stageItem.children, .Material3D) != nil {
                
                materialIdHierarchy.removeLast()
                if materialIdHierarchy.count > 0 {
                    currentMaterialId = materialIdHierarchy.last!
                } else {
                    currentMaterialId = 0
                }
            }
        }
        
        /// Recursively iterate the object hierarchy
        func processChildren(_ stageItem: StageItem)
        {
            for child in stageItem.children {
                if let shapes = child.getComponentList("shapes") {
                    pushStageItem(child)
                    for shape in shapes {
                        pushComponent(shape)
                    }
                    processChildren(child)
                    pullStageItem()
                }
            }
        }

        if let shapes = object.getComponentList("shapes") {
            pushStageItem(object)
            for shape in shapes {
                pushComponent(shape)
            }
            processChildren(object)
            pullStageItem()
            
            //idCounter += codeBuilder.sdfStream.idCounter - idCounter + 1
        }
        
        mapCode += """

            return outShape;
        }
        
        """
        
        return headerCode + materialFuncCode + mapCode
    }
    
    func buildTriangles()
    {
        bbTriangles = [
            // left
            -1, +1, +1, 1.0, -1, +1, -1, 1.0, -1, -1, -1, 1.0,
            -1, +1, +1, 1.0, -1, -1, -1, 1.0, -1, -1, +1, 1.0,
            // right
            +1, +1, -1, 1.0, +1, +1, +1, 1.0, +1, -1, +1, 1.0,
            +1, +1, -1, 1.0, +1, -1, +1, 1.0, +1, -1, -1, 1.0,
            // bottom
            -1, -1, -1, 1.0, +1, -1, -1, 1.0, +1, -1, +1, 1.0,
            -1, -1, -1, 1.0, +1, -1, +1, 1.0, -1, -1, +1, 1.0,
            // top
            -1, +1, +1, 1.0, +1, +1, +1, 1.0, +1, +1, -1, 1.0,
            -1, +1, +1, 1.0, +1, +1, -1, 1.0, -1, +1, -1, 1.0,
            // back
            -1, +1, -1, 1.0, +1, +1, -1, 1.0, +1, -1, -1, 1.0,
            -1, +1, -1, 1.0, +1, -1, -1, 1.0, -1, -1, -1, 1.0,
            // front
            +1, +1, +1, 1.0, -1, +1, +1, 1.0, -1, -1, +1, 1.0,
            +1, +1, +1, 1.0, -1, -1, +1, 1.0, +1, -1, +1, 1.0
        ]
    }
}
