//
//  PostShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PostShader      : BaseShader
{
    var scene           : Scene
    var sh              : [Shader] = []
    
    var fragmentCode    = ""
    var postCounter     : Int = 0
            
    init(instance: PRTInstance, scene: Scene)
    {
        self.scene = scene
                    
        super.init(instance: instance)
        
        let postStage = scene.getStage(.PostStage)
        if let item = postStage.children2D.first {
            if let list = item.componentLists["PostFX"] {
                for c in list {
                    createFragmentSource(component: c)
                }
            }
        }
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: sh)
    }
    
    func createFragmentSource(component: CodeComponent)
    {
        dryRunComponent(component, data.count)
        collectProperties(component)

        if postCounter == 0 {
            fragmentCode += prtInstance.fragmentUniforms
            
            fragmentCode +=
            """
            fragment float4 copy(RasterizerData in [[stage_in]],
                                         texture2d<half, access::read>           colorTexture [[texture(0)]])
            {
                float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
                float2 size = in.viewportSize;
                ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

                float4 color = float4(colorTexture.read(textureUV));
            
                return color;
            }
            """
            sh.append(Shader(id: "COPY", fragmentName: "copy", textureOffset: 0, blending: false))
        }
        
        fragmentCode +=
        """
                
        \(component.globalCode!)

        fragment float4 post\(postCounter)(RasterizerData in [[stage_in]],
                                     __POST\(postCounter)_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     texture2d<half, access::read>           colorTexture [[texture(1)]],
                                     texture2d<half, access::sample>         sampleTexture [[texture(2)]],
                                     texture2d<half, access::read>           depthTexture [[texture(3)]],
                                     texture2d<half, access::sample>         sampleDepthTexture [[texture(4)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            __POST\(postCounter)_INITIALIZE_FUNC_DATA__

            float4 outColor = float4(0, 0, 0, 1);
            float4 color = float4(colorTexture.read(textureUV));
            float4 shape = float4(depthTexture.read(textureUV));
        
            __funcData->texture1 = &sampleTexture;
            __funcData->texture2 = &sampleDepthTexture;
        
            \(component.code!)
        
            return outColor;
        }

        """
        
        sh.append(Shader(id: "POST\(postCounter)", fragmentName: "post\(postCounter)", textureOffset: 5, blending: false))
        postCounter += 1
    }
    
    func render(texture: MTLTexture, otherTexture: MTLTexture)
    {
        updateData()
        
        for i in 0..<postCounter {
            if let mainShader = shaders["POST\(i)"] {
                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = otherTexture
                renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
                
                let renderEncoder = prtInstance.commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
                renderEncoder.setRenderPipelineState(mainShader.pipelineState)
                
                // ---
                renderEncoder.setViewport( prtInstance.quadViewport )
                renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
                
                var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
                renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
                
                renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
                renderEncoder.setFragmentTexture(texture, index: 1)
                renderEncoder.setFragmentTexture(texture, index: 2)
                renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
                renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 4)
                // ---
                
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                
                renderEncoder.endEncoding()
                
                copy(texture: texture, otherTexture: otherTexture)
            }
        }
    }
    
    func copy(texture: MTLTexture, otherTexture: MTLTexture)
    {
        if let shader = shaders["COPY"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let renderEncoder = prtInstance.commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // ---
            renderEncoder.setViewport( prtInstance.quadViewport )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            renderEncoder.setFragmentTexture(otherTexture, index: 0)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
}
