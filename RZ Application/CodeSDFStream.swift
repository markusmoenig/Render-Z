//
//  CodeSDFStream.swift
//  Shape-Z
//
//  Created by Markus Moenig on 21/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

class CodeSDFStream
{
    var type                : CodeComponent.ComponentType = .SDF2D
    var instance            : CodeBuilderInstance!
    var codeBuilder         : CodeBuilder!
    var componentCounter    : Int = 0
    
    var headerCode          : String = ""
    var mapCode             : String = ""

    var hitAndNormalsCode   : String = ""
    var aoCode              : String = ""
    var shadowCode          : String = ""

    var monitor             : CodeFragment? = nil

    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]
    var idCounter           : Int = 0
    
    var materialIds         : [Int:StageItem] = [:]
    var materialIdCounter   : Int = 0
    var materialIdHierarchy : [Int] = []
    var currentMaterialId   : Int = 0

    var hierarchy           : [StageItem] = []

    init()
    {
        
    }
    
    func reset()
    {
        ids = [:]
        idCounter = 0
        
        materialIds = [:]
        materialIdCounter = 0
        materialIdHierarchy = []
        currentMaterialId = 0
        
        hierarchy = []
    }
    
    func openStream(_ type: CodeComponent.ComponentType,_ instance : CodeBuilderInstance,_ codeBuilder: CodeBuilder, camera: CodeComponent? = nil, groundComponent: CodeComponent? = nil)
    {
        self.type = type
        self.instance = instance
        self.codeBuilder = codeBuilder
        
        monitor = nil
        componentCounter = 0        
        instance.properties = []
                
        if type == .SDF2D {
            headerCode = codeBuilder.getHeaderCode()
            headerCode +=
            """
                        
            float2 __translate(float2 p, float2 t)
            {
                return p - t;
            }
            
            """
            
            // Generate the camera code and add the global camera code
            if let camera = camera {
                dryRunComponent(camera, instance.data.count, monitor)
                instance.collectProperties(camera)
                if let globalCode = camera.globalCode {
                    headerCode += globalCode
                }
            }
            
            instance.code =
                
            """
            kernel void hitAndNormals(
            texture2d<half, access::write>          __outTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            //texture2d<half, access::sample>       fontTexture [[texture(2)]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float4 __monitorOut = float4(0,0,0,0);
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );
                float2 __origin = float2(__gid.x, __gid.y);
                float2 __center = __size / 2;
                __origin = __translate(__origin, __center);

                float GlobalTime = __data[0].x;
                float outDistance = 10;
                float4 outShape = float4(100000, 0,0,0);
            
                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.__monitorOut = &__monitorOut;
                __funcData.__data = __data;
            
            """
            
            if let camera = camera {
                instance.code +=
                """
                
                    {
                        float2 position = __origin;
                        float2 outPosition = float2(0);
                
                """
                instance.code += camera.code!
                instance.code +=
                """
                
                        __origin = float2(outPosition.x, outPosition.y);
                    }
                
                """
            }
        } else
        if type == .SDF3D {
            headerCode = codeBuilder.getHeaderCode()
            headerCode +=
            """
            
            float3 __translate(float3 p, float3 t)
            {
                return p - t;
            }
            
            """
            
            mapCode =
            """
            
            float4 sceneMap( float3 __origin, thread struct FuncData *__funcData )
            {
                float4 outShape = float4(100000, 100000, -1, -1);
                float outDistance = 10;
            
                constant float4 *__data = __funcData->__data;
                float4 __monitorOut = *__funcData->__monitorOut;
                float GlobalTime = __funcData->GlobalTime;

            
            """
            
            hitAndNormalsCode =
                
            """
            kernel void hitAndNormals(
            texture2d<half, access::write>          __outTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::sample>         __depthInTexture [[texture(2)]],
            texture2d<half, access::sample>         __normalInTexture [[texture(3)]],
            texture2d<half, access::sample>         __metaInTexture [[texture(4)]],
            texture2d<half, access::sample>         __rayOriginTexture [[texture(5)]],
            texture2d<half, access::sample>         __rayDirectionTexture [[texture(6)]],
            texture2d<half, access::write>          __normalTexture [[texture(7)]],
            texture2d<half, access::write>          __metaTexture [[texture(8)]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

                float4 __monitorOut = float4(0,0,0,0);
            
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );

                float GlobalTime = __data[0].x;
            
                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.sample(__textureSampler, __uv / __size )).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.sample(__textureSampler, __uv / __size )).xyz;

                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.__monitorOut = &__monitorOut;
                __funcData.__data = __data;
            
                float4 outShape = float4(__depthInTexture.sample(__textureSampler, __uv / __size ));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalInTexture.sample(__textureSampler, __uv / __size )).xyz;
                float4 outMeta = float4(__metaInTexture.sample(__textureSampler, __uv / __size ));
            
            """
            
            aoCode =
                
            """
            kernel void computeAO(
            texture2d<half, access::write>          __outTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::sample>         __depthInTexture [[texture(2)]],
            texture2d<half, access::sample>         __normalInTexture [[texture(3)]],
            texture2d<half, access::sample>         __metaInTexture [[texture(4)]],
            texture2d<half, access::sample>         __rayOriginTexture [[texture(5)]],
            texture2d<half, access::sample>         __rayDirectionTexture [[texture(6)]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

                float4 __monitorOut = float4(0,0,0,0);
            
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );

                float GlobalTime = __data[0].x;
            
                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.sample(__textureSampler, __uv / __size )).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.sample(__textureSampler, __uv / __size )).xyz;

                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.__monitorOut = &__monitorOut;
                __funcData.__data = __data;
            
                float4 outShape = float4(__depthInTexture.sample(__textureSampler, __uv / __size ));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalInTexture.sample(__textureSampler, __uv / __size )).xyz;
                float4 outMeta = float4(__metaInTexture.sample(__textureSampler, __uv / __size ));
            
            """
            
            shadowCode =
                
            """
            kernel void computeShadow(
            texture2d<half, access::write>          __outTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::sample>         __depthInTexture [[texture(2)]],
            texture2d<half, access::sample>         __normalInTexture [[texture(3)]],
            texture2d<half, access::sample>         __metaInTexture [[texture(4)]],
            texture2d<half, access::sample>         __rayOriginTexture [[texture(5)]],
            texture2d<half, access::sample>         __rayDirectionTexture [[texture(6)]],
            constant float4                        *__lightData   [[ buffer(7) ]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

                float4 __monitorOut = float4(0,0,0,0);
            
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );

                float GlobalTime = __data[0].x;
            
                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.sample(__textureSampler, __uv / __size )).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.sample(__textureSampler, __uv / __size )).xyz;

                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.__monitorOut = &__monitorOut;
                __funcData.__data = __data;
            
                float4 outShape = float4(__depthInTexture.sample(__textureSampler, __uv / __size ));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalInTexture.sample(__textureSampler, __uv / __size )).xyz;
                float4 outMeta = float4(__metaInTexture.sample(__textureSampler, __uv / __size ));
            
            """
            
            if let ground = groundComponent {
                if ground.componentType == .Ground3D {
                    
                    dryRunComponent(ground, instance.data.count, monitor)
                    instance.collectProperties(ground)
                    if let globalCode = ground.globalCode {
                        headerCode += globalCode
                    }
                    if let code = ground.code {
                        hitAndNormalsCode += code
                    }
                    
                    ids[idCounter] = ([globalApp!.project.selected!.getStage(.ShapeStage).getChildren()[0]], ground)
                    idCounter += 1
                }
            } else
            if let rayMarch = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .RayMarch3D) {
                dryRunComponent(rayMarch, instance.data.count, monitor)
                instance.collectProperties(rayMarch)
                if let globalCode = rayMarch.globalCode {
                    headerCode += globalCode
                }
                if let code = rayMarch.code {
                    hitAndNormalsCode += code
                }
                
                hitAndNormalsCode +=
                """
                
                if (outShape.w != inShape.w) {

                """
                
                // For hitAndNormals Stage compute the normals
                if let normal = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Normal3D) {
                    dryRunComponent(normal, instance.data.count, monitor)
                    instance.collectProperties(normal)
                    if let globalCode = normal.globalCode {
                        headerCode += globalCode
                    }
                    if let code = normal.code {
                        hitAndNormalsCode +=
                        """
                        
                        {
                        float3 position = rayOrigin + outShape.y * rayDirection;
                        """
                        hitAndNormalsCode += code
                        hitAndNormalsCode +=
                        """
                        
                        }
                        
                        """
                    }
                }
                
                if let ao = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .AO3D) {
                    dryRunComponent(ao, instance.data.count, monitor)
                    instance.collectProperties(ao)
                    if let globalCode = ao.globalCode {
                        headerCode += globalCode
                    }
                    if let code = ao.code {
                        aoCode +=
                        """
                        
                        {
                        float3 position = rayOrigin + outShape.y * rayDirection;
                        float3 normal = outNormal;
                        float outAO = 1.;
                        """
                        aoCode += code
                        aoCode +=
                        """
                        
                        outMeta.x = min(outMeta.x, outAO);
                        }
                        
                        """
                    }
                }
                
                if let shadows = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Shadows3D) {
                    dryRunComponent(shadows, instance.data.count, monitor)
                    instance.collectProperties(shadows)
                    if let globalCode = shadows.globalCode {
                        headerCode += globalCode
                    }
                    if let code = shadows.code {
                        shadowCode +=
                        """
                        
                        {
                        float3 position = rayOrigin + (outShape.y - 0.025) * rayDirection;
                        float3 direction = __lightData[0].xyz;
                        float outShadow = 1.;
                        """
                        shadowCode += code
                        shadowCode +=
                        """
                        
                        outMeta.y = min(outMeta.y, outShadow);
                        }
                        
                        """
                    }
                }
                
                hitAndNormalsCode +=
                """
                
                }

                """
                
                /*
                
                if let shadows = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Shadows3D) {
                    dryRunComponent(shadows, instance.data.count, monitor)
                    instance.collectProperties(shadows)
                    if let globalCode = shadows.globalCode {
                        headerCode += globalCode
                    }
                    if let code = shadows.code {

                        shadowCode += code
                        shadowCode = shadowCode.replacingOccurrences(of: "&__", with: "__")
                    }
                }
                
                if let sun = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .SampleSun3D) {
                    dryRunComponent(sun, instance.data.count, monitor)
                    instance.collectProperties(sun)
                    if let globalCode = sun.globalCode {
                        headerCode += globalCode
                    }
                    if let code = sun.code {
                        instance.code +=
                        """
                        
                        {
                        float3 position = rayOrigin + outShape.y * rayDirection;
                        float outSun = 1.;
                        """
                        instance.code += code
                        instance.code +=
                        """
                        
                        outMeta.y = min(outMeta.y, outSun);
                        }
                        
                        """
                    }
                }
                */
            }
        }
    }

    func closeStream()
    {
        if let monitorFragment = monitor {
            if monitorFragment.name != "outDistance" {
                instance.code +=
                """
                
                outShape = __monitorOut;
                
                """
            } else {
                instance.code +=
                """
                
                outShape = float4(float3(outShape.x), 1);
                
                """
            }
        }
    
        if type == .SDF2D {
            instance.code +=
            """
            
                __outTexture.write(half4(outShape), __gid);
            }
            """
            instance.code = headerCode + instance.code
        } else
        if type == .SDF3D {
            hitAndNormalsCode +=
            """
            
                __normalTexture.write(half4(float4(outNormal, 0)), __gid);
                __metaTexture.write(half4(outMeta), __gid);
                __outTexture.write(half4(outShape), __gid);
            }
            """
            
            aoCode +=
            """
            
                __outTexture.write(half4(outMeta), __gid);
            }
            
            """
            
            shadowCode +=
            """
            
                __outTexture.write(half4(outMeta), __gid);
            }
            
            """
                        
            mapCode +=
            """
            
                return outShape;
            }
            
            """
            
            instance.code = headerCode + mapCode + shadowCode + hitAndNormalsCode + aoCode
        }
        
        codeBuilder.buildInstance(instance, name: "hitAndNormals", additionalNames: type == .SDF3D ? ["computeAO", "computeShadow"] : [])
    }
    
    func pushComponent(_ component: CodeComponent,_ monitor: CodeFragment? = nil)
    {
        dryRunComponent(component, instance.data.count, monitor)
        instance.collectProperties(component, hierarchy)
        self.monitor = monitor
        
        if let globalCode = component.globalCode {
            headerCode += globalCode
        }
        
        var code = ""
        
        if type == .SDF2D
        {
            let posX = instance.getTransformPropertyIndex(component, "_posX")
            let posY = instance.getTransformPropertyIndex(component, "_posY")

            code +=
            """
                {
                    float2 position = __translate(__origin, float2(__data[\(posX)].x, -__data[\(posY)].x));

            """
        } else
        if type == .SDF3D
        {
            let posX = instance.getTransformPropertyIndex(component, "_posX")
            let posY = instance.getTransformPropertyIndex(component, "_posY")
            let posZ = instance.getTransformPropertyIndex(component, "_posZ")

            code +=
            """
                {
                    float3 position = __translate(__origin, float3(__data[\(posX)].x, -__data[\(posY)].x, __data[\(posZ)].x));

            """
        }
        
        code += component.code!

        if componentCounter > 0 {
            code +=
            """
            
                float4 shapeA = outShape;
                float4 shapeB = float4(outDistance, -1, \(currentMaterialId), \(idCounter));
            
            """
            
            if let subComponent = component.subComponent {
                dryRunComponent(subComponent, instance.data.count, monitor)
                instance.collectProperties(subComponent)
                code += subComponent.code!
            }
        } else {
            code +=
            """
            
                outShape = float4(outDistance, -1, \(currentMaterialId), \(idCounter));
            
            """
        }
    
        code += "\n    }\n"
        if type == .SDF2D {
            instance.code += code
        } else
        if type == .SDF3D {
            mapCode += code
        }
        
        // If we have a stageItem, store the id
        if hierarchy.count > 0 {
            ids[idCounter] = (hierarchy, component)
        }
        idCounter += 1
        componentCounter += 1
    }
    
    func pushStageItem(_ stageItem: StageItem)
    {
        hierarchy.append(stageItem)
        
        if getFirstComponentOfType(stageItem.children, .Material3D) != nil {
            // If this item has a material, push it on the stack
            materialIdHierarchy.append(materialIdCounter)
            materialIds[materialIdCounter] = stageItem
            currentMaterialId = materialIdCounter
            //print(stageItem.name, materialIdCounter, currentMaterialId)
            materialIdCounter += 1
        }
    }
    
    func pullStageItem()
    {
        let stageItem = hierarchy.removeLast()
        
        // If object had a material, pop the materialHierarchy
        if getFirstComponentOfType(stageItem.children, .Material3D) != nil {
            materialIdHierarchy.removeLast()
            if materialIdHierarchy.count > 0 {
                currentMaterialId = materialIdHierarchy.last!
            } else {
                currentMaterialId = 0
            }
        }
    }
}
