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
    var monitorComponents   : Int = 1
        
    var properties          : [(CodeFragment?, CodeFragment?, String?, Int, CodeComponent)] = []
    
    /// Collect all the properties of the component and create a data entry for it
    func collectProperties(_ component: CodeComponent)
    {
        // Collect properties, stored in the value property of the CodeFragment
        for uuid in component.properties
        {
            let rc = component.getPropertyOfUUID(uuid)
            if rc.0 != nil && rc.1 != nil {
                properties.append((rc.0, rc.1, nil, data.count, component))
                data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
            }
        }
        
        // Collect transforms, stored in the values map of the component
        if component.componentType == .SDF2D {
            properties.append((nil, nil, "_posX", data.count, component))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_posY", data.count, component))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotate", data.count, component))
            data.append(SIMD4<Float>(0,0,0,0))
        }
    }
    
    ///
    func getTransformPropertyIndex(_ component: CodeComponent,_ name: String) -> Int
    {
        for property in properties {
            if let propertyName = property.2 {
                if propertyName == name && property.4 === component {
                    return property.3
                }
            }
        }
        print("property", name, "not found")
        return 0
    }
}

class CodeBuilder
{
    var mmView              : MMView
    
    var compute             : MMCompute

    var currentFrame        : Int = 0
    var isPlaying           : Bool = false
    
    var clearBuffer         : MTLBuffer!
    var clearState          : MTLComputePipelineState? = nil
    
    var sdfStream           : CodeSDFStream

    init(_ view: MMView)
    {
        mmView = view
        
        compute = MMCompute()
        sdfStream = CodeSDFStream()
        
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
        
        dryRunComponent(component, inst.data.count, monitor)

        if let globalCode = component.globalCode {
            inst.code += globalCode
        }
        
        // Compute monitor components
        if let fragment = monitor {
            inst.monitorComponents = 1
            if fragment.typeName.contains("2") {
                inst.monitorComponents = 2
            } else
            if fragment.typeName.contains("3") {
                inst.monitorComponents = 3
            }
            if fragment.typeName.contains("4") {
                inst.monitorComponents = 4
            }
        }
        
        inst.collectProperties(component)
        
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
    
        buildInstance(inst)
        return inst
    }
    
    func buildInstance(_ inst: CodeBuilderInstance)
    {
        inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        inst.computeOutBuffer = compute.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride, options: [])!

        let library = compute.createLibraryFromSource(source: inst.code)
        inst.computeState = compute.createState(library: library, name: "componentBuilder")
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
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        //texture2d<half, access::sample>       __fontTexture [[texture(2)]],
        uint2 __gid                               [[thread_position_in_grid]])
        {
            float4 __monitorOut = float4(0,0,0,0);
            float2 uv = float2(__gid.x, __gid.y);
            float2 size = float2(__outTexture.get_width(), __outTexture.get_height() );
            uv /= size;
            uv.y = 1.0 - uv.y;
        

            float4 outColor = float4(0,0,0,1);
            float GlobalTime = __data[0].x;

        """
        
        if let code = component.code {
            inst.code += code
        }
        
        if let monitorFragment = monitor, monitorFragment.name != "outColor" {
            inst.code +=
            """
            
            outColor = __monitorOut;
            
            """
        }
        
        inst.code +=
        """
        
            __outTexture.write(half4(outColor), __gid);
        }
        
        """
    }
    
    /// Build the source code for the component
    func buildSkyDome(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        //texture2d<half, access::sample>       fontTexture [[texture(2)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float4 __monitorOut = float4(0,0,0,0);
            float2 uv = float2(__gid.x, __gid.y);
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            uv /= size;
            uv.y = 1.0 - uv.y;
            float3 dir = float3(0,0,0);

            float4 outColor = float4(0,0,0,1);
            float GlobalTime = __data[0].x;
        
        """
        
        if let code = component.code {
            inst.code += code
        }

        if let monitorFragment = monitor, monitorFragment.name != "outColor" {
            inst.code +=
            """
            
            outColor = __monitorOut;
            
            """
        }

        inst.code +=
        """
        
            __outTexture.write(half4(outColor), __gid);
        }
        
        """
    }
    
    /// Build the source code for the component
    func buildSDF2D(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        sdfStream.openStream(.SDF2D, inst, self)
        sdfStream.pushComponent(component, monitor)
        sdfStream.closeStream()
        
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
            float4 __monitorOut = float4(0,0,0,0);

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

        if let monitorFragment = monitor, monitorFragment.name != "outColor" {
            inst.code +=
            """
            
            outColor = __monitorOut;
            
            """
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
    
    ///
    func openSDFStream()
    {
        
    }
    
    ///
    func closeSDFStream()
    {
        
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
        for property in inst.properties {
            
            let dataIndex = property.3
            let component = property.4

            if property.0 != nil
            {
                // Property, stored in the CodeFragments
                
                let data = extractValueFromFragment(property.1!)
                let components = property.1!.evaluateComponents()
                
                // Transform the properties inside the artist editor
                
                let name = property.0!.name
                var properties : [String:Float] = [:]
                
                if components == 1 {
                    properties[name] = data.x
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[dataIndex].x = transformed[name]!
                } else
                if components == 2 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[dataIndex].x = transformed[name + "_x"]!
                    inst.data[dataIndex].y = transformed[name + "_y"]!
                } else
                if components == 3 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    properties[name + "_z"] = data.z
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[dataIndex].x = transformed[name + "_x"]!
                    inst.data[dataIndex].y = transformed[name + "_y"]!
                    inst.data[dataIndex].z = transformed[name + "_z"]!
                } else
                if components == 4 {
                    properties[name + "_x"] = data.x
                    properties[name + "_y"] = data.y
                    properties[name + "_z"] = data.z
                    properties[name + "_w"] = data.w
                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    inst.data[dataIndex].x = transformed[name + "_x"]!
                    inst.data[dataIndex].y = transformed[name + "_y"]!
                    inst.data[dataIndex].z = transformed[name + "_z"]!
                    inst.data[dataIndex].w = transformed[name + "_w"]!
                }
                if globalApp!.currentEditor === globalApp!.artistEditor {
                    globalApp!.artistEditor.designProperties.updateTransformedProperty(name, data: inst.data[dataIndex])
                }
            } else
            if let name = property.2 {
                // Transform property, stored in the values of the component
                
                var properties : [String:Float] = [:]
                properties[name] = component.values[name]!

                let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                
                inst.data[dataIndex].x = transformed[name]!
            }
        }
        updateBuffer(inst)
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
