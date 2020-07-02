//
//  GroundShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class GroundShader      : BaseShader
{
    var scene           : Scene
    var object          : StageItem
    var camera          : CodeComponent
    
    init(instance: PRTInstance, scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
                    
        super.init(instance: instance)
        
        if let ground = object.components[object.defaultName] {
            createFragmentSource(groundComponent: ground, camera: camera)
        }
    }
    
    func createFragmentSource(groundComponent: CodeComponent, camera: CodeComponent)
    {
        dryRunComponent(groundComponent, data.count)
        collectProperties(groundComponent)

        let material = generateMaterialCode(stageItem: self.object)
        
        let lightSamplingCode = prtInstance.utilityShader.createLightSamplingMaterialCode(materialCode: "material0(rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);")

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
                                     texture2d<half, access::read> camOriginTexture [[texture(2)]],
                                     texture2d<half, access::read> camDirectionTexture [[texture(3)]])
        {
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            __MAIN_INITIALIZE_FUNC_DATA__

            float3 position = float3(uv.x, uv.y, 0);
                    
            float3 rayOrigin = float3(camOriginTexture.read(textureUV).xyz);
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
                                    texture2d<half, access::read> camOriginTexture [[texture(9)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(10)]])
        {
            __MATERIAL_INITIALIZE_FUNC_DATA__
        
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 outColor = float4(0,0,0,0);

            float4 reflectionShape = float4(reflectionTextureIn.read(textureUV));
            float4 reflectionDir = float4(reflectionDirTextureIn.read(textureUV));
        
            float4 outShape = float4(shapeTexture.read(textureUV));
            if (isEqual(outShape.w, 0.0)) {
                float2 shadows = float2(shadowTexture.read(textureUV).xy);
            
                float3 rayOrigin = float3(camOriginTexture.read(textureUV).xyz);
                float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
                float3 outNormal = float3(0);
            
                \(groundComponent.code!)
            
                float3 position = rayOrigin + rayDirection * outShape.y;
        
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
                                                
                    material0(rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &materialOut, __funcData);
                    outColor += materialOut.color;
        
                    reflectionShape = float4(1000, 1000, -1, -1);
                    reflectionDir.xyz = materialOut.reflectionDir;
                }
        
                \(lightSamplingCode)
            }
        
            reflectionTextureOut.write(half4(reflectionShape), textureUV);
            reflectionDirTextureOut.write(half4(reflectionDir), textureUV);
        
            return outColor;
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "MAIN", textureOffset: 3, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "MATERIAL", fragmentName: "materialFragment", textureOffset: 11, blending: true)
        ])
        
        prtInstance.idCounter += 1
    }
    
    override func render(texture: MTLTexture)
    {
        updateData()
        
        if let mainShader = shaders["MAIN"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShapeTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
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

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.camOriginTexture!, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 3)
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
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 5)
            renderEncoder.setFragmentTexture(prtInstance.otherReflTexture, index: 6)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 7)
            renderEncoder.setFragmentTexture(prtInstance.otherReflDirTexture, index: 8)
            renderEncoder.setFragmentTexture(prtInstance.camOriginTexture!, index: 9)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 10)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
        }
    }
}
