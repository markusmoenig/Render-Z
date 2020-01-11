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
    
    var properties          : [(CodeFragment?, CodeFragment?, Int)] = []
}

class CodeBuilder
{
    var mmView              : MMView
    
    var fragment            : MMFragment
    var compute             : MMCompute

    var currentFrame        : Int = 0
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
        
        // Time
        inst.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )

        // Compute monitor components
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
        
        // Collect properties
        for uuid in component.properties
        {
            let rc = component.getPropertyOfUUID(uuid)
            if rc.0 != nil && rc.1 != nil {
                inst.properties.append((rc.0, rc.1, inst.data.count))
                inst.data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
            }
        }
        
        if component.componentType == .Colorize {
            buildColorize(inst, component, monitor)
        } else
        if component.componentType == .SDF2D {
            buildSDF2D(inst, component, monitor)
        } else
        if component.componentType == .Render {
            buildRender(inst, component, monitor)
        }
        
//        print( inst.code )
        
        if inst.data.count == 0 {
            inst.data.append(SIMD4<Float>(0,0,0,0))
        }
        
        if monitor == nil && component.componentType == .Colorize {
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
                float2 uv = in.textureCoordinate.xy;
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
                float2 uv = float2(gid.x, gid.y);

                float4 outColor = float4(0,0,0,1);
                float GlobalTime = data[0].x;
            
            
            """
        }
        
        if let code = component.code {
            inst.code += code
        }

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
    
    /// Build the source code for the component
    func buildSDF2D(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        inst.code +=
        """
        
        float2 translate(float2 p, float2 t)
        {
            return p - t;
        }
        
        float sdCircle(float2 p, float r)
        {
          return length(p) - r;
        }
        
        float fillMask(float dist)
        {
            return clamp(-dist, 0.0, 1.0);
        }
        
        kernel void componentBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        constant float4                        *data   [[ buffer(1) ]],
        //texture2d<half, access::sample>       fontTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            float2 center = size / 2;

            //float2 fragCoord = float2( gid.x, gid.y );
        
            float2 uv = float2(gid.x, gid.y);
            uv = translate(uv, center);
        
            float d = sdCircle(uv, 40);

            float4 outColor = float4(1, 1, 1,1);
            float GlobalTime = data[0].x;
        
            outTexture.write(half4( d, 0, 0, 1 ), gid);
            
        """
    
        //if let code = component.code {
        //    inst.code += code
        //}

        if let frag = monitor {

            if inst.computeComponents == 1 {
                inst.code += "out[0].x = " + frag.name + ";\n";
            }
            if inst.computeComponents == 4 {
                inst.code += "out[0].x = " + frag.name + ".x;\n";
                inst.code += "out[0].y = " + frag.name + ".y;\n";
                inst.code += "out[0].z = " + frag.name + ".z;\n";
                inst.code += "out[0].w = " + frag.name + ".w;\n";
            }
        }
        
        inst.code +=
        """
         
        }
         
        """
    }
    
    /// Build the source code for the component
     func buildRender(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
     {
         inst.code +=
         """
         
         float2 translate(float2 p, float2 t)
         {
             return p - t;
         }
         
         float sdCircle(float2 p, float r)
         {
           return length(p) - r;
         }
         
         float fillMask(float dist)
         {
             return clamp(-dist, 0.0, 1.0);
         }
         
         kernel void componentBuilder(
         texture2d<half, access::write>          outTexture  [[texture(0)]],
         constant float4                        *data   [[ buffer(1) ]],
         texture2d<half, access::sample>         depthTexture [[texture(2)]],
         uint2 gid                               [[thread_position_in_grid]])
         {
             constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);

             float2 size = float2( outTexture.get_width(), outTexture.get_height() );
             float2 center = size / 2;

             //float2 fragCoord = float2( gid.x, gid.y );
         
             float2 uv = float2(gid.x, gid.y);
             //uv = translate(uv, center);
         
             //float d = sdCircle(uv, 40);

             float4 outColor = float4(1, 0, 0,1);
             //float GlobalTime = data[0].x;
             
             float4 s = float4(depthTexture.sample(textureSampler, uv / size ));
             
            //if ( s.x > 60 ) {
            //    outColor = float4(0,0,0, 1);
             //}
                outColor.x = fillMask(s.x);
         
             outTexture.write(half4(outColor.x, outColor.y, outColor.z, 1 ), gid);
             //outTexture.write(s, gid);

         """
     
         //if let code = component.code {
         //    inst.code += code
         //}

         if let frag = monitor {

             if inst.computeComponents == 1 {
                 inst.code += "out[0].x = " + frag.name + ";\n";
             }
             if inst.computeComponents == 4 {
                 inst.code += "out[0].x = " + frag.name + ".x;\n";
                 inst.code += "out[0].y = " + frag.name + ".y;\n";
                 inst.code += "out[0].z = " + frag.name + ".z;\n";
                 inst.code += "out[0].w = " + frag.name + ".w;\n";
             }
         }
         
         inst.code +=
         """
          
         }
          
         """
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
        let timeline = globalApp!.artistEditor.timeline
        
        var time : Float

        if isPlaying {
            // Global Playback, control time locally
            time = (Float(currentFrame) * 1000/60) / 1000
            currentFrame += 1
        } else {
            // Timeline Playback
            time = (Float(timeline.currentFrame) * 1000/60) / 1000
        }
        
        inst.data[0].x = time
        for property in inst.properties{
            
            let data = extractValueFromFragment(property.1!)
            let components = property.1!.evaluateComponents()
                
            if globalApp!.currentEditor === globalApp!.artistEditor {
                // Transform the properties inside the artist editor
                
                let name = property.0!.name
                var properties : [String:Float] = [:]
                
                if components == 1 {
                    properties[name] = data.x
                    let transformed = timeline.transformProperties(sequence: inst.component!.sequence, uuid: inst.component!.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[property.2].x = transformed[name]!
                } else
                if components == 2 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    let transformed = timeline.transformProperties(sequence: inst.component!.sequence, uuid: inst.component!.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[property.2].x = transformed[name + "_x"]!
                    inst.data[property.2].y = transformed[name + "_y"]!
                } else
                if components == 3 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    properties[name + "_z"] = data.z
                    let transformed = timeline.transformProperties(sequence: inst.component!.sequence, uuid: inst.component!.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[property.2].x = transformed[name + "_x"]!
                    inst.data[property.2].y = transformed[name + "_y"]!
                    inst.data[property.2].z = transformed[name + "_z"]!
                } else
                if components == 4 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    properties[name + "_z"] = data.z
                    properties[name + "_w"] = data.w
                    let transformed = timeline.transformProperties(sequence: inst.component!.sequence, uuid: inst.component!.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[property.2].x = transformed[name + "_x"]!
                    inst.data[property.2].y = transformed[name + "_y"]!
                    inst.data[property.2].z = transformed[name + "_z"]!
                    inst.data[property.2].w = transformed[name + "_w"]!
                }
                globalApp!.artistEditor.designProperties.updateTransformedProperty(name, data: inst.data[property.2])
            } else {
                // Otherwise copy 1:1
                inst.data[property.2] = data
            }
        }
        updateBuffer(inst)
    }
    
    // Render the component into a fragment texture
    func render(_ inst: CodeBuilderInstance,_ texture: MTLTexture? = nil)
    {
        updateData(inst)
        if fragment.encoderStart(outTexture: texture)
        {
            fragment.encodeRun(inst.fragmentState!, inBuffer: inst.buffer)
    
            fragment.encodeEnd()
        }
    }
    
    // Compute the component into a texture
    func compute(_ inst: CodeBuilderInstance,_ texture: MTLTexture? = nil,_ inTexture: MTLTexture? = nil)
    {
        updateData(inst)
        
        compute.run( inst.computeState!, outTexture: texture, inBuffer: inst.buffer, inTexture: inTexture)
        
        compute.commandBuffer.waitUntilCompleted()
    }
    
    // Compute the monitor data
    func computeMonitor(_ inst: CodeBuilderInstance)
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
}
