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
    var component           : CodeComponent? = nil
    var code                : String = ""
    
    var fragmentState       : MTLRenderPipelineState? = nil
    var computeState        : MTLComputePipelineState? = nil

    var data                : [SIMD4<Float>] = []
    var buffer              : MTLBuffer!
    
    var computeOutBuffer    : MTLBuffer!
    var computeResult       : SIMD4<Float> = SIMD4<Float>(0,0,0,0)
    var computeComponents   : Int = 1
}

class CodeBuilder
{
    var mmView              : MMView
    
    var fragment            : MMFragment
    var compute             : MMCompute

    var GlobalTime          : Double = 0
    var isPlaying           : Bool = false
    
    init(_ view: MMView)
    {
        mmView = view
        
        fragment = MMFragment(view)
        compute = MMCompute()
    }
    
    func build(_ component: CodeComponent, _ monitor: CodeFragment? = nil) -> CodeBuilderInstance
    {
        //print("build", component.componentType, monitor)
        let inst = CodeBuilderInstance()
        inst.component = component
        
        inst.code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        """
        
        if let fragment = monitor {
            inst.computeComponents = 1
            print( fragment.fragmentType, fragment.typeName )
            if fragment.typeName.contains("2") {
                inst.computeComponents = 2
            } else
            if fragment.typeName.contains("3") {
                inst.computeComponents = 3
            }
            if fragment.typeName.contains("4") {
                inst.computeComponents = 4
            }
        }
        
        if component.componentType == .Colorize {
            buildColorize(inst, component, monitor)
        }
        
        //print( inst.code )
        
        if inst.data.count == 0 {
            inst.data.append(SIMD4<Float>(0,0,0,0))
        }
        
        if monitor == nil {
            inst.buffer = fragment.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!

            let library = fragment.createLibraryFromSource(source: inst.code)
            inst.fragmentState = fragment.createState(library: library, name: "componentBuilder")
        } else {
            inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            inst.computeOutBuffer = compute.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride, options: [])!

            let library = compute.createLibraryFromSource(source: inst.code)
            inst.computeState = compute.createState(library: library, name: "componentBuilder")
        }
        
        return inst
    }
    
    /// Build the source code for the component
    func buildColorize(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        if monitor == nil {
            
            inst.code +=
            """
            
            fragment float4 componentBuilder(RasterizerData in                      [[stage_in]],
                                             constant float4 *data                  [[ buffer(2) ]])
                                             //texture2d<half, access::sample>      fontTexture [[texture(1)]])
            {
                //float2 size = float2(layerData->limiterSize.x, layerData->limiterSize.y);//float2( outTexture.get_width(), outTexture.get_height() );
                //float2 fragCoord = float2(in.textureCoordinate.x, 1. - in.textureCoordinate.y) * size;
                float4 outColor = float4(0,0,0,1);
            
                //float test = sin( float3(1) );
            
                float GlobalTime = data[0].x;
            
            """
            
        } else {
            
            inst.code +=
            """
            
            kernel void componentBuilder(
            //texture2d<half, access::write>        outTexture  [[texture(0)]],
            constant float4                        *data   [[ buffer(1) ]],
            device float4                          *out [[ buffer(0) ]],
            //texture2d<half, access::sample>       fontTexture [[texture(2)]],
            uint2 gid                               [[thread_position_in_grid]])
            {
                //float2 size = float2( outTexture.get_width(), outTexture.get_height() );
                //float2 fragCoord = float2( gid.x, gid.y );
            
                float4 outColor = float4(0,0,0,1);
                float GlobalTime = data[0].x;
            
            
            """
        }
        
        //print("buildComponent", component.code)
        inst.code += component.code!
        
        inst.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
        
        // --- Return value
        if monitor == nil {
            inst.code +=
            """
            
                return outColor;
                //return float4(total.x / total.w, total.y / total.w, total.z / total.w, total.w);
            }
            
            """
        } else {
            let frag = monitor!

            if inst.computeComponents == 1 {
                inst.code += "out[0].x = " + frag.name + ";\n";
            }
            if inst.computeComponents == 4 {
                inst.code += "out[0].x = " + frag.name + ".x;\n";
                inst.code += "out[0].y = " + frag.name + ".y;\n";
                inst.code += "out[0].z = " + frag.name + ".z;\n";
                inst.code += "out[0].w = " + frag.name + ".w;\n";
            }
            
            inst.code +=
            """
             
            }
             
            """
        }
    }
    
    /// Update the instance buffer
    func updateBuffer(_ inst: CodeBuilderInstance)
    {
        if inst.fragmentState != nil {
            inst.buffer = fragment.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        } else
        if inst.computeState != nil {
            inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        }
    }
    
    /// Update the instance data
    func updateData(_ inst: CodeBuilderInstance)
    {
        inst.data[0].x = getDeltaTime()
        updateBuffer(inst)
    }
    
    func render(_ inst: CodeBuilderInstance,_ texture: MTLTexture? = nil)
    {
        updateData(inst)
        if fragment.encoderStart(outTexture: texture)
        {
            fragment.encodeRun(inst.fragmentState!, inBuffer: inst.buffer)
    
            fragment.encodeEnd()
        }
    }
    
    func compute(_ inst: CodeBuilderInstance)
    {
        updateData(inst)
        
        compute.runBuffer( inst.computeState!, outBuffer: inst.computeOutBuffer, inBuffer: inst.buffer, wait: false )
        
        compute.commandBuffer.waitUntilCompleted()
        let result = inst.computeOutBuffer.contents().bindMemory(to: Float.self, capacity: 4)
        inst.computeResult.x = result[0]
        inst.computeResult.y = result[1]
        inst.computeResult.z = result[2]
        inst.computeResult.w = result[3]
    }
    
    func getCurrentTime() -> Double {
        return Double(Date().timeIntervalSince1970)
    }
    
    func getDeltaTime() -> Float
    {
        let time = getCurrentTime()
        let delta : Float = Float(time - GlobalTime)
        return delta
    }
}
