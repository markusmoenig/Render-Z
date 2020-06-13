//
//  ObjectShader.swift
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
        
    init(scene: Scene, camera: CodeComponent)
    {
        self.scene = scene
        self.camera = camera
                    
        super.init()
        
        let preStage = scene.getStage(.PreStage)
        for item in preStage.getChildren() {
            if let comp = item.components[item.defaultName], comp.componentType == .SkyDome || comp.componentType == .Pattern {
                createFragmentSource(backComponent: comp)
            }
        }
    }
    
    func createFragmentSource(backComponent: CodeComponent)
    {
        let fragmentCode =
        """

        fragment half4 procFragment() {
            return half4(0,0,1,1.0);
        }

        """
        
        compile(vertexCode: getQuadVertexSource(), fragmentCode: fragmentCode)
    }
    
    func render(texture: MTLTexture)
    {
        //let camHelper = CamHelper3D()
        //camHelper.initFromComponent(aspect: Float(texture.width) / Float(texture.height), component: camera)
        //var matrix = camHelper.getMatrix()
        //memcpy(renderParams?.contents(), camHelper.getMatrix().m, MemoryLayout<matrix_float4x4>.size)
        
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
        // ---
        
        //renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        //renderEncoder.setVertexBytes(&matrix, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
    }
}
