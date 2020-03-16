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
    var backgroundCode      : String = ""

    var materialFuncCode    : String = ""
    var materialCode        : String = ""

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
    
    func openStream(_ type: CodeComponent.ComponentType,_ instance : CodeBuilderInstance,_ codeBuilder: CodeBuilder, camera: CodeComponent? = nil, groundComponent: CodeComponent? = nil, backgroundComponent: CodeComponent? = nil)
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
            
            backgroundCode =
            """
            
            float4 background( float2 uv, float2 size, float3 position, float3 rayDirection, thread struct FuncData *__funcData )
            {
                float4 outColor = float4(0,0,0,1);
            
                constant float4 *__data = __funcData->__data;
                float4 __monitorOut = *__funcData->__monitorOut;
                float GlobalTime = __funcData->GlobalTime;

            
            """
            
            if let background = backgroundComponent {
                dryRunComponent(background, instance.data.count, monitor)
                instance.collectProperties(background)
                if let globalCode = background.globalCode {
                    headerCode += globalCode
                }
                if let code = background.code {
                    backgroundCode += code
                }
            }
            
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
            texture2d<half, access::sample>         __rayOriginInTexture [[texture(5)]],
            texture2d<half, access::sample>         __rayDirectionInTexture [[texture(6)]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

                float4 __monitorOut = float4(0,0,0,0);
            
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );

                float GlobalTime = __data[0].x;
            
                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginInTexture.sample(__textureSampler, __uv / __size )).xyz;
                float3 rayDirection = float4(__rayDirectionInTexture.sample(__textureSampler, __uv / __size )).xyz;

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
            
            materialCode =
                
            """
            kernel void computeMaterial(
            texture2d<half, access::write>          __outTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::sample>         __colorInTexture [[texture(2)]],
            texture2d<half, access::sample>         __depthInTexture [[texture(3)]],
            texture2d<half, access::sample>         __normalInTexture [[texture(4)]],
            texture2d<half, access::sample>         __metaInTexture [[texture(5)]],
            texture2d<half, access::sample>         __rayOriginInTexture [[texture(6)]],
            texture2d<half, access::sample>         __rayDirectionInTexture [[texture(7)]],
            texture2d<half, access::sample>         __maskInTexture [[texture(8)]],
            texture2d<half, access::write>          __rayOriginTexture [[texture(9)]],
            texture2d<half, access::write>          __rayDirectionTexture [[texture(10)]],
            texture2d<half, access::write>          __maskTexture [[texture(11)]],
            constant float4                        *__lightData   [[ buffer(12) ]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

                float4 __monitorOut = float4(0,0,0,0);
            
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );

                float GlobalTime = __data[0].x;
            
                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginInTexture.sample(__textureSampler, __uv / __size )).xyz;
                float3 rayDirection = float4(__rayDirectionInTexture.sample(__textureSampler, __uv / __size )).xyz;

                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.__monitorOut = &__monitorOut;
                __funcData.__data = __data;
            
                float4 shape = float4(__depthInTexture.sample(__textureSampler, __uv / __size ));
                float4 meta = float4(__metaInTexture.sample(__textureSampler, __uv / __size ));
                float3 mask = float4(__maskInTexture.sample(__textureSampler, __uv / __size )).xyz;
                float4 color = float4(__colorInTexture.sample(__textureSampler, __uv / __size ));

                float3 incomingDirection = rayDirection;
                float3 hitPosition = rayOrigin + shape.y * rayDirection;
                float3 newPosition = rayOrigin + (shape.y - 0.025) * rayDirection;

                float3 hitNormal = float4(__normalInTexture.sample(__textureSampler, __uv / __size )).xyz;
                float occlusion = meta.x;
                float shadow = meta.y;
            
                float4 light = __lightData[0];
                float4 lightType = __lightData[1];
                float4 lightColor = __lightData[2];
            
                struct MaterialOut __materialOut;
                __materialOut.color = float4(1);
                __materialOut.mask = float3(0);
            
                if (rayDirection.x != 0.0 && rayDirection.y != 0.0 && rayDirection.z != 0.0)
                {
                    if (shape.z == -1 ) {
                        float2 uv = __uv / __size;
                        uv.y = 1.0 - uv.y;
                        color.xyz += background( uv, __size, hitPosition, rayDirection, &__funcData ).xyz * mask;
                        mask = float3(0);
                        rayDirection = float3(0);
                    }
            
            """
            
            materialFuncCode = ""
            
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
            }
            
            // --- Materials
            
            
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
            
            materialCode +=
            """
                }
                __outTexture.write(half4(color), __gid);
                __rayOriginTexture.write(half4(float4(rayOrigin, 0)), __gid);
                __rayDirectionTexture.write(half4(float4(rayDirection, 0)), __gid);
                __maskTexture.write(half4(float4(mask, 0)), __gid);
            }
            
            """
                        
            mapCode +=
            """
            
                return outShape;
            }
            
            """
            
            backgroundCode +=
            """
            
                return outColor;
            }
            
            """
            
            instance.code = headerCode + backgroundCode + mapCode + shadowCode + hitAndNormalsCode + aoCode + materialFuncCode + materialCode
        }
        
        codeBuilder.buildInstance(instance, name: "hitAndNormals", additionalNames: type == .SDF3D ? ["computeAO", "computeShadow", "computeMaterial"] : [])
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
        
        if let material = getFirstComponentOfType(stageItem.children, .Material3D) {
            // If this item has a material, generate the material function code and push it on the stack
            
            // Material Function Code
            
            materialFuncCode +=
            """
            
            void material\(materialIdCounter)( float3 incomingDirection, float3 hitPosition, float3 hitNormal, float4 light, float4 lightType,
            float4 lightColor, float shadow, float occlusion, thread struct MaterialOut *__materialOut, thread struct FuncData *__funcData )
            {
                constant float4 *__data = __funcData->__data;
                float4 __monitorOut = *__funcData->__monitorOut;
                float GlobalTime = __funcData->GlobalTime;
            
                float4 outColor = __materialOut->color;
                float3 outMask = __materialOut->mask;
                float3 outReflectionDir = float3(0);
                float outReflectionBlur = 0.;

            """
            
            dryRunComponent(material, instance.data.count, monitor)
            instance.collectProperties(material)
            if let globalCode = material.globalCode {
                headerCode += globalCode
            }
            if var code = material.code {
                code = code.replacingOccurrences(of: "&__", with: "__")
                materialFuncCode += code
            }

            materialFuncCode +=
            """
                
                __materialOut->color = outColor;
                __materialOut->mask = outMask;
                __materialOut->reflectionDir = outReflectionDir;
            }
            
            """
                    
            //print(materialFuncCode)
            
            materialCode +=
            """

            if (shape.z == \(materialIdCounter) )
            {
                material\(materialIdCounter)(incomingDirection, hitPosition, hitNormal, light, lightType, lightColor, shadow, occlusion, &__materialOut, &__funcData);
                rayDirection = __materialOut.reflectionDir;
                //rayOrigin = newPosition;//hitPosition + 0.025 * rayDirection;
                rayOrigin = newPosition + 0.025 * rayDirection;
                color.xyz = color.xyz + __materialOut.color.xyz * mask;
                color = clamp(color, 0.0, 1.0);
                mask *= __materialOut.mask;
            }

            """
            
            // Push it on the stack
            
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
