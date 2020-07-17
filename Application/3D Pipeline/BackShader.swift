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
    
    var cloudHeaderCode = ""
    var cloudCode       = ""
            
    init(instance: PRTInstance, scene: Scene, camera: CodeComponent)
    {
        self.scene = scene
        self.camera = camera
                    
        super.init(instance: instance)
        
        let preStage = scene.getStage(.PreStage)
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome || comp.componentType == .Pattern {
                createFragmentSource(backComponent: comp, camera: camera)
                item.shader = self
            }
        }
    }
    
    static func needsToCompile(scene: Scene) -> Bool
    {
        var compile = true
        
        let preStage = scene.getStage(.PreStage)
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome || comp.componentType == .Pattern {
                if item.shader != nil {
                    compile = false
                }
            }
        }

        return compile
    }
    
    func createFragmentSource(backComponent: CodeComponent, camera: CodeComponent)
    {
        dryRunComponent(backComponent, data.count)
        collectProperties(backComponent)

        createCloudCode()
        
        let fragmentCode =
        """
        
        \(prtInstance.fragmentUniforms)
        \(backComponent.globalCode!)
        \(cloudHeaderCode)

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     __MAIN_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<half, access::read> camDirectionTexture [[texture(2)]],
                                     texture2d<half, access::write> shapeTexture [[texture(3)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            __MAIN_INITIALIZE_FUNC_DATA__

            float3 outDirection = float3(camDirectionTexture.read(textureUV).xyz);

            shapeTexture.write(half4(1000, 1000, -1, -1), textureUV);

            float4 outColor = float4(0,0,0,1);
            float3 rayOrigin = uniforms.cameraOrigin;
            float3 rayDirection = outDirection;
        
            \(backComponent.code!)
        
            float4 inColor = outColor;

            \(cloudCode)

            return float4(outColor.xyz, 1.0);
        }
        
        fragment float4 reflMaterialFragment(RasterizerData in [[stage_in]],
                                     __REFLMATERIAL_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<half, access::read> depthTexture [[texture(2)]],
                                     texture2d<half, access::read> reflectionTexture [[texture(3)]],
                                     texture2d<half, access::read> reflectionDirTexture [[texture(4)]],
                                     texture2d<half, access::read> maskTexture [[texture(5)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);
            
            float4 outColor = float4(0,0,0,0);
            float4 shape = float4(depthTexture.read(textureUV));
            float4 reflectionShape = float4(reflectionTexture.read(textureUV));

            if (isNotEqual(shape.w, -1) && isEqual(reflectionShape.w, -1))
            {
                float4 mask = float4(maskTexture.read(textureUV));

                __REFLMATERIAL_INITIALIZE_FUNC_DATA__

                float4 direction = float4(reflectionDirTexture.read(textureUV));
                float3 outDirection = direction.xyz;

                float3 rayOrigin = uniforms.cameraOrigin;
                float3 rayDirection = outDirection;
        
                \(backComponent.code!)
        
                float4 inColor = outColor;

                \(cloudCode)
        
                outColor.xyz *= mask.xyz;
            }

            return outColor;
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
                Shader(id: "MAIN", textureOffset: 4, blending: false),
                Shader(id: "REFLMATERIAL", fragmentName: "reflMaterialFragment", textureOffset: 6, addition: true)
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
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // ---
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            var fragmentUniforms = createFragmentUniform()

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    override func reflectionMaterialPass(texture: MTLTexture)
    {
        if let shader = shaders["REFLMATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // ---
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            var fragmentUniforms = createFragmentUniform()

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.currentMaskTexture, index: 5)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    func createCloudCode()
    {
        // Insert fog / cloud if they dont exist
        let preStage = scene.getStage(.PreStage)
        for c in preStage.children3D {
            if let list = c.componentLists["clouds"] {
                for cloudComp in list {
                    dryRunComponent(cloudComp, data.count)
                    collectProperties(cloudComp)
                    
                    if let headerCode = cloudComp.globalCode {
                        cloudHeaderCode += headerCode
                    }
                    
                    cloudCode +=
                    """

                    inColor = outColor;
                    
                    """
                    cloudCode += cloudComp.code!
                }
            }
        }
    }
}
