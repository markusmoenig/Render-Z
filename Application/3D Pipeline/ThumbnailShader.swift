//
//  ThumbnailShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 22/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class ThumbnailShader       : BaseShader
{
    let camera              : CodeComponent
    
    init(instance: PRTInstance, shape: CodeComponent, camera: CodeComponent)
    {
        self.camera = camera
        super.init(instance: instance)
        
        createThumbnailSource(shape: shape)
    }
    
    func createThumbnailSource(shape: CodeComponent)
    {
        dryRunComponent(camera, data.count)
        collectProperties(camera)
        
        dryRunComponent(shape, data.count)
        collectProperties(shape)
        
        let fragmentCode =
        """

        \(prtInstance.fragmentUniforms)
        \(camera.globalCode!)
        \(shape.globalCode!)
        
        float4 sceneMap(float3 position, thread struct FuncData *__funcData)
        {
            float outDistance = 10;
            float bump = 0;
            float scale = 1;

            float4 outShape = float4(1000, 1000, -1, -1);

            constant float4 *__data = __funcData->__data;
            float GlobalTime = __funcData->GlobalTime;
            float GlobalSeed = __funcData->GlobalSeed;
        
            \(shape.code!)
        
            outShape = float4(outDistance, 0, 0, 0);
        
            return outShape;
        }

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
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
        
            float4 inShape = float4(1000, 1000, -1, -1);
            float4 outShape = float4(1000, 1000, -1, -1);
            float maxDistance = 15.0;
            float4 outColor = float4(0,0,0,0);

            float RJrRIP=0.001;
            int nRqCSQ=70;
            for( int noGouA=0; noGouA<nRqCSQ&&RJrRIP<maxDistance; noGouA+=1) {
                float4 cKFBUP=sceneMap( rayOrigin+rayDirection*RJrRIP, __funcData) ;
                if( cKFBUP.x<0.001*RJrRIP) {
                    outShape=cKFBUP;
                    outShape.y=RJrRIP;
                    break;
                }
                RJrRIP+=cKFBUP.x;
            }
        
            if (isNotEqual(outShape.w, inShape.w)) {
                float3 position = rayOrigin + outShape.y * rayDirection;
                float3 outNormal;

                float2 dXjBFB=float2( 1.000, -1.000) *0.5773*0.0005;
                outNormal=dXjBFB.xyy*sceneMap( position+dXjBFB.xyy, __funcData) .x;
                outNormal+=dXjBFB.yyx*sceneMap( position+dXjBFB.yyx, __funcData) .x;
                outNormal+=dXjBFB.yxy*sceneMap( position+dXjBFB.yxy, __funcData) .x;
                outNormal+=dXjBFB.xxx*sceneMap( position+dXjBFB.xxx, __funcData) .x;
                outNormal=normalize( outNormal) ;
        
                float3 L = float3(-0.5, 0.3, 0.7);
                outColor.xyz = dot(L, outNormal);

                L = float3(0.5, 0.3, -0.7);
                outColor.xyz += dot(L, outNormal);

                L = float3(0.5, -0.3, 0.7);
                outColor.xyz += dot(L, outNormal);
                outColor.xyz = pow( outColor.xyz, float3(0.4545) );
                outColor.w = 1.0;
            }
        
            return outColor;
        }

        """
                
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "MAIN", textureOffset: 0, pixelFormat: .bgra8Unorm)
        ], sync: true)
    }
    
    override func render(texture: MTLTexture)
    {
        if let shader = shaders["MAIN"] {
            updateData()
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0, alpha: 0.0)

            let renderEncoder = prtInstance.commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
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

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            
            // ---
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            prtInstance.commandBuffer.commit()
        }
    }
}
