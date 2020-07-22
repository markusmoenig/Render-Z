//
//  ObjectShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import simd
import MetalKit

class ObjectShader      : BaseShader
{
    var scene           : Scene
    var object          : StageItem
    var camera          : CodeComponent
    
    // bbox buffer
    var P               = SIMD3<Float>(0,0,0)
    var L               = SIMD3<Float>(0,0,0)
    var F               : matrix_float3x3 = matrix_identity_float3x3

    var materialCode    = ""
    var materialBumpCode = ""
    
    var bbTriangles     : [Float] = []
    var claimedIds      : [Int] = []
    
    var sphereBuilderState : MTLComputePipelineState? = nil
    
    var spheres         : [SIMD4<Float>] = []

    init(instance: PRTInstance, scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
        
        super.init(instance: instance)
        self.rootItem = object

        buildShader()
    }
    
    deinit {
        prtInstance.returnIds(claimedIds)
    }
    
    func buildShader()
    {
        let vertexShader =
        """
        
        \(prtInstance.fragmentUniforms)

        typedef struct {
            matrix_float4x4     modelMatrix;
            matrix_float4x4     viewMatrix;
            matrix_float4x4     projectionMatrix;
        } ObjectVertexUniforms;

        struct VertexOut{
            float4              position[[position]];
            float3              worldPosition;;
            //float3              screenPosition;
        };

        vertex VertexOut procVertex(const device packed_float4 *triangles [[ buffer(0) ]],
                                    constant ObjectVertexUniforms &uniforms [[ buffer(1) ]],
                                    unsigned int vid [[ vertex_id ]] )
        {
            VertexOut out;

            out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(triangles[vid]);
            out.worldPosition = (uniforms.modelMatrix * float4(triangles[vid])).xyz;

            return out;
        }

        """
        
        var headerCode = ""
        
        let mapCode = createMapCode()

        idStart = Float(claimedIds.first!)
        idEnd = Float(claimedIds.last!)
                
        // Raymarch
        let rayMarch = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .RayMarch3D)!
        dryRunComponent(rayMarch, data.count)
        collectProperties(rayMarch)
        if let globalCode = rayMarch.globalCode {
            headerCode += globalCode
        }
        
