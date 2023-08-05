//
//  FXShape.swift
//  Render-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class FXShape               : BaseShader
{
    var scene               : Scene
    var uuid                : UUID
    var camera              : CodeComponent
            
    init(instance: PFXInstance, scene: Scene, uuid: UUID, camera: CodeComponent)
    {
        self.scene = scene
        self.camera = camera
        self.uuid = uuid
                    
        super.init(instance: instance)
        
        if let comp = scene.itemOfUUID(uuid) {
            if comp.componentType == .Shape {
                createFragmentSource(component: comp, camera: camera)
                comp.shader = self
            }
        }
    }
    
    func needsToCompile(scene: Scene) -> Bool
    {
        var compile = true
        
        if let comp = scene.itemOfUUID(uuid) {
            if comp.shader != nil {
                compile = false
            }
        }

        return compile
    }
    
    func createFragmentSource(component: CodeComponent, camera: CodeComponent)
    {
        dryRunComponent(component, data.count)
        collectProperties(component)
        
        let fragmentCode =
        """
        
        \(prtInstance.fragmentUniforms)
        \(component.globalCode!)

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     __MAIN_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<half, access::read> camOriginTexture [[texture(2)]],
                                     texture2d<half, access::read> camDirectionTexture [[texture(3)]],
                                     texture2d<half, access::read_write> distanceNormalTexture [[texture(4)]])
        {
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            float2 size = in.viewportSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);
        
            __MAIN_INITIALIZE_FUNC_DATA__

            __funcData->cameraOrigin = float4(camOriginTexture.read(textureUV)).xyz;
            __funcData->cameraDirection = float4(camDirectionTexture.read(textureUV)).xyz;
            float4 distanceNormal = float4(distanceNormalTexture.read(textureUV));
        
            float3 CamOrigin = __funcData->cameraOrigin;
            float3 CamDir = __funcData->cameraDirection;
        
            float4 outColor = float4(0, 0, 0, 1);
        
            float outDistance = 10000.0;
            float3 outNormal = float3(0, 0, 0);
            float3 outMaterialAlbedo = float3(0, 0, 0);
            float outMaterialMetallic = 1.0;
            float outMaterialRoughness = 1.0;
            float3 outMaterialEmissive = float3(0, 0, 0);
            float3 outMaterialTransmissive = float3(0, 0, 0);

            \(component.code!)

            if (outDistance < distanceNormal.x) {
                distanceNormal.x = outDistance;
                distanceNormal.yzw = outNormal;
                distanceNormalTexture.write(half4(distanceNormal), textureUV);
            }
        
            return float4(outColor);
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
                Shader(id: "MAIN", textureOffset: 5, blending: true),
        ], sync: true)
    }
    
    override func render(texture: MTLTexture)
    {
        updateData()
        
        if let mainShader = shaders["MAIN"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            //renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 1.0)
            
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
            renderEncoder.setFragmentTexture(prtInstance.camOriginTexture!, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.distanceNormalTexture!, index: 4)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
}
