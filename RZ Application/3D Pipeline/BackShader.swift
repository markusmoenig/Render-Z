//
//  BackgroundShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class BackgroundShader      : BaseShader
{
    var scene           : Scene
    var camera          : CodeComponent
            
    init(instance: PRTInstance, scene: Scene, camera: CodeComponent)
    {
        self.scene = scene
        self.camera = camera
                    
        super.init(instance: instance)
        
        let preStage = scene.getStage(.PreStage)
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome || comp.componentType == .Pattern {
                createFragmentSource(backComponent: comp, camera: camera)
            }
        }
    }
    
    func createFragmentSource(backComponent: CodeComponent, camera: CodeComponent)
    {
        dryRunComponent(camera, data.count)
        collectProperties(camera)
        
        dryRunComponent(backComponent, data.count)
        collectProperties(backComponent)

        let fragmentCode =
        """

        \(camera.globalCode!)
        \(backComponent.globalCode!)

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
        
            float3 rayDirection = outDirection;
        
            \(backComponent.code!)

            return float4(pow(outColor.x, 0.4545), pow(outColor.y, 0.4545), pow(outColor.z, 0.4545), 1.0);
        }

        """
        
        compile(vertexCode: BaseShader.getQuadVertexSource(), fragmentCode: fragmentCode, textureOffset: 3)
    }
    
    override func render(texture: MTLTexture)
    {
        updateData()
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 1.0)
        
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
        
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { cb in
            globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
        }
        
        commandBuffer.commit()
    }
}
