//
//  MMCompute.swift
//  Framework
//
//  Created by Markus Moenig on 06.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class MMCompute {
    
    let device                  : MTLDevice
    let defaultLibrary          : MTLLibrary?
    var commandQueue            : MTLCommandQueue?
//    var computePipelineState    : MTLComputePipelineState?

    var texture                 : MTLTexture!
    var width, height           : Float
    
    var threadgroupSize         : MTLSize!
    var threadgroupCount        : MTLSize!
    
    init()
    {
        device = MTLCreateSystemDefaultDevice()!
        defaultLibrary = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()
        
        width = 0
        height = 0
    }
    
    /// Creates a state from an optional library and the function name
    func createState( library: MTLLibrary? = nil, name: String ) -> MTLComputePipelineState?
    {
        let function : MTLFunction?
            
        if library != nil {
            function = library!.makeFunction( name: name )
        } else {
            function = defaultLibrary!.makeFunction( name: name )
        }
        
        var computePipelineState : MTLComputePipelineState?
        
        do {
            computePipelineState = try device.makeComputePipelineState( function: function! )
        } catch {
            print( "computePipelineState failed" )
            return nil
        }
        
        return computePipelineState
    }
    
    /// --- Creates a library from the given source
    func createLibraryFromSource( source: String ) -> MTLLibrary?
    {
        var library : MTLLibrary
        do {
            library = try device.makeLibrary( source: source, options: nil )
        } catch
        {
            print( "Make Library Failed" )
            print( error )
            return nil
        }
        return library;
    }
    
    /// Allocate the output texture, optionally can be used to create an arbitray texture by setting output to false
    @discardableResult func allocateTexture( width: Float, height: Float, output: Bool? = true ) -> MTLTexture?
    {
        self.texture = nil
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type2D
        textureDescriptor.pixelFormat = MTLPixelFormat.bgra8Unorm
        textureDescriptor.width = Int(width)
        textureDescriptor.height = Int(height)
        
        textureDescriptor.usage = MTLTextureUsage.unknown;

        let texture = device.makeTexture( descriptor: textureDescriptor )
        if output! {
            self.texture = texture
        }
        
        threadgroupSize = MTLSize(width: Int(width), height: Int(height), depth: 1)
        
        let tWidth = 1;//( inputTexture!.width + threadgroupSize.width -  1) / threadgroupSize.width
        let tHeight = 1;//( inputTexture!.height + threadgroupSize.height - 1) / threadgroupSize.height;
        threadgroupCount = MTLSize(width: tWidth, height: tHeight, depth: 1)
        
        self.width = width
        self.height = height
        
        return texture
    }

    /// Run the given state
    func run(_ state: MTLComputePipelineState?, outTexture: MTLTexture? = nil, inBuffer: MTLBuffer? = nil, inTexture: MTLTexture? = nil )
    {
        let commandBuffer = commandQueue!.makeCommandBuffer()!
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        computeEncoder.setComputePipelineState( state! )
//        computeEncoder.setTexture( inputTexture, index: 0 )
        computeEncoder.setTexture( outTexture != nil ? outTexture : texture, index: 0 )
        
        if let buffer = inBuffer {
            computeEncoder.setBuffer(buffer, offset: 0, index: 1)
        }
        
        if let texture = inTexture {
            computeEncoder.setTexture(texture, index: 2)
        }
        
        computeEncoder.dispatchThreadgroups( threadgroupSize, threadsPerThreadgroup: threadgroupCount )
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
    }

    /// Run the given state
    func runBuffer(_ state: MTLComputePipelineState?, outBuffer: MTLBuffer, inBuffer: MTLBuffer? = nil )
    {
        let commandBuffer = commandQueue!.makeCommandBuffer()!
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        
        computeEncoder.setComputePipelineState( state! )
//        computeEncoder.setTexture( inputTexture, index: 0 )
        computeEncoder.setBuffer(outBuffer, offset: 0, index: 0)

        if let buffer = inBuffer {
            computeEncoder.setBuffer(buffer, offset: 0, index: 1)
        }
        
        let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
        let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
        computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
