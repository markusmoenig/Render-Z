//
//  PrimitivesShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PrimitivesShader      : BaseShader
{
    var camera              : CodeComponent!
    var instance            : PRTInstance!
    
    init(instance: PRTInstance, camera: CodeComponent)
    {
        self.instance = instance
        
        self.camera = camera
        super.init(instance: instance)
        
        createFragmentSource()
    }
    
    func createFragmentSource()
    {
        dryRunComponent(camera, data.count)
        collectProperties(camera)
        
        let fragmentCode =
        """

        \(prtInstance.fragmentUniforms)
        \(camera.globalCode!)
        
        fragment float4 drawSpheres(RasterizerData in [[stage_in]],
                                     constant FragmentUniforms &uniforms [[ buffer(0) ]],
                                     constant float4 *spheres [[ buffer(1) ]],
                                     constant float4 *__data [[ buffer(2) ]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
        
            float2 jitter = float2(0.5);
            float3 outPosition = float3(0,0,0);
            float3 outDirection = float3(0,0,0);
            
            float3 position = float3(uv.x, uv.y, 0);

            \(camera.code!)
        
            float4 outColor = float4(0);
            float4 color = float4(0);

            float t = 0.0001;
            int steps = 70;
            float stepSize = 1.0;
            for (int i = 0; i < steps; ++i)
            {
                float3 pos = outPosition + outDirection * t;
                
                int index = 0;
                float d = 1000;

                while(1)
                {
                    constant float4 *posAndRadius = &spheres[index++];
                    if (posAndRadius->w < 0.0) break;
                    float4 ccolor = spheres[index++];

                    float dd = length(pos - posAndRadius->xyz) - posAndRadius->w;
                    if (dd < d) {
                        color = ccolor;
                        d = dd;
                    }
                }
                if (abs(d) < 0.001 * t) {
                    outColor = color;
                    break;
                }
                t += d * stepSize;
            }
            return outColor;
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "DRAWSPHERES", fragmentName: "drawSpheres", textureOffset: 0, pixelFormat: .rgba16Float, blending: true),
        ], sync: true)
    }
    
    func drawSpheres(texture: MTLTexture, sphereData: [SIMD4<Float>])
    {
        if let mainShader = shaders["DRAWSPHERES"] {

            updateData()

            prtInstance.commandQueue = globalApp!.mmView.device!.makeCommandQueue()
            prtInstance.commandBuffer = prtInstance.commandQueue!.makeCommandBuffer()!
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(texture.width), height: Double(texture.height), znear: 0.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(texture.width), Float(texture.height) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize
            
            //var sphereUniforms = SphereUniforms()
            //sphereUniforms.spheres.0.posAndRadius = SIMD4<Float>(0,0,0,1)
            //sphereUniforms.spheres.0.color = SIMD4<Float>(1,0,0,0.5)
            //sphereUniforms.spheres.1.posAndRadius = SIMD4<Float>(0,0,0,-1)

            let sphereBuffer = device.makeBuffer(bytes: sphereData, length: sphereData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!

            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 0)
            renderEncoder.setFragmentBuffer(sphereBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 2)

            // ---
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            prtInstance.commandBuffer!.commit()
        }
    }
}
