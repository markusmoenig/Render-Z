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
    var additionalStates    : [String: MTLComputePipelineState?] = [:]

    var data                : [SIMD4<Float>] = []
    var buffer              : MTLBuffer!
    
    var computeOutBuffer    : MTLBuffer!
    var computeResult       : SIMD4<Float> = SIMD4<Float>(0,0,0,0)
            
    var properties          : [(CodeFragment?, CodeFragment?, String?, Int, CodeComponent, [StageItem])] = []
    
    // Texture path, token, type (0 == Image, 1 == Texture)
    var textures            : [(String, String, Int)] = []
    
    // Texture replacement info
    var textureRep          : [(String, Int)] = []
    
    // Ids for objects inside the instance
    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]
    
    // Ids for materials inside the instance
    var materialIds         : [Int:StageItem] = [:]
    var materialIdHierarchy : [Int] = []
    
    var idStart             : Int = 0
        
    /// Collect all the properties of the component and create a data entry for it
    func collectProperties(_ component: CodeComponent,_ hierarchy: [StageItem] = [])
    {
        // Collect properties and globalVariables
        for (index,uuid) in component.inputDataList.enumerated() {
            let propComponent = component.inputComponentList[index]
            if propComponent.properties.contains(uuid) {
                // Property
                let rc = propComponent.getPropertyOfUUID(uuid)
                if rc.0 != nil && rc.1 != nil {
                    properties.append((rc.0, rc.1, nil, data.count, propComponent, hierarchy))
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
        
        // Add the textures
        textures += component.textures
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
    var clearShadowState    : MTLComputePipelineState? = nil
    var copyState           : MTLComputePipelineState? = nil
    var copyAndSwapState    : MTLComputePipelineState? = nil
    var sampleState         : MTLComputePipelineState? = nil
    var previewState        : MTLComputePipelineState? = nil

    var sdfStream           : CodeSDFStream

    init(_ view: MMView)
    {
        mmView = view
        
        compute = MMCompute()
        sdfStream = CodeSDFStream()
        
        buildClearState()
        buildCopyState()
        buildSampleState()
        buildPreviewState()
    }
    
    func build(_ component: CodeComponent, camera: CodeComponent? = nil) -> CodeBuilderInstance
    {
        let inst = CodeBuilderInstance()
        inst.component = component
        
        inst.code = getHeaderCode()
        
        // Time
        inst.data.append( SIMD4<Float>( 0, 0, 0, 0 ) )
        
        dryRunComponent(component, inst.data.count)

        if let globalCode = component.globalCode {
            inst.code += globalCode
        }
        
        inst.collectProperties(component)
        
        if component.componentType == .Colorize {
            buildColorize(inst, component)
        } else
        if component.componentType == .SkyDome || component.componentType == .Pattern {
            buildBackground(inst, component)
        } else
        if component.componentType == .Camera3D {
            buildCamera3D(inst, component)
        } else
        if component.componentType == .SDF2D {
            buildSDF2D(inst, component)
        } else
        if component.componentType == .SDF3D {
            buildSDF3D(inst, component)
        } else
        if component.componentType == .Render2D {
            buildRender2D(inst, component)
        } else
        if component.componentType == .Render3D {
            buildRender3D(inst, component)
        }

        buildInstance(inst)
        return inst
    }
    
    func buildInstance(_ inst: CodeBuilderInstance, name: String = "componentBuilder", additionalNames: [String] = [])
    {
        sdfStream.replaceTexturReferences(inst)
        
        inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        inst.computeOutBuffer = compute.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride, options: [])!

        let library = compute.createLibraryFromSource(source: inst.code)
        inst.computeState = compute.createState(library: library, name: name)
        
        //if inst.computeState == nil {
        //    print(inst.code)
        //}
        
        for name in additionalNames {
            inst.additionalStates[name] = compute.createState(library: library, name: name)
        }
    }
    
    /// Build the source code for the component
    func buildColorize(_ inst: CodeBuilderInstance, _ component: CodeComponent)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        __COLORIZE_TEXTURE_HEADER_CODE__
        uint2 __gid                               [[thread_position_in_grid]])
        {
            float2 uv = float2(__gid.x, __gid.y);
            float2 size = float2(__outTexture.get_width(), __outTexture.get_height() );
            uv /= size;
            uv.y = 1.0 - uv.y;

        """
        
        inst.code += getFuncDataCode(inst, "COLORIZE", 2)
        if let code = component.code {
            inst.code += code
        }
        
        //print( inst.code )
        
        inst.code +=
        """
        
            __outTexture.write(half4(outColor), __gid);
        }
        
        """
    }
    
    /// Build the source code for the component
    func buildBackground(_ inst: CodeBuilderInstance, _ component: CodeComponent)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        texture2d<half, access::read>           __rayDirectionTexture [[texture(2)]],
        __BACKGROUND_TEXTURE_HEADER_CODE__
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 uv = float2(__gid.x, __gid.y);
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float3 rayDirection = float4(__rayDirectionTexture.read(__gid)).xyz;
            float3 position = float3(uv.x, uv.y, 0);
        
            float outMask = 0;
            float outId = 0;

            uv /= size;
            uv.y = 1.0 - uv.y;

            float4 outColor = float4(0,0,0,1);
        
        """
        inst.code += getFuncDataCode(inst, "BACKGROUND", 3)
        
        if let code = component.code {
            inst.code += code
        }
        
        inst.code +=
        """
        
            __outTexture.write(half4(outColor), __gid);
        }
        
        """
    }
    
    /// Build the source code for the component
    func buildCamera3D(_ inst: CodeBuilderInstance, _ component: CodeComponent)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          __outOriginTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        texture2d<half, access::write>          __outDirectionTexture  [[texture(2)]],
        __CAMERA3D_TEXTURE_HEADER_CODE__
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 uv = float2(__gid.x, __gid.y);
            float2 size = float2( __outOriginTexture.get_width(), __outOriginTexture.get_height() );
            uv /= size;
            uv.y = 1.0 - uv.y;

            float2 jitter = float2(__data[0].z, __data[0].w);

            float3 outPosition = float3(0,0,0);
            float3 outDirection = float3(0,0,0);
        
        """
        inst.code += getFuncDataCode(inst, "CAMERA3D", 3)

        
        if let code = component.code {
            inst.code += code
        }

        inst.code +=
        """
            __outOriginTexture.write(half4(half3(outPosition), 0), __gid);
            __outDirectionTexture.write(half4(half3(outDirection), 0), __gid);
        }
        
        """
    
    }
    
    /// Build the source code for the component
    func buildSDF2D(_ inst: CodeBuilderInstance,_ component: CodeComponent, camera: CodeComponent? = nil)
    {
        sdfStream.openStream(.SDF2D, inst, self, camera: camera)
        sdfStream.pushComponent(component)
        sdfStream.closeStream()
        
        // Position
        inst.data.append(SIMD4<Float>(0,0,0,0))
    }
    
    /// Build the source code for the component
    func buildSDF3D(_ inst: CodeBuilderInstance,_ component: CodeComponent, camera: CodeComponent? = nil)
    {
        sdfStream.openStream(.SDF3D, inst, self, camera: camera)
        sdfStream.pushComponent(component)
        sdfStream.closeStream()
        
        // Position
        inst.data.append(SIMD4<Float>(0,0,0,0))
    }
    
    /// Build the source code for the component
    func buildRender2D(_ inst: CodeBuilderInstance, _ component: CodeComponent)
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
            float GlobalTime = __data[0].x;
            float GlobalSeed = __data[0].z;

            struct FuncData __funcData;
            __funcData.GlobalTime = GlobalTime;
            __funcData.GlobalSeed = GlobalSeed;
            __funcData.__data = __data;

        """
     
        if let code = component.code {
            inst.code += code
        }

        inst.code +=
        """
                       
            __outTexture.write(half4(outColor), __gid);
        }
          
        """
    }
    
    /// Build the source code for the component
    func buildRender3D(_ inst: CodeBuilderInstance, _ component: CodeComponent)
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
        texture2d<half, access::read>           __colorTexture [[texture(2)]],
        __RENDER3D_TEXTURE_HEADER_CODE__
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y);

            float4 outColor = float4(0, 0, 0, 1);
            float4 color = float4(__colorTexture.read(__gid));

        """
        inst.code += getFuncDataCode(inst, "RENDER3D", 3)
     
        if let code = component.code {
            inst.code += code
        }

        inst.code +=
        """
                       
            __outTexture.write(half4(outColor), __gid);
        }
          
        """
    }
    
    func buildPreviewState()
    {
        let code =
        """
        
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void preview(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        texture2d<half, access::read>           __depthTexture [[texture(2)]],
        texture2d<half, access::read>           __backTexture [[texture(3)]],
        texture2d<half, access::read>           __normalTexture [[texture(4)]],
        texture2d<half, access::read>           __metaTexture [[texture(5)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y);

            float4 outColor = float4(0, 0, 0, 1);
            float4 backColor = float4(__backTexture.read(__gid));
            float4 matColor = float4(1, 1, 1, 1);
        
            float3 normal = float4(__normalTexture.read(__gid)).xyz;
            float4 meta = float4(__metaTexture.read(__gid));

            float4 shape = float4(__depthTexture.read(__gid));

            float4 result = backColor;
            if (shape.w >= 0.0) {
                float3 L = float3(-0.5, 0.3, 0.7);
                result.xyz = dot(L, normal);
                result.xyz *= meta.x;
                result.xyz *= meta.y;
                result.w = 1.0;
            }
        
            outColor = result;
                       
            outColor.xyz = pow( outColor.xyz, float3(0.4545) );
            __outTexture.write(half4(outColor), __gid);
        }
          
        """

        let library = compute.createLibraryFromSource(source: code)
        previewState = compute.createState(library: library, name: "preview")
    }

    
    /// Build a clear texture shader
    func buildClearState()
    {
        var code =
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

        var library = compute.createLibraryFromSource(source: code)
        clearState = compute.createState(library: library, name: "clearBuilder")
        
        code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void clearShadowBuilder(
        texture2d<half, access::read_write>     outTexture  [[texture(0)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
           half4 data = outTexture.read(gid);
           data.y = 1.0;
           outTexture.write(data, gid);
        }
         
        """

        library = compute.createLibraryFromSource(source: code)
        clearShadowState = compute.createState(library: library, name: "clearShadowBuilder")
    }
    
    /// Build a copy texture shader
    func buildCopyState()
    {
        var code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void copyBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        texture2d<half, access::read>           inTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            outTexture.write(inTexture.read(gid), gid);
        }
         
        """

        var library = compute.createLibraryFromSource(source: code)
        copyState = compute.createState(library: library, name: "copyBuilder")
        
        code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void copyBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        texture2d<half, access::read>           inTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            half4 color = inTexture.read(gid).zyxw;
            color.xyz = pow(color.xyz, 2.2);
            outTexture.write(color, gid);
        }
         
        """

        library = compute.createLibraryFromSource(source: code)
        copyAndSwapState = compute.createState(library: library, name: "copyBuilder")
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
        texture2d<half, access::read_write>     sampleTexture  [[texture(0)]],
        constant float4                        *data   [[ buffer(1) ]],
        texture2d<half, access::read>           resultTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            float frame = data[0].x;

            float4 sample = float4(sampleTexture.read(gid));
            float4 result = float4(resultTexture.read(gid));
            float4 final = mix(sample, result, 1./frame);

            sampleTexture.write(half4(final), gid);
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
        inst.data[0].z = Float.random(in: 0.0...1.0)
        inst.data[0].w = Float.random(in: 0.0...1.0)
        
        //inst.data[0].z = 1
        //inst.data[0].w = 1

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
                    globalApp!.artistEditor.designProperties.updateTransformedProperty(component: property.4, name: name, data: inst.data[dataIndex])
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
                
                inst.data[dataIndex].x = transformed[name]!
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
    
    // Clear the shadow
    func renderClearShadow(texture: MTLTexture)
    {
        compute.run( clearShadowState!, outTexture: texture)
        compute.commandBuffer.waitUntilCompleted()
    }
    
    // Copy the texture
    func renderCopy(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( copyState!, outTexture: to, inTexture: from, syncronize: syncronize)
        compute.commandBuffer.waitUntilCompleted()
    }
    
    // Copy the texture and swap the rgb values
    func renderCopyAndSwap(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( copyAndSwapState!, outTexture: to, inTexture: from, syncronize: syncronize)
        compute.commandBuffer.waitUntilCompleted()
    }
    
    // Copy the texture using nearest sampling
    func renderSample(sampleTexture: MTLTexture, resultTexture: MTLTexture, frame: Int)
    {
        sampleBuffer = compute.device.makeBuffer(bytes: [SIMD4<Float>(Float(frame), 0, 0, 0)], length: 1 * MemoryLayout<SIMD4<Float>>.stride, options: [])!

        compute.run( sampleState!, outTexture: sampleTexture, inBuffer: sampleBuffer, inTextures: [resultTexture])
        compute.commandBuffer.waitUntilCompleted()
    }
    
    
    // Render the component into a texture
    func render(_ inst: CodeBuilderInstance,_ outTexture: MTLTexture? = nil, inTextures: [MTLTexture] = [], outTextures: [MTLTexture] = [], inBuffers: [MTLBuffer] = [], syncronize: Bool = false, optionalState: String? = nil)
    {
        updateData(inst)
        
        var state : MTLComputePipelineState? = nil
        
        if let oState = optionalState {
            state = inst.additionalStates[oState]!
        } else {
            state = inst.computeState
        }
        
        // Atach the instance textures to the outTextures
        var myOuTextures = outTextures
        for t in inst.textures {
            if let texture = globalApp!.images[t.0] {
                myOuTextures.append(texture)
            }
        }
        
        if let state = state {
            compute.run( state, outTexture: outTexture, inBuffer: inst.buffer, inTextures: inTextures, outTextures: myOuTextures, inBuffers: inBuffers, syncronize: syncronize)
            compute.commandBuffer.waitUntilCompleted()
        }
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
            float                            GlobalTime;
            float                            GlobalSeed;
            constant float4                 *__data;
            __FUNCDATA_TEXTURE_LIST__
        };
        
        struct MaterialOut
        {
            float4              color;
            float3              mask;
            float3              reflectionDir;
            float               reflectionDist;
            float               reflectionBlur;
        };
        
        struct PatternOut
        {
            float4              color;
            float               mask;
            float               id;
        };
        
        #define PI 3.1415926535897932384626422832795028841971

        float degrees(float radians)
        {
            return radians * 180.0 / PI;
        }
        
        float radians(float degrees)
        {
            return degrees * PI / 180.0;
        }
        
        float4 toGamma(float4 linearColor) {
           return float4(pow(linearColor.xyz, float3(1.0/2.2)), linearColor.w);
        }

        float4 toLinear(float4 gammaColor) {
           return float4(pow(gammaColor.xyz, float3(2.2)), gammaColor.w);
        }
        
        float4 __interpolateTexture(texture2d<half, access::sample> texture, float2 uv)
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);
            float2 size = float2(texture.get_width(), texture.get_height());
            uv = fract(uv);
            uv = uv*size - 0.5;
            float2 iuv = floor(uv);
            float2 f = fract(uv);
            f = f*f*(3.0-2.0*f);
            float4 rg1 = float4(texture.sample( __textureSampler, (iuv+ float2(0.5,0.5))/size, 0.0 ));
            float4 rg2 = float4(texture.sample( __textureSampler, (iuv+ float2(1.5,0.5))/size, 0.0 ));
            float4 rg3 = float4(texture.sample( __textureSampler, (iuv+ float2(0.5,1.5))/size, 0.0 ));
            float4 rg4 = float4(texture.sample( __textureSampler, (iuv+ float2(1.5,1.5))/size, 0.0 ));
            return mix( mix(rg1,rg2,f.x), mix(rg3,rg4,f.x), f.y );
        }
        
        """
    }
    
    func getFuncDataCode(_ inst: CodeBuilderInstance,_ id: String, _ textureOffset: Int) -> String
    {
        let code =
        """

        float GlobalTime = __data[0].x;
        float GlobalSeed = __data[0].z;

        struct FuncData __funcData_;
        thread struct FuncData *__funcData = &__funcData_;
        __funcData_.GlobalTime = GlobalTime;
        __funcData_.GlobalSeed = GlobalSeed;
        __funcData_.__data = __data;

        __\(id)_TEXTURE_ASSIGNMENT_CODE__

        """
        
        inst.textureRep.append((id, textureOffset))
        
        return code
    }
}
