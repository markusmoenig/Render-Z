//
//  CodeProperties.swift
//  Render-Z
//
//  Created by Markus Moenig on 30/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class CodeBuilderInstance
{
    var component       : CodeComponent? = nil
    var code            : String = ""
    
    var fragmentState   : MTLRenderPipelineState? = nil
    var computeState    : MTLComputePipelineState? = nil

    var data            : [SIMD4<Float>] = []
    var buffer          : MTLBuffer? = nil
}

class CodeBuilder
{
    var mmView              : MMView
    
    var fragment            : MMFragment
    var compute             : MMCompute

    init(_ view: MMView)
    {
        mmView = view
        
        fragment = MMFragment(view)
        compute = MMCompute()
    }
    
    func build(_ component: CodeComponent, _ monitor: CodeFragment? = nil) -> CodeBuilderInstance
    {
        let inst = CodeBuilderInstance()
        inst.component = component
        
        inst.code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        """
        
        if monitor == nil {
            
            inst.code +=
            """
            
            fragment float4 componentBuilder(RasterizerData in [[stage_in]],
                                             constant float4 *data [[ buffer(2) ]])
                                             //texture2d<half, access::sample>   fontTexture [[texture(1)]])
            {
                //float2 size = float2(layerData->limiterSize.x, layerData->limiterSize.y);//float2( outTexture.get_width(), outTexture.get_height() );
                //float2 fragCoord = float2(in.textureCoordinate.x, 1. - in.textureCoordinate.y) * size;
            """
            
        } else {
            
            inst.code +=
            """
            
            kernel void componentBuilder(
            texture2d<half, access::write>  outTexture  [[texture(0)]],
            constant LAYER_DATA            *layerData   [[ buffer(1) ]],
            texture2d<half, access::sample>   fontTexture [[texture(2)]],
            uint2                           gid         [[thread_position_in_grid]])
            {
                float2 size = float2( outTexture.get_width(), outTexture.get_height() );
                float2 fragCoord = float2( gid.x, gid.y );
            """
        }
        
        // --- Return value
        if monitor == nil {
            inst.code +=
            """
            
                return float4(1,1,1,1);
                //return float4(total.x / total.w, total.y / total.w, total.z / total.w, total.w);
            }
            
            """
        } else {
            inst.code +=
             """
                 outTexture.write(half4(total.x, total.y, total.z, total.w), gid);
             }
             
             """
        }
        
        print( inst.code )
        
        if inst.data.count == 0 {
            inst.data.append(SIMD4<Float>(0,0,0,0))
        }
        
        if monitor == nil {
            inst.buffer = fragment.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<Float>.stride, options: [])!

            let library = fragment.createLibraryFromSource(source: inst.code)
            inst.fragmentState = fragment.createState(library: library, name: "componentBuilder")
        } else {
            if inst.data.count > 0 {
                inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<Float>.stride, options: [])!
            }
            
            let library = compute.createLibraryFromSource(source: inst.code)
            inst.computeState = compute.createState(library: library, name: "componentBuilder")
        }
        
        return inst
    }
    
    func render(_ inst: CodeBuilderInstance,_ texture: MTLTexture? = nil)
    {            
        if fragment.encoderStart(outTexture: texture)
        {
            print( texture!.width)
            fragment.encodeRun(inst.fragmentState!, inBuffer: inst.buffer)
    
            fragment.encodeEnd()
        }
    }
}
