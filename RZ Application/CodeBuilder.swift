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
    
    var computeState        : MTLComputePipelineState? = nil

    var data                : [SIMD4<Float>] = []
    var buffer              : MTLBuffer!
    
    var computeOutBuffer    : MTLBuffer!
    var computeResult       : SIMD4<Float> = SIMD4<Float>(0,0,0,0)
    var computeComponents   : Int = 1
    
    var afterPropertyOffset : Int = 0
    
    var properties          : [(CodeFragment?, CodeFragment?, Int)] = []
}

class CodeBuilder
{
    var mmView              : MMView
    
    var compute             : MMCompute

    var currentFrame        : Int = 0
    var isPlaying           : Bool = false
    
    var clearBuffer         : MTLBuffer!
    var clearState          : MTLComputePipelineState? = nil

    init(_ view: MMView)
    {
        mmView = view
        
        compute = MMCompute()
        buildClearState()
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
        
        inst.afterPropertyOffset = inst.data.count
        
        if component.componentType == .Colorize {
            buildColorize(inst, component, monitor)
        } else
        if component.componentType == .SkyDome {
            buildSkyDome(inst, component, monitor)
        } else
        if component.componentType == .SDF2D {
            buildSDF2D(inst, component, monitor)
        } else
        if component.componentType == .Render2D {
            buildRender2D(inst, component, monitor)
        }
        
        //print( inst.code )
        
        inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        inst.computeOutBuffer = compute.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride, options: [])!

        let library = compute.createLibraryFromSource(source: inst.code)
        inst.computeState = compute.createState(library: library, name: "componentBuilder")
    
