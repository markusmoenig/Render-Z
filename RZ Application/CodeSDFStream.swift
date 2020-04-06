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
    
    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]
    var idCounter           : Int = 0
    
    var materialIdCounter   : Int = 0
    var currentMaterialId   : Int = 0

    var hierarchy           : [StageItem] = []
    
    var globalsAddedFor     : [UUID] = []

    init()
    {
        
    }
    
    func reset()
    {
        ids = [:]
        idCounter = 0
        
        materialIdCounter = 0
        currentMaterialId = 0
        
        hierarchy = []
    }
    
    func openStream(_ type: CodeComponent.ComponentType,_ instance : CodeBuilderInstance,_ codeBuilder: CodeBuilder, camera: CodeComponent? = nil, groundComponent: CodeComponent? = nil, backgroundComponent: CodeComponent? = nil, thumbNail: Bool = false, idStart: Int = 0)
    {
        self.type = type
        self.instance = instance
        self.codeBuilder = codeBuilder
        
        globalsAddedFor = []
        
        idCounter = idStart
        materialIdCounter = idStart
        currentMaterialId = idStart
        
        instance.idStart = idStart
        
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
                dryRunComponent(camera, instance.data.count)
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
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float2 __size = float2( __outTexture.get_width(), __outTexture.get_height() );
                float2 __origin = float2(__gid.x, __gid.y);
                float2 __center = __size / 2;
                __origin = __translate(__origin, __center);

                float GlobalTime = __data[0].x;
                float GlobalSeed = __data[0].z;
                float outDistance = 10;
                float4 outShape = float4(100000, 0,0,0);
            
                struct FuncData __funcData;
                __funcData.GlobalTime = GlobalTime;
                __funcData.GlobalSeed = GlobalSeed;
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
                float GlobalTime = __funcData->GlobalTime;
                float GlobalSeed = __funcData->GlobalSeed;
                __CREATE_TEXTURE_DEFINITIONS__

                float outMask = 0;
                float outId = 0;
                        
            """
            
            if let background = backgroundComponent {
                dryRunComponent(background, instance.data.count)
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
                float GlobalTime = __funcData->GlobalTime;
                float GlobalSeed = __funcData->GlobalSeed;
                __CREATE_TEXTURE_DEFINITIONS__
            
            """
            
            hitAndNormalsCode =
                
            """
            kernel void hitAndNormals(
            texture2d<half, access::read_write>     __depthTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::read_write>     __normalTexture [[texture(2)]],
            texture2d<half, access::read_write>     __metaTexture [[texture(3)]],
            texture2d<half, access::read>           __rayOriginTexture [[texture(4)]],
            texture2d<half, access::read>           __rayDirectionTexture [[texture(5)]],
            __HITANDNORMALS_TEXTURE_HEADER_CODE__
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float2 __size = float2( __depthTexture.get_width(), __depthTexture.get_height() );

                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.read(__gid)).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.read(__gid)).xyz;

            """
            
            hitAndNormalsCode += codeBuilder.getFuncDataCode(instance, "HITANDNORMALS", 6)
            hitAndNormalsCode +=
                
            """
            
                float4 outShape = float4(__depthTexture.read(__gid));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalTexture.read(__gid)).xyz;
                float4 outMeta = float4(__metaTexture.read(__gid));
            
            """
            
            aoCode =
                
            """
            kernel void computeAO(
            texture2d<half, access::read_write>     __metaTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::read>           __depthInTexture [[texture(2)]],
            texture2d<half, access::read>           __normalInTexture [[texture(3)]],
            texture2d<half, access::read>           __rayOriginInTexture [[texture(4)]],
            texture2d<half, access::read>           __rayDirectionInTexture [[texture(5)]],
            __AO_TEXTURE_HEADER_CODE__
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float2 __size = float2( __metaTexture.get_width(), __metaTexture.get_height() );

                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginInTexture.read(__gid)).xyz;
                float3 rayDirection = float4(__rayDirectionInTexture.read(__gid)).xyz;
            
                float4 outShape = float4(__depthInTexture.read(__gid));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalInTexture.read(__gid)).xyz;
                float4 outMeta = float4(__metaTexture.read(__gid));
            
            """
            aoCode += codeBuilder.getFuncDataCode(instance, "AO", 6)
            
            shadowCode =
                
            """
            kernel void computeShadow(
            texture2d<half, access::read_write>     __metaTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::read>           __depthInTexture [[texture(2)]],
            texture2d<half, access::read>           __normalInTexture [[texture(3)]],
            texture2d<half, access::read>           __rayOriginTexture [[texture(4)]],
            texture2d<half, access::read>           __rayDirectionTexture [[texture(5)]],
            __SHADOW_TEXTURE_HEADER_CODE__
            constant float4                        *__lightData   [[ buffer(__SHADOW_AFTER_TEXTURE_OFFSET__) ]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float2 __size = float2( __metaTexture.get_width(), __metaTexture.get_height() );

                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.read(__gid)).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.read(__gid)).xyz;
            
                float4 outShape = float4(__depthInTexture.read(__gid));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalInTexture.read(__gid)).xyz;
                float4 outMeta = float4(__metaTexture.read(__gid));
            
            """
            shadowCode += codeBuilder.getFuncDataCode(instance, "SHADOW", 6)

            materialCode =
                
            """
            kernel void computeMaterial(
            texture2d<half, access::read_write>     __colorTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::read>           __depthInTexture [[texture(2)]],
            texture2d<half, access::read>           __normalInTexture [[texture(3)]],
            texture2d<half, access::read>           __metaInTexture [[texture(4)]],
            texture2d<half, access::read_write>     __rayOriginTexture [[texture(5)]],
            texture2d<half, access::read_write>     __rayDirectionTexture [[texture(6)]],
            texture2d<half, access::read_write>     __maskTexture [[texture(7)]],
            __MATERIAL_TEXTURE_HEADER_CODE__
            constant float4                        *__lightData   [[ buffer(__MATERIAL_AFTER_TEXTURE_OFFSET__) ]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float2 __size = float2( __colorTexture.get_width(), __colorTexture.get_height() );

                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.read(__gid)).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.read(__gid)).xyz;

                float4 shape = float4(__depthInTexture.read(__gid));
                float4 meta = float4(__metaInTexture.read(__gid));
                float3 mask = float4(__maskTexture.read(__gid)).xyz;
                float4 color = float4(__colorTexture.read(__gid));

                float3 incomingDirection = rayDirection;
                float3 hitPosition = rayOrigin + shape.y * rayDirection;

                float3 hitNormal = float4(__normalInTexture.read(__gid)).xyz;
                float occlusion = meta.x;
                float shadow = meta.y;

                float4 light = __lightData[0];
                float4 lightType = __lightData[1];
                float4 lightColor = __lightData[2];

                float3 directionToLight = float3(0);
                if (lightType.y == 0.0) {
                    directionToLight = normalize(__lightData[0].xyz);
                } else {
                    directionToLight = normalize(__lightData[0].xyz - hitPosition);
                }
            
                struct MaterialOut __materialOut;
                __materialOut.color = float4(0,0,0,1);
                __materialOut.mask = float3(0);
                        
            """
            materialCode += codeBuilder.getFuncDataCode(instance, "MATERIAL", 8)
                        
            if let rayMarch = findDefaultComponentForStageChildren(stageType: .ShapeStage, componentType: .UVMAP3D), thumbNail == false {
                dryRunComponent(rayMarch, instance.data.count)
                instance.collectProperties(rayMarch)
                if let globalCode = rayMarch.globalCode {
                    headerCode += globalCode
                }
                if let code = rayMarch.code {
                    hitAndNormalsCode += code
                }
            }
            
            materialCode +=
                
            """

                if (shape.z == -1 ) {
                    float2 uv = __uv / __size;
                    uv.y = 1.0 - uv.y;
                    color.xyz += background( uv, __size, hitPosition, rayDirection, __funcData ).xyz * mask;
                    //color = clamp(color, 0.0, 1.0);
                    mask = float3(0);
                    rayDirection = float3(0);
                }
            
            """
            
            materialFuncCode = ""
            
            if let ground = groundComponent {
                if ground.componentType == .Ground3D {
                    
                    dryRunComponent(ground, instance.data.count)
                    instance.collectProperties(ground)
                    if let globalCode = ground.globalCode {
                        headerCode += globalCode
                    }
                    if let code = ground.code {
                        hitAndNormalsCode += code
                    }
                    
                    ids[idCounter] = ([globalApp!.project.selected!.getStage(.ShapeStage).getChildren()[0]], ground)
                    instance.ids[idCounter] = ids[idCounter]

                    idCounter += 1
                }
            } else
            if let rayMarch = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .RayMarch3D), thumbNail == false {
                dryRunComponent(rayMarch, instance.data.count)
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
                    dryRunComponent(normal, instance.data.count)
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
                    dryRunComponent(ao, instance.data.count)
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
                    dryRunComponent(shadows, instance.data.count)
                    instance.collectProperties(shadows)
                    if let globalCode = shadows.globalCode {
                        headerCode += globalCode
                    }
                    if let code = shadows.code {
                        shadowCode +=
                        """
                        
                        {
                        float3 position = rayOrigin + (outShape.y - 0.025) * rayDirection;
                        float3 direction =  float3(0);
                        
                        float4 lightType = __lightData[1];
                        if (lightType.y == 0.0) {
                            direction = normalize(__lightData[0].xyz);
                        } else {
                            direction = normalize(__lightData[0].xyz - position);
                        }
                        
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
            else {
               // No Raymarch code, probably thumbnail generation, supply our own
               hitAndNormalsCode +=
               """
               
               float RJrRIP=0.001;
               int nRqCSQ=70;
               for( int noGouA=0; noGouA<nRqCSQ&&RJrRIP<maxDistance; noGouA+=1) {
                   float4 cKFBUP=sceneMap( rayOrigin+rayDirection*RJrRIP, __funcData) ;
                   if( cKFBUP.x<0.001*RJrRIP) {
                       outShape=cKFBUP;
                       outShape.y=RJrRIP;
                       break;
                   }
                   RJrRIP+=cKFBUP.x;
               }
                
               if (outShape.w != inShape.w) {
                   float3 position = rayOrigin + outShape.y * rayDirection;

                   float2 dXjBFB=float2( 1.000, -1.000) *0.5773*0.0005;
                   outNormal=dXjBFB.xyy*sceneMap( position+dXjBFB.xyy, __funcData) .x;
                   outNormal+=dXjBFB.yyx*sceneMap( position+dXjBFB.yyx, __funcData) .x;
                   outNormal+=dXjBFB.yxy*sceneMap( position+dXjBFB.yxy, __funcData) .x;
                   outNormal+=dXjBFB.xxx*sceneMap( position+dXjBFB.xxx, __funcData) .x;
                   outNormal=normalize( outNormal) ;
               }
               
               """
           }
        }
    }

    func closeStream()
    {
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
                __depthTexture.write(half4(outShape), __gid);
            }
            """
            
            aoCode +=
            """
            
                __metaTexture.write(half4(outMeta), __gid);
            }
            
            """
            
            shadowCode +=
            """
            
                __metaTexture.write(half4(outMeta), __gid);
            }
            
            """
            
            materialCode +=
            """

                __colorTexture.write(half4(color), __gid);
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
    
    func pushComponent(_ component: CodeComponent)
    {
        dryRunComponent(component, instance.data.count)
        instance.collectProperties(component, hierarchy)
        
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
                    float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    float3 position = __translate(__origin, __originalPosition);

            """
        }
        
        code += component.code!
        
        if type == .SDF3D
        {
            // Modifier 3D
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["modifier3D"] {
                    if list.count > 0 {
                        
                        code +=
                        """
                        {
                        float3 offsetFromCenter = __origin - __originalPosition;
                        float distance = outDistance;
                        
                        """

                        for modifier in list {
                            dryRunComponent(modifier, instance.data.count)
                            instance.collectProperties(modifier)

                            code += modifier.code!
                            if let globalCode = modifier.globalCode {
                                if globalsAddedFor.contains(modifier.uuid) == false {
                                    headerCode += globalCode
                                    globalsAddedFor.append(modifier.uuid)
                                }
                            }
                        }
                        
                        code +=
                        """
                        
                        }
                        """                        
                    }
                }
            }
        }


        if componentCounter > 0 {
            code +=
            """
            
                float4 shapeA = outShape;
                float4 shapeB = float4(outDistance, -1, \(currentMaterialId), \(idCounter));
            
            """
            
            if let subComponent = component.subComponent {
                dryRunComponent(subComponent, instance.data.count)
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
            instance.ids[idCounter] = ids[idCounter]
        }
        idCounter += 1
        componentCounter += 1
    }
    
    func pushStageItem(_ stageItem: StageItem)
    {
        hierarchy.append(stageItem)
        
        // Handle the domains
        
        if type == .SDF3D {
            if let list = stageItem.componentLists["domain3D"] {
                for domain in list {
                    dryRunComponent(domain, instance.data.count)
                    instance.collectProperties(domain)
                    
                    if let globalCode = domain.globalCode {
                        headerCode += globalCode
                    }
                    
                    mapCode +=
                    """
                    {
                    float3 position = __origin, outPosition = position;
                    
                    """
                    mapCode += domain.code!
                    mapCode +=
                    """
                    
                    __origin = outPosition;
                    }
                    """
                }
            }
        }
        
        // Handle the materials
        if let material = getFirstComponentOfType(stageItem.children, .Material3D) {
            // If this item has a material, generate the material function code and push it on the stack
            
            // Material Function Code
            
            materialFuncCode +=
            """
            
            void material\(materialIdCounter)(float2 uv, float3 incomingDirection, float3 hitPosition, float3 hitNormal, float3 directionToLight, float4 lightType,
            float4 lightColor, float shadow, float occlusion, thread struct MaterialOut *__materialOut, thread struct FuncData *__funcData)
            {
                constant float4 *__data = __funcData->__data;
                float GlobalTime = __funcData->GlobalTime;
                float GlobalSeed = __funcData->GlobalSeed;
                __CREATE_TEXTURE_DEFINITIONS__


                float4 outColor = __materialOut->color;
                float3 outMask = __materialOut->mask;
                float3 outReflectionDir = float3(0);
                float outReflectionBlur = 0.;
                float outReflectionDist = 0.;
            
            """
            
            // Get the patterns of the material if any
            var patterns : [CodeComponent] = []
            if let materialStageItem = getFirstStageItemOfComponentOfType(stageItem.children, .Material3D) {
                if materialStageItem.componentLists["patterns"] != nil {
                    patterns = materialStageItem.componentLists["patterns"]!
                }
            }
            
            dryRunComponent(material, instance.data.count, patternList: patterns)
            instance.collectProperties(material)
            if let globalCode = material.globalCode {
                headerCode += globalCode
            }
            if let code = material.code {
                materialFuncCode += code
            }

            materialFuncCode +=
            """
                
                __materialOut->color = outColor;
                __materialOut->mask = outMask;
                __materialOut->reflectionDir = outReflectionDir;
                __materialOut->reflectionDist = outReflectionDist;
            }
            
            """

            materialCode +=
            """
            else
            if (shape.z == \(materialIdCounter) )
            {
                float3 position = hitPosition; float3 normal = normal;
                float2 outUV = float2(0);
            
            """
            
            // Create the UVMapping for this material
            
            if let uvMap = getFirstComponentOfType(stageItem.children, .UVMAP3D) {
                dryRunComponent(uvMap, instance.data.count)
                instance.collectProperties(uvMap)
                if let globalCode = uvMap.globalCode {
                    headerCode += globalCode
                }
                if let code = uvMap.code {
                    materialCode += code
                }
            }
            
            materialCode +=
                
            """
            
                material\(materialIdCounter)(outUV, incomingDirection, hitPosition, hitNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);
                if (lightType.z == lightType.w) {
                    rayDirection = __materialOut.reflectionDir;
                    rayOrigin = hitPosition + 0.001 * rayDirection * shape.y + __materialOut.reflectionDist * rayDirection;
                }
                color.xyz = color.xyz + __materialOut.color.xyz * mask;
                color = clamp(color, 0.0, 1.0);
                if (lightType.z == lightType.w) {
                    mask *= __materialOut.mask;
                }
            }

            """
            
            // Push it on the stack
            
            instance.materialIdHierarchy.append(materialIdCounter)
            instance.materialIds[materialIdCounter] = stageItem
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
            instance.materialIdHierarchy.removeLast()
            if instance.materialIdHierarchy.count > 0 {
                currentMaterialId = instance.materialIdHierarchy.last!
            } else {
                currentMaterialId = instance.idStart
            }
        }
    }
    
    func insertTextureCode(_ instance: CodeBuilderInstance, startOffset: Int, id: String)
    {
        // Replace
        var code = ""
        
        for (index, t) in instance.textures.enumerated() {
            code += "texture2d<half, access::sample>     \(t.1) [[texture(\(index + startOffset))]], \n"
            //print(t.0, index + startOffset)
        }

        var changed = instance.code.replacingOccurrences(of: "__\(id)_TEXTURE_HEADER_CODE__", with: code)

        changed = changed.replacingOccurrences(of: "__\(id)_AFTER_TEXTURE_OFFSET__", with: String(startOffset + instance.textures.count))
        //print("__AFTER_TEXTURE_OFFSET__", startOffset + instance.textures.count)

        code = ""
        if instance.textures.count > 0 {
            code = "constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);\n"
        }
        for t in instance.textures{
            code += "__funcData->\(t.1) = \(t.1);\n"
        }
        
        changed = changed.replacingOccurrences(of: "__\(id)_TEXTURE_ASSIGNMENT_CODE__", with: code)
        instance.code = changed
    }
    
    func replaceTexturReferences(_ instance: CodeBuilderInstance)
    {
        for tR in instance.textureRep {
            insertTextureCode(instance, startOffset: tR.1, id: tR.0)
        }
        var code = instance.code
        
        // __FuncData structure and texture definitions
        var funcData = ""
        var textureDefs = ""//constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);\n"

        for t in instance.textures {
            funcData += "texture2d<half, access::sample> " + t.1 + ";"
            textureDefs += "texture2d<half, access::sample> " + t.1 + " = __funcData->\(t.1);\n"
        }

        code = code.replacingOccurrences(of: "__FUNCDATA_TEXTURE_LIST__", with: funcData)
        code = code.replacingOccurrences(of: "__CREATE_TEXTURE_DEFINITIONS__", with: textureDefs)
        instance.code = code
    }
}
