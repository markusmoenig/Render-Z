//
//  MergeShader.swift
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
                                     texture2d<half, access::read> localDepthTexture [[texture(1)]],
                                     texture2d<half, access::read> shapeInTexture [[texture(2)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
        
            float4 local = float4(localDepthTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)));
            float4 depth = float4(shapeInTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)));

            float4 outShape = depth;
            
            if (local.y > 0.0 && local.y < depth.y) {
                outShape = local;
            }

            return outShape;
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [Shader(id: "MAIN", textureOffset: 0, pixelFormat: .rgba16Float, blending: false)])
    }
    
    func merge()
    {
        if let mainShader = shaders["MAIN"] {

            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShapeTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, prtInstance.screenSize.x, prtInstance.screenSize.y ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( prtInstance.screenSize.x ), UInt32( prtInstance.screenSize.y ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 0)
            renderEncoder.setFragmentTexture(prtInstance.localTexture!, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 2)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
                //print("Merge Shader: ", (cb.gpuEndTime - cb.gpuStartTime) * 1000)
            }
            
            commandBuffer.commit()
        }
    }
}