        return inst
    }
    
    func insertMonitorCode(_ fragment: CodeFragment,_ outVariableName: String,_ components: Int) -> String
    {
        var code : String = ""
        if components == 1 {
            code += "\(outVariableName) = float4(float3(" + fragment.name + "),1);\n";
        } else
        if components == 2 {
            code += "\(outVariableName).x = " + fragment.name + ".x;\n";
            code += "\(outVariableName).y = " + fragment.name + ".y;\n";
            code += "\(outVariableName).z = 0;\n";
            code += "\(outVariableName).w = 1;\n";
        } else
        if components == 3 {
            code += "\(outVariableName).x = " + fragment.name + ".x;\n";
            code += "\(outVariableName).y = " + fragment.name + ".y;\n";
            code += "\(outVariableName).z = " + fragment.name + ".z;\n";
            code += "\(outVariableName).w = 1;\n";
        } else
        if components == 4 {
            code += "\(outVariableName).x = " + fragment.name + ".x;\n";
            code += "\(outVariableName).y = " + fragment.name + ".y;\n";
            code += "\(outVariableName).z = " + fragment.name + ".z;\n";
            code += "\(outVariableName).w = " + fragment.name + ".w;\n";
        }
        return code
    }
    
    /// Build the source code for the component
    func buildColorize(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        constant float4                        *data   [[ buffer(1) ]],
        //texture2d<half, access::sample>       fontTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            float2 uv = float2(gid.x, gid.y);
            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            uv /= size;
            uv.y = 1.0 - uv.y;

            float4 outColor = float4(0,0,0,1);
            float GlobalTime = data[0].x;

        """
        
        if let code = component.code {
            inst.code += code
        }

        // --- Monitor
        if let fragment = monitor {
            inst.code += insertMonitorCode(fragment, "outColor", inst.computeComponents)
        }
        
        inst.code +=
        """
        
            outTexture.write(half4(outColor.x, outColor.y, outColor.z, outColor.w ), gid);
        }
        
        """
    }
    
    /// Build the source code for the component
    func buildSkyDome(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        constant float4                        *data   [[ buffer(1) ]],
        //texture2d<half, access::sample>       fontTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            float2 uv = float2(gid.x, gid.y);
            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            uv /= size;
            uv.y = 1.0 - uv.y;
            float3 dir = float3(0,0,0);

            float4 outColor = float4(0,0,0,1);
            float GlobalTime = data[0].x;
        
        """
        
        if let code = component.code {
            inst.code += code
        }

        // --- Monitor
        if let fragment = monitor {
            inst.code += insertMonitorCode(fragment, "outColor", inst.computeComponents)
        }

        inst.code +=
        """
        
            outTexture.write(half4(outColor.x, outColor.y, outColor.z, outColor.w ), gid);
        }
        
        """
    }
    
    /// Build the source code for the component
    func buildSDF2D(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        inst.code +=
        """
        
        float2 __translate(float2 p, float2 t)
        {
            return p - t;
        }
        
        """
        
        inst.code +=
            
        """
        kernel void componentBuilder(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        //texture2d<half, access::sample>       fontTexture [[texture(2)]],
        uint2 __gid                               [[thread_position_in_grid]])
        {
            float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 pos = float2(__gid.x, __gid.y);
            float2 __center = __size / 2;
            pos = __translate(pos, __center);

            float GlobalTime = __data[0].x;
            float outDistance = 10;
            float4 __output = float4(0,0,0,0);
            int __offset = int(__data[0].y);
            pos = __translate(pos, float2(__data[__offset].x, -__data[__offset].y));

        """
    
        if let code = component.code {
            inst.code += code
        }

        // --- Monitor
        if let fragment = monitor {
            inst.code += insertMonitorCode(fragment, "__output", inst.computeComponents)
        } else {
            inst.code +=
            """
            
            __output.x = outDistance;
            """
        }
        
        inst.code +=
        """
        
            __outTexture.write(half4(__output), __gid);
         }
        """
        
        // Position
        inst.data.append(SIMD4<Float>(0,0,0,0))
    }
    
    /// Build the source code for the component
    func buildRender2D(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        inst.code +=
        """
        
        float2 __translate(float2 p, float2 t)
        {
            return p - t;
        }
        
        kernel void componentBuilder(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        texture2d<half, access::sample>         __depthTexture [[texture(2)]],
        texture2d<half, access::sample>         __backTexture [[texture(3)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y);

            float4 outColor = float4(0, 0, 0, 1);
            float4 backColor = float4(__backTexture.sample(__textureSampler, uv / size ));
            float4 matColor = float4(1, 1, 1, 1);

            float4 __depthIn = float4(__depthTexture.sample(__textureSampler, uv / size ));
            float distance = __depthIn.x;

        """
     
        if let code = component.code {
            inst.code += code
        }

        // Monitor
        if let fragment = monitor {
            inst.code += insertMonitorCode(fragment, "outColor", inst.computeComponents)
        }

        inst.code +=
        """
                       
            __outTexture.write(half4(outColor), __gid);
        }
          
        """
    }
    
    /// Build a clear texture shader
    func buildClearState()
    {
        let code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void clearBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        constant float4                        *data   [[ buffer(1) ]],
        uint2 gid                               [[thread_position_in_grid]])
        {
        
           outTexture.write(half4(data[0]), gid);
        }
         
        """
        
        let data : [SIMD4<Float>] = [SIMD4<Float>(0,0,0,0)]
        
        clearBuffer = compute.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!

        let library = compute.createLibraryFromSource(source: code)
        clearState = compute.createState(library: library, name: "clearBuilder")
    }
    
    /// Update the instance buffer
    func updateBuffer(_ inst: CodeBuilderInstance)
    {
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
        inst.data[0].y = Float(inst.afterPropertyOffset)
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
        updateComponentSpecificData(inst)
        updateBuffer(inst)
    }
    
    /// Update the data from the components
    func updateComponentSpecificData(_ inst: CodeBuilderInstance)
    {
        if let comp = inst.component {
            if comp.componentType == .SDF2D, comp.values["_posX"] != nil {
                inst.data[inst.afterPropertyOffset].x = comp.values["_posX"]!
                inst.data[inst.afterPropertyOffset].y = comp.values["_posY"]!
            }
        }
    }

    // Cear the texture
    func renderClear(texture: MTLTexture, data: SIMD4<Float>)
    {
        clearBuffer = compute.device.makeBuffer(bytes: [data], length: 1 * MemoryLayout<SIMD4<Float>>.stride, options: [])!

        compute.run( clearState!, outTexture: texture, inBuffer: clearBuffer)
        compute.commandBuffer.waitUntilCompleted()
    }
    
    // Render the component into a texture
    func render(_ inst: CodeBuilderInstance,_ outTexture: MTLTexture? = nil,_ inTextures: [MTLTexture] = [], syncronize: Bool = false)
    {
        updateData(inst)
        
        compute.run( inst.computeState!, outTexture: outTexture, inBuffer: inst.buffer, inTextures: inTextures, syncronize: syncronize)
        
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
