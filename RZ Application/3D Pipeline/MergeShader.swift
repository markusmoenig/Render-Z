//
//  GroundShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class MergeShader      : BaseShader
{
    override init(instance: PRTInstance)
    {                    
        super.init(instance: instance)
        
        createFragmentSource()
    }
    
    func createFragmentSource()
    {
        let fragmentCode =
        """

        \(prtInstance.fragmentUniforms)

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant FragmentUniforms &uniforms [[ buffer(0) ]],
                                     texture2d<half, access::read_write> depthTexture [[texture(1)]],
                                     texture2d<half, access::read> localDepthTexture [[texture(2)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
        
            float4 depth = float4(depthTexture.read(ushort2(uv.x * size.x, uv.y * size.y)));
            float4 local = float4(localDepthTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)));
        
            float4 outColor = float4(0, 0, 0, 0);
            
            if (local.w > 0.0 && local.w < depth.y) {
                outColor = float4(local.xyz, local.w);
            }

            //outColor = float4(float3(depth.y / 10.0), 1);// float4(local.xyz, 1);

            //outColor = float4(float3(local.y / 10), 1);

            return outColor;
        }

        """
        
        compile(vertexCode: BaseShader.getQuadVertexSource(), fragmentCode: fragmentCode, textureOffset: 3)
    }
    
    func merge(output: MTLTexture, localDepth: MTLTexture)
    {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = output
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // --- Vertex
        renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(output.width), height: Double(output.height), znear: -1.0, zfar: 1.0 ) )
        
        let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, prtInstance.screenSize.x, prtInstance.screenSize.y ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        var viewportSize : vector_uint2 = vector_uint2( UInt32( output.width ), UInt32( output.height ) )
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        // --- Fragment
        
        var fragmentUniforms = ObjectFragmentUniforms()
        fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
        fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
        fragmentUniforms.screenSize = prtInstance.screenSize

        renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 0)
        renderEncoder.setFragmentTexture(prtInstance.depthTexture!, index: 1)
        renderEncoder.setFragmentTexture(localDepth, index: 2)
        // ---
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { cb in
            globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
        }
        
        commandBuffer.commit()
    }
}
