//
//  MergeShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class UtilityShader         : BaseShader
{
    let scene               : Scene
    
    init(instance: PRTInstance, scene: Scene)
    {
        self.scene = scene
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
        
        fragment float2 clearShadowsFragment(RasterizerData in [[stage_in]])
        {
            return float2(1,1);
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "MERGE", textureOffset: 0, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "CLEARSHADOW", fragmentName: "clearShadowFragment", textureOffset: 0, pixelFormat: .rg16Float, blending: false),
        ])
    }
    
    func mergeShapes()
    {
        if let mainShader = shaders["MERGE"] {

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
    
    func clearShadow(shadowTexture: MTLTexture)
    {
        if let shader = shaders["CLEARSHADOW"], shader.shaderState == .Compiled {

            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = shadowTexture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1, alpha: 1.0)

            let commandBuffer = shader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, prtInstance.screenSize.x, prtInstance.screenSize.y ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( prtInstance.screenSize.x ), UInt32( prtInstance.screenSize.y ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
                //print("Shadow Shader: ", (cb.gpuEndTime - cb.gpuStartTime) * 1000)
            }
            
            commandBuffer.commit()
        }
    }
    
    func createLightStruct() -> LightUniforms
    {
        // Fill out the lights, first sun
        
        var lightUniforms = LightUniforms()
        lightUniforms.numberOfLights = 1
        
        let sunDirection = getGlobalVariableValue(withName: "Sun.sunDirection")
        let sunStrength : Float = getGlobalVariableValue(withName: "Sun.sunStrength")!.x
        var sunColor : SIMD4<Float>? = getGlobalVariableValue(withName: "Sun.sunColor")
        if sunColor != nil {
            var norm = SIMD3<Float>(sunColor!.x, sunColor!.y, sunColor!.z)
            norm = normalize(norm)
            
            sunColor!.x = norm.x * sunStrength
            sunColor!.y = norm.y * sunStrength
            sunColor!.z = norm.z * sunStrength
        } else {
            sunColor = SIMD4<Float>(sunStrength,sunStrength,sunStrength,1)
        }
        
        lightUniforms.lights.0.lightType = 0
        lightUniforms.lights.0.lightColor = sunColor!
        lightUniforms.lights.0.directionToLight = sunDirection!
        
        let stage = globalApp!.project.selected!.getStage(.LightStage)
        let lights = stage.getChildren()
        
        for (index, lightItem) in lights.enumerated() {
            
            let component = lightItem.components[lightItem.defaultName]!
            let t = getTransformedComponentValues(component)
            
            var lightColor = getTransformedComponentProperty(component, "lightColor")
            let lightStrength = getTransformedComponentProperty(component, "lightStrength")
            lightColor.x *= lightStrength.x
            lightColor.y *= lightStrength.x
            lightColor.z *= lightStrength.x

            if index == 0 {
                lightUniforms.lights.1.lightType = 1
                lightUniforms.lights.1.lightColor = lightColor
                lightUniforms.lights.1.directionToLight = SIMD4<Float>(t["_posX"]!, t["_posY"]!, t["_posZ"]!, 1)
                print(t["_posX"]!, t["_posY"]!, t["_posZ"]!)
            }
            
            lightUniforms.numberOfLights += 1
        }
        
        return lightUniforms
    }
}
