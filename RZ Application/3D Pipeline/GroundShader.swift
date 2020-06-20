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
        dryRunComponent(camera, data.count)
        collectProperties(camera)
        
        dryRunComponent(groundComponent, data.count)
        collectProperties(groundComponent)

        let material = generateMaterialCode(stageItem: self.object)
        
        let fragmentCode =
        """

        \(prtInstance.fragmentUniforms)
        
        \(camera.globalCode!)
        \(groundComponent.globalCode!)
        \(material)

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     __MAIN_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]])
        {
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 jitter = float2(0.5);

            __MAIN_INITIALIZE_FUNC_DATA__

            float3 outPosition = float3(0,0,0);
            float3 outDirection = float3(0,0,0);

            float3 position = float3(uv.x, uv.y, 0);
        
            float outMask = 0;
            float outId = 0;
            
            \(camera.code!)
        
            float3 rayOrigin = outPosition;
            float3 rayDirection = outDirection;
        
            float4 outShape = float4(1000, 1000, -1, -1);
            float3 outNormal = float3(0);
        
            \(groundComponent.code!)
                    
            return outShape;
        }
                
        fragment float4 materialFragment(RasterizerData in [[stage_in]],
                                    __MATERIAL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    texture2d<half, access::read> shapeTexture [[texture(2)]])
        {
            __MATERIAL_INITIALIZE_FUNC_DATA__
        
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
        
            float4 outColor = float4(0,0,0,0);

            float4 outShape = float4(shapeTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)));
            if (isEqual(outShape.w, 0.0)) {
                float2 jitter = float2(0.5);

                float3 outPosition = float3(0,0,0);
                float3 outDirection = float3(0,0,0);

                float3 position = float3(uv.x, uv.y, 0);
            
                float outMask = 0;
                float outId = 0;
            
                \(camera.code!)
            
                float3 rayOrigin = outPosition;
                float3 rayDirection = outDirection;
            
                float3 outNormal = float3(0);
            
                \(groundComponent.code!)
            
                struct MaterialOut materialOut;
                materialOut.color = float4(0,0,0,1);
                materialOut.mask = float3(0);
                
                float3 hitPosition = rayOrigin + rayDirection * outShape.y;
                float3 directionToLight = float3(0,1,0);
                float4 lightType = float4(0);
                float4 lightColor = float4(20);
                float shadow = 1.0;
                float occlusion = 1.0;
                float3 mask = float3(1);
                                            
                material0(rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &materialOut, __funcData);
            
                outColor = materialOut.color;
            }
        
            return outColor;
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "MAIN", textureOffset: 3, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "MATERIAL", fragmentName: "materialFragment", textureOffset: 4, blending: true)
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

            //renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 2)
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

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 2)
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
