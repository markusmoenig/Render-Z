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
    var fogDensityCode      : String = ""
    
    var boundingBoxCode     : String = ""

    var materialFuncCode    : String = ""
    var materialCode        : String = ""
    
    var regionMapCode       : String = ""
    var regionCode          : String = ""
    
    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]
    var idCounter           : Int = 0
    
    var materialIdCounter   : Int = 0
    var currentMaterialId   : Int = 0

    var hierarchy           : [StageItem] = []
    
    var globalsAddedFor     : [UUID] = []
    
    var scene               : Scene? = nil

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
    
    func openStream(_ type: CodeComponent.ComponentType,_ instance : CodeBuilderInstance,_ codeBuilder: CodeBuilder, camera: CodeComponent? = nil, groundComponent: CodeComponent? = nil, backgroundComponent: CodeComponent? = nil, thumbNail: Bool = false, idStart: Int = 0, scene: Scene? = nil)
    {
        self.type = type
        self.instance = instance
        self.codeBuilder = codeBuilder
        self.scene = scene
        
        globalsAddedFor = []
        
        regionCode = ""
        regionMapCode = ""
        
        fogDensityCode = ""
        
        boundingBoxCode = "if (true) {\n"
        
        idCounter = idStart
        materialIdCounter = idStart
        currentMaterialId = idStart
        
        instance.idStart = idStart
        
        componentCounter = 0
        instance.properties = []
                
        if type == .SDF2D {
            headerCode = codeBuilder.getHeaderCode()
            
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

                if (rayDirection.x == INFINITY)
                    return;
            
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
            
                if (rayDirection.x == INFINITY)
                    return;
            
                float4 outShape = float4(__depthInTexture.read(__gid));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalInTexture.read(__gid)).xyz;
                float4 outMeta = float4(__metaTexture.read(__gid));
            
            """
            aoCode += codeBuilder.getFuncDataCode(instance, "AO", 6)
            
            shadowCode =
                
            """
            
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
            
            float2 __getParticipatingMedia(float3 position, float constFogDensity, thread struct FuncData *__funcData)
            {
                constant float4 *__data = __funcData->__data;
                float GlobalTime = __funcData->GlobalTime;
                float GlobalSeed = __funcData->GlobalSeed;
                __CREATE_TEXTURE_DEFINITIONS__
            
                float outDensity = 0, density = outDensity;
                __DENSITY_CODE__
            
                float sigmaS = constFogDensity + density;
               
                const float sigmaA = 0.0;
                const float sigmaE = max(0.000000001, sigmaA + sigmaS);
                
                return float2( sigmaS, sigmaE );
            }
            
            float __phaseFunction()
            {
                return 1.0/(4.0*3.14);
            }
            
            float __volumetricShadow(float3 from, float3 dir, float lengthToLight, float constFogDensity, thread struct FuncData *__funcData)
            {
                const float numStep = 16.0; // quality control. Bump to avoid shadow alisaing
                float shadow = 1.0;
                float sigmaS = 0.0;
                float sigmaE = 0.0;
                float dd = lengthToLight / numStep;
                for(float s=0.5; s<(numStep-0.1); s+=1.0)// start at 0.5 to sample at center of integral part
                {
                    float3 pos = from + dir * (s/(numStep));
                    float2 sigma = __getParticipatingMedia(pos, constFogDensity, __funcData);
                    shadow *= exp(-sigma.y * dd);
                }
                return shadow;
            }
            
            kernel void computeShadow(
            texture2d<half, access::read_write>     __metaTexture  [[texture(0)]],
            constant float4                        *__data   [[ buffer(1) ]],
            texture2d<half, access::read>           __depthInTexture [[texture(2)]],
            texture2d<half, access::read>           __normalInTexture [[texture(3)]],
            texture2d<half, access::read>           __rayOriginTexture [[texture(4)]],
            texture2d<half, access::read>           __rayDirectionTexture [[texture(5)]],
            texture2d<half, access::read_write>     __densityTexture [[texture(6)]],
            __SHADOW_TEXTURE_HEADER_CODE__
            constant float4                        *__lightData   [[ buffer(__SHADOW_AFTER_TEXTURE_OFFSET__) ]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float2 __size = float2( __metaTexture.get_width(), __metaTexture.get_height() );

                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.read(__gid)).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.read(__gid)).xyz;
            
                if (rayDirection.x == INFINITY)
                    return;
            
                float4 outShape = float4(__depthInTexture.read(__gid));
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalInTexture.read(__gid)).xyz;
                float4 outMeta = float4(__metaTexture.read(__gid));
            
            """
            shadowCode += codeBuilder.getFuncDataCode(instance, "SHADOW", 7)

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
            texture2d<half, access::read_write>     __densityTexture [[texture(8)]],
            __MATERIAL_TEXTURE_HEADER_CODE__
            constant float4                        *__lightData   [[ buffer(__MATERIAL_AFTER_TEXTURE_OFFSET__) ]],
            uint2 __gid                             [[thread_position_in_grid]])
            {
                float2 __size = float2( __colorTexture.get_width(), __colorTexture.get_height() );

                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.read(__gid)).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.read(__gid)).xyz;

                if (rayDirection.x == INFINITY)
                    return;
            
                float4 shape = float4(__depthInTexture.read(__gid));
                float4 meta = float4(__metaInTexture.read(__gid));
                float3 mask = float4(__maskTexture.read(__gid)).xyz;
                float4 color = float4(__colorTexture.read(__gid));

                float3 incomingDirection = rayDirection;
                float3 hitPosition = rayOrigin + shape.y * rayDirection;

                float3 hitNormal = float4(__normalInTexture.read(__gid)).xyz;
                float occlusion = meta.x;
                float shadow = meta.y;
            
            """
            
            materialCode +=
            """
            
                struct MaterialOut __materialOut;
                __materialOut.color = float4(0,0,0,1);
                __materialOut.mask = float3(0);
                        
            """
            materialCode += codeBuilder.getFuncDataCode(instance, "MATERIAL", 9)
            
            // Insert code for all lights and their references

            materialCode +=
            """
            
                float4 light = __lightData[0];
                float4 lightType = __lightData[1];
                float4 lightColor = __lightData[2];

                float3 directionToLight = float3(0);
                if (lightType.y == 0.0) {
                    directionToLight = normalize(__lightData[0].xyz);
                } else {
                    directionToLight = normalize(__lightData[0].xyz - hitPosition);
                        
            """
            
            if let scene = scene {
                let lightStage = scene.getStage(.LightStage)
                if lightStage.children3D.count > 0 {
                    materialCode +=
                    """
                    
                    int lightIndex = int(lightType.z) - 1;
                    
                    """
                }
                for (index,l) in lightStage.children3D.enumerated() {
                    if let light = l.components[l.defaultName] {
                        dryRunComponent(light, instance.data.count)
                        instance.collectProperties(light)
                        if let globalCode = light.globalCode {
                            headerCode += globalCode
                        }

                        var code =
                        """

                        float4 light\(index)(float3 lightPosition, float3 position, thread struct FuncData *__funcData )
                        {
                            float4 outColor = float4(0);

                            constant float4 *__data = __funcData->__data;
                            float GlobalTime = __funcData->GlobalTime;
                            float GlobalSeed = __funcData->GlobalSeed;
                            __CREATE_TEXTURE_DEFINITIONS__

                        """
                        
                        code += light.code!
                        
                        code +=
                        """

                            return outColor;
                        }
                        
                        """
                        
                        headerCode += code
                        
                        materialCode +=
                        """
                        
                        if (\(index) == lightIndex) {
                            lightColor = light\(index)(light.xyz, hitPosition, __funcData);
                        }
                        """
                    }
                }
            }
            
            materialCode +=
            """

            }
                        
            """
                        
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
                    rayDirection = float3(INFINITY);
                }
            
            """
            
            materialFuncCode = ""
            
            
            // Ground
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
                    
                    hitAndNormalsCode +=
                    """
                    
                    inShape = outShape;
                    maxDistance = outShape.y;
                    
                    """
                    
                    let groundItem : StageItem = globalApp!.project.selected!.getStage(.ShapeStage).getChildren()[0]
                    
                    ids[idCounter] = ([groundItem], ground)
                    instance.ids[idCounter] = ids[idCounter]
                    idCounter += 1
                    
                    regionMapCode +=
                    """

                    float4 regionMapCode(float3 position, thread struct FuncData *__funcData)
                    {
                        constant float4 *__data = __funcData->__data;
                        float GlobalTime = __funcData->GlobalTime;
                        float GlobalSeed = __funcData->GlobalSeed;
                        
                        __CREATE_TEXTURE_DEFINITIONS__

                        float outDistance = 1000000.0;
                        float height = 0;
                        float outHeight = height;
                        float4 region = float4(outDistance, 0, 0, 0);
                    
                    """
                    
                    for (index, region) in groundItem.children.enumerated() {
                        if region.componentLists["shapes2D"] == nil { continue }
                        
                        regionCode +=
                        """
                        
                        float region\(index)(float2 pos, thread struct FuncData *__funcData)
                        {
                            float outDistance = 1000000.0;
                            constant float4 *__data = __funcData->__data;

                        """
                        
                        var posX : Int = 0
                        var posY : Int = 0
                        var rotate : Int = 0

                        // Add the component to the region
                        for regionComponent in region.componentLists["shapes2D"]! {
                            dryRunComponent(regionComponent, instance.data.count)
                            instance.collectProperties(regionComponent, hierarchy)
                            
                            if let globalCode = regionComponent.globalCode {
                                headerCode += globalCode
                            }
                            
                            posX = instance.getTransformPropertyIndex(regionComponent, "_posX")
                            posY = instance.getTransformPropertyIndex(regionComponent, "_posY")
                            rotate = instance.getTransformPropertyIndex(regionComponent, "_rotate")

                            regionCode +=
                            """
                                {
                                    float oldDistance = outDistance;
                                    float2 position = __translate(pos, float2(__data[\(posX)].x, -__data[\(posY)].x));
                                    position = rotate( position, radians(360 - __data[\(rotate)].x) );

                            """
                            
                            regionCode += regionComponent.code!
                            
                            regionCode +=
                            """
                            
                                    outDistance = min(oldDistance, outDistance); // TODO: Future support custom booleans
                                }
                            
                            """
                        }
                        
                        regionCode +=
                        """
                        
                            return outDistance;
                        }
                        
                        """
                        
                        if let regionProfile = region.components[region.defaultName] {
                            dryRunComponent(regionProfile, instance.data.count)
                            instance.collectProperties(regionProfile, hierarchy)
                            
                            if let globalCode = regionProfile.globalCode {
                                headerCode += globalCode
                            }
                            
                            regionMapCode += regionProfile.code!.replacingOccurrences(of: "regionDistance", with: "region\(index)")
                            regionMapCode +=
                            """
                            
                            if (outDistance < region.x) {
                                region = float4(outDistance, 0, 0, 0);
                            }
                            height = outHeight;

                            
                            """
                        }
                    }
                    
                    regionMapCode +=
                    """
                    
                        return region;
                    }
                    
                    """
                    
                    if regionCode.count > 0 {
                        headerCode += regionCode
                        headerCode += regionMapCode
                        
                        if let rayMarch = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .RayMarch3D), thumbNail == false
                        {
                            dryRunComponent(rayMarch, instance.data.count)
                            instance.collectProperties(rayMarch)
                            if let globalCode = rayMarch.globalCode {
                                headerCode += globalCode
                            }
                            if let code = rayMarch.code {
                                hitAndNormalsCode += code.replacingOccurrences(of: "sceneMap", with: "regionMapCode")
                            }
                        }
                        hitAndNormalsCode +=
                        """
                        
                        if (inShape.y != outShape.y) {

                        """
                        
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
                                hitAndNormalsCode += code.replacingOccurrences(of: "sceneMap", with: "regionMapCode")
                                hitAndNormalsCode +=
                                """
                                
                                }
                                
                                """
                            }
                        }
                        
                        hitAndNormalsCode +=
                        """
                        
                        }
                        
                        """
                    }
                }
            } else
            if let rayMarch = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .RayMarch3D), thumbNail == false {
                
                hitAndNormalsCode +=
                """
                
                __BOUNDING_BOX_CODE__

                """
                
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
                
                }
                
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
                        
                        var softShadowCode =
                        """
                        float __calcSoftshadow( float3 ro, float3 rd, thread struct FuncData *__funcData)
                        {
                            float outShadow = 1.;
                            float3 position = ro;
                            float3 direction = rd;

                        """
                        
                        softShadowCode += code
                        softShadowCode +=
                        """

                            return outShadow;
                        }

                        """
                        
                        shadowCode = softShadowCode + shadowCode
                        
                        shadowCode +=
                        """
                        
                        {
                        float3 position = rayOrigin + (outShape.y - 0.025) * rayDirection;
                        float3 direction =  float3(0);
                        
                        float4 lightType = __lightData[1];
                        float3 lightColor = __lightData[2].xyz;

                        if (lightType.y == 0.0) {
                            direction = normalize(__lightData[0].xyz);
                        } else {
                            direction = normalize(__lightData[0].xyz - position);
                        }
                        
                        float outShadow = 1.;
                        """
                        shadowCode += code
                        
                        var hasFogOrClouds = false
                        
                        if let scene = scene {
                            let preStage = scene.getStage(.PreStage)
                            for c in preStage.children3D {
                                if let list = c.componentLists["fog"] {
                                    if list.count > 0 {
                                        hasFogOrClouds = true
                                    }
                                }
                                if let list = c.componentLists["clouds"] {
                                    if list.count > 0 {
                                        hasFogOrClouds = true
                                    }
                                }
                            }
                        }
                        
                        var maxDistanceCode = "50.0"
                        if let index = instance.addGlobalVariable(name: "World.worldMaxFogDistance") {
                            maxDistanceCode = "__data[\(index)].x"
                        }
                        
                        shadowCode +=
                        """
                        
                        outMeta.y = min(outMeta.y, outShadow);
                        
                        // Fog Density Code
                        
                        float4 densityIn = float4(__densityTexture.read(__gid));
                        float constFogDensity = __lightData[0].w;
                        if (constFogDensity > 0.0000 || \(String(hasFogOrClouds))) {
                            float transmittance = 1.0;
                            float3 scatteredLight = float3(0.0, 0.0, 0.0);
                                                                                
                            //if (inShape.z == -1) {
                            //    maxDistance = \(maxDistanceCode);
                            //}
                            
                            maxDistance = min(maxDistance, \(maxDistanceCode));
                            
                            float t = random(__funcData) * maxDistance;
                            float tt = 0.0;

                            for( int i=0; i < 5 && t < maxDistance; i++ )
                            {
                                float3 pos = rayOrigin + rayDirection * t;
                                
                                float2 sigma = __getParticipatingMedia( pos, constFogDensity, __funcData);
                                
                                const float sigmaS = sigma.x;
                                const float sigmaE = sigma.y;
                            
                                float3 lightDirection; float lengthToLight;
                                if (lightType.y == 0.0) {
                                    lightDirection = normalize(__lightData[0].xyz);
                                    lengthToLight = 0.5;
                                } else {
                                    lightDirection = normalize(__lightData[0].xyz - pos);
                                    lengthToLight = length(lightDirection);
                        """
                        
                        // Insert fog density code
                        if let scene = scene {
                            let preStage = scene.getStage(.PreStage)
                            for c in preStage.children3D {
                                if let list = c.componentLists["fog"] {
                                    for fog in list {
                                        dryRunComponent(fog, instance.data.count)
                                        instance.collectProperties(fog)
                                        if let globalCode = fog.globalCode {
                                            headerCode += globalCode
                                        }
                                        if let code = fog.code {
                                            fogDensityCode += code
                                            fogDensityCode +=
                                            """
                                            
                                            density += outDensity;
                                            outDensity = 0;
                                            
                                            """
                                            
                                            //print( fogDensityCode)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Insert Light code for density sampling
                        if let scene = scene {
                            let lightStage = scene.getStage(.LightStage)
                            if lightStage.children3D.count > 0 {
                                shadowCode +=
                                """
                                
                                int lightIndex = int(lightType.z) - 1;
                                
                                """
                            }
                            for (index,l) in lightStage.children3D.enumerated() {
                                if l.components[l.defaultName] != nil {
                                    shadowCode +=
                                    """
                                    
                                    if (\(index) == lightIndex) {
                                        lightColor = light\(index)(__lightData[0].xyz, pos, __funcData).xyz;
                                    }
                                    
                                    """
                                }
                            }
                        }
                        
                        shadowCode +=
                        """

                                }
                                
                                float3 S = lightColor * sigmaS * __phaseFunction() * __volumetricShadow(pos, lightDirection, lengthToLight, constFogDensity, __funcData) * __calcSoftshadow(pos, lightDirection, __funcData);
                                float3 Sint = (S - S * exp(-sigmaE * tt)) / sigmaE;
                                scatteredLight += transmittance * Sint;

                                transmittance *= exp(-sigmaE * tt);
                                                    
                                tt += random(__funcData);
                                t += tt;
                            }
                        
                            // Cloud Density Code
                        
                            if (lightType.y == 0.0) {

                                float3 lightDirection = normalize(__lightData[0].xyz);
                                float lengthToLight = 0.5;
                        
                        """
                        
                        // Insert cloud density code
                        if let scene = scene {
                            let preStage = scene.getStage(.PreStage)
                            for c in preStage.children3D {
                                if let list = c.componentLists["clouds"] {
                                    for (index,cloud) in list.enumerated() {
                                        
                                        let pOffset = instance.properties.count - 1
                                        
                                        dryRunComponent(cloud, instance.data.count)
                                        instance.collectProperties(cloud)
                                        if let globalCode = cloud.globalCode {
                                            headerCode += globalCode
                                        }
                                        if let code = cloud.code {
                                            
                                            headerCode +=
                                            """
                                            
                                            float2 __cloudMap\(index)(float3 position, thread struct FuncData *__funcData)
                                            {
                                                constant float4 *__data = __funcData->__data;
                                                float GlobalTime = __funcData->GlobalTime;
                                                float GlobalSeed = __funcData->GlobalSeed;
                                                __CREATE_TEXTURE_DEFINITIONS__
                                            
                                                float outDensity = 0;
                                            
                                            """
                                            
                                            headerCode += code
                                            headerCode +=
                                            """
                                                                                                                                    
                                                float sigmaS = outDensity;
                                               
                                                const float sigmaA = 0.0;
                                                const float sigmaE = max(0.000000001, sigmaA + sigmaS);
                                                
                                                return float2( sigmaS, sigmaE );
                                            }
                                            
                                            float __cloudMapShadow\(index)(float3 from, float3 dir, thread struct FuncData *__funcData)
                                            {
                                                const float numStep = 16.0; // quality control. Bump to avoid shadow alisaing
                                                float shadow = 1.0;
                                                float sigmaS = 0.0;
                                                float sigmaE = 0.0;
                                                float dd = 10.;
                                                float d = dd * 0.5;
                                                for(int s=0; s < 6; s += 1)
                                                {
                                                    float3 pos = from + dir * d;
                                                    float2 sigma = __cloudMap\(index)(pos, __funcData);
                                                    shadow *= exp(-sigma.y * dd);
                                                    dd *= 1.3;
                                                    d += dd;
                                                }
                                                return shadow;
                                            }
                                            
                                            """
                                                                                        
                                            var layerHeight = "100.0"
                                            var layerDepth = "20.0"
                                            var bottomColor = "float3(0.7)"
                                            var topColor = "float3(0.3)"

                                            for i in pOffset..<instance.properties.count {
                                                let pp = instance.properties[i]
                                                if let prop = pp.0 {
                                                    if prop.name == "height" {
                                                        layerHeight = "__data[\(pp.3)].x"
                                                    } else
                                                    if prop.name == "depth" {
                                                        layerDepth = "__data[\(pp.3)].x"
                                                    } else
                                                    if prop.name == "bottomColor" {
                                                        bottomColor = "__data[\(pp.3)].xyz"
                                                    } else
                                                    if prop.name == "topColor" {
                                                        topColor = "__data[\(pp.3)].xyz"
                                                    }
                                                }
                                            }
                                            
                                            shadowCode +=
                                            """
                                            
                                                    //if (inShape.z == -1)
                                                    {
                                                    float height = \(layerHeight);
                                                    float layerSize = \(layerDepth);
                                                    
                                                    float3 ro = rayOrigin;
                                                    ro.y = sqrt(EARTH_RADIUS*EARTH_RADIUS-dot(ro.xz,ro.xz));

                                                    float start = __intersectCloudSphere( rayDirection, height );
                                                    float end  = __intersectCloudSphere( rayDirection, height + layerSize );
                                            
                                                    if (inShape.z != -1) {
                                                        end = min( inShape.y, end );
                                                    }
                                            
                                                    float t = start + random(__funcData) * (layerSize / 2.);
                                                    float tt = 0.0;
                                            
                                                    float sundotrd = dot( rayDirection, -lightDirection);
                                                    float scattering =  mix( __HenyeyGreenstein(sundotrd, CLOUDS_FORWARD_SCATTERING_G),
                                                        __HenyeyGreenstein(sundotrd, CLOUDS_BACKWARD_SCATTERING_G), CLOUDS_SCATTERING_LERP );
                                            
                                                    for( int i=0; i < 5 && t < end; i++ )
                                                    {
                                                        float3 pos = ro + rayDirection * t;
                                                        
                                                        float norY = clamp( (length(pos) - (EARTH_RADIUS + height)) * (1./(layerSize)), 0., 1.);
                                                        float3 ambientLight = mix( \(bottomColor), \(topColor), norY );

                                                        float2 sigma = __cloudMap\(index)( pos, __funcData);
                                                        
                                                        const float sigmaS = sigma.x;
                                                        const float sigmaE = sigma.y;
                                                    
                                                        if (sigmaS > 0.0) {
                                                        float3 S = (ambientLight + lightColor  * (__phaseFunction() * scattering * __cloudMapShadow\(index)(pos, lightDirection, __funcData))) * sigmaS;
                                                        float3 Sint = (S - S * exp(-sigmaE * tt)) / sigmaE;
                                                        scatteredLight += transmittance * Sint;

                                                        transmittance *= exp(-sigmaE * tt);
                                                        }
                                                        tt += (layerSize / 5.) * random(__funcData);
                                                        t += tt;
                                                    }
                                                    }
                                            """
                                        }
                                    }
                                }
                            }
                        }
                        
                        shadowCode +=
                        """
                            }
                        
                            // Finished
                        
                            float4 scatTrans = float4(scatteredLight, transmittance);
                            scatTrans.xyz += densityIn.xyz;//(scatTrans.xyz + densityIn.xyz) / 2;
                            scatTrans.w *= densityIn.w;//max(scatTrans.w, densityIn.w);//(scatTrans.w + densityIn.w) / 2;
                            
                            __densityTexture.write(half4(scatTrans), __gid);
                        }
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
            
            hitAndNormalsCode = hitAndNormalsCode.replacingOccurrences(of: "__BOUNDING_BOX_CODE__", with: boundingBoxCode)
            
            aoCode +=
            """
            
                __metaTexture.write(half4(outMeta), __gid);
            }
            
            """
            
            shadowCode = shadowCode.replacingOccurrences(of: "__DENSITY_CODE__", with: fogDensityCode)
            shadowCode +=
            """
            
                __metaTexture.write(half4(outMeta), __gid);
            }
            
            """
            
            materialCode +=
            """
            
                float4 density = float4(__densityTexture.read(__gid));
                color.xyz = color.xyz * density.w + density.xyz;
                mask.xyz = mask.xyz * density.w;

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
            let rotate = instance.getTransformPropertyIndex(component, "_rotate")

            code +=
            """
                {
                    float2 position = __translate(__origin, float2(__data[\(posX)].x, -__data[\(posY)].x));
                    position = rotate( position, radians(360 - __data[\(rotate)].x) );

            """
        } else
        if type == .SDF3D
        {
            let posX = instance.getTransformPropertyIndex(component, "_posX")
            let posY = instance.getTransformPropertyIndex(component, "_posY")
            let posZ = instance.getTransformPropertyIndex(component, "_posZ")
            
            let rotateX = instance.getTransformPropertyIndex(component, "_rotateX")
            let rotateY = instance.getTransformPropertyIndex(component, "_rotateY")
            let rotateZ = instance.getTransformPropertyIndex(component, "_rotateZ")

            code +=
            """
                {
                    float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    float3 position = __translate(__origin, __originalPosition);
            
                    position.yz = rotate( position.yz, radians(__data[\(rotateX)].x) );
                    position.xz = rotate( position.xz, radians(__data[\(rotateY)].x) );
                    position.xy = rotate( position.xy, radians(__data[\(rotateZ)].x) );

            """
            
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["domain3D"] {
                    for domain in list {
                        dryRunComponent(domain, instance.data.count)
                        instance.collectProperties(domain)
                        
                        if let globalCode = domain.globalCode {
                            headerCode += globalCode
                        }
                        
                        code +=
                        """
                        {
                        float3 outPosition = position;
                        
                        """
                        code += domain.code!
                        code +=
                        """
                        
                        position = outPosition;
                        }
                        """
                    }
                }
            }
        }
        
        code += component.code!
        
        if type == .SDF3D
        {
            // Modifier 3D
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["modifier3D"] {
                    if list.count > 0 {
                        
                        let rotateX = instance.getTransformPropertyIndex(component, "_rotateX")
                        let rotateY = instance.getTransformPropertyIndex(component, "_rotateY")
                        let rotateZ = instance.getTransformPropertyIndex(component, "_rotateZ")
                        
                        code +=
                        """
                        {
                        float3 offsetFromCenter = __origin - __originalPosition;
                        offsetFromCenter.yz = rotate( offsetFromCenter.yz, radians(__data[\(rotateX)].x) );
                        offsetFromCenter.xz = rotate( offsetFromCenter.xz, radians(__data[\(rotateY)].x) );
                        offsetFromCenter.xy = rotate( offsetFromCenter.xy, radians(__data[\(rotateZ)].x) );
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
                            
                            code +=
                            """
                            
                            distance = outDistance;

                            """
                        }
                        
                        code +=
                        """
                        
                        }
                        """                        
                    }
                }
            }
        }


        code +=
        """
        
            float4 shapeA = outShape;
            float4 shapeB = float4(outDistance, -1, \(currentMaterialId), \(idCounter));
        
        """
        
        if let subComponent = component.subComponent {
            dryRunComponent(subComponent, instance.data.count)
            instance.collectProperties(subComponent)
            code += subComponent.code!
        } else {
            // Thumbnails
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
            
            /*
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
            }*/
        }
        
        // Handle the materials
        if let material = getFirstComponentOfType(stageItem.children, .Material3D) {
            // If this item has a material, generate the material function code and push it on the stack
            
            // Material Function Code
            
            materialFuncCode +=
            """
            
            void material\(materialIdCounter)(float3 incomingDirection, float3 hitPosition, float3 hitNormal, float3 directionToLight, float4 lightType,
            float4 lightColor, float shadow, float occlusion, thread struct MaterialOut *__materialOut, thread struct FuncData *__funcData)
            {
                float2 uv = float2(0);
                constant float4 *__data = __funcData->__data;
                float GlobalTime = __funcData->GlobalTime;
                float GlobalSeed = __funcData->GlobalSeed;
                __CREATE_TEXTURE_DEFINITIONS__


                float4 outColor = __materialOut->color;
                float3 outMask = __materialOut->mask;
                float3 outReflectionDir = float3(0);
                float outReflectionBlur = 0.;
                float outReflectionDist = 0.;
            
                float3 localPosition = hitPosition;
            
            """
            
            if let transform = stageItem.components[stageItem.defaultName], transform.componentType == .Transform3D {
                
                dryRunComponent(transform, instance.data.count)
                instance.collectProperties(transform)
                
                let posX = instance.getTransformPropertyIndex(transform, "_posX")
                let posY = instance.getTransformPropertyIndex(transform, "_posY")
                let posZ = instance.getTransformPropertyIndex(transform, "_posZ")
                
                let rotateX = instance.getTransformPropertyIndex(transform, "_rotateX")
                let rotateY = instance.getTransformPropertyIndex(transform, "_rotateY")
                let rotateZ = instance.getTransformPropertyIndex(transform, "_rotateZ")
                
                materialFuncCode +=
                """
                
                    float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    localPosition = __translate(hitPosition, __originalPosition);
                
                    localPosition.yz = rotate( localPosition.yz, radians(__data[\(rotateX)].x) );
                    localPosition.xz = rotate( localPosition.xz, radians(__data[\(rotateY)].x) );
                    localPosition.xy = rotate( localPosition.xy, radians(__data[\(rotateZ)].x) );
                
                """
                
                if hierarchy.count == 1 {
                    let bBox = instance.getTransformPropertyIndex(transform, "_bbox")

                    // Bounding Box code
                    boundingBoxCode =
                    """
                    
                        float3 __bbPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    
                        float2 bDistance = sphereIntersect(rayOrigin, rayDirection, __bbPosition, __data[\(bBox)].x);
                        if (bDistance.y >= 0.0) {
                    
                        //if (bDistance.x >= 0.0)
                            //rayOrigin = rayOrigin + bDistance.x * rayDirection;
                        
                    """
                }
            }
                
            // Create the UVMapping for this material
            
            if let uvMap = getFirstComponentOfType(stageItem.children, .UVMAP3D) {
                
                materialFuncCode +=
                """
                
                {
                float3 position = localPosition; float3 normal = hitNormal;
                float2 outUV = float2(0);
                
                """
                    
                dryRunComponent(uvMap, instance.data.count)
                instance.collectProperties(uvMap)
                if let globalCode = uvMap.globalCode {
                    headerCode += globalCode
                }
                if let code = uvMap.code {
                    materialFuncCode += code
                }
                
                materialFuncCode +=
                """
                
                    uv = outUV;
                    }
                
                """
            }
            
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
            """
            
            materialCode +=
                
            """
            
                material\(materialIdCounter)(incomingDirection, hitPosition, hitNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);
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