        // Normals
        let normal = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Normal3D)!
        dryRunComponent(normal, data.count)
        collectProperties(normal)
        if let globalCode = normal.globalCode {
            headerCode += globalCode
        }
                
        // --- Create Soft Shadow Function Code
        var softShadowCode =
        """
        float calcSoftShadow( float3 ro, float3 rd, thread struct FuncData *__funcData)
        {
            float outShadow = 1.;
            float3 position = ro;
            float3 direction = rd;

        """
        if let shadows = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Shadows3D) {
            dryRunComponent(shadows, data.count)
            collectProperties(shadows)
            if let globalCode = shadows.globalCode {
                headerCode += globalCode
            }
            if let code = shadows.code {
                softShadowCode += code
            }
        }
        softShadowCode +=
        """

            return outShadow;
        }

        """
        
        // --- Create AO Code
        var aoCode = ""
        if let ao = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .AO3D) {
            dryRunComponent(ao, data.count)
            collectProperties(ao)
            if let globalCode = ao.globalCode {
                headerCode += globalCode
            }
            if let code = ao.code {
                aoCode = code
            }
        }
        
        // Light Sampling Code
        let lightSamplingCode = prtInstance.utilityShader!.createLightSamplingMaterialCode(materialCode: materialCode)
        
        let fragmentShader =
        """
        
        \(headerCode)
        \(mapCode)
        \(createLightCode(scene: scene))

        fragment half4 procFragment(VertexOut vertexIn [[stage_in]],
                                    __MAIN_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(2)]])
        {
            __MAIN_INITIALIZE_FUNC_DATA__
        
            float2 size = uniforms.screenSize;
            float3 position = vertexIn.position.xyz;
            float2 uv = float2((position.x / size.x), 1.0 - (position.y / size.y));
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 inShape = float4(1000, 1000, -1, -1);
            float4 outShape = float4(1000, 1000, -1, -1);
            float maxDistance = uniforms.maxDistance;

            //__funcData->inShape = float4(1000, 1000, -1, -1);
            //__funcData->inHitPoint = rayOrigin + rayDirection * outShape.y;
        
            float3 outPosition = uniforms.cameraOrigin;
            float3 outDirection = float3(camDirectionTexture.read(textureUV).xyz);
                            
            float3 rayOrigin = vertexIn.worldPosition.xyz;//outPosition;// + distance(outPosition, vertexIn.worldPosition.xyz) * outDirection;
            float3 rayDirection = outDirection;

            \(rayMarch.code!)
        
            if (isNotEqual(outShape.w, inShape.w)) {
                outShape.y += distance(rayOrigin, uniforms.cameraOrigin);
            }
            return half4(outShape);
        }
        
        \(BaseShader.getQuadVertexSource(name: "quadVertex"))
        
        float bbox(float3 C, float3 D, float3 P, float3 L, float3x3 F)
        {
            float d = 1e5, l;
            
            C = (C-P) * F;    D *= F;
            float3 I = abs(C-.5); bool inside = max(I.x, max(I.y,I.z)) <= .5;
            if ( inside ) return 0.;
                
            #define test(i)                                                       \
            l =  D[i] > 0. ?  C[i] < 0. ? -C[i]   : C[i] < 1. ? 1.-C[i] : -1.     \
                           :  C[i] > 1. ? 1.-C[i] : C[i] > 0. ? -C[i]   :  1.;    \
            l /= D[i];                                                            \
            I = C+l*D;                                                            \
            if ( l > 0. && l < d                                                  \
                 && I[(i+1)%3] >= 0. && I[(i+1)%3] <= 1.                          \
                 && I[(i+2)%3] >= 0. && I[(i+2)%3] <= 1.                          \
               )  d = l
        
            test(0);
            test(1);
            test(2);
            return d==1e5 ? -1. : d;
        }
        
        fragment half4 fullFragment(RasterizerData vertexIn [[stage_in]],
                                    __MAINFULL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(2)]],
                                    texture2d<half, access::read> inShapeTexture [[texture(3)]])
        {
            __MAINFULL_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 inShape = float4(inShapeTexture.read(textureUV));float4(1000, 1000, -1, -1);
            float4 outShape = inShape;//float4(1000, 1000, -1, -1);
            float maxDistance = 10;//uniforms.maxDistance;

            //__funcData->inShape = float4(1000, 1000, -1, -1);
            //__funcData->inHitPoint = rayOrigin + rayDirection * outShape.y;
        
            float3 outPosition = uniforms.cameraOrigin;
            float3 outDirection = float3(camDirectionTexture.read(textureUV).xyz);
            
            float d = bbox( outPosition, outDirection, uniforms.P, uniforms.L, uniforms.F );
            if (d > -0.5)
            {
                float3 rayOrigin = outPosition + d * outDirection;
                float3 rayDirection = outDirection;

                \(rayMarch.code!)
        
                if (isNotEqual(outShape.w, inShape.w)) {
                    outShape.y += d;
        
                    if (outShape.y > inShape.y)
                        outShape = inShape;
                }
            }
        
            return half4(outShape);
        }
        
        fragment half4 bboxFragment(VertexOut vertexIn [[stage_in]])
        {
            return (1,0,0,0.5);
        }
        
        fragment half4 bboxFullFragment(RasterizerData vertexIn [[stage_in]],
                                        constant FragmentUniforms &uniforms [[ buffer(0) ]],
                                        texture2d<half, access::read> camDirectionTexture [[texture(1)]])
        {
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);
        
            float3 outPosition = uniforms.cameraOrigin;
            float3 outDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
            float d = bbox( outPosition, outDirection, uniforms.P, uniforms.L, uniforms.F );
            if (d > -0.5)
            {
                return half4(1,0,0,0.5);
            } else {
                return half4(0);
            }
        
            return half4(0);
        }
        
        \(softShadowCode)
        
        float smin( float a, float b, float k )
        {
            float h = clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
            return mix( b, a, h ) - k*h*(1.0-h);
        }
        
        fragment float2 shadowFragment(RasterizerData vertexIn [[stage_in]],
                                    __SHADOW_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> shadowTexture [[texture(3)]],
                                    texture2d<half, access::read> shapeTexture [[texture(4)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(5)]])
        {
            __SHADOW_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 shape = float4(shapeTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)));
            float2 shadows = float2(shadowTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)).xy);
            
            if (shape.w > -0.5)
            {
                float3 rayOrigin = uniforms.cameraOrigin;
                float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
                
                float3 position = rayOrigin + shape.y * rayDirection;
            
                float3 outNormal = float3(0,0,0);
                \(normal.code!)
            
                float3 normal = outNormal;
                float outAO = 1.;
            
                \(aoCode)
        
                shadows.x = min(shadows.x, outAO);
                
                if (shape.w < \(idStart - 0.1) || shape.w > \(idEnd + 0.1))
                {
                    // Calculate shadows (No self shadowing)
                    float shadow = calcSoftShadow(position, normalize(lights.lights[0].directionToLight.xyz), __funcData);

                    float3 lightDir = float3(0);
                    for (int i = 1; i < lights.numberOfLights; ++i)
                    {
                        Light light = lights.lights[i];
                        if (light.lightType == 0) lightDir = normalize(light.directionToLight.xyz);
                        else lightDir = normalize(light.directionToLight.xyz - position);
            
                        shadow = max(calcSoftShadow(position, lightDir, __funcData), shadow);
                    }
            
                    shadows.y = min(shadows.y, shadow);
                }
            }
            return shadows;
        }

        fragment float4 materialFragment(RasterizerData vertexIn [[stage_in]],
                                    __MATERIAL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> depthTexture [[texture(3)]],
                                    texture2d<half, access::read> shadowTexture [[texture(4)]],
                                    texture2d<half, access::write> reflectionTextureOut [[texture(5)]],
                                    texture2d<half, access::read> reflectionDirTextureIn [[texture(6)]],
                                    texture2d<half, access::write> reflectionDirTextureOut [[texture(7)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(8)]],
                                    texture2d<half, access::read> maskTextureIn [[texture(9)]],
                                    texture2d<half, access::write> maskTextureOut [[texture(10)]])
        {
            __MATERIAL_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 outColor = float4(0);
            float4 shape = float4(depthTexture.read(textureUV));
            float4 reflectionDir = float4(reflectionDirTextureIn.read(textureUV));
            float4 maskOut = float4(maskTextureIn.read(textureUV));

            if (shape.w >= \(idStart - 0.1) && shape.w <= \(idEnd + 0.1))
            {
                float2 shadows = float2(shadowTexture.read(ushort2(uv.x * size.x, (1.0 - uv.y) * size.y)).xy);
        
                float3 rayOrigin = uniforms.cameraOrigin;
                float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
                float3 position = rayOrigin + shape.y * rayDirection;
                float3 outNormal = float3(0);
        
                \(normal.code!)
                \(materialBumpCode)
        
                // Sun
                {
                    struct MaterialOut __materialOut;
                    __materialOut.color = float4(0,0,0,1);
                    __materialOut.mask = float3(0);
                    
                    float3 incomingDirection = rayDirection;
                    float3 hitPosition = position;
                    float3 hitNormal = outNormal;
                    float3 directionToLight = normalize(lights.lights[0].directionToLight.xyz);
                    float4 lightType = float4(0);
                    float4 lightColor = lights.lights[0].lightColor;
                    float shadow = shadows.y;
                    float occlusion = shadows.x;
                    float3 mask = float3(1);

                    \(materialCode)
        
                    reflectionDir.xyz = __materialOut.reflectionDir;
                    reflectionDir.w = __materialOut.reflectionDist;
                    maskOut.xyz = __materialOut.mask * shadows.y;

                    outColor += __materialOut.color;
                }
        
                \(lightSamplingCode)
        
                outColor.xyz += uniforms.ambientColor.xyz;
            }
        
            maskTextureOut.write(half4(maskOut), textureUV);
            reflectionTextureOut.write(half4(1000, 1000, -1, -1), textureUV);
            reflectionDirTextureOut.write(half4(reflectionDir), textureUV);

            return outColor;
        }

        fragment float4 reflectionFragment(RasterizerData vertexIn [[stage_in]],
                                    __REFLECTION_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    texture2d<half, access::read> depthTexture [[texture(2)]],
                                    texture2d<half, access::read> reflectionTexture [[texture(3)]],
                                    texture2d<half, access::read> reflectionDirTexture [[texture(4)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(5)]])
        {
            __REFLECTION_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 shape = float4(depthTexture.read(textureUV));
        
            float4 inShape = float4(reflectionTexture.read(textureUV));
            float4 outShape = inShape;
        
            // Check if anything ELSE reflects on this object
            if (shape.w > -0.4 && (shape.w < \(idStart - 0.1) || shape.w > \(idEnd + 0.1)))
            {
                float maxDistance = 10.0;
            
                float3 camOrigin = uniforms.cameraOrigin;
                float3 camDirection = float3(camDirectionTexture.read(textureUV).xyz);
            
                float3 rayOrigin = camOrigin + shape.y * camDirection;
        
                float4 direction = float4(reflectionDirTexture.read(textureUV));
                float3 rayDirection = direction.xyz;
                rayOrigin += direction.w * rayDirection;
        
                float d = bbox( rayOrigin, rayDirection, uniforms.P, uniforms.L, uniforms.F );
                if (d > -0.5)
                {
                    rayOrigin += d * rayDirection;

                    \(rayMarch.code!)
        
                    if (isNotEqual(outShape.w, inShape.w)) {
                        outShape.y += d;
        
                        if (outShape.y > inShape.y)
                            outShape = inShape;
                    }
                }
            }

            return outShape;
        }
        
        fragment float4 reflMaterialFragment(RasterizerData vertexIn [[stage_in]],
                                    __REFLMATERIAL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> depthTexture [[texture(3)]],
                                    texture2d<half, access::read> reflectionTexture [[texture(4)]],
                                    texture2d<half, access::read> reflectionDirTexture [[texture(5)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(6)]],
                                    texture2d<half, access::read> maskTexture [[texture(7)]])
        {
            __REFLMATERIAL_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 outColor = float4(0);
            float4 shape = float4(depthTexture.read(textureUV));
            float4 reflectionShape = float4(reflectionTexture.read(textureUV));
            float4 mask = float4(maskTexture.read(textureUV));

            if (reflectionShape.w >= \(idStart - 0.1) && reflectionShape.w <= \(idEnd + 0.1))
            {
                float2 shadows = float2(1,1);

                float3 rayOrigin = uniforms.cameraOrigin;
                float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);

                float4 reflectionDir = float4(reflectionDirTexture.read(textureUV));

                float3 position = (rayOrigin + shape.y * rayDirection) + reflectionDir.xyz * (reflectionShape.y + reflectionDir.w);
                float3 outNormal = float3(0);
        
                \(normal.code!)
                \(materialBumpCode)
        
                // Sun
                {
                    struct MaterialOut __materialOut;
                    __materialOut.color = float4(0,0,0,1);
                    __materialOut.mask = float3(0);
                    
                    float3 incomingDirection = rayDirection;
                    float3 hitPosition = position;
                    float3 hitNormal = outNormal;
                    float3 directionToLight = normalize(lights.lights[0].directionToLight.xyz);
                    float4 lightType = float4(0);
                    float4 lightColor = lights.lights[0].lightColor;
                    float shadow = shadows.y;
                    float occlusion = shadows.x;

                    \(materialCode)
                
                    outColor.xyz += uniforms.ambientColor.xyz;
                    outColor.xyz += __materialOut.color.xyz * mask.xyz;
                    outColor.w = 1.0;
                }
        
                \(lightSamplingCode)
            }
        
            return outColor;
        }
        
        
        kernel void sphereBuilder(constant float4 *__data [[ buffer(0) ]],
                                        device float4  *out [[ buffer(1) ]],
                constant FragmentUniforms &uniforms [[ buffer(2) ]],
                                                  uint  gid [[thread_position_in_grid]])
        {
            float GlobalTime = __data[0].x;
            float GlobalSeed = __data[0].z;
            
            struct FuncData __funcData_;
            thread struct FuncData *__funcData = &__funcData_;
            __funcData_.GlobalTime = GlobalTime;
            __funcData_.GlobalSeed = GlobalSeed;
            __funcData_.inShape = float4(1000, 1000, -1, -1);
            __funcData_.hash = 1.0;

            __funcData_.__data = __data;
        
            int index = 0;
            float3 position = float3(0,0,0);
        
            float4 rc = sceneMap(position, __funcData);
            if (rc.x < 0.0) {
                out[gid + index++] = float4(position, -rc.x);
            }
        
            float3 bbox = uniforms.cameraOrigin;
        
            // Edge 1
            float3 rayOrigin = float3(-bbox.x, -bbox.y, -bbox.z);
            float stepSize = distance(position, rayOrigin) / 3.0;
            float3 rayDirection = normalize(float3(bbox.x, bbox.y, bbox.z) - rayOrigin);
        
            float t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            // Edge 2
            rayOrigin = float3(bbox.x, bbox.y, bbox.z);
            rayDirection = normalize(float3(-bbox.x, -bbox.y, -bbox.z) - rayOrigin);
        
            t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            // Edge 3
            rayOrigin = float3(-bbox.x, -bbox.y, bbox.z);
            rayDirection = normalize(float3(bbox.x, bbox.y, -bbox.z) - rayOrigin);
        
            t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            // Edge 4
            rayOrigin = float3(bbox.x, bbox.y, -bbox.z);
            rayDirection = normalize(float3(-bbox.x, -bbox.y, bbox.z) - rayOrigin);
        
            t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            // Edge 5
            rayOrigin = float3(bbox.x, -bbox.y, -bbox.z);
            rayDirection = normalize(float3(-bbox.x, bbox.y, bbox.z) - rayOrigin);
        
            t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            // Edge 6
            rayOrigin = float3(-bbox.x, bbox.y, bbox.z);
            rayDirection = normalize(float3(bbox.x, -bbox.y, -bbox.z) - rayOrigin);
        
            t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            // Edge 7
            rayOrigin = float3(-bbox.x, bbox.y, -bbox.z);
            rayDirection = normalize(float3(bbox.x, -bbox.y, bbox.z) - rayOrigin);
        
            t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            // Edge 8
            rayOrigin = float3(bbox.x, -bbox.y, bbox.z);
            rayDirection = normalize(float3(-bbox.x, bbox.y, -bbox.z) - rayOrigin);
        
            t = stepSize;
            for(int i = 0; i < 3; i++)
            {
                position = rayOrigin + rayDirection * t;
        
                float4 rc = sceneMap(position, __funcData);
                if (rc.x < 0.0) {
                    out[gid + index++] = float4(position, -rc.x);
                    break;
                }
                t += stepSize;
            }
        
            out[gid + index] = float4(-1);
        }
        
        """
        
        //print(fragmentShader)
                        
        compile(code: vertexShader + fragmentShader, shaders: [
            Shader(id: "MAIN", textureOffset: 3, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "MAINFULL", vertexName: "quadVertex", fragmentName: "fullFragment", textureOffset: 4, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "BBOX", fragmentName: "bboxFragment", textureOffset: 4, pixelFormat: .rgba16Float, blending: true),
            Shader(id: "BBOXFULL", vertexName: "quadVertex", fragmentName: "bboxFullFragment", textureOffset: 2, pixelFormat: .rgba16Float, blending: true),
            Shader(id: "MATERIAL", vertexName: "quadVertex", fragmentName: "materialFragment", textureOffset: 11, blending: true),
            Shader(id: "SHADOW", vertexName: "quadVertex", fragmentName: "shadowFragment", textureOffset: 6, pixelFormat: .rg16Float, blending: false),
            Shader(id: "REFLECTION", vertexName: "quadVertex", fragmentName: "reflectionFragment", textureOffset: 6, blending: false),
            Shader(id: "REFLMATERIAL", vertexName: "quadVertex", fragmentName: "reflMaterialFragment", textureOffset: 8, addition: true)
        ])
        buildTriangles()
    }
    
    func buildSpheres() -> [SIMD4<Float>]
    {
        var spheres : [SIMD4<Float>] = []
        
        if sphereBuilderState == nil {
            sphereBuilderState = createComputeState(name: "sphereBuilder")
        }
        
        if let state = sphereBuilderState {
                        
            let values = rootItem!.components[rootItem!.defaultName]!.values
            rootItem!.components[rootItem!.defaultName]!.values["_posX"] = 0
            rootItem!.components[rootItem!.defaultName]!.values["_posY"] = 0
            rootItem!.components[rootItem!.defaultName]!.values["_posZ"] = 0
            rootItem!.components[rootItem!.defaultName]!.values["_rotateX"] = 0
            rootItem!.components[rootItem!.defaultName]!.values["_rotateY"] = 0
            rootItem!.components[rootItem!.defaultName]!.values["_rotateZ"] = 0
            updateData()
            rootItem!.components[rootItem!.defaultName]!.values = values
            
            let commandQueue = device.makeCommandQueue()
            let commandBuffer = commandQueue!.makeCommandBuffer()!
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
            
            computeEncoder.setComputePipelineState( state )
            computeEncoder.setBuffer(buffer, offset: 0, index: 0)
            
            let outBuffer = device.makeBuffer(length: 10 * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            computeEncoder.setBuffer(outBuffer, offset: 0, index: 1)
            
            var fragmentUniforms = ObjectFragmentUniforms()
            let scale = values["_scale"]!
            
            let bbX : Float
            let bbY : Float
            let bbZ : Float

            if values["_bb_x"] == nil {
                bbX = 1 * scale
                bbY = 1 * scale
                bbZ = 1 * scale
            } else {
                bbX = values["_bb_x"]! * scale
                bbY = values["_bb_y"]! * scale
                bbZ = values["_bb_z"]! * scale
            }
            
            fragmentUniforms.cameraOrigin = SIMD3<Float>(bbX, bbY, bbZ)
            computeEncoder.setBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 2)

            //calculateThreadGroups(state, computeEncoder, Int(prtInstance.screenSize.x), Int(prtInstance.screenSize.y), limitThreads: true)
            let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
            let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
            computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
            
            computeEncoder.endEncoding()
            commandBuffer.commit()
            
            commandBuffer.waitUntilCompleted()
            
            let result = outBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: 1)
            
            var index : Int = 0
            var rc = result[index]
            while rc.w > 0 {
                spheres.append(rc)
                
                index += 1
                rc = result[index]
            }
        }
        
        self.spheres = spheres
        return spheres
    }

    override func render(texture: MTLTexture)
    {
        updateData()
    
        #if false
        if let mainShader = shaders["MAIN"] {

            if bbTriangles.count == 0 { return }
            let dataSize = bbTriangles.count * MemoryLayout<Float>.size
            let vertexBuffer = device.makeBuffer(bytes: bbTriangles, length: dataSize, options: [])

            var mTranslation = matrix_identity_float4x4
            var mRotation = matrix_identity_float4x4
            var mScale = matrix_identity_float4x4
            
            var maxDistance : Float = 100

            if let transform = self.object.components[self.object.defaultName] {
                let scale = transform.values["_scale"]!
                
                let tx = transform.values["_posX"]!
                let ty = transform.values["_posY"]!
                let tz = transform.values["_posZ"]!

                mTranslation = float4x4(translation: [tx - (1 - scale) * tx, ty - (1 - scale) * ty, tz  - (1 - scale) * tz])
                mRotation = float4x4(rotation: [transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians])
                
                let bbX : Float
                let bbY : Float
                let bbZ : Float

                if transform.values["_bb_x"] == nil {
                    bbX = 1 * scale
                    bbY = 1 * scale
                    bbZ = 1 * scale
                } else {
                    bbX = transform.values["_bb_x"]! * scale
                    bbY = transform.values["_bb_y"]! * scale
                    bbZ = transform.values["_bb_z"]! * scale
                }
                
                maxDistance = sqrt( bbX * bbX + bbY * bbY + bbZ * bbZ)
                mScale = float4x4(scaling: [(bbX), (bbY), (bbZ)])
            }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.localTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 0.0)

            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            //renderEncoder.setDepthStencilState(buildDepthStencilState())
            
            // Vertex Uniforms
            
            var vertexUniforms = ObjectVertexUniforms()
            vertexUniforms.projectionMatrix = prtInstance.projectionMatrix
            vertexUniforms.modelMatrix = mTranslation * mRotation * mScale
            vertexUniforms.viewMatrix = prtInstance.viewMatrix
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<ObjectVertexUniforms>.stride, index: 1)
            
            // Fragment Uniforms
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize
            fragmentUniforms.maxDistance = maxDistance
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 2)
            applyUserFragmentTextures(shader: mainShader, encoder: renderEncoder)
            
            renderEncoder.setCullMode(.back)
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setDepthClipMode(.clamp)
            
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: bbTriangles.count / 4)
            renderEncoder.endEncoding()
            
            commandBuffer.commit()
            
            // --- Merge the result
            prtInstance.utilityShader.mergeShapes()
        }
        
        #else
        
        if let shader = shaders["MAINFULL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShapeTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0, blue: 0, alpha: 0.0)
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = createFragmentUniform()
            var lightUniforms = prtInstance.utilityShader!.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        } else {
            print("NO")
        }
        
        #endif
    }
    
    func bbox(texture: MTLTexture)
    {
        #if false
        if let mainShader = shaders["BBOX"] {

            if bbTriangles.count == 0 { return }
            let dataSize = bbTriangles.count * MemoryLayout<Float>.size
            let vertexBuffer = device.makeBuffer(bytes: bbTriangles, length: dataSize, options: [])

            var mTranslation = matrix_identity_float4x4
            var mRotation = matrix_identity_float4x4
            var mScale = matrix_identity_float4x4
            
            var maxDistance : Float = 100

            if let transform = self.object.components[self.object.defaultName] {
                let scale = transform.values["_scale"]!
                
                let tx = transform.values["_posX"]!
                let ty = transform.values["_posY"]!
                let tz = transform.values["_posZ"]!

                mTranslation = float4x4(translation: [tx - (1 - scale) * tx, ty - (1 - scale) * ty, tz  - (1 - scale) * tz])
                mRotation = float4x4(rotation: [transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians])
                
                let bbX : Float
                let bbY : Float
                let bbZ : Float

                if transform.values["_bb_x"] == nil {
                    bbX = 1 * scale
                    bbY = 1 * scale
                    bbZ = 1 * scale
                } else {
                    bbX = transform.values["_bb_x"]! * scale
                    bbY = transform.values["_bb_y"]! * scale
                    bbZ = transform.values["_bb_z"]! * scale
                }
                
                maxDistance = sqrt( bbX * bbX + bbY * bbY + bbZ * bbZ)
                mScale = float4x4(scaling: [(bbX), (bbY), (bbZ)])
            }
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load

            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            //renderEncoder.setDepthStencilState(buildDepthStencilState())
            
            // Vertex Uniforms
            
            var vertexUniforms = ObjectVertexUniforms()
            vertexUniforms.projectionMatrix = prtInstance.projectionMatrix
            vertexUniforms.modelMatrix = mTranslation * mRotation * mScale
            vertexUniforms.viewMatrix = prtInstance.viewMatrix
            
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<ObjectVertexUniforms>.stride, index: 1)
            
            // Fragment Uniforms
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize
            fragmentUniforms.maxDistance = maxDistance
            
            renderEncoder.setCullMode(.back)
            renderEncoder.setFrontFacing(.counterClockwise)
            renderEncoder.setDepthClipMode(.clamp)
            
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: bbTriangles.count / 4)
            renderEncoder.endEncoding()
            
            commandBuffer.commit()
        }
        
        #else

        if let shader = shaders["BBOXFULL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            
            var fragmentUniforms = createFragmentUniform()
            var lightUniforms = prtInstance.utilityShader!.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 0)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 1)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
        
        #endif
    }
    
    override func createFragmentUniform() -> ObjectFragmentUniforms
    {
        var fragmentUniforms = ObjectFragmentUniforms()

        fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
        fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
        fragmentUniforms.screenSize = prtInstance.screenSize
        if let ambient = getGlobalVariableValue(withName: "World.worldAmbient") {
            fragmentUniforms.ambientColor = ambient
        }

        if let transform = self.object.components[self.object.defaultName] {
                            
            var bboxPos = SIMD3<Float>(transform.values["_posX"]!, transform.values["_posY"]!, transform.values["_posZ"]!)
            let scale = transform.values["_scale"]!

            let bbX : Float
            let bbY : Float
            let bbZ : Float

            if transform.values["_bb_x"] == nil {
                bbX = 1 * scale
                bbY = 1 * scale
                bbZ = 1 * scale
            } else {
                bbX = transform.values["_bb_x"]! * scale
                bbY = transform.values["_bb_y"]! * scale
                bbZ = transform.values["_bb_z"]! * scale
            }
            
            let bboxSize = SIMD3<Float>(bbX * 2, bbY * 2, bbZ * 2)

            bboxPos -= bboxSize / 2 + (1 - scale) * bboxPos;
            
            fragmentUniforms.maxDistance = sqrt( bbX * bbX + bbY * bbY + bbZ * bbZ)
            
            let rotationMatrix = float4x4(rotationZYX: [(-transform.values["_rotateX"]!).degreesToRadians, (transform.values["_rotateY"]!).degreesToRadians, (-transform.values["_rotateZ"]!).degreesToRadians])
            
            var X0 = SIMD4<Float>(bboxSize.x, 0, 0, 1)
            var X1 = SIMD4<Float>(0, bboxSize.y, 0, 1)
            var X2 = SIMD4<Float>(0, 0, bboxSize.z, 1)
            
            var C = SIMD3<Float>(0,0,0)
            C.x = bboxPos.x + (X0.x + X1.x + X2.x) / 2.0
            C.y = bboxPos.y + (X0.y + X1.y + X2.y) / 2.0
            C.z = bboxPos.z + (X0.z + X1.z + X2.z) / 2.0
                        
            X0 = X0 * rotationMatrix
            X1 = X1 * rotationMatrix
            X2 = X2 * rotationMatrix
            
            fragmentUniforms.P.x = C.x - (X0.x + X1.x + X2.x) / 2.0
            fragmentUniforms.P.y = C.y - (X0.y + X1.y + X2.y) / 2.0
            fragmentUniforms.P.z = C.z - (X0.z + X1.z + X2.z) / 2.0
                
            let X03 = SIMD3<Float>(X0.x, X0.y, X0.z)
            let X13 = SIMD3<Float>(X1.x, X1.y, X1.z)
            let X23 = SIMD3<Float>(X2.x, X2.y, X2.z)
            
            fragmentUniforms.L = SIMD3<Float>(length(X03), length(X13), length(X23))
            fragmentUniforms.F = float3x3( X03 / dot(X03, X03), X13 / dot(X13, X13), X23 / dot(X23, X23) )
            
            P = fragmentUniforms.P
            L = fragmentUniforms.L
            F = fragmentUniforms.F
        }
        
        return fragmentUniforms
    }
    
    override func shadowPass(texture: MTLTexture)
    {
        if let shader = shaders["SHADOW"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShadowTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            var lightUniforms = prtInstance.utilityShader!.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentTexture(prtInstance.currentShadowTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 5)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    override func materialPass(texture: MTLTexture)
    {
        if let shader = shaders["MATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            var lightUniforms = prtInstance.utilityShader!.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentShadowTexture!, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 5)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 6)
            renderEncoder.setFragmentTexture(prtInstance.otherReflDirTexture, index: 7)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 8)
            renderEncoder.setFragmentTexture(prtInstance.currentMaskTexture!, index: 9)
            renderEncoder.setFragmentTexture(prtInstance.otherMaskTexture!, index: 10)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    override func reflectionPass(texture: MTLTexture)
    {
        if let shader = shaders["REFLECTION"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherReflTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize
            fragmentUniforms.P = P
            fragmentUniforms.L = L
            fragmentUniforms.F = F

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 5)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    override func reflectionMaterialPass(texture: MTLTexture)
    {
        if let shader = shaders["REFLMATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            var lightUniforms = prtInstance.utilityShader!.createLightStruct()
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)
            
            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 5)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 6)
            renderEncoder.setFragmentTexture(prtInstance.currentMaskTexture!, index: 7)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    func createMapCode() -> String
    {
        var hierarchy           : [StageItem] = []
        
        var globalsAddedFor     : [UUID] = []
        
        var componentCounter    : Int = 0

        var materialIdCounter   : Int = 0
        var currentMaterialId   : Int = 0
        
        var materialFuncCode    = ""

        var headerCode = ""
        var mapCode = """

        float4 sceneMap( float3 __origin, thread struct FuncData *__funcData )
        {
            float3 __originBackupForScaling = __origin;
            float3 __objectPosition = float3(0);
            float outDistance = 10;
            //float bump = 0;
            float scale = 1;

            //float4 outShape = __funcData->inShape;
            //outShape.x = length(__origin - __funcData->inHitPoint) + 0.5;

            float4 outShape = float4(1000, 1000, -1, -1);

            constant float4 *__data = __funcData->__data;
            float GlobalTime = __funcData->GlobalTime;
            float GlobalSeed = __funcData->GlobalSeed;

        """
                        
        func pushComponent(_ component: CodeComponent)
        {
            dryRunComponent(component, data.count)
            collectProperties(component, hierarchy)
             
            if let globalCode = component.globalCode {
                headerCode += globalCode
            }
             
            var code = ""
             
            let posX = getTransformPropertyIndex(component, "_posX")
            let posY = getTransformPropertyIndex(component, "_posY")
            let posZ = getTransformPropertyIndex(component, "_posZ")
                 
            let rotateX = getTransformPropertyIndex(component, "_rotateX")
            let rotateY = getTransformPropertyIndex(component, "_rotateY")
            let rotateZ = getTransformPropertyIndex(component, "_rotateZ")

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
                            dryRunComponent(domain, data.count)
                            collectProperties(domain)
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
             
            if component.componentType == .SDF3D {
                code += component.code!
            } else
            if component.componentType == .SDF2D {
                // 2D Component in a 3D World, needs extrusion code
                  
                let extrusion = getTransformPropertyIndex(component, "_extrusion")
                let revolution = getTransformPropertyIndex(component, "_revolution")
                let rounding = getTransformPropertyIndex(component, "_rounding")

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
             
            // Modifier 3D
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["modifier3D"] {
                    if list.count > 0 {
                             
                        let rotateX = getTransformPropertyIndex(component, "_rotateX")
                        let rotateY = getTransformPropertyIndex(component, "_rotateY")
                        let rotateZ = getTransformPropertyIndex(component, "_rotateZ")
                             
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
                                dryRunComponent(modifier, data.count)
                                collectProperties(modifier)
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

            let id = prtInstance.claimId()

            code +=
            """
             
                float4 shapeA = outShape;
            float4 shapeB = float4((outDistance /*- bump*/) * scale, -1, \(currentMaterialId), \(id));
             
            """
             
            if let subComponent = component.subComponent {
                dryRunComponent(subComponent, data.count)
                collectProperties(subComponent)
                code += subComponent.code!
            }
         
            code += "\n    }\n"
            mapCode += code
             
            // If we have a stageItem, store the id
            //if hierarchy.count > 0 {
                claimedIds.append(id)
                ids[id] = (hierarchy, component)
            //}
            componentCounter += 1
        }
        
        func pushStageItem(_ stageItem: StageItem)
        {
            hierarchy.append(stageItem)
            // Handle the materials
            if let material = getFirstComponentOfType(stageItem.children, .Material3D) {
                // If this item has a material, generate the material function code and push it on the stack
                
                // Material Function Code
                
                materialFuncCode +=
                """
                
                void material\(materialIdCounter)(float3 rayOrigin, float3 incomingDirection, float3 hitPosition, float3 hitNormal, float3 directionToLight, float4 lightType,
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
                    float outReflectionDist = 0.;
                
                    float3 localPosition = hitPosition;
                
                """
                
                if let transform = stageItem.components[stageItem.defaultName], transform.componentType == .Transform3D {
                    
                    dryRunComponent(transform, data.count)
                    collectProperties(transform, hierarchy)
                    
                    let posX = getTransformPropertyIndex(transform, "_posX")
                    let posY = getTransformPropertyIndex(transform, "_posY")
                    let posZ = getTransformPropertyIndex(transform, "_posZ")
                                    
                    let rotateX = getTransformPropertyIndex(transform, "_rotateX")
                    let rotateY = getTransformPropertyIndex(transform, "_rotateY")
                    let rotateZ = getTransformPropertyIndex(transform, "_rotateZ")
                    
                    let scale = getTransformPropertyIndex(transform, "_scale")
                                    
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
                        
                    dryRunComponent(uvMap, data.count)
                    collectProperties(uvMap)
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
                
                dryRunComponent(material, data.count, patternList: patterns)
                collectProperties(material)
                if let globalCode = material.globalCode {
                    headerCode += globalCode
                }
                if let code = material.code {
                    materialFuncCode += code
                }
        
                // Check if material has a bump
                //var hasBump = false
                for (_, conn) in material.propertyConnections {
                    let fragment = conn.2
                    if fragment.name == "bump" && material.properties.contains(fragment.uuid) {
                        
                        // Needs shape, outNormal, position
                        materialBumpCode +=
                        """
                        
                        if (shape.z > \(Float(materialIdCounter) - 0.5) && shape.z < \(Float(materialIdCounter) + 0.5))
                        {
                            float3 realPosition = position;
                            float3 position = realPosition; float3 normal = outNormal;
                            float2 outUV = float2(0);
                            float bumpFactor = 0.2;
                        
                            // bref
                            {
                                \(uvMappingCode)
                            }
                        
                            struct PatternOut data;
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float bRef = data.\(conn.1);
                        
                            const float2 e = float2(.001, 0);
                        
                            // b1
                            position = realPosition - e.xyy;
                            {
                                \(uvMappingCode)
                            }
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float b1 = data.\(conn.1);
                        
                            // b2
                            position = realPosition - e.yxy;
                            {
                                \(uvMappingCode)
                            }
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float b2 = data.\(conn.1);
                        
                            // b3
                            position = realPosition - e.yyx;
                            \(uvMappingCode)
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float b3 = data.\(conn.1);
                        
                            float3 grad = (float3(b1, b2, b3) - bRef) / e.x;
                        
                            grad -= normal * dot(normal, grad);
                            outNormal = normalize(normal + grad * bumpFactor);
                        }

                        """
                        
                        
                        /*
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
                        \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                        bump = data.\(conn.1) * 0.02;
                        }
                        
                        """
                        
                        hasBump = true
                        */
                    }
                }
                
                /*
                // If material has no bump, reset it
                if hasBump == false {
                    mapCode +=
                    """
                    
                    bump = 0;
                    
                    """
                }*/

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
                
                if (shape.z > \(Float(materialIdCounter) - 0.5) && shape.z < \(Float(materialIdCounter) + 0.5))
                {
                    material\(materialIdCounter)(rayOrigin, incomingDirection, hitPosition, hitNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);
                }

                """
                
                // Push it on the stack
                
                materialIdHierarchy.append(materialIdCounter)
                materialIds[materialIdCounter] = stageItem
                currentMaterialId = materialIdCounter
                materialIdCounter += 1
            } else
            if let transform = stageItem.components[stageItem.defaultName], transform.componentType == .Transform2D || transform.componentType == .Transform3D {
                
                dryRunComponent(transform, data.count)
                collectProperties(transform, hierarchy)
                
                let posX = getTransformPropertyIndex(transform, "_posX")
                let posY = getTransformPropertyIndex(transform, "_posY")
                let posZ = getTransformPropertyIndex(transform, "_posZ")
                
                let scale = getTransformPropertyIndex(transform, "_scale")

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
        
        /// Recursively iterate the object hierarchy
        func processChildren(_ stageItem: StageItem)
        {
            for child in stageItem.children {
                if let shapes = child.getComponentList("shapes") {
                    pushStageItem(child)
                    for shape in shapes {
                        pushComponent(shape)
                    }
                    processChildren(child)
                    pullStageItem()
                }
            }
        }

        if let shapes = object.getComponentList("shapes") {
            pushStageItem(object)
            for shape in shapes {
                pushComponent(shape)
            }
            processChildren(object)
            pullStageItem()
            
            //idCounter += codeBuilder.sdfStream.idCounter - idCounter + 1
        }
        
        mapCode += """

            return outShape;
        }
        
        """
        
        return headerCode + mapCode + materialFuncCode
    }
    
    func buildTriangles()
    {
        bbTriangles = [
            // left
            -1, +1, +1, 1.0, -1, +1, -1, 1.0, -1, -1, -1, 1.0,
            -1, +1, +1, 1.0, -1, -1, -1, 1.0, -1, -1, +1, 1.0,
            // right
            +1, +1, -1, 1.0, +1, +1, +1, 1.0, +1, -1, +1, 1.0,
            +1, +1, -1, 1.0, +1, -1, +1, 1.0, +1, -1, -1, 1.0,
            // bottom
            -1, -1, -1, 1.0, +1, -1, -1, 1.0, +1, -1, +1, 1.0,
            -1, -1, -1, 1.0, +1, -1, +1, 1.0, -1, -1, +1, 1.0,
            // top
            -1, +1, +1, 1.0, +1, +1, +1, 1.0, +1, +1, -1, 1.0,
            -1, +1, +1, 1.0, +1, +1, -1, 1.0, -1, +1, -1, 1.0,
            // back
            -1, +1, -1, 1.0, +1, +1, -1, 1.0, +1, -1, -1, 1.0,
            -1, +1, -1, 1.0, +1, -1, -1, 1.0, -1, -1, -1, 1.0,
            // front
            +1, +1, +1, 1.0, -1, +1, +1, 1.0, -1, -1, +1, 1.0,
            +1, +1, +1, 1.0, -1, -1, +1, 1.0, +1, -1, +1, 1.0
        ]
    }
}
