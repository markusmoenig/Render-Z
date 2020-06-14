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
        
    init(scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
                    
        super.init()
        
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

        let fragmentCode =
        """

        \(camera.globalCode!)
        \(groundComponent.globalCode!)

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     constant float4 *__data [[ buffer(2) ]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
            float2 jitter = float2(1);

            __INITIALIZE_FUNC_DATA__

            float3 outPosition = float3(0,0,0);
            float3 outDirection = float3(0,0,0);

            float3 position = float3(uv.x, uv.y, 0);
        
            float outMask = 0;
            float outId = 0;

            float4 outColor = float4(0,0,0,1);
        
            \(camera.code!)
        
            float3 rayOrigin = outPosition;
            float3 rayDirection = outDirection;
        
            float4 outShape = float4(1000, 1000, -1, -1);
            float3 outNormal = float3(0);
        
            \(groundComponent.code!)

            if (outShape.x == 0.0)
                outColor = float4(0,1,0,1);
            else outColor = float4(0);
            
            return outColor;
        }

        """
        
        compile(vertexCode: BaseShader.getQuadVertexSource(), fragmentCode: fragmentCode, textureOffset: 3)
    }
    
    override func render(texture: MTLTexture)
    {
        //let camHelper = CamHelper3D()
        //camHelper.initFromComponent(aspect: Float(texture.width) / Float(texture.height), component: camera)
        //var matrix = camHelper.getMatrix()
        //memcpy(renderParams?.contents(), camHelper.getMatrix().m, MemoryLayout<matrix_float4x4>.size)
        
        updateData()
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // ---
        renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(texture.width), height: Double(texture.height), znear: -1.0, zfar: 1.0 ) )
        
        let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(texture.width), Float(texture.height) ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 2)

        // ---
        
        //renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        //renderEncoder.setVertexBytes(&matrix, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
    }
}
