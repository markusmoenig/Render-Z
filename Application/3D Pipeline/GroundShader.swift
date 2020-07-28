//
//  GroundShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class GroundShader              : BaseShader
{
    var scene                   : Scene
    var object                  : StageItem
    var camera                  : CodeComponent
    
    var sphereContactsState     : MTLComputePipelineState? = nil
    
    var materialBumpCode = ""
    
    init(instance: PRTInstance, scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
                    
        super.init(instance: instance)
        
        self.rootItem = object

        if let ground = object.components[object.defaultName] {
            createFragmentSource(groundComponent: ground, camera: camera)
        }
    }
    
    func createFragmentSource(groundComponent: CodeComponent, camera: CodeComponent)
    {
        dryRunComponent(groundComponent, data.count)
        collectProperties(groundComponent)

        let material = generateMaterialCode(stageItem: self.object)
        
        let lightSamplingCode = prtInstance.utilityShader!.createLightSamplingMaterialCode(materialCode: "material0(rayOrigin, rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);")

        let fragmentCode =
        """

        \(prtInstance.fragmentUniforms)
        
        \(groundComponent.globalCode!)
        \(material)
        \(createLightCode(scene: scene))

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     __MAIN_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<half, access::read> camDirectionTexture [[texture(2)]])
        {
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            __MAIN_INITIALIZE_FUNC_DATA__

            float3 position = float3(uv.x, uv.y, 0);
                    
            float3 rayOrigin = uniforms.cameraOrigin;
            float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
            float4 outShape = float4(1000, 1000, -1, -1);
            float3 outNormal = float3(0);
        
            \(groundComponent.code!)
                    
            return outShape;
        }
                
        fragment float4 materialFragment(RasterizerData in [[stage_in]],
                                    __MATERIAL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> shapeTexture [[texture(3)]],
                                    texture2d<half, access::read> shadowTexture [[texture(4)]],
                                    texture2d<half, access::read> reflectionTextureIn [[texture(5)]],
                                    texture2d<half, access::write> reflectionTextureOut [[texture(6)]],
                                    texture2d<half, access::read> reflectionDirTextureIn [[texture(7)]],
                                    texture2d<half, access::write> reflectionDirTextureOut [[texture(8)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(9)]],
                                    texture2d<half, access::read> maskTextureIn [[texture(10)]],
                                    texture2d<half, access::write> maskTextureOut [[texture(11)]])
        {
            __MATERIAL_INITIALIZE_FUNC_DATA__
        
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 outColor = float4(0,0,0,0);
            
            float4 reflectionShape = float4(reflectionTextureIn.read(textureUV));
            float4 reflectionDir = float4(reflectionDirTextureIn.read(textureUV));
            float4 maskOut = float4(maskTextureIn.read(textureUV));

            float4 outShape = float4(shapeTexture.read(textureUV));
            if (isEqual(outShape.w, 0.0)) {
                float2 shadows = float2(shadowTexture.read(textureUV).xy);
            
                float3 rayOrigin = uniforms.cameraOrigin;
                float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
                float3 outNormal = float3(0);
            
                \(groundComponent.code!)

                float3 position = rayOrigin + rayDirection * outShape.y;
                \(materialBumpCode)

                // Sun
                {
                    struct MaterialOut materialOut;
                    materialOut.color = float4(0,0,0,1);
                    materialOut.mask = float3(0);
                    
                    float3 hitPosition = position;
                    float3 directionToLight = normalize(lights.lights[0].directionToLight.xyz);
                    float4 lightType = float4(0);
                    float4 lightColor = lights.lights[0].lightColor;
                    float shadow = shadows.y;
                    float occlusion = shadows.x;
                    float3 mask = float3(1);
                                                
                    material0(rayOrigin, rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &materialOut, __funcData);
                    outColor += materialOut.color;
        
                    reflectionShape = float4(1000, 1000, -1, -1);
                    reflectionDir.xyz = materialOut.reflectionDir;
                    reflectionDir.w = materialOut.reflectionDist;
                    maskOut.xyz = materialOut.mask * shadows.y;
                }
        
                \(lightSamplingCode)
        
                outColor.xyz += uniforms.ambientColor.xyz;
            }
        
            maskTextureOut.write(half4(maskOut), textureUV);
            reflectionTextureOut.write(half4(reflectionShape), textureUV);
            reflectionDirTextureOut.write(half4(reflectionDir), textureUV);
            
            return outColor;
        }
        
        fragment float4 reflectionFragment(RasterizerData vertexIn [[stage_in]],
                                    __REFLECTION_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    texture2d<half, access::read> depthTexture [[texture(2)]],
                                    texture2d<half, access::read> reflectionTexture [[texture(3)]],
                                    texture2d<half, access::read> reflectionDirTexture [[texture(4)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(5)]])
        {
            __REFLECTION_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 shape = float4(depthTexture.read(textureUV));
        
            float4 inShape = float4(1000, 1000, -1, -1);
            float4 outShape = inShape;
        
            // Check if anything ELSE reflects on the ground
            if (shape.w > -0.4 && (shape.w < \(idStart - 0.1) || shape.w > \(idEnd + 0.1)))
            {
                float maxDistance = 10.0;
            
                float3 camOrigin = uniforms.cameraOrigin;
                float3 camDirection = float3(camDirectionTexture.read(textureUV).xyz);
            
                float3 rayOrigin = camOrigin + shape.y * camDirection;
                float4 direction = float4(reflectionDirTexture.read(textureUV));
                float3 rayDirection = direction.xyz;
                rayOrigin += direction.w * rayDirection;
        
                float3 outNormal = float3(0);
        
                \(groundComponent.code!)
        
                if (outShape.y > inShape.y)
                    outShape = inShape;
            }

            return outShape;
        }
        
        fragment float4 reflMaterialFragment(RasterizerData vertexIn [[stage_in]],
                                     __REFLMATERIAL_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     constant LightUniforms &lights [[ buffer(2) ]],
                                     texture2d<half, access::read> depthTexture [[texture(3)]],
                                     texture2d<half, access::read> reflectionTexture [[texture(4)]],
                                     texture2d<half, access::read> reflectionDirTexture [[texture(5)]],
                                     texture2d<half, access::read> camDirectionTexture [[texture(6)]],
                                     texture2d<half, access::read> maskTexture [[texture(7)]])
         {
             __REFLMATERIAL_INITIALIZE_FUNC_DATA__
         
             float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
             float2 size = uniforms.screenSize;
             ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

             float4 outColor = float4(0);
             float4 shape = float4(depthTexture.read(textureUV));
             float4 reflectionShape = float4(reflectionTexture.read(textureUV));
             float4 mask = float4(maskTexture.read(textureUV));

             if (reflectionShape.w >= \(idStart - 0.1) && reflectionShape.w <= \(idEnd + 0.1))
             {
                 float2 shadows = float2(1,1);

                 float3 rayOrigin = uniforms.cameraOrigin;
                 float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);

                 float4 reflectionDir = float4(reflectionDirTexture.read(textureUV));

                 float3 position = (rayOrigin + shape.y * rayDirection) + reflectionDir.xyz * (reflectionShape.y + reflectionDir.w);
                 float3 outNormal = float3(0);
                 float4 outShape = shape;
         
                 \(groundComponent.code!)
                 \(materialBumpCode)
         
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

                     material0(rayOrigin, rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);
        
                     outColor.xyz += uniforms.ambientColor.xyz;
                     outColor.xyz += __materialOut.color.xyz * mask.xyz;
                     outColor.w = 1.0;
                 }
         
                 \(lightSamplingCode)
             }
         
            return outColor;
        }
        
        kernel void sphereContacts( constant float4 *__data [[ buffer(0) ]],
                                    constant float4 *sphereIn [[ buffer(1) ]],
                                     device float4  *sphereOut [[ buffer(2) ]],
                            constant SphereUniforms &uniforms [[ buffer(3) ]],
                                              uint  gid [[thread_position_in_grid]])
        {
            float GlobalTime = __data[0].x;
            float GlobalSeed = __data[0].z;
            
            struct FuncData __funcData_;
            thread struct FuncData *__funcData = &__funcData_;
            __funcData_.GlobalTime = GlobalTime;
            __funcData_.GlobalSeed = GlobalSeed;
            __funcData_.inShape = float4(1000, 1000, -1, -1);
            __funcData_.hash = 1.0;

            __funcData_.__data = __data;

            float4 out = float4(0,1,0,0);

            float4 outShape = float4(1000, 1000, -1, -1);
            float3 outNormal = float3(0);
        
            for( int i = 0; i < uniforms.numberOfSpheres; ++i)
            {
                float3 position = sphereIn[i].xyz;
                float d = position.y;

                out.w = d - sphereIn[i].w;
        
                sphereOut[gid + i] = out;
            }
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "MAIN", textureOffset: 3, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "MATERIAL", fragmentName: "materialFragment", textureOffset: 12, blending: true),
            Shader(id: "REFLECTION", fragmentName: "reflectionFragment", textureOffset: 6, blending: false),
            Shader(id: "REFLMATERIAL", fragmentName: "reflMaterialFragment", textureOffset: 8, addition: true)
        ])        
    }
    
    override func render(texture: MTLTexture)
    {
        updateData()
        
        if let mainShader = shaders["MAIN"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShapeTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = createFragmentUniform()

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 2)
            applyUserFragmentTextures(shader: mainShader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    override func materialPass(texture: MTLTexture)
    {
        if let shader = shaders["MATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            //renderEncoder.waitForFence(prtInstance.fence, before: .fragment)
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            
            var fragmentUniforms = createFragmentUniform()
            var lightUniforms = prtInstance.utilityShader!.createLightStruct()

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentShadowTexture!, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 5)
            renderEncoder.setFragmentTexture(prtInstance.otherReflTexture, index: 6)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 7)
            renderEncoder.setFragmentTexture(prtInstance.otherReflDirTexture, index: 8)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 9)
            renderEncoder.setFragmentTexture(prtInstance.currentMaskTexture!, index: 10)
            renderEncoder.setFragmentTexture(prtInstance.otherMaskTexture!, index: 11)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    override func reflectionPass(texture: MTLTexture)
    {
        if let shader = shaders["REFLECTION"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherReflTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            //renderEncoder.waitForFence(prtInstance.fence, before: .fragment)
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = createFragmentUniform()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 5)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    override func reflectionMaterialPass(texture: MTLTexture)
    {
        if let shader = shaders["REFLMATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            
            //renderEncoder.waitForFence(prtInstance.fence, before: .fragment)
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = createFragmentUniform()
            var lightUniforms = prtInstance.utilityShader!.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)
            
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 5)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 6)
            renderEncoder.setFragmentTexture(prtInstance.currentMaskTexture!, index: 7)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    func generateMaterialCode(stageItem: StageItem, materialIndex: Int = 0) -> String
    {
        var globalCode = ""
        
        if let material = getFirstComponentOfType(stageItem.children, .Material3D) {

            globalCode +=
            """
            
            void material\(materialIndex)(float3 rayOrigin, float3 incomingDirection, float3 hitPosition, float3 hitNormal, float3 directionToLight, float4 lightType,
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
            
                float2 outUV = float2(0);
                float3 position = hitPosition;
            
            """
            
            // UV Mapping
            
            var uvMappingCode = ""
            if let uvMap = getFirstComponentOfType(stageItem.children, .UVMAP3D) {
                dryRunComponent(uvMap, data.count)
                collectProperties(uvMap)
                
                globalCode = uvMap.globalCode! + globalCode
                globalCode += uvMap.code!
                
                uvMappingCode = uvMap.code!
            }
            
            globalCode +=
            """
            
            uv = outUV;
            
            """
            
            // ---
            
            // Get the patterns of the material if any
            var patterns : [CodeComponent] = []
            if let materialStageItem = getFirstStageItemOfComponentOfType(stageItem.children, .Material3D) {
                if materialStageItem.componentLists["patterns"] != nil {
                    patterns = materialStageItem.componentLists["patterns"]!
                }
            }
            
            dryRunComponent(material, data.count, patternList: patterns)
            collectProperties(material)
            if let gCode = material.globalCode {
                globalCode = gCode + globalCode
            }
            if let code = material.code {
                globalCode += code
            }
            
            // Check if material has a bump
            for (_, conn) in material.propertyConnections {
                let fragment = conn.2
                if fragment.name == "bump" && material.properties.contains(fragment.uuid) {
                    
                    // Needs shape, outNormal, position
                    materialBumpCode +=
                    """
                    
                    {
                        float3 realPosition = position;
                        float3 position = realPosition; float3 normal = outNormal;
                        float2 outUV = float2(0);
                        float bumpFactor = 0.2;
                    
                        // bref
                        {
                            \(uvMappingCode)
                        }
                    
                        struct PatternOut data;
                        \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                        float bRef = data.\(conn.1);
                    
                        const float2 e = float2(.001, 0);
                    
                        // b1
                        position = realPosition - e.xyy;
                        {
                            \(uvMappingCode)
                        }
                        \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                        float b1 = data.\(conn.1);
                    
                        // b2
                        position = realPosition - e.yxy;
                        {
                            \(uvMappingCode)
                        }
                        \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                        float b2 = data.\(conn.1);
                    
                        // b3
                        position = realPosition - e.yyx;
                        \(uvMappingCode)
                        \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                        float b3 = data.\(conn.1);
                    
                        float3 grad = (float3(b1, b2, b3) - bRef) / e.x;
                    
                        grad -= normal * dot(normal, grad);
                        outNormal = normalize(normal + grad * bumpFactor);
                    }

                    """
                    
                }
            }
            
            globalCode +=
            """
                
                __materialOut->color = outColor;
                __materialOut->mask = outMask;
                __materialOut->reflectionDir = outReflectionDir;
                __materialOut->reflectionDist = outReflectionDist;
            }
            
            """
        }
        
        return globalCode
    }
    
    func sphereContacts(objectSpheres: [ObjectSpheres3D])
    {
        if sphereContactsState == nil {
            sphereContactsState = createComputeState(name: "sphereContacts")
        }
         
        if let state = sphereContactsState {
                         
            updateData()
             
            let commandQueue = device.makeCommandQueue()
            let commandBuffer = commandQueue!.makeCommandBuffer()!
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
             
            computeEncoder.setComputePipelineState( state )
            computeEncoder.setBuffer(buffer, offset: 0, index: 0)
             
            var sphereUniforms = SphereUniforms()
            
            var sphereData : [float4] = []
            
            for oS in objectSpheres {
                for s in oS.spheres {
                    sphereData.append(s + oS.position)
                }
            }
            
            sphereUniforms.numberOfSpheres = Int32(sphereData.count)
            
            let inBuffer = device.makeBuffer(bytes: sphereData, length: sphereData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            computeEncoder.setBuffer(inBuffer, offset: 0, index: 1)

            let outBuffer = device.makeBuffer(length: sphereData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            computeEncoder.setBuffer(outBuffer, offset: 0, index: 2)
            
            computeEncoder.setBytes(&sphereUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 3)

            let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
            let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
            computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
             
            computeEncoder.endEncoding()
            commandBuffer.commit()
             
            commandBuffer.waitUntilCompleted()
             
            let result = outBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: 1)
            
            var index : Int = 0
            for oS in objectSpheres {
                for _ in oS.spheres {
                    
                    if result[index].w < oS.penetrationDepth {
                        oS.penetrationDepth = result[index].w
                        oS.hitNormal = float3(result[index].x, result[index].y, result[index].z)
                    }
                    
                    index += 1
                }
            }
         }
     }
}
