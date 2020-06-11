//
//  CodeProperties.swift
//  Render-Z
//
//  Created by Markus Moenig on 30/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class PointCloudBuilder
{
    var mmView              : MMView
    var fragment            : MMFragment
    
    let defaultLibrary      : MTLLibrary
    
    let pipelineStateDesc   : MTLRenderPipelineDescriptor
    var pipelineState       : MTLRenderPipelineState

    var commandQueue        : MTLCommandQueue!

    let device              : MTLDevice
    
    var vertexBuffer        : MTLBuffer!
    
    init(_ view: MMView)
    {
        mmView = view
        fragment = MMFragment(view)
        
        device = MTLCreateSystemDefaultDevice()!

        defaultLibrary = device.makeDefaultLibrary()!
        
        pipelineStateDesc = MTLRenderPipelineDescriptor()
        
        pipelineStateDesc.vertexFunction = defaultLibrary.makeFunction(name: "basic_vertex")
        pipelineStateDesc.fragmentFunction = defaultLibrary.makeFunction(name: "basic_fragment")
        pipelineStateDesc.colorAttachments[0].pixelFormat = .rgba16Float

        pipelineState = try! device.makeRenderPipelineState(descriptor: pipelineStateDesc)
        
        commandQueue = device.makeCommandQueue()

        /*
        let fragmentProgram = defaultLibrary.makeFunction(name: "basic_fragment")
        let vertexProgram = defaultLibrary.makeFunction(name: "basic_vertex")
        
        print(vertexProgram)*/
    }
    
    func render(points: [Float], texture: MTLTexture, camera: CodeComponent)
    {
        //let renderParamsSize = MemoryLayout<matrix_float4x4>.size
        //let renderParams = device.makeBuffer(length: renderParamsSize, options: .cpuCacheModeWriteCombined)
        
        if points.count == 0 { return }
        let dataSize = points.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: points, length: dataSize, options: [])
        
        let camHelper = CamHelper3D()
        camHelper.initFromComponent(aspect: Float(texture.width) / Float(texture.height), component: camera)
        var matrix = camHelper.getMatrix()
        //memcpy(renderParams?.contents(), camHelper.getMatrix().m, MemoryLayout<matrix_float4x4>.size)
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 1.0)
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&matrix, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 3, instanceCount: 1)
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
    }
}
