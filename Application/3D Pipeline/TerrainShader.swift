//
//  TerrainShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class TerrainShader     : BaseShader
{
    var scene           : Scene
    var object          : StageItem
    var camera          : CodeComponent
        
    var terrainObjects  : [StageItem] = []
    var terrainMapCode  = ""
    
    var materialCode    = ""
    var materialBumpCode = ""

    init(instance: PFXInstance, scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
                    
        super.init(instance: instance)
        createFragmentSource(camera: camera)
    }
    
    func createFragmentSource(camera: CodeComponent)
    {
        let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
        let terrain = shapeStage.terrain!

        let lightSamplingCode = prtInstance.utilityShader!.createLightSamplingMaterialCode(materialCode: "material0(rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);")

        var headerCode = ""
        terrainMapCode =
        """
        
        float __hash12(float2 p)
        {
            float3 p3  = fract(float3(p.xyx) * .1031);
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.x + p3.y) * p3.z);
        }

        float4 sceneMap(float3 position, thread struct FuncData *__funcData)
        {
            constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);
        
            constant float4 *__data = __funcData->__data;
            float GlobalTime = __funcData->GlobalTime;
            float GlobalSeed = __funcData->GlobalSeed;
            float materialId = 0.0;

            float outDistance = 1000.0;
            float localHeight = 0.0;
            float4 instObject = float4(1000, 1000, -1, -1);
        
            float height = __interpolateHeightTexture(*__funcData->terrainTexture, (position.xz + \(terrain.terrainSize) / \(terrain.terrainScale) / 2.0) / \(terrain.terrainSize) * \(terrain.terrainScale)) * \(terrain.terrainHeightScale);
        
        """
        
        if terrain.noiseType != .None {
            let component = CodeComponent(.Dummy)
            let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
            ctx.reset(globalApp!.developerEditor.codeEditor.rect.width, data.count, patternList: [])
            ctx.cComponent = component
            component.globalCode = ""
            
            if terrain.noiseType == .TwoD {

                let layerName = generateNoise2DFunction(ctx, terrain.noise2DFragment)
                terrainMapCode +=
                """
                localHeight = \(layerName)(position.xz, __funcData);
                """
            } else
            if terrain.noiseType == .ThreeD {

                let layerName = generateNoise3DFunction(ctx, terrain.noise3DFragment)
                terrainMapCode +=
                """
                localHeight = \(layerName)(position + float3(0,localHeight, 0), __funcData);
                """
            } else
            if terrain.noiseType == .Image {

                let layerName = generateImageFunction(ctx, terrain.imageFragment)
                terrainMapCode +=
                """
                localHeight = \(layerName)(position.xz, __funcData).x;
                """
            }
            
            headerCode += component.globalCode!
            collectProperties(component)
        }
        
        terrainMapCode +=
        """
        
        height += localHeight;
        
        """
        
         // Insert the noise layers
         /*
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
                     dryRunComponent(shapeComponent, data.count)
                     collectProperties(shapeComponent)
                     
                     if let globalCode = shapeComponent.globalCode {
                         headerCode += globalCode
                     }
                     
                     posX = getTransformPropertyIndex(shapeComponent, "_posX")
                     posY = getTransformPropertyIndex(shapeComponent, "_posY")
                     rotate = getTransformPropertyIndex(shapeComponent, "_rotate")
                     
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
                     //__BUMP_CODE_\(layerMaterialId)__
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
             ctx.reset(globalApp!.developerEditor.codeEditor.rect.width, data.count, patternList: [])
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
             collectProperties(component)
             
             if layer.shapes.isEmpty == false {
                 terrainMapCode +=
                 """
                 
                     }

                 """
             }
         }*/
         
         terrainMapCode +=
         """
         
         float4 rc = float4(position.y - height, 0, materialId, 0);
         
         """
                                                     
         terrainMapCode +=
         """
         
             return rc;
         }
          
         """
        
        let mainMaterialCode = generateMaterialCode(terrain: terrain)
                
        var raymarchCode = ""
        if let rayMarch = terrain.rayMarcher {
            dryRunComponent(rayMarch, data.count)
            collectProperties(rayMarch)
            if let globalCode = rayMarch.globalCode {
                headerCode += globalCode
            }
            if let code = rayMarch.code {
            //    raymarchCode = code.replacingOccurrences(of: "sceneMap", with: "terrainMapCode")
                raymarchCode = code
            }
        }
        
        var normalCode = ""
        if let normal = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .Normal3D) {
            dryRunComponent(normal, data.count)
            collectProperties(normal)
            if let globalCode = normal.globalCode {
                headerCode += globalCode
            }
            if let code = normal.code {
                normalCode = code
            }
        }
        
        var calculateMaterialIdCode = ""
        
        if terrain.materials.count > 1 {
            calculateMaterialIdCode +=
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
                
                calculateMaterialIdCode +=
                """
                
                if ( normal.y >= 1.0 - \(material.values["maxSlope"]!) && normal.y <= 1.0 - \(material.values["minSlope"]!))
                    outShape.z = \(index);
                
                """
            }
            
            calculateMaterialIdCode +=
            """
            
                }
            }
            
            """
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
                        
        let fragmentCode =
        """
        
        \(mainMaterialCode)
        
        \(headerCode)
        \(terrainMapCode)

        \(prtInstance.fragmentUniforms)
        \(createLightCode(scene: scene))

        fragment float4 procFragment(RasterizerData in [[stage_in]],
                                     __MAIN_TEXTURE_HEADER_CODE__
                                     constant float4 *__data [[ buffer(0) ]],
                                     constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                     texture2d<half, access::read> camDirectionTexture [[texture(2)]],
                                     texture2d<int, access::sample> terrainTexture [[texture(3)]])
        {
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            __MAIN_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &terrainTexture;

            float3 position = float3(uv.x, uv.y, 0);
                    
            float3 rayOrigin = uniforms.cameraOrigin;
            float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
            float4 outShape = float4(1000, 1000, -1, -1);
            float3 outNormal = float3(0);
            float maxDistance = 200.0;
        
            rayOrigin += rayDirection * (random(__funcData) * 0.1);
        
            \(raymarchCode)
            \(calculateMaterialIdCode)
            return outShape;
        }
        
        \(softShadowCode)
        
        fragment float2 shadowFragment(RasterizerData vertexIn [[stage_in]],
                                    __SHADOW_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> shadowTexture [[texture(3)]],
                                    texture2d<half, access::read> shapeTexture [[texture(4)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(5)]],
                                    texture2d<int, access::sample> terrainTexture [[texture(6)]])
        {
            __SHADOW_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &terrainTexture;

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
                position += random(__funcData) * 0.1;

                float3 outNormal = float3(0,0,0);
                \(normalCode)

                float3 normal = outNormal;
                float outAO = 1.;
        
                \(aoCode)
                    
                shadows.x = min(shadows.x, outAO);
                
                //if (isNotEqual(shape.w, 0.0))
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
                
        fragment float4 materialFragment(RasterizerData in [[stage_in]],
                                    __MATERIAL_TEXTURE_HEADER_CODE__
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]],
                                    constant LightUniforms &lights [[ buffer(2) ]],
                                    texture2d<half, access::read> shapeTexture [[texture(3)]],
                                    texture2d<half, access::read> shadowTexture [[texture(4)]],
                                    texture2d<half, access::read> reflectionTextureIn [[texture(5)]],
                                    texture2d<half, access::write> reflectionTextureOut [[texture(6)]],
                                    texture2d<half, access::read> reflectionDirTextureIn [[texture(7)]],
                                    texture2d<half, access::write> reflectionDirTextureOut [[texture(8)]],
                                    texture2d<half, access::read> camDirectionTexture [[texture(9)]],
                                    texture2d<int, access::sample> terrainTexture [[texture(10)]],
                                    texture2d<half, access::read> maskTextureIn [[texture(11)]],
                                    texture2d<half, access::write> maskTextureOut [[texture(12)]])
        {
            __MATERIAL_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &terrainTexture;

            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 outColor = float4(0,0,0,0);

            float4 reflectionShape = float4(reflectionTextureIn.read(textureUV));
            float4 reflectionDir = float4(reflectionDirTextureIn.read(textureUV));
            float4 maskOut = float4(maskTextureIn.read(textureUV));
        
            float4 outShape = float4(shapeTexture.read(textureUV));
            if (isEqual(outShape.w, 0.0)) {
                float2 shadows = float2(shadowTexture.read(textureUV).xy);
            
                float3 rayOrigin = uniforms.cameraOrigin;
                float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
                float3 outNormal = float3(0);
                float3 position = rayOrigin + rayDirection * outShape.y;

                float4 shape = outShape;

                \(normalCode)
                \(materialBumpCode)
        
                // Sun
                {
                    struct MaterialOut materialOut;
                    materialOut.color = float4(0,0,0,1);
                    materialOut.mask = float3(0);
                    
                    float3 hitPosition = position;
                    float3 directionToLight = normalize(lights.lights[0].directionToLight.xyz);
                    float4 lightType = float4(0);
                    float4 lightColor = lights.lights[0].lightColor;
                    float shadow = shadows.y;
                    float occlusion = shadows.x;
                    float3 mask = float3(1);
                                                
                    \(materialCode)
                    outColor += materialOut.color;
        
                    reflectionShape = float4(1000, 1000, -1, -1);
                    reflectionDir.xyz = materialOut.reflectionDir;
                    reflectionDir.w = materialOut.reflectionDist;
                    maskOut.xyz = materialOut.mask * shadows.y;
                }
        
                \(lightSamplingCode)
        
                outColor.xyz += uniforms.ambientColor.xyz;
            }
        
            maskTextureOut.write(half4(maskOut), textureUV);
            reflectionTextureOut.write(half4(reflectionShape), textureUV);
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
                                    texture2d<half, access::read> camDirectionTexture [[texture(5)]],
                                    texture2d<int, access::sample> terrainTexture [[texture(6)]])
        {
            __REFLECTION_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &terrainTexture;

            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 shape = float4(depthTexture.read(textureUV));
        
            float4 inShape = float4(1000, 1000, -1, -1);
            float4 outShape = inShape;
        
            // Check if anything ELSE reflects on the terrain
            if (shape.w > -0.4 && (shape.w < \(idStart - 0.1) || shape.w > \(idEnd + 0.1)))
            {
                float maxDistance = 10.0;
            
                float3 camOrigin = uniforms.cameraOrigin;
                float3 camDirection = float3(camDirectionTexture.read(textureUV).xyz);
            
                float3 rayOrigin = camOrigin + shape.y * camDirection;
                float4 direction = float4(reflectionDirTexture.read(textureUV));
                float3 rayDirection = direction.xyz;
                rayOrigin += direction.w * rayDirection;
        
                \(raymarchCode)
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
                                     texture2d<int, access::sample> terrainTexture [[texture(7)]],
                                     texture2d<half, access::read> maskTexture [[texture(8)]])
         {
             __REFLMATERIAL_INITIALIZE_FUNC_DATA__
             __funcData->terrainTexture = &terrainTexture;

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
                 float4 outShape = shape;
         
                \(normalCode)
                \(materialBumpCode)

                 // Sun
                 {
                     struct MaterialOut materialOut;
                     materialOut.color = float4(0,0,0,1);
                     materialOut.mask = float3(0);
                     
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
                     outColor.xyz += materialOut.color.xyz * mask.xyz;
                     outColor.w = 1.0;
                 }
         
                 \(lightSamplingCode)
             }
         
             return outColor;
         }
        
        kernel void sphereContacts( constant float4 *__data [[ buffer(0) ]],
                                    constant float4 *sphereIn [[ buffer(1) ]],
                                     device float4  *sphereOut [[ buffer(2) ]],
                            constant SphereUniforms &uniforms [[ buffer(3) ]],
                     texture2d<int, access::sample> terrainTexture [[texture(4)]],
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
            __funcData->terrainTexture = &terrainTexture;

            float4 out = float4(0,0,0,0);
        
            for( int i = 0; i < uniforms.numberOfSpheres; ++i)
            {
                float3 position = sphereIn[i].xyz;

                float4 rc = sceneMap(position, __funcData);
                out.w = rc.x - sphereIn[i].w;
        
                if (out.w < 0) {
                    float3 outNormal = float3(0,0,0);
                    \(normalCode)
                    out.xyz = outNormal;
                }
        
                sphereOut[gid + i] = out;
            }
        }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "MAIN", textureOffset: 4, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "MATERIAL", fragmentName: "materialFragment", textureOffset: 13, blending: true),
            Shader(id: "SHADOW", fragmentName: "shadowFragment", textureOffset: 7, pixelFormat: .rg16Float, blending: false),
            Shader(id: "REFLECTION", fragmentName: "reflectionFragment", textureOffset: 7, blending: false),
            Shader(id: "REFLMATERIAL", fragmentName: "reflMaterialFragment", textureOffset: 9, addition: true)
        ])        
    }
    
    override func render(texture: MTLTexture)
    {
        updateData()
        
        if let mainShader = shaders["MAIN"] {
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShapeTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( prtInstance.quadViewport! )
            renderEncoder.setVertexBuffer(prtInstance.quadVertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = createFragmentUniform()

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 2)
            if let terrain = globalApp!.artistEditor.getTerrain() {
                renderEncoder.setFragmentTexture(terrain.getTexture(), index: 3)
            }
            applyUserFragmentTextures(shader: mainShader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
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
            if let terrain = globalApp!.artistEditor.getTerrain() {
                renderEncoder.setFragmentTexture(terrain.getTexture(), index: 6)
            }
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
            
            var fragmentUniforms = createFragmentUniform()
            var lightUniforms = prtInstance.utilityShader!.createLightStruct()

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            renderEncoder.setFragmentBytes(&lightUniforms, length: MemoryLayout<LightUniforms>.stride, index: 2)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentShadowTexture!, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 5)
            renderEncoder.setFragmentTexture(prtInstance.otherReflTexture, index: 6)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 7)
            renderEncoder.setFragmentTexture(prtInstance.otherReflDirTexture, index: 8)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 9)
            if let terrain = globalApp!.artistEditor.getTerrain() {
                renderEncoder.setFragmentTexture(terrain.getTexture(), index: 10)
            }
            renderEncoder.setFragmentTexture(prtInstance.currentMaskTexture!, index: 11)
            renderEncoder.setFragmentTexture(prtInstance.otherMaskTexture!, index: 12)
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
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)

            renderEncoder.setFragmentTexture(prtInstance.currentShapeTexture!, index: 2)
            renderEncoder.setFragmentTexture(prtInstance.currentReflTexture, index: 3)
            renderEncoder.setFragmentTexture(prtInstance.currentReflDirTexture, index: 4)
            renderEncoder.setFragmentTexture(prtInstance.camDirTexture!, index: 5)
            if let terrain = globalApp!.artistEditor.getTerrain() {
                renderEncoder.setFragmentTexture(terrain.getTexture(), index: 6)
            }
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
            if let terrain = globalApp!.artistEditor.getTerrain() {
                renderEncoder.setFragmentTexture(terrain.getTexture(), index: 7)
            }
            renderEncoder.setFragmentTexture(prtInstance.currentMaskTexture!, index: 8)
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
        }
    }
    
    func generateMaterialCode(terrain: Terrain) -> String
    {
        var headerCode = ""
        var materialFuncCode = ""
        
        var materialIdCounter : Int = 0

        func processMaterial(materialStageItem: StageItem, processBumps: Bool = false)
        {
            materialFuncCode +=
            """
            
            void material\(materialIdCounter)(float3 rayOrigin, float3 incomingDirection, float3 hitPosition, float3 hitNormal, float3 directionToLight, float4 lightType,
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
                float outReflectionDist = 0.;
                
                float3 localPosition = hitPosition;
                
            """
           
            // Get the patterns of the material if any
            let material = materialStageItem.components[materialStageItem.defaultName]!
            let patterns : [CodeComponent] = material.components

            dryRunComponent(material, data.count, patternList: patterns)
            collectProperties(material)
            if let globalCode = material.globalCode {
                headerCode += globalCode
            }
            if let code = material.code {
               materialFuncCode += code
            }
            
            if processBumps {
                // Check if material has a bump
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
                            float2 outUV = float2(position.xz);
                            float bumpFactor = 0.2;
                        
                            // bref
                            struct PatternOut data;
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float bRef = data.\(conn.1);
                        
                            const float2 e = float2(.001, 0);
                        
                            // b1
                            position = realPosition - e.xyy;
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float b1 = data.\(conn.1);
                        
                            // b2
                            position = realPosition - e.yxy;
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float b2 = data.\(conn.1);
                        
                            // b3
                            position = realPosition - e.yyx;
                            \(conn.3)(outUV, position, position, normal, float3(0), &data, __funcData );
                            float b3 = data.\(conn.1);
                        
                            float3 grad = (float3(b1, b2, b3) - bRef) / e.x;
                        
                            grad -= normal * dot(normal, grad);
                            outNormal = normalize(normal + grad * bumpFactor);
                        }

                        """
                    }
                }
                
                //terrainMapCode = terrainMapCode.replacingOccurrences(of: "__BUMP_CODE_\(materialIdCounter)__", with: bumpCode)
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
            
            if (outShape.z > \(Float(materialIdCounter) - 0.5) && outShape.z < \(Float(materialIdCounter) + 0.5))
            {
            """
            
            materialCode +=
                
            """
               
                material\(materialIdCounter)(rayOrigin, rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &materialOut, __funcData);
            }

            """
                            
            // Push it on the stack
            //instance.materialIds[materialIdCounter] = stageItem
            //currentMaterialId = materialIdCounter
            materialIdCounter += 1
        }
        
        for (index, stageItem) in terrain.materials.enumerated() {
            processMaterial(materialStageItem: stageItem, processBumps: index == 0 ? true : false)
        }
        
        /*
        let codeBuilder = CodeBuilder(globalApp!.mmView)
        codeBuilder.sdfStream.openStream(.SDF3D, CodeBuilderInstance(), codeBuilder)

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
                

                codeBuilder.sdfStream.pushStageItem(object)
                for shape in shapes {
                    codeBuilder.sdfStream.pushComponent(shape)
                }
                processChildren(object)
                codeBuilder.sdfStream.pullStageItem()
                                    
                codeBuilder.sdfStream.mapCode = codeBuilder.sdfStream.mapCode.replacingOccurrences(of: "float4 sceneMap(", with: "float4 sceneMap\(index+1)(")
            }
        }
        
        codeBuilder.sdfStream.closeStream()
        headerCode += codeBuilder.sdfStream.mapCode
        */

        return headerCode + materialFuncCode
    }
    
    override func sphereContacts(objectSpheres: [ObjectSpheres3D])
    {
        if sphereContactsState == nil {
            sphereContactsState = createComputeState(name: "sphereContacts")
        }
         
        if let state = sphereContactsState {
                         
            updateData()
             
            let commandQueue = device.makeCommandQueue()
            let commandBuffer = commandQueue!.makeCommandBuffer()!
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
             
            computeEncoder.setComputePipelineState( state )
            computeEncoder.setBuffer(buffer, offset: 0, index: 0)
             
            var sphereUniforms = SphereUniforms()
            
            var sphereData : [float4] = []
            
            for oS in objectSpheres {
                for s in oS.transSpheres {
                    sphereData.append(s)
                }
            }
            
            sphereUniforms.numberOfSpheres = Int32(sphereData.count)
            
            let inBuffer = device.makeBuffer(bytes: sphereData, length: sphereData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            computeEncoder.setBuffer(inBuffer, offset: 0, index: 1)

            let outBuffer = device.makeBuffer(length: sphereData.count * MemoryLayout<SIMD4<Float>>.stride, options: [])!
            computeEncoder.setBuffer(outBuffer, offset: 0, index: 2)
            computeEncoder.setBytes(&sphereUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 3)

            if let terrain = globalApp!.artistEditor.getTerrain() {
                computeEncoder.setTexture(terrain.getTexture(), index: 4)
            }
            
            let numThreadgroups = MTLSize(width: 1, height: 1, depth: 1)
            let threadsPerThreadgroup = MTLSize(width: 1, height: 1, depth: 1)
            computeEncoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerThreadgroup)
             
            computeEncoder.endEncoding()
            commandBuffer.commit()
             
            commandBuffer.waitUntilCompleted()
             
            let result = outBuffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: 1)
            
            var index : Int = 0
            for oS in objectSpheres {
                for (ii,s) in oS.transSpheres.enumerated() {
                    
                    if result[index].w < 0 {
                        let penetration = -result[index].w
                        let hitNormal = float3(result[index].x, result[index].y, result[index].z)
                        let contactPoint = float3(s.x, s.y, s.z) + -hitNormal * (s.w - penetration)
                    
                        oS.sphereHits[ii] = true
                        
                        let contact = RigidBody3DContact(body: [oS.body3D, nil], contactPoint: _Vector3(contactPoint), normal: _Vector3(hitNormal), penetration: Double(penetration))
                        if let restitution = oS.object.components[oS.object.defaultName]!.values["restitution"] {
                            contact.restitution = Double(restitution)
                        }
                        if let friction = oS.object.components[oS.object.defaultName]!.values["friction"] {
                            contact.friction = Double(friction)
                        }
                        oS.world!.contacts.append(contact)
                    }                    
                    index += 1
                }
            }
        }
    }
}
