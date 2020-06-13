//
//  ObjectShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class BaseShader
{
    enum ShaderState {
        case Undefined, Compiling, Compiled
    }
    
    var shaderState         : ShaderState = .Undefined
    
    var pipelineStateDesc   : MTLRenderPipelineDescriptor!
    var pipelineState       : MTLRenderPipelineState!

    var commandQueue        : MTLCommandQueue!
    
    let device              : MTLDevice

    init()
    {
        device = globalApp!.mmView.device!
    }
    
    func compile(vertexCode: String, fragmentCode: String)
    {
        pipelineStateDesc = MTLRenderPipelineDescriptor()
        
        shaderState = .Compiling
        device.makeLibrary( source: vertexCode + fragmentCode, options: nil, completionHandler: { (library, error) in
            if let error = error {
                print(error)
                self.shaderState = .Undefined
            } else
            if let library = library {

                self.pipelineStateDesc.vertexFunction = library.makeFunction(name: "procVertex")
                self.pipelineStateDesc.fragmentFunction = library.makeFunction(name: "procFragment")
                self.pipelineStateDesc.colorAttachments[0].pixelFormat = .rgba16Float

                self.pipelineState = try! self.device.makeRenderPipelineState(descriptor: self.pipelineStateDesc)
                
                self.commandQueue = self.device.makeCommandQueue()
                self.shaderState = .Compiled
            }
        } )
    }
    
    func getQuadVertexSource() -> String
    {
        let code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

        typedef struct
        {
            float4 clipSpacePosition [[position]];
            float2 textureCoordinate;
        } RasterizerData;

        typedef struct
        {
            vector_float2 position;
            vector_float2 textureCoordinate;
        } VertexData;

        // Quad Vertex Function
        vertex RasterizerData
        procVertex(uint vertexID [[ vertex_id ]],
                     constant VertexData *vertexArray [[ buffer(0) ]],
                     constant vector_uint2 *viewportSizePointer  [[ buffer(1) ]])

        {
            
            RasterizerData out;
            
            float2 pixelSpacePosition = vertexArray[vertexID].position.xy;
            float2 viewportSize = float2(*viewportSizePointer);
            
            out.clipSpacePosition.xy = pixelSpacePosition / (viewportSize / 2.0);
            out.clipSpacePosition.z = 0.0;
            out.clipSpacePosition.w = 1.0;
            
            out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
            return out;
        }
        """

        return code
    }
    
    func getQuadVertexBuffer(_ rect: MMRect ) -> MTLBuffer?
    {
        let left = -rect.width / 2 + rect.x
        let right = left + rect.width//self.width / 2 - x
        
        let top = rect.height / 2 - rect.y
        let bottom = top - rect.height
        
        let quadVertices: [Float] = [
            right, bottom, 1.0, 0.0,
            left, bottom, 0.0, 0.0,
            left, top, 0.0, 1.0,
            
            right, bottom, 1.0, 0.0,
            left, top, 0.0, 1.0,
            right, top, 1.0, 1.0,
            ]
        
        return device.makeBuffer(bytes: quadVertices, length: quadVertices.count * MemoryLayout<Float>.stride, options: [])!
    }
}
