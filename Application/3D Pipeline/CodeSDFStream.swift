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
    
    var terrainMapCode      : String = ""
    var terrainCode         : String = ""
        
    var ids                 : [Int:([StageItem], CodeComponent?)] = [:]
    var idCounter           : Int = 0
    
    var materialIdCounter   : Int = 0
    var currentMaterialId   : Int = 0

    var hierarchy           : [StageItem] = []
    
    var globalsAddedFor     : [UUID] = []
    
    var scene               : Scene? = nil
    var isGroundComponent   : CodeComponent? = nil
    
    var terrainObjects      : [StageItem] = []
    
    var pointBuilderCode    : String = ""

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
        isGroundComponent = groundComponent
        
        terrainObjects = []
        globalsAddedFor = []
        
        terrainCode = ""
        terrainMapCode = ""
        
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
                float2 __originBackupForScaling = __origin;
                float2 __center = __size / 2;
                __origin = __translate(__origin, __center);

                float GlobalTime = __data[0].x;
                float GlobalSeed = __data[0].z;
                float outDistance = 10;
                float4 outShape = float4(100000, 0,0,0);
                float bump = 0;
                float scale = 1;
            
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
                float3 __originBackupForScaling = __origin;
                float3 __objectPosition = float3(0);
                float outDistance = 10;
                float bump = 0;
                float scale = 1;
            
                float4 outShape = __funcData->inShape;
                outShape.x = length(__origin - __funcData->inHitPoint) + 0.5;
            
                //float4 outShape = float4(1000, 1000, -1, -1);

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
            texture2d<int, access::sample>          __terrainTexture [[texture(6)]],
            __HITANDNORMALS_TEXTURE_HEADER_CODE__
            uint2 __gid                             [[thread_position_in_grid]])
            {
                if (__gid.y < int(__data[0].y) || __gid.y >= int(__data[0].y) + 50)
                    return;
            
                float2 __size = float2( __depthTexture.get_width(), __depthTexture.get_height() );
            
                float2 __uv = float2(__gid.x, __gid.y);
                float3 rayOrigin = float4(__rayOriginTexture.read(__gid)).xyz;
                float3 rayDirection = float4(__rayDirectionTexture.read(__gid)).xyz;

                if (rayDirection.x == INFINITY)
                    return;
            
            """
            
            hitAndNormalsCode += codeBuilder.getFuncDataCode(instance, "HITANDNORMALS", 7)
            hitAndNormalsCode +=
                
            """
            
                __funcData->terrainTexture = &__terrainTexture;
            
                float4 outShape = float4(__depthTexture.read(__gid));

                __funcData->inShape = outShape;
                __funcData->inHitPoint = rayOrigin + rayDirection * outShape.y;
            
                float maxDistance = outShape.y;
                float4 inShape = outShape;
                float3 outNormal = float4(__normalTexture.read(__gid)).xyz;
                float4 outMeta = float4(__metaTexture.read(__gid));
                __funcData->hash = outMeta.z;
            
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
                if (__gid.y < int(__data[0].y) || __gid.y >= int(__data[0].y) + 50)
                    return;

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
            aoCode +=
            """
            
            __funcData->hash = outMeta.z;
            
            __funcData->inShape = outShape;
            __funcData->inHitPoint = rayOrigin + rayDirection * outShape.y;
            
            """
            
            shadowCode =
                
            """
            
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
                if (__gid.y < int(__data[0].y) || __gid.y >= int(__data[0].y) + 50)
                    return;
            
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
            shadowCode +=
            """
            
            __funcData->hash = outMeta.z;
            
            """

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
                if (__gid.y < int(__data[0].y) || __gid.y >= int(__data[0].y) + 50)
                    return;
            
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
            
                __funcData->hash = meta.z;
                __funcData->distance2D = abs(meta.w);
            
                __funcData->inShape = shape;
                __funcData->inHitPoint = rayOrigin + rayDirection * shape.y;
            
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

                if (shape.z < 0.0 ) {
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
                    
                    let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                    
                    if shapeStage.terrain == nil {
                        
                        // No terrain, analytical
                        
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
                    } else {
                        
                        let terrain = shapeStage.terrain!
                        
                        terrainMapCode +=
                        """
                        
                        float __hash12(float2 p)
                        {
                            float3 p3  = fract(float3(p.xyx) * .1031);
                            p3 += dot(p3, p3.yzx + 33.33);
                            return fract((p3.x + p3.y) * p3.z);
                        }

                        float4 terrainMapCode(float3 position, thread struct FuncData *__funcData)
                        {
                            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

                            constant float4 *__data = __funcData->__data;
                            float GlobalTime = __funcData->GlobalTime;
                            float GlobalSeed = __funcData->GlobalSeed;
                            float materialId = 0.0;

                            float outDistance = 1000000.0;
                            float localHeight = 0.;
                            float bump = 0;
                            float localDistance;
                            float4 instObject = float4(1000, 1000, -1, -1);
                        
                            bool layerMaterial = false;
                        
                            float height = __interpolateHeightTexture(*__funcData->terrainTexture, (position.xz + \(terrain.terrainSize) / \(terrain.terrainScale) / 2.0) / \(terrain.terrainSize) * \(terrain.terrainScale)) * \(terrain.terrainHeightScale);
                        
                        """
                        
                        // Insert the noise layers
                        
                        let materialId = terrain.materials.count
                        for (index, layer) in terrain.layers.reversed().enumerated() {
                            
                            let layerMaterialId : Int = materialId + index

                            if layer.shapes.isEmpty == false {
                                                                
                                var posX : Int = 0
                                var posY : Int = 0
                                var rotate : Int = 0

                                terrainMapCode +=
                                """
                                
                                    localHeight = 0.;

                                    {
                                        outDistance = 1000000.0;
                                        float oldDistance = outDistance;
                                        float3 position3 = position;
                                        float2 position;


                                """
                                
                                // Add the shapes
                                for shapeComponent in layer.shapes {
                                    dryRunComponent(shapeComponent, instance.data.count)
                                    instance.collectProperties(shapeComponent)
                                    
                                    if let globalCode = shapeComponent.globalCode {
                                        headerCode += globalCode
                                    }
                                    
                                    posX = instance.getTransformPropertyIndex(shapeComponent, "_posX")
                                    posY = instance.getTransformPropertyIndex(shapeComponent, "_posY")
                                    rotate = instance.getTransformPropertyIndex(shapeComponent, "_rotate")
                                    
                                    terrainMapCode +=
                                    """
                                            
                                            position = __translate(position3.xz, float2(__data[\(posX)].x, -__data[\(posY)].x));
                                            position = rotate( position, radians(360 - __data[\(rotate)].x) );

                                    """
                                    
                                    terrainMapCode += shapeComponent.code!
                                    terrainMapCode +=
                                    """

                                        localDistance = outDistance;
                                        outDistance = min( outDistance, oldDistance );
                                        oldDistance = outDistance;
                                    
                                    """
                                }

                                terrainMapCode +=
                                """
                                
                                    }
                                    
                                    if (localDistance <= 0.0)
                                    {
                                        if (\(layer.shapeFactor) < 0.0)
                                            localHeight += max(\(layer.shapesBlendType == .FactorTimesShape ? "abs(outDistance) * " : "") \(layer.shapeFactor), \(layer.shapeFactor));
                                        else
                                            localHeight += min(\(layer.shapesBlendType == .FactorTimesShape ? "abs(outDistance) * " : "") \(layer.shapeFactor), \(layer.shapeFactor));
                                
                                """
                                
                                if layer.material != nil && layer.blendType != .Max {
                                    terrainMapCode +=
                                    """
                                    
                                    materialId = \(layerMaterialId);
                                    __BUMP_CODE_\(layerMaterialId)__
                                    layerMaterial = true;
                                    
                                    """
                                    
                                } else {
                                    terrainMapCode +=
                                    """
                                    
                                    //materialId = 0.0;
                                    
                                    """
                                }
                                
                                // Instantiate object in this area
                                if let object = layer.object {
                                    terrainObjects.append(object)
                                                                                
                                    terrainMapCode +=
                                    """
                                               
                                    float3 pos = position - float3(__data[\(posX)].x - 50., height, -__data[\(posY)].x - 50.);
                                    __funcData->hash = __hash12(floor(pos.xz / \(layer.objectSpacing)));
                                    if (__funcData->hash <= \(layer.objectVisible)) {
                                        pos.xz = fmod(pos.xz, \(layer.objectSpacing)) - \(layer.objectSpacing) / 2.0;
                                        pos.xz += \(layer.objectRandom) * random(__funcData) / 5.0;
                                        instObject = sceneMap\(terrainObjects.count)(pos, __funcData);
                                    }
                                        
                                    """
                                }
                            }
                            
                            let component = CodeComponent(.Dummy)
                            let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                            ctx.reset(globalApp!.developerEditor.codeEditor.rect.width, instance.data.count, patternList: [])
                            ctx.cComponent = component
                            component.globalCode = ""
                            
                            if layer.noiseType != .None {
                                if layer.blendType == .Add || layer.blendType == .Max {
                                    terrainMapCode +=
                                    """
                                    
                                    localHeight +=
                                    """
                                } else
                                if layer.blendType == .Subtract {
                                    terrainMapCode +=
                                    """
                                    
                                    localHeight +=
                                    """
                                }
                            }
                            
                            if layer.noiseType == .TwoD {

                                let layerName = generateNoise2DFunction(ctx, layer.noise2DFragment)
                                terrainMapCode +=
                                """
                                 \(layerName)(position.xz, __funcData);
                                """
                            } else
                            if layer.noiseType == .ThreeD {

                                let layerName = generateNoise3DFunction(ctx, layer.noise3DFragment)
                                terrainMapCode +=
                                """
                                 \(layerName)(position + float3(0,localHeight, 0), __funcData);
                                """
                            } else
                            if layer.noiseType == .Image {

                                let layerName = generateImageFunction(ctx, layer.imageFragment)
                                terrainMapCode +=
                                """
                                 \(layerName)(position.xz, __funcData).x;
                                """
                            }
                            
                            if layer.noiseType != .None && layer.shapes.isEmpty == false {
                                terrainMapCode +=
                                """
                                
                                localHeight = localHeight * smoothstep(0.0, -0.20, outDistance);

                                """
                            }
                            
                            if layer.blendType == .Max {
                                terrainMapCode +=
                                """
                                
                                //height = max(height, localHeight - 0.5);
                                if (height + localHeight - 0.5 > height)
                                {
                                    height = height + localHeight - 0.5;
                                    \(layer.material != nil ? " materialId = \(layerMaterialId);" : "")
                                }
                                
                                """
                                
                            } else {
                                
                                if layer.blendType == .Subtract {
                                    terrainMapCode +=
                                    """
                                    
                                    height -= localHeight;
                                    
                                    """
                                } else {
                                    terrainMapCode +=
                                    """
                                    
                                    height += localHeight;
                                    
                                    """
                                }
                            }
                            
                            headerCode += component.globalCode!
                            instance.collectProperties(component)
                            
                            if layer.shapes.isEmpty == false {
                                terrainMapCode +=
                                """
                                
                                    }

                                """
                            }
                        }
                        
                        terrainMapCode +=
                        """
                        
                        if (layerMaterial == false)
                        {
                            float localHeight = 0;
                            __BUMP_CODE_0__
                            height += localHeight;
                        }
                        
                        float4 rc = float4(position.y - height, 0, materialId, 0);
                        if (instObject.x < rc.x)
                            rc = instObject;
                        
                        """
                                                                    
                        terrainMapCode +=
                        """
                        
                            return rc;
                        }
                         
                        """
                        
                        //print(terrainMapCode)
                                                
                        if let rayMarch = terrain.rayMarcher {
                            dryRunComponent(rayMarch, instance.data.count)
                            instance.collectProperties(rayMarch)
                            if let globalCode = rayMarch.globalCode {
                                headerCode += globalCode
                            }
                            if let code = rayMarch.code {
                                hitAndNormalsCode += code.replacingOccurrences(of: "sceneMap", with: "terrainMapCode")
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
                                hitAndNormalsCode += code.replacingOccurrences(of: "sceneMap", with: "terrainMapCode")
                                hitAndNormalsCode +=
                                """
                                
                                }
                                
                                """
                            }
                        }
                        
                        // Calculate terrain materialIds

                        if terrain.materials.count > 1 {
                            hitAndNormalsCode +=
                            """
                            
                            {
                                float3 position = rayOrigin + outShape.y * rayDirection;
                                float3 normal = outNormal;
                            
                                if (outShape.w == 0.0)
                                {
                            
                            """
                            
                            for (index, material) in terrain.materials.enumerated() {
                                if index == 0 {
                                    continue
                                }
                                
                                hitAndNormalsCode +=
                                """
                                
                                if ( normal.y >= 1.0 - \(material.values["maxSlope"]!) && normal.y <= 1.0 - \(material.values["minSlope"]!))
                                    outShape.z = \(index);
                                
                                """                                
                            }
                            
                            hitAndNormalsCode +=
                            """
                            
                                }
                            }
                            
                            """
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

                outMeta.z = __funcData->hash;
                outMeta.w = __funcData->distance2D;
                
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
                        var hasFog = false
                        var hasClouds = false

                        if let scene = scene {
                            let preStage = scene.getStage(.PreStage)
                            for c in preStage.children3D {
                                if let list = c.componentLists["fog"] {
                                    if list.count > 0 {
                                        hasFogOrClouds = true
                                        hasFog = true
                                    }
                                }
                                
                                if let list = c.componentLists["clouds"] {
                                    if list.count > 0 {
                                        hasFogOrClouds = true
                                        hasClouds = true
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

                            if (\(String(hasFog))) {
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
                            }
                        
                            // Cloud Density Code
                        
                            if (lightType.y == 0.0 && \(String(hasClouds))) {

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
                                            
                                            float2 __cloudMap\(index)(float3 position, float norY, thread struct FuncData *__funcData)
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
                                                                                                                                    
                                                float sigmaS = outDensity * cloudGradient(norY);
                                               
                                                const float sigmaA = 0.0;
                                                const float sigmaE = max(0.000000001, sigmaA + sigmaS);
                                                
                                                return float2( sigmaS, sigmaE );
                                            }
                                            
                                            float __cloudMapShadow\(index)(float3 from, float3 dir, float height, float layerSize, thread struct FuncData *__funcData)
                                            {
                                                float shadow = 1.0;
                                                float dd = (layerSize / 2.) * random(__funcData);
                                                float d = dd * 0.5;
                                            
                                                for(int s=0; s < 6; s += 1)
                                                {
                                                    float3 pos = from + dir * d;
                                            
                                                    float norY = (length(pos) - (EARTH_RADIUS + height)) * (1./(layerSize));
                                                    if(norY > 1.) return shadow;

                                                    float2 sigma = __cloudMap\(index)(pos, norY, __funcData);
                                                    shadow *= exp(-sigma.y * dd);
                                                    
                                                    dd *= 0.5 + random(__funcData);
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
                                            
                                                    for( int i=0; i < 10 && t < end; i++ )
                                                    {
                                                        float3 pos = ro + rayDirection * t;
                                                        
                                                        float norY = clamp( (length(pos) - (EARTH_RADIUS + height)) * (1./(layerSize)), 0., 1.);
                                                        float3 ambientLight = mix( \(bottomColor), \(topColor), norY );

                                                        float2 sigma = __cloudMap\(index)( pos, norY, __funcData);
                                                        
                                                        const float sigmaS = sigma.x;
                                                        const float sigmaE = sigma.y;
                                                    
                                                        if (sigmaS > 0.0) {
                                                        float3 S = (ambientLight + lightColor  * (__phaseFunction() * scattering * __cloudMapShadow\(index)(pos, lightDirection, height, layerSize, __funcData))) * sigmaS;
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

    func closeStream(async : Bool = false)
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
            
            // --- Point Builder Code
            if pointBuilderCode.count > 0 {
                let funcData = globalApp!.pipeline3D.codeBuilder.getFuncDataCode(instance, "POINTCLOUDBUILDER", 2)
                pointBuilderCode = pointBuilderCode.replacingOccurrences(of: "__FUNCDATA_CODE__", with: funcData)
            }
            
            instance.code = headerCode + backgroundCode + mapCode + terrainMapCode + shadowCode + hitAndNormalsCode + aoCode + materialFuncCode + materialCode + pointBuilderCode
        }
        
        var addInstances = ["computeAO", "computeShadow", "computeMaterial"]
        if pointBuilderCode.count > 0 {
            addInstances.append("pointBuilder")
        }
        
        if async {
            codeBuilder.buildInstanceAsync(instance, name: "hitAndNormals", additionalNames: type == .SDF3D ? addInstances : [])
        } else {
            codeBuilder.buildInstance(instance, name: "hitAndNormals", additionalNames: type == .SDF3D ? addInstances : [])
        }
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
                    float2 position = __translate(__origin / 80., float2(__data[\(posX)].x / 80., -__data[\(posY)].x / 80.));
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
                    float3 __offsetFromCenter = __objectPosition - __originalPosition;

                    position.yz = rotatePivot( position.yz, radians(__data[\(rotateX)].x\(getInstantiationModifier("_rotateRandomX", component.values))), __offsetFromCenter.yz );
                    position.xz = rotatePivot( position.xz, radians(__data[\(rotateY)].x\(getInstantiationModifier("_rotateRandomY", component.values))), __offsetFromCenter.xz );
                    position.xy = rotatePivot( position.xy, radians(__data[\(rotateZ)].x\(getInstantiationModifier("_rotateRandomZ", component.values))), __offsetFromCenter.xy );

            """
            
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["domain3D"] {
                    for domain in list {
                        
                        var firstRun = false
                        if globalsAddedFor.contains(domain.uuid) == false {
                            dryRunComponent(domain, instance.data.count)
                            instance.collectProperties(domain)
                            globalsAddedFor.append(domain.uuid)
                            firstRun = true
                        }
                        
                        if let globalCode = domain.globalCode {
                            if firstRun == true {
                                headerCode += globalCode
                            }
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
        
        if type == .SDF2D {
            code += component.code!
            code +=
            """
            
            outDistance *= 80;
            
            """
        } else {
            if component.componentType == .SDF3D {
                code += component.code!
            } else
            if component.componentType == .SDF2D {
                // 2D Component in a 3D World, needs extrusion code
             
                let extrusion = instance.getTransformPropertyIndex(component, "_extrusion")
                let revolution = instance.getTransformPropertyIndex(component, "_revolution")
                let rounding = instance.getTransformPropertyIndex(component, "_rounding")

                code +=
                """
                {
                    float3 originalPos = position;
                    float2 position = originalPos.xy;
                
                    if (__data[\(revolution)].x > 0.)
                        position = float2( length(originalPos.xz) - __data[\(revolution)].x, originalPos.y );
                
                    \(component.code!)
                    __funcData->distance2D = outDistance;
                    if (__data[\(revolution)].x == 0.)
                    {
                        float2 w = float2( outDistance, abs(originalPos.z) - __data[\(extrusion)].x );
                        outDistance = min(max(w.x,w.y),0.0) + length(max(w,0.0)) - __data[\(rounding)].x;
                    }
                }
                """
            }
        }
        
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
                            
                            var firstRun = false
                            if globalsAddedFor.contains(modifier.uuid) == false {
                                dryRunComponent(modifier, instance.data.count)
                                instance.collectProperties(modifier)
                                globalsAddedFor.append(modifier.uuid)
                                firstRun = true
                            }

                            code += modifier.code!
                            if let globalCode = modifier.globalCode {
                                if firstRun {
                                    headerCode += globalCode
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
            float4 shapeB = float4((outDistance - bump) * scale, -1, \(currentMaterialId), \(idCounter));
        
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
    
    // MARK:- pushStageItem
    func pushStageItem(_ stageItem: StageItem)
    {
        hierarchy.append(stageItem)
        
        // Insert terrain materials
        if isGroundComponent != nil && scene != nil && scene!.getStage(.ShapeStage).terrain != nil {
            
            func processMaterial(materialStageItem: StageItem, processBumps: Bool = false)
            {
                materialFuncCode +=
                """
                
                void material\(materialIdCounter)(float3 incomingDirection, float3 hitPosition, float3 hitNormal, float3 directionToLight, float4 lightType,
                float4 lightColor, float shadow, float occlusion, thread struct MaterialOut *__materialOut, thread struct FuncData *__funcData)
                {
                    float2 uv = float2(hitPosition.xz);
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
               
                // Get the patterns of the material if any
                var patterns : [CodeComponent] = []
                if materialStageItem.componentLists["patterns"] != nil {
                    patterns = materialStageItem.componentLists["patterns"]!
                }
               
                let material = materialStageItem.components[materialStageItem.defaultName]!
                
                dryRunComponent(material, instance.data.count, patternList: patterns)
                instance.collectProperties(material)
                if let globalCode = material.globalCode {
                    headerCode += globalCode
                }
                if let code = material.code {
                   materialFuncCode += code
                }
                
                if processBumps {
                    var bumpCode = ""

                    // Check if material has a bump
                    for (_, conn) in material.propertyConnections {
                        let fragment = conn.2
                        if fragment.name == "bump" && material.properties.contains(fragment.uuid) {
                            
                            bumpCode =
                            """
                            
                            {
                                float3 normal = float3(0);
                                float2 outUV = float2(position.xz);
                                
                            """
                                                  
                            // Than call the pattern and assign it to the output of the bump terminal
                            bumpCode +=
                            """
                            
                            struct PatternOut data;
                            \(conn.3)(outUV, position, normal, float3(0), &data, __funcData );
                            localHeight += data.\(conn.1) * 0.02;
                            }
                            
                            """
                        
                            
                        }
                    }
                    
                    terrainMapCode = terrainMapCode.replacingOccurrences(of: "__BUMP_CODE_\(materialIdCounter)__", with: bumpCode)
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
                if (shape.z > \(Float(materialIdCounter) - 0.5) && shape.z < \(Float(materialIdCounter) + 0.5))
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
                instance.materialIds[materialIdCounter] = stageItem
                currentMaterialId = materialIdCounter
                materialIdCounter += 1
            }
            
            for (index, stageItem) in scene!.getStage(.ShapeStage).terrain!.materials.enumerated() {
                processMaterial(materialStageItem: stageItem, processBumps: index == 0 ? true : false)
            }
            
            for layer in scene!.getStage(.ShapeStage).terrain!.layers.reversed() {
                if let material = layer.material {
                    processMaterial(materialStageItem: material, processBumps: true)
                } else {
                    currentMaterialId = materialIdCounter
                    materialIdCounter += 1
                }
            }
            
            /// Recursively iterate the object hierarchy
            func processChildren(_ stageItem: StageItem)
            {
                for child in stageItem.children {
                    if let shapes = child.getComponentList("shapes") {
                        codeBuilder.sdfStream.pushStageItem(child)
                        for shape in shapes {
                            codeBuilder.sdfStream.pushComponent(shape)
                        }
                        processChildren(child)
                        codeBuilder.sdfStream.pullStageItem()
                    }
                }
            }
            
            // Build the objects
            for (index, object) in terrainObjects.enumerated() {
                if let shapes = object.getComponentList("shapes") {

                    let gComponent = isGroundComponent
                    isGroundComponent = nil
                    
                    codeBuilder.sdfStream.pushStageItem(object)
                    for shape in shapes {
                        codeBuilder.sdfStream.pushComponent(shape)
                    }
                    processChildren(object)
                    codeBuilder.sdfStream.pullStageItem()
                                        
                    mapCode = mapCode.replacingOccurrences(of: "float4 sceneMap(", with: "float4 sceneMap\(index+1)(")
                    isGroundComponent = gComponent
                }
            }
        } else
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
                instance.collectProperties(transform, hierarchy)
                
                let posX = instance.getTransformPropertyIndex(transform, "_posX")
                let posY = instance.getTransformPropertyIndex(transform, "_posY")
                let posZ = instance.getTransformPropertyIndex(transform, "_posZ")
                                
                let rotateX = instance.getTransformPropertyIndex(transform, "_rotateX")
                let rotateY = instance.getTransformPropertyIndex(transform, "_rotateY")
                let rotateZ = instance.getTransformPropertyIndex(transform, "_rotateZ")
                
                let scale = instance.getTransformPropertyIndex(transform, "_scale")
                                
                // Handle scaling the object
                if hierarchy.count == 1 {
                    mapCode +=
                    """
                    
                    __objectPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x ) / scale;
                    scale = __data[\(scale)].x\(getInstantiationModifier("_scaleRandom", transform.values));
                    __origin = __originBackupForScaling / scale;
                    
                    """
                } else {
                    mapCode +=
                    """
                    
                    __objectPosition += float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x  ) / scale;
                    scale *= __data[\(scale)].x;
                    __origin = __originBackupForScaling / scale;

                    """
                }
                
                materialFuncCode +=
                """
                
                    float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    localPosition = __translate(hitPosition, __originalPosition);
                
                    localPosition.yz = rotate( localPosition.yz, radians(__data[\(rotateX)].x\(getInstantiationModifier("_rotateRandomX", transform.values))) );
                    localPosition.xz = rotate( localPosition.xz, radians(__data[\(rotateY)].x\(getInstantiationModifier("_rotateRandomY", transform.values))) );
                    localPosition.xy = rotate( localPosition.xy, radians(__data[\(rotateZ)].x\(getInstantiationModifier("_rotateRandomZ", transform.values))) );
                
                """
                
                if hierarchy.count == 1 {
                    let bbX = instance.getTransformPropertyIndex(transform, "_bb_x")
                    let bbY = instance.getTransformPropertyIndex(transform, "_bb_y")
                    let bbZ = instance.getTransformPropertyIndex(transform, "_bb_z")
                    
                    // Bounding Box code
                    boundingBoxCode =
                    """
                        
                        float3 __bbPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    
                        //float2 bDistance = boxIntersection(rayOrigin, rayDirection, float3(__data[\(bbX)].x, __data[\(bbY)].x, __data[\(bbZ)].x) );
                            
                        float3 _bbMin = __bbPosition - float3(__data[\(bbX)].x, __data[\(bbY)].x, __data[\(bbZ)].x) / 2;
                        float3 _bbMax = __bbPosition + float3(__data[\(bbX)].x, __data[\(bbY)].x, __data[\(bbZ)].x) / 2;

                        float2 bb = hitBBox(rayOrigin, rayDirection, _bbMin, _bbMax );
                    
                        if (bb.y >= 0.0) {
                    
                        if (bb.x >= 0.0)
                            rayOrigin = rayOrigin + bb.x * rayDirection;
                        
                        maxDistance = min(bb.y, maxDistance);
                        
                    """
                }
            }
                
            // Create the UVMapping for this material
            
            // In case we need to reuse it for displacement bumps
            var uvMappingCode = ""
            
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
                    uvMappingCode = code
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
    
            // Check if material has a bump
            var hasBump = false
            for (_, conn) in material.propertyConnections {
                let fragment = conn.2
                if fragment.name == "bump" && material.properties.contains(fragment.uuid) {
                    
                    // First, insert the uvmapping code
                    mapCode +=
                    """
                    
                    {
                    float3 position = __origin; float3 normal = float3(0);
                    float2 outUV = float2(0);
                    
                    """
                    
                    mapCode += uvMappingCode
                    
                    // Than call the pattern and assign it to the output of the bump terminal
                    mapCode +=
                    """
                    
                    struct PatternOut data;
                    \(conn.3)(outUV, position, normal, float3(0), &data, __funcData );
                    bump = data.\(conn.1) * 0.02;
                    }
                    
                    """
                    
                    hasBump = true
                }
            }
            
            // If material has no bump, reset it
            if hasBump == false {
                mapCode +=
                """
                
                bump = 0;
                
                """
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
            if (shape.z > \(Float(materialIdCounter) - 0.5) && shape.z < \(Float(materialIdCounter) + 0.5))
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
        } else
        if let transform = stageItem.components[stageItem.defaultName], transform.componentType == .Transform2D || transform.componentType == .Transform3D {
            
            dryRunComponent(transform, instance.data.count)
            instance.collectProperties(transform, hierarchy)
            
            let posX = instance.getTransformPropertyIndex(transform, "_posX")
            let posY = instance.getTransformPropertyIndex(transform, "_posY")
            let posZ = instance.getTransformPropertyIndex(transform, "_posZ")
            
            let scale = instance.getTransformPropertyIndex(transform, "_scale")

            // Handle scaling the object here if it has no material
            if hierarchy.count == 1 {
                mapCode +=
                """
                
                __objectPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x ) / scale;
                scale = __data[\(scale)].x;
                __origin = __originBackupForScaling / scale;
                
                """
            } else {
                mapCode +=
                """
                
                __objectPosition += float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x ) / scale;
                scale *= __data[\(scale)].x;
                __origin = __originBackupForScaling / scale;

                """
            }
        }
    }
    
    func pullStageItem()
    {
        let stageItem = hierarchy.removeLast()
        
        if isGroundComponent != nil && scene != nil && scene!.getStage(.ShapeStage).terrain != nil {
            // Terrain materials

        } else
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
    
    /// Creates code for value modifiers
    func getInstantiationModifier(_ variable: String,_ values: [String:Float],_ multiplier: Float = 1.0) -> String
    {
        var result = ""
        
        if let value = values[variable] {
            if value != 0 {
                result = " + " + String(value) + " * (__funcData->hash - 0.5)"
            }
        }
        return result
    }
}
