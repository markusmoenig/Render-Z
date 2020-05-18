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
    
    var finishedCompiling   : Bool = false

    /// Adds a global variable manually, used when we need to know the index of a global variable
    func addGlobalVariable(name: String) -> Int?
    {
        let globalVars = globalApp!.project.selected!.getStage(.VariablePool).getGlobalVariable()
        if let variableComp = globalVars[name] {
            
            for uuid in variableComp.properties {
                let rc = variableComp.getPropertyOfUUID(uuid)
                if rc.0!.values["variable"] == 1 {
                    let index = data.count
                    properties.append((rc.0, rc.1, nil, data.count, variableComp, []))
                    data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
                    return index
                }
            }
        }
        
        return nil
    }
    
    /// Collect all the properties of the component and create a data entry for it
    func collectProperties(_ component: CodeComponent,_ hierarchy: [StageItem] = [])
    {
        // Collect properties and globalVariables
        for (index,uuid) in component.inputDataList.enumerated() {
            let propComponent = component.inputComponentList[index]
            if propComponent.properties.contains(uuid) {
                // Normal property
                let rc = propComponent.getPropertyOfUUID(uuid)
                if rc.0 != nil && rc.1 != nil {
                    properties.append((rc.0, rc.1, nil, data.count, propComponent, hierarchy))
                    data.append(SIMD4<Float>(rc.1!.values["value"]!,0,0,0))
                }
            } else
            if let tool = propComponent.toolPropertyIndex[uuid] {
                // Tool property, tool.0 is the name of fragment value
                for t in tool {
                    properties.append((t.1, t.1, t.0, data.count, propComponent, hierarchy))
                    data.append(SIMD4<Float>(t.1.values[t.0]!,0,0,0))
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
            
            if component.values["2DIn3D"] == 1 {
                properties.append((nil, nil, "_posZ", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rotateX", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rotateY", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rotateZ", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_extrusion", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_revolution", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
                properties.append((nil, nil, "_rounding", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
            } else {
                properties.append((nil, nil, "_rotate", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
            }
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
            if component.values["_bbox"] != nil {
                properties.append((nil, nil, "_bbox", data.count, component, hierarchy))
                data.append(SIMD4<Float>(0,0,0,0))
            }
        }
        
        // Scaling on the transforms
        if component.componentType == .Transform2D || component.componentType == .Transform3D {
            if component.values["_scale"] == nil { component.values["_scale"] = 1 }
            properties.append((nil, nil, "_scale", data.count, component, hierarchy))
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
    var clearTerrainState   : MTLComputePipelineState? = nil

    var copyState           : MTLComputePipelineState? = nil
    var copyGammaState      : MTLComputePipelineState? = nil
    var copyAndSwapState    : MTLComputePipelineState? = nil
    var sampleState         : MTLComputePipelineState? = nil
    var previewState        : MTLComputePipelineState? = nil

    var depthMapState       : MTLComputePipelineState? = nil
    var aoState             : MTLComputePipelineState? = nil
    var shadowState         : MTLComputePipelineState? = nil

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
        } else
        if component.componentType == .PostFX {
            buildPostFX(inst, component)
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
        
        if inst.computeState == nil {
            print(inst.code)
        }
        
        for name in additionalNames {
            inst.additionalStates[name] = compute.createState(library: library, name: name)
        }
        
        inst.finishedCompiling = true
    }
    
    func buildInstanceAsync(_ inst: CodeBuilderInstance, name: String = "componentBuilder", additionalNames: [String] = [])
    {
        sdfStream.replaceTexturReferences(inst)
        
        inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        inst.computeOutBuffer = compute.device.makeBuffer(length: MemoryLayout<SIMD4<Float>>.stride, options: [])!

        compute.createLibraryFromSourceAsync(source: inst.code, cb: { (library, error) in

            inst.computeState = self.compute.createState(library: library, name: name)
            
            if inst.computeState == nil && error != nil {
                print(error!.localizedDescription)
                print(inst.code)
            }
            
            for name in additionalNames {
                inst.additionalStates[name] = self.compute.createState(library: library, name: name)
            }
            
            inst.finishedCompiling = true
                        
            DispatchQueue.main.async {
                globalApp!.currentEditor.render()
            }
        })
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
    
    /// Build the source code for the component
    func buildPostFX(_ inst: CodeBuilderInstance, _ component: CodeComponent)
    {
        inst.code +=
        """
        
        kernel void componentBuilder(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        constant float4                        *__data   [[ buffer(1) ]],
        texture2d<half, access::read>           __colorTexture [[texture(2)]],
        texture2d<half, access::sample>         __sampleTexture [[texture(3)]],
        texture2d<half, access::read>           __depthTexture [[texture(4)]],
        texture2d<half, access::sample>         __sampleDepthTexture [[texture(5)]],
        __POSTFX_TEXTURE_HEADER_CODE__
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y) / size;

            float4 outColor = float4(0, 0, 0, 1);
            float4 color = float4(__colorTexture.read(__gid));
            float4 shape = float4(__depthTexture.read(__gid));

        """
        inst.code += getFuncDataCode(inst, "POSTFX", 6)
        
        inst.code +=
        """
        
        __funcData->texture1 = &__sampleTexture;
        __funcData->texture2 = &__sampleDepthTexture;

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
    
    func buildPreviewState()
    {
        var code =
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

                L = float3(0.5, 0.3, 0.7);
                result.xyz += dot(L, normal);

                L = float3(0.5, -0.3, -0.7);
                result.xyz += dot(L, normal);

                result.xyz *= meta.x;
                result.xyz *= meta.y;
                result.w = 1.0;
            }
        
            outColor = result;
                       
            outColor.xyz = pow( outColor.xyz, float3(0.4545) );
            __outTexture.write(half4(outColor), __gid);
        }
          
        """
        
        var library = compute.createLibraryFromSource(source: code)
        previewState = compute.createState(library: library, name: "preview")
        
        code =
        """
        
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void depthMap(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        texture2d<half, access::read>           __depthTexture [[texture(2)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y);

            float4 depthColor = float4(__depthTexture.read(__gid));

            float4 outColor = float4(float3(1.0 - depthColor.y / 20.), 1);
                       
            __outTexture.write(half4(outColor), __gid);
        }
          
        """

        library = compute.createLibraryFromSource(source: code)
        depthMapState = compute.createState(library: library, name: "depthMap")
        
        code =
        """
        
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void ao(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        texture2d<half, access::read>           __depthTexture [[texture(2)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y);

            float4 depthColor = float4(__depthTexture.read(__gid));

            float4 outColor = float4(float3(depthColor.x), 1);
                       
            __outTexture.write(half4(outColor), __gid);
        }
          
        """

        library = compute.createLibraryFromSource(source: code)
        aoState = compute.createState(library: library, name: "ao")
        
        code =
        """
        
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void shadow(
        texture2d<half, access::write>          __outTexture  [[texture(0)]],
        texture2d<half, access::read>           __depthTexture [[texture(2)]],
        uint2 __gid                             [[thread_position_in_grid]])
        {
            float2 size = float2( __outTexture.get_width(), __outTexture.get_height() );
            float2 uv = float2(__gid.x, __gid.y);

            float4 depthColor = float4(__depthTexture.read(__gid));

            float4 outColor = float4(float3(depthColor.y), 1);
                       
            __outTexture.write(half4(outColor), __gid);
        }
          
        """

        library = compute.createLibraryFromSource(source: code)
        shadowState = compute.createState(library: library, name: "shadow")
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
        
        code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        kernel void clearTerrainBuilder(
        texture2d<int, access::write>           outTexture  [[texture(0)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
           outTexture.write(int4(0), gid);
        }
         
        """

        library = compute.createLibraryFromSource(source: code)
        clearTerrainState = compute.createState(library: library, name: "clearTerrainBuilder")
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
        
        kernel void copyGammaBuilder(
        texture2d<half, access::write>          outTexture  [[texture(0)]],
        texture2d<half, access::read>           inTexture [[texture(2)]],
        uint2 gid                               [[thread_position_in_grid]])
        {
            half4 color = inTexture.read(gid);
            color.xyz = pow(color.xyz, 1./2.2);
            outTexture.write(color, gid);
        }
         
        """

        library = compute.createLibraryFromSource(source: code)
        copyGammaState = compute.createState(library: library, name: "copyGammaBuilder")
        
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
    
    func waitUntilCompleted()
    {
        compute.commandBuffer.waitUntilCompleted()
    }
    
    /// Update the instance buffer
    func updateBuffer(_ inst: CodeBuilderInstance)
    {
        if inst.computeState != nil {
            inst.buffer = compute.device.makeBuffer(bytes: inst.data, length: inst.data.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
        }
    }
    
    /// Update the instance data
    func updateData(_ inst: CodeBuilderInstance,_ jitter: Bool = true)
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
        if jitter {
            inst.data[0].z = Float.random(in: 0.0...1.0)
            inst.data[0].w = Float.random(in: 0.0...1.0)
        } else {
            inst.data[0].z = 0.5
            inst.data[0].w = 0.5
        }
        
        //inst.data[0].z = 1
        //inst.data[0].w = 1

        for property in inst.properties {
            
            let dataIndex = property.3
            let component = property.4

            if property.0 != nil
            {
                // Property, stored in the CodeFragments
                
                let isToolProperty : Bool = property.2 != nil && property.1 != nil
                
                let data = isToolProperty ? SIMD4<Float>(property.1!.values[property.2!]!,0,0,0) : extractValueFromFragment(property.1!)
                let components = isToolProperty ? 1 : property.1!.evaluateComponents()
                
                // Transform the properties inside the artist editor
                
                let name = isToolProperty ? property.2! : property.0!.name
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
                if components == 4 {
                    // For colors, convert them to sRGB for rendering
                    inst.data[dataIndex].x = pow(inst.data[dataIndex].x, 2.2)
                    inst.data[dataIndex].y = pow(inst.data[dataIndex].y, 2.2)
                    inst.data[dataIndex].z = pow(inst.data[dataIndex].z, 2.2)
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
                        
                        if let value = transComponent.values[name] {
                            properties[name] = value
                            
                            let transformed = timeline.transformProperties(sequence: transComponent.sequence, uuid: transComponent.uuid, properties: properties, frame: timeline.currentFrame)
                            
                            parentValue += transformed[name]!
                        }
                    }
                }
                
                var properties : [String:Float] = [:]
                if let value = component.values[name] {
                    properties[name] = value

                    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                    
                    if component.componentType != .Transform2D && component.componentType != .Transform3D {
                        inst.data[dataIndex].x = transformed[name]! + parentValue
                    } else {
                        // Transforms do not get their parent values, these are added by hand in the shader for the pivot
                        inst.data[dataIndex].x = transformed[name]!
                    }
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
    }
    
    // Clear the shadow
    func renderClearShadow(texture: MTLTexture)
    {
        compute.run( clearShadowState!, outTexture: texture)
    }
    
    // Clear terrain
    func renderClearTerrain(texture: MTLTexture)
    {
        compute.run( clearTerrainState!, outTexture: texture)
    }
    
    // Copy the texture
    func renderCopy(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( copyState!, outTexture: to, inTexture: from, syncronize: syncronize)
    }
    
    // Copy and gamma correct the texture
    func renderCopyGamma(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( copyGammaState!, outTexture: to, inTexture: from, syncronize: syncronize)
    }
    
    // Render the Depth Map
    func renderDepthMap(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( depthMapState!, outTexture: to, inTexture: from, syncronize: syncronize)
    }
    
    // Render the AO
    func renderAO(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( aoState!, outTexture: to, inTexture: from, syncronize: syncronize)
    }
    
    // Render the Shadows
    func renderShadow(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( shadowState!, outTexture: to, inTexture: from, syncronize: syncronize)
    }
    
    // Copy the texture and swap the rgb values
    func renderCopyAndSwap(_ to: MTLTexture,_ from: MTLTexture, syncronize: Bool = false)
    {
        compute.run( copyAndSwapState!, outTexture: to, inTexture: from, syncronize: syncronize)
    }
    
    // Copy the texture using nearest sampling
    func renderSample(sampleTexture: MTLTexture, resultTexture: MTLTexture, frame: Int)
    {
        sampleBuffer = compute.device.makeBuffer(bytes: [SIMD4<Float>(Float(frame), 0, 0, 0)], length: 1 * MemoryLayout<SIMD4<Float>>.stride, options: [])!

        compute.run( sampleState!, outTexture: sampleTexture, inBuffer: sampleBuffer, inTextures: [resultTexture])
    }
    
    // Render the component into a texture
    func render(_ inst: CodeBuilderInstance,_ outTexture: MTLTexture? = nil, inTextures: [MTLTexture] = [], outTextures: [MTLTexture] = [], inBuffers: [MTLBuffer] = [], syncronize: Bool = false, optionalState: String? = nil, jitter: Bool = true)
    {
        updateData(inst, jitter)
        
        var state : MTLComputePipelineState? = nil
        
        if let oState = optionalState {
            if let s =  inst.additionalStates[oState] {
                state = s
            }
        } else {
            state = inst.computeState
        }
        
        // Atach the instance textures to the outTextures
        var myOuTextures = outTextures
        for t in inst.textures {
            for texture in globalApp!.images {
                if texture.0 == t.0 {
                    myOuTextures.append(texture.1)
                    break
                }
            }
        }
        
        if let state = state {
            compute.run( state, outTexture: outTexture, inBuffer: inst.buffer, inTextures: inTextures, outTextures: myOuTextures, inBuffers: inBuffers, syncronize: syncronize)
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
            thread texture2d<half, access::sample>   *texture1;
            thread texture2d<half, access::sample>   *texture2;
            thread texture2d<int, access::sample>    *terrainTexture;
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
        
        uint baseHash( uint2 p ) {
            p = 1103515245U*((p >> 1U)^(p.yx));
            uint h32 = 1103515245U*((p.x)^(p.y>>3U));
            return h32^(h32 >> 16);
        }
        
        float random(thread FuncData *__funcData) {
            uint n = baseHash(as_type<uint2>(float2(__funcData->GlobalSeed+=.1,__funcData->GlobalSeed+=.1)));
            return float(n)/float(0xffffffffU);
        }
        
        float2 random2(thread FuncData *__funcData) {
            uint n = baseHash(as_type<uint2>(float2(__funcData->GlobalSeed+=.1,__funcData->GlobalSeed+=.1)));
            uint2 rz = uint2(n, n*48271U);
            return float2(rz.xy & uint2(0x7fffffffU))/float(0x7fffffff);
        }
        
        float axis(int index, float3 domain)
        {
            return domain[index];
        }
        
        float degrees(float radians)
        {
            return radians * 180.0 / PI;
        }
        
        float radians(float degrees)
        {
            return degrees * PI / 180.0;
        }
        
        float linearstep( const float s, const float e, float v ) {
            return clamp( (v-s)*(1./(e-s)), 0., 1. );
        }
        
        float cloudGradient( float norY ) {
            return linearstep( 0., .05, norY ) - linearstep( .8, 1.2, norY);
        }
        
        #define EARTH_RADIUS    (1500000.) // (6371000.)
        #define CLOUDS_FORWARD_SCATTERING_G (.8)
        #define CLOUDS_BACKWARD_SCATTERING_G (-.2)
        #define CLOUDS_SCATTERING_LERP (.5)
        
        float __HenyeyGreenstein( float sundotrd, float g) {
            float gg = g * g;
            return (1. - gg) / pow( 1. + gg - 2. * g * sundotrd, 1.5);
        }

        float __intersectCloudSphere( float3 rd, float r ) {
            float b = EARTH_RADIUS * rd.y;
            float d = b * b + r * r + 2. * EARTH_RADIUS * r;
            return -b + sqrt( d );
        }
        
        float4 toGamma(float4 linearColor) {
           return float4(pow(linearColor.xyz, float3(1.0/2.2)), linearColor.w);
        }

        float4 toLinear(float4 gammaColor) {
           return float4(pow(gammaColor.xyz, float3(2.2)), gammaColor.w);
        }
        
        float4 sampleColor(float2 uv, thread FuncData *__funcData)
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);
            return float4(__funcData->texture1->sample(__textureSampler, uv));
        }
        
        float sampleDistance(float2 uv, thread FuncData *__funcData)
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);
            return float4(__funcData->texture2->sample(__textureSampler, uv)).y;
        }
        
        float2 rotate(float2 pos, float angle)
        {
            float ca = cos(angle), sa = sin(angle);
            return pos * float2x2(ca, sa, -sa, ca);
        }

        float2 rotatePivot(float2 pos, float angle, float2 pivot)
        {
            float ca = cos(angle), sa = sin(angle);
            return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
        }
        
        float2 sphereIntersect( float3 ro, float3 rd, float3 ce, float ra )
        {
            float3 oc = ro - ce;
            float b = dot( oc, rd );
            float c = dot( oc, oc ) - ra*ra;
            float h = b*b - c;
            if( h<0.0 ) return float2(-1); // no intersection
            h = sqrt( h );
            return float2( -b-h, -b+h );
        }
        
        /*
        float4 __sampleTexture(texture2d<half, access::sample> texture, float2 uv)
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);
            return float4(texture.sample( __textureSampler, uv));
        }*/
        
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
        
        float __interpolateHeightTexture(texture2d<int, access::sample> texture, float2 uv)
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);
            float2 size = float2(texture.get_width(), texture.get_height());
            uv = fract(uv);
            uv = uv*size - 0.5;
            float2 iuv = floor(uv);
            float2 f = fract(uv);
            f = f*f*(3.0-2.0*f);
            float rg1 = float4(texture.sample( __textureSampler, (iuv+ float2(0.5,0.5))/size, 0.0 )).x;
            float rg2 = float4(texture.sample( __textureSampler, (iuv+ float2(1.5,0.5))/size, 0.0 )).x;
            float rg3 = float4(texture.sample( __textureSampler, (iuv+ float2(0.5,1.5))/size, 0.0 )).x;
            float rg4 = float4(texture.sample( __textureSampler, (iuv+ float2(1.5,1.5))/size, 0.0 )).x;
            return mix( mix(rg1,rg2,f.x), mix(rg3,rg4,f.x), f.y );
        }
        
        float2 __translate(float2 p, float2 t)
        {
            return p - t;
        }
        
        // 2D Noise -------------
        float hash(float2 p) {float3 p3 = fract(float3(p.xyx) * 0.13); p3 += dot(p3, p3.yzx + 3.333); return fract((p3.x + p3.y) * p3.z); }

        float noise(float2 x) {
            float2 i = floor(x);
            float2 f = fract(x);

            // Four corners in 2D of a tile
            float a = hash(i);
            float b = hash(i + float2(1.0, 0.0));
            float c = hash(i + float2(0.0, 1.0));
            float d = hash(i + float2(1.0, 1.0));

            float2 u = f * f * (3.0 - 2.0 * f);
            return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
        }
        
        float __valueNoise2D(float2 x, int octaves = 4, float persistence = 0.5, float scale = 1) {
            float v = 0.0;
            float a = 0.5;
            float2 shift = float2(100);
            for (int i = 0; i < octaves; ++i) {
                v += a * noise(x * scale);
                x = x * 2.0 + shift;
                a *= persistence;
            }
            return v;
        }
        
        // 3D Noise -------------
        
        // Value Noise, https://www.shadertoy.com/view/4dS3Wd
        float __valueHash1(float p) { p = fract(p * 0.011); p *= p + 7.5; p *= p + p; return fract(p); }
        
        float __valueN3D(float3 x) {
            const float3 step = float3(110, 241, 171);
            float3 i = floor(x);
            float3 f = fract(x);
            float n = dot(i, step);

            float3 u = f * f * (3.0 - 2.0 * f);
            return mix(mix(mix( __valueHash1(n + dot(step, float3(0, 0, 0))), __valueHash1(n + dot(step, float3(1, 0, 0))), u.x),
                           mix( __valueHash1(n + dot(step, float3(0, 1, 0))), __valueHash1(n + dot(step, float3(1, 1, 0))), u.x), u.y),
                       mix(mix( __valueHash1(n + dot(step, float3(0, 0, 1))), __valueHash1(n + dot(step, float3(1, 0, 1))), u.x),
                           mix( __valueHash1(n + dot(step, float3(0, 1, 1))), __valueHash1(n + dot(step, float3(1, 1, 1))), u.x), u.y), u.z);
        }

        float __valueNoise3D(float3 x, int octaves = 4, float persistence = 0.5, float scale = 1) {
            float v = 0.0;
            float a = 0.5;
            float3 shift = float3(100);
            for (int i = 0; i < octaves; ++i) {
                v += a * __valueN3D(x * scale);
                x = x * 2.0 + shift;
                a *= persistence;
            }
            return v;
        }
        
        // Perlin noise, https://www.shadertoy.com/view/4tycWy
        float hash(float3 p3)
        {
            p3 = fract(p3 * 0.1031);
            p3 += dot(p3, p3.yzx + 19.19);
            return fract((p3.x + p3.y) * p3.z);
        }

        float3 fade(float3 t) { return t*t*t*(t*(6.*t-15.)+10.); }

        float grad(float hash, float3 p)
        {
            int h = int(1e4*hash) & 15;
            float u = h<8 ? p.x : p.y,
                  v = h<4 ? p.y : h==12||h==14 ? p.x : p.z;
            return ((h&1) == 0 ? u : -u) + ((h&2) == 0 ? v : -v);
        }

        float perlinNoise3D(float3 p)
        {
            float3 pi = floor(p), pf = p - pi, w = fade(pf);
            return mix( mix( mix( grad(hash(pi + float3(0, 0, 0)), pf - float3(0, 0, 0)),
                                   grad(hash(pi + float3(1, 0, 0)), pf - float3(1, 0, 0)), w.x ),
                              mix( grad(hash(pi + float3(0, 1, 0)), pf - float3(0, 1, 0)),
                                   grad(hash(pi + float3(1, 1, 0)), pf - float3(1, 1, 0)), w.x ), w.y ),
                         mix( mix( grad(hash(pi + float3(0, 0, 1)), pf - float3(0, 0, 1)),
                                   grad(hash(pi + float3(1, 0, 1)), pf - float3(1, 0, 1)), w.x ),
                              mix( grad(hash(pi + float3(0, 1, 1)), pf - float3(0, 1, 1)),
                                   grad(hash(pi + float3(1, 1, 1)), pf - float3(1, 1, 1)), w.x ), w.y ), w.z );
        }

        float __perlinNoise3D(float3 pos, int octaves = 4, float persistence = 0.5, float scale = 1)
        {
            float total = 0.0, frequency = 1.0, amplitude = 1.0, maxValue = 0.0;
            for(int i = 0; i < octaves; ++i)
            {
                total += perlinNoise3D(pos * frequency * scale) * amplitude;
                maxValue += amplitude;
                amplitude *= persistence;
                frequency *= 2.0;
            }
            return total / maxValue;
        }
        
        float3 hash33w(float3 p3)
        {
            p3 = fract(p3 * float3(0.1031f, 0.1030f, 0.0973f));
            p3 += dot(p3, p3.yxz+19.19f);
            return fract((p3.xxy + p3.yxx)*p3.zyx);

        }

        float3 hash33s(float3 p3)
        {
            p3 = fract(p3 * float3(0.1031f, 0.11369f, 0.13787f));
            p3 += dot(p3, p3.yxz + 19.19f);
            return -1.0f + 2.0f * fract(float3((p3.x + p3.y) * p3.z, (p3.x + p3.z) * p3.y, (p3.y + p3.z) * p3.x));
        }

        float worley(float3 x)
        {
            float3 p = floor(x);
            float3 f = fract(x);
            
            float result = 1.0f;
            
            for(int k = -1; k <= 1; ++k)
            {
                for(int j = -1; j <= 1; ++j)
                {
                    for(int i = -1; i <= 1; ++i)
                    {
                        float3 b = float3(float(i), float(j), float(k));
                        float3 r = b - f + hash33w(p + b);
                        float d = dot(r, r);
                        
                        result = min(d, result);
                    }
                }
            }
            
            return sqrt(result);
        }

        float worleyFbm(float3 pos, int octaves, float persistence, float scale)
        {
            float final        = 0.0;
            float amplitude    = 1.0;
            float maxAmplitude = 0.0;
            
            for(float i = 0.0; i < octaves; ++i)
            {
                final        += worley(pos * scale) * amplitude;
                scale        *= 2.0;
                maxAmplitude += amplitude;
                amplitude    *= persistence;
            }
            
            return 1.0 - final;//((min(final, 1.0f) + 1.0f) * 0.5f);
        }

        float simplex(float3 pos)
        {
            const float K1 = 0.333333333;
            const float K2 = 0.166666667;
            
            float3 i = floor(pos + (pos.x + pos.y + pos.z) * K1);
            float3 d0 = pos - (i - (i.x + i.y + i.z) * K2);
            
            float3 e = step(float3(0.0), d0 - d0.yzx);
            float3 i1 = e * (1.0 - e.zxy);
            float3 i2 = 1.0 - e.zxy * (1.0 - e);
            
            float3 d1 = d0 - (i1 - 1.0 * K2);
            float3 d2 = d0 - (i2 - 2.0 * K2);
            float3 d3 = d0 - (1.0 - 3.0 * K2);
            
            float4 h = max(0.6 - float4(dot(d0, d0), dot(d1, d1), dot(d2, d2), dot(d3, d3)), 0.0);
            float4 n = h * h * h * h * float4(dot(d0, hash33s(i)), dot(d1, hash33s(i + i1)), dot(d2, hash33s(i + i2)), dot(d3, hash33s(i + 1.0)));
            
            return dot(float4(31.316), n);
        }

        float simplexFbm(float3 pos, float octaves, float persistence, float scale)
        {
            float final        = 0.0;
            float amplitude    = 1.0;
            float maxAmplitude = 0.0;
            
            for(float i = 0.0; i < octaves; ++i)
            {
                final        += simplex(pos * scale) * amplitude;
                scale        *= 2.0;
                maxAmplitude += amplitude;
                amplitude    *= persistence;
            }
            
            return final;//(min(final, 1.0f) + 1.0f) * 0.5f;
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
        {
            float2 uv = float2(__gid.x, __gid.y);
            //__funcData_.seed = fract(cos((uv.xy+uv.yx * float2(1000.0,1000.0) ) + float2(__data[0].z, __data[0].w)*10.0));
            __funcData_.GlobalSeed = float(baseHash(as_type<uint2>(uv - (float2(__data[0].z, __data[0].w) * 100.0) )))/float(0xffffffffU);
        }
        __funcData_.__data = __data;

        __\(id)_TEXTURE_ASSIGNMENT_CODE__

        """
        //float seed = float(baseHash(floatBitsToUint(p - iTime)))/float(0xffffffffU);

        inst.textureRep.append((id, textureOffset))
        
        return code
    }
}
