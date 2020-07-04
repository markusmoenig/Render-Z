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
        dryRunComponent(backComponent, data.count)
        collectProperties(backComponent)

        let fragmentCode =
        """

        \(backComponent.globalCode!)

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     __MAIN_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     texture2d<half, access::read> camDirectionTexture [[texture(1)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            __MAIN_INITIALIZE_FUNC_DATA__

            float3 outDirection = float3(camDirectionTexture.read(textureUV).xyz);

            float4 outColor = float4(0,0,0,1);
            float3 rayDirection = outDirection;
        
            \(backComponent.code!)

            return float4(outColor.xyz, 1.0);
        }
        
        fragment float4 reflMaterialFragment(RasterizerData in [[stage_in]],
                                     __REFLMATERIAL_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     texture2d<half, access::read> depthTexture [[texture(1)]],
                                     texture2d<half, access::read> reflectionTexture [[texture(2)]],
                                     texture2d<half, access::read> reflectionDirTexture [[texture(3)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 outColor = float4(0,0,0,0);
            float4 shape = float4(depthTexture.read(textureUV));
            float4 reflectionShape = float4(reflectionTexture.read(textureUV));
                
            if (isNotEqual(shape.w, -1) && isEqual(reflectionShape.w, -1))
            {
                __REFLMATERIAL_INITIALIZE_FUNC_DATA__

                float4 direction = float4(reflectionDirTexture.read(textureUV));
                float3 outDirection = direction.xyz;

                float3 rayDirection = outDirection;
            
                \(backComponent.code!)
        
                outColor *= direction.w;
            }

            return outColor;
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
                Shader(id: "MAIN", textureOffset: 2, blending: false),
                Shader(id: "REFLMATERIAL", fragmentName: "reflMaterialFragment", textureOffset: 4, addition: true)
        ])
    }
    
    override func render(texture: MTLTexture)
    {
        updateData()
        
        if let mainShader = shaders["MAIN"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 1.0)
            
            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // ---
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(texture.width), height: Double(texture.height), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(texture.width), Float(texture.height) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 1)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
        }
    }
    
    override func reflectionMaterialPass(texture: MTLTexture)
    {
        if let mainShader = shaders["REFLMATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // ---
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(texture.width), height: Double(texture.height), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(texture.width), Float(texture.height) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 3)
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