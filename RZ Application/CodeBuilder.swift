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
    weak var component      : CodeComponent? = nil
    var code                : String = ""
    
    var computeState        : MTLComputePipelineState? = nil
    var additionalStates    : [String: MTLComputePipelineState] = [:]

    var data                : [SIMD4<Float>] = []
    var buffer              : MTLBuffer!
    
    var computeOutBuffer    : MTLBuffer!
    var computeResult       : SIMD4<Float> = SIMD4<Float>(0,0,0,0)
    var monitorComponents   : Int = 1
        
    var properties          : [(CodeFragment?, CodeFragment?, String?, Int, CodeComponent, [StageItem])] = []
        
    /// Collect all the properties of the component and create a data entry for it
    func collectProperties(_ component: CodeComponent,_ hierarchy: [StageItem] = [])
    {
        // Collect properties and globalVariables
        for uuid in component.inputDataList {
            if component.properties.contains(uuid) {
                // Property
                let rc = component.getPropertyOfUUID(uuid)
                if rc.0 != nil && rc.1 != nil {
                    properties.append((rc.0, rc.1, nil, data.count, component, hierarchy))
                    data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
                }
            } else
            if let variableComp = component.globalVariables[uuid] {
                // Global Variable, Extract the CodeFragment from the VariableComponent
                for uuid in variableComp.properties {
                    let rc = variableComp.getPropertyOfUUID(uuid)
                    if rc.0!.values["variable"] == 1 {
                        properties.append((rc.0, rc.1, nil, data.count, variableComp, []))
                        data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
                    }
                }
            }
        }
        
        // Collect transforms, stored in the values map of the component
        if component.componentType == .SDF2D || component.componentType == .Transform2D {
            properties.append((nil, nil, "_posX", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_posY", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotate", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
        } else
        if component.componentType == .SDF3D || component.componentType == .Transform3D {
            properties.append((nil, nil, "_posX", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_posY", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_posZ", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotateX", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotateY", data.count, component, hierarchy))
            data.append(SIMD4<Float>(0,0,0,0))
            properties.append((nil, nil, "_rotateZ", data.count, component, hierarchy))
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
    var sampleBuffer        : MTLBuffer!

    var clearState          : MTLComputePipelineState? = nil
    var copyNearestState    : MTLComputePipelineState? = nil
    var sampleState         : MTLComputePipelineState? = nil

    var sdfStream           : CodeSDFStream

    init(_ view: MMView)
    {
        mmView = view
        
        compute = MMCompute()
        sdfStream = CodeSDFStream()
        
        buildClearState()
        buildCopyStates()
        buildSampleState()
    }
    
    func build(_ component: CodeComponent, camera: CodeComponent? = nil, monitor: CodeFragment? = nil) -> CodeBuilderInstance
    {
        //print("build", component.componentType, monitor)
        let inst = CodeBuilderInstance()
        inst.component = component
        
        inst.code = getHeaderCode()
        
        // Time
        inst.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
        
        dryRunComponent(component, inst.data.count, monitor)

        if let globalCode = component.globalCode {
            inst.code += globalCode
        }
        
        // Compute monitor components
        if let fragment = monitor {
            if fragment.name == "out" {
                // Correct the out fragment return type
                fragment.typeName = fragment.parentBlock!.parentFunction!.header.fragment.typeName
            }
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
        if component.componentType == .Camera3D {
            buildCamera3D(inst, component, monitor)
        } else
        if component.componentType == .SDF2D {
            buildSDF2D(inst, component, monitor)
        } else
        if component.componentType == .SDF3D {
            buildSDF3D(inst, component, monitor)
        } else
        if component.componentType == .Render2D {
            buildRender2D(inst, component, monitor)
        } else
        if component.componentType == .Render3D {
            buildRender3D(inst, component, monitor)
        }
        
        //print( inst.code )
    
        buildInstance(inst)
        return inst
    }
    
    func buildInstance(_ inst: CodeBuilderInstance, name: String = "componentBuilder", additionalNames: [String] = [])
    {
        inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        inst.computeOutBuffer = compute.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride, options: [])!

        let library = compute.createLibraryFromSource(source: inst.code)
        inst.computeState = compute.createState(library: library, name: name)
        
        for name in additionalNames {
            inst.additionalStates[name] = compute.createState(library: library, name: name)
        }
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
        
            struct FuncData __funcData;
            __funcData.GlobalTime = GlobalTime;
            __funcData.__monitorOut = &__monitorOut;
            __funcData.__data = __data;

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
        
        //print( inst.code )
        
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
        texture2d<half, access::sample>         __rayDirectionTexture [[texture(2)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

            float4 __monitorOut = float4(0,0,0,0);
            float2 uv = float2(__gid.x, __gid.y);
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float3 rayDirection = float4(__rayDirectionTexture.sample(__textureSampler, uv / size )).xyz;
            uv /= size;
            uv.y = 1.0 - uv.y;

            float4 outColor = float4(0,0,0,1);
            float GlobalTime = __data[0].x;
        
            struct FuncData __funcData;
            __funcData.GlobalTime = GlobalTime;
            __funcData.__monitorOut = &__monitorOut;
            __funcData.__data = __data;
        
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
    func buildCamera3D(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          __outOriginTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        texture2d<half, access::write>          __outDirectionTexture  [[texture(2)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float4 __monitorOut = float4(0,0,0,0);
            float2 uv = float2(__gid.x, __gid.y);
            float2 size = float2( __outOriginTexture.get_width(), __outOriginTexture.get_height() );
            uv /= size;
            uv.y = 1.0 - uv.y;
        
            float GlobalTime = __data[0].x;

            //float2 randv2 = fract(cos((uv.xy+uv.yx*float2(1000.0,1000.0))+float2(GlobalTime)*10.0));

            //randv2 += float2(1.0,1.0);
            //float2 jitter = float2(fract(sin(dot(randv2.xy ,float2(12.9898,78.233))) * 43758.5453), fract(cos(dot(randv2.xy ,float2(4.898,7.23))) * 23421.631));
        
            float2 jitter = float2(0.5, 0.5);
            //float2 jitter = float2(__data[0].z, __data[0].w);

            float3 outPosition = float3(0,0,0);
            float3 outDirection = float3(0,0,0);
        
            struct FuncData __funcData;
            __funcData.GlobalTime = GlobalTime;
            __funcData.__monitorOut = &__monitorOut;
            __funcData.__data = __data;
        
        """
        
        if let code = component.code {
            inst.code += code
        }

        if let monitorFragment = monitor, monitorFragment.name != "outPosition", monitorFragment.name != "outDirection" {
            inst.code +=
            """
            
                __outOriginTexture.write(half4(__monitorOut), __gid);
            }
            """
        } else {

            inst.code +=
            """
            
                __outOriginTexture.write(half4(half3(outPosition), 0), __gid);
                __outDirectionTexture.write(half4(half3(outDirection), 0), __gid);
            }
            
            """
        }
    }
    
    /// Build the source code for the component
    func buildSDF2D(_ inst: CodeBuilderInstance,_ component: CodeComponent,_ monitor: CodeFragment? = nil, camera: CodeComponent? = nil)
    {
        sdfStream.openStream(.SDF2D, inst, self, camera: camera)
        sdfStream.pushComponent(component, monitor)
        sdfStream.closeStream()
        
        // Position
        inst.data.append(SIMD4<Float>(0,0,0,0))
    }
    
    /// Build the source code for the component
    func buildSDF3D(_ inst: CodeBuilderInstance,_ component: CodeComponent,_ monitor: CodeFragment? = nil, camera: CodeComponent? = nil)
    {
        sdfStream.openStream(.SDF3D, inst, self, camera: camera)
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
            float GlobalTime = __data[0].x;

            struct FuncData __funcData;
            __funcData.GlobalTime = GlobalTime;
            __funcData.__monitorOut = &__monitorOut;
            __funcData.__data = __data;

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
    func buildRender3D(_ inst: CodeBuilderInstance, _ component: CodeComponent,_ monitor: CodeFragment? = nil)
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
        texture2d<half, access::sample>         __normalTexture [[texture(4)]],
        texture2d<half, access::sample>         __metaTexture [[texture(5)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);
            float4 __monitorOut = float4(0,0,0,0);

            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y);

            float4 outColor = float4(0, 0, 0, 1);
            float4 backColor = float4(__backTexture.sample(__textureSampler, uv / size ));
            float4 matColor = float4(1, 1, 1, 1);
        
            float3 normal = float4(__normalTexture.sample(__textureSampler, uv / size )).xyz;
            float4 meta = float4(__metaTexture.sample(__textureSampler, uv / size ));

            float4 shape = float4(__depthTexture.sample(__textureSampler, uv / size ));
            float GlobalTime = __data[0].x;

            struct FuncData __funcData;
            __funcData.GlobalTime = GlobalTime;
            __funcData.__monitorOut = &__monitorOut;
            __funcData.__data = __data;

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
                       
            outColor.xyz = pow( outColor.xyz, float3(0.4545) );
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
    
    /// Build a copy texture shader
    func buildCopyStates()
    {
        let code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void copyNearestBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        texture2d<half, access::sample>         inTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            constexpr sampler sampler(mag_filter::linear, min_filter::linear);

            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            float2 uv = float2(gid.x, gid.y) / size;

            outTexture.write( inTexture.sample(sampler, uv), gid);
        }
         
        """

        let library = compute.createLibraryFromSource(source: code)
        copyNearestState = compute.createState(library: library, name: "copyNearestBuilder")
    }
    
    /// Build a copy texture shader
    func buildSampleState()
    {
        let code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void sampleBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        constant float4                        *data   [[ buffer(1) ]],
        texture2d<half, access::sample>         sampleTexture [[texture(2)]],
        texture2d<half, access::sample>         resultTexture [[texture(3)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            constexpr sampler linear_sampler(mag_filter::linear, min_filter::linear);
            constexpr sampler nearest_sampler(mag_filter::nearest, min_filter::nearest);

            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            float2 uv = float2(gid.x, gid.y) / size;

            float frame = data[0].x;

            float4 sample = float4(sampleTexture.sample(nearest_sampler, uv));
            float4 result = float4(resultTexture.sample(linear_sampler, uv));
            float4 final = mix(sample, result, 1./frame);

            outTexture.write(half4(final), gid);
        }
         
        """

        let data : [SIMD4<Float>] = [SIMD4<Float>(0,0,0,0)]
        sampleBuffer = compute.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        
        let library = compute.createLibraryFromSource(source: code)
        sampleState = compute.createState(library: library, name: "sampleBuilder")
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
        inst.data[0].z = Float.random(in: 0...1)
        inst.data[0].w = Float.random(in: 0...1)
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
                
                // Recursively add the parent values for this transform
                var parentValue : Float = 0
                for stageItem in property.5.reversed() {
                    if let transComponent = stageItem.components[stageItem.defaultName] {
                        // Transform
                        var properties : [String:Float] = [:]
                        properties[name] = transComponent.values[name]!
                        
                        let transformed = timeline.transformProperties(sequence: transComponent.sequence, uuid: transComponent.uuid, properties: properties, frame: timeline.currentFrame)
                        
                        parentValue += transformed[name]!
                    }
                }
                
                var properties : [String:Float] = [:]
                properties[name] = component.values[name]! + parentValue

                let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                
                if globalApp!.currentSceneMode == .ThreeD {
                    if name == "_posY" {
                        inst.data[dataIndex].x = -transformed[name]!
                    } else {
                        inst.data[dataIndex].x = transformed[name]!
                    }
                } else {
                    inst.data[dataIndex].x = transformed[name]!
                }
            }
        }
        updateBuffer(inst)
    }

    // Clear the texture
    func renderClear(texture: MTLTexture, data: SIMD4<Float>)
    {
        clearBuffer = compute.device.makeBuffer(bytes: [data], length: 1 * MemoryLayout<SIMD4<Float>>.stride, options: [])!

        compute.run( clearState!, outTexture: texture, inBuffer: clearBuffer)
        compute.commandBuffer.waitUntilCompleted()
    }
    
    // Copy the texture using nearest sampling
    func renderCopyNearest(texture: MTLTexture, inTexture: MTLTexture, syncronize: Bool = false)
    {
        compute.run( copyNearestState!, outTexture: texture, inTexture: inTexture, syncronize: syncronize)
        compute.commandBuffer.waitUntilCompleted()
    }
    
    // Copy the texture using nearest sampling
    func renderSample(texture: MTLTexture, sampleTexture: MTLTexture, resultTexture: MTLTexture, frame: Int)
    {
        sampleBuffer = compute.device.makeBuffer(bytes: [SIMD4<Float>(Float(frame), 0, 0, 0)], length: 1 * MemoryLayout<SIMD4<Float>>.stride, options: [])!

        compute.run( sampleState!, outTexture: texture, inBuffer: sampleBuffer, inTextures: [sampleTexture, resultTexture])
        compute.commandBuffer.waitUntilCompleted()
    }
    
    
    // Render the component into a texture
    func render(_ inst: CodeBuilderInstance,_ outTexture: MTLTexture? = nil, inTextures: [MTLTexture] = [], outTextures: [MTLTexture] = [], syncronize: Bool = false, optionalState: String? = nil)
    {
        updateData(inst)
        
        var state : MTLComputePipelineState? = nil
        
        if let oState = optionalState {
            state = inst.additionalStates[oState]
        } else {
            state = inst.computeState
        }
        
        if let state = state {
            compute.run( state, outTexture: outTexture, inBuffer: inst.buffer, inTextures: inTextures, outTextures: outTextures, syncronize: syncronize)
            compute.commandBuffer.waitUntilCompleted()
        }
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
    
    /// Returns the header code required by every shader
    func getHeaderCode() -> String
    {
        return """
        
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
                
        struct FuncData
        {
            float               GlobalTime;
            thread float4      *__monitorOut;
            constant float4    *__data;
        };
        
        #define PI 3.14159265359

        float degrees(float radians)
        {
            return radians * 180.0 / PI;
        }
        
        float radians(float degrees)
        {
            return degrees * PI / 180.0;
        }
        
        """
    }
}
