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
    
    init(instance: PRTInstance, scene: Scene, object: StageItem, camera: CodeComponent)
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

        let lightSamplingCode = prtInstance.utilityShader.createLightSamplingMaterialCode(materialCode: "material0(rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);")

        var headerCode = ""
        terrainMapCode =
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
        
        let mainMaterialCode = generateMaterialCode(terrain: terrain)
        
        var raymarchCode = ""
        if let rayMarch = terrain.rayMarcher {
            dryRunComponent(rayMarch, data.count)
            collectProperties(rayMarch)
            if let globalCode = rayMarch.globalCode {
                headerCode += globalCode
            }
            if let code = rayMarch.code {
                raymarchCode = code.replacingOccurrences(of: "sceneMap", with: "terrainMapCode")
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
                normalCode = code.replacingOccurrences(of: "sceneMap", with: "terrainMapCode")
            }
        }
        
        print(normalCode)
                
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
                                     texture2d<int, access::sample> __terrainTexture [[texture(3)]])
        {
            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            __MAIN_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &__terrainTexture;

            float3 position = float3(uv.x, uv.y, 0);
                    
            float3 rayOrigin = uniforms.cameraOrigin;
            float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
            float4 outShape = float4(1000, 1000, -1, -1);
            float3 outNormal = float3(0);
            float maxDistance = 100.0;
        
            \(raymarchCode)
            return outShape;
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
                                    texture2d<int, access::sample> __terrainTexture [[texture(10)]])
        {
            __MATERIAL_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &__terrainTexture;

            float2 size = in.viewportSize;
            float2 uv = float2(in.textureCoordinate.x, in.textureCoordinate.y);
            ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

            float4 outColor = float4(0,0,0,0);

            float4 reflectionShape = float4(reflectionTextureIn.read(textureUV));
            float4 reflectionDir = float4(reflectionDirTextureIn.read(textureUV));
        
            float4 outShape = float4(shapeTexture.read(textureUV));
            if (isEqual(outShape.w, 0.0)) {
                float2 shadows = float2(shadowTexture.read(textureUV).xy);
            
                float3 rayOrigin = uniforms.cameraOrigin;
                float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);
        
                float3 outNormal = float3(0);
                float3 position = rayOrigin + rayDirection * outShape.y;
        
                \(normalCode)
        
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
                    reflectionDir.w = materialOut.mask.x * shadows.y;
                }
        
                \(lightSamplingCode)
            }
        
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
                                    texture2d<int, access::sample> __terrainTexture [[texture(6)]])
        {
            __REFLECTION_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &__terrainTexture;

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
                float3 rayDirection = float3(reflectionDirTexture.read(textureUV).xyz);

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
                                     texture2d<int, access::sample> __terrainTexture [[texture(7)]])
         {
             __REFLMATERIAL_INITIALIZE_FUNC_DATA__
            __funcData->terrainTexture = &__terrainTexture;

             float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
             float2 size = uniforms.screenSize;
             ushort2 textureUV = ushort2(uv.x * size.x, (1.0 - uv.y) * size.y);

             float4 outColor = float4(0);
             float4 shape = float4(depthTexture.read(textureUV));
             float4 reflectionShape = float4(reflectionTexture.read(textureUV));

             if (reflectionShape.w >= \(idStart - 0.1) && reflectionShape.w <= \(idEnd + 0.1))
             {
                 float2 shadows = float2(1,1);

                 float3 rayOrigin = uniforms.cameraOrigin;
                 float3 rayDirection = float3(camDirectionTexture.read(textureUV).xyz);

                 float4 reflectionDir = float4(reflectionDirTexture.read(textureUV));

                 float3 position = (rayOrigin + shape.y * rayDirection) + reflectionDir.xyz * reflectionShape.y;
                 float3 outNormal = float3(0);
                 float4 outShape = shape;
         
                \(normalCode)

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

                     material0(rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &__materialOut, __funcData);
        
                     outColor.xyz += __materialOut.color.xyz * reflectionDir.w;
                     outColor.w = 1.0;
                 }
         
                 \(lightSamplingCode)
             }
         
             return outColor;
         }

        """
        
        compile(code: BaseShader.getQuadVertexSource() + fragmentCode, shaders: [
            Shader(id: "MAIN", textureOffset: 4, pixelFormat: .rgba16Float, blending: false),
            Shader(id: "MATERIAL", fragmentName: "materialFragment", textureOffset: 11, blending: true),
            Shader(id: "REFLECTION", fragmentName: "reflectionFragment", textureOffset: 7, blending: false),
            Shader(id: "REFLMATERIAL", fragmentName: "reflMaterialFragment", textureOffset: 8, addition: true)
        ])
        
        prtInstance.idCounter += 1
    }
    
    override func render(texture: MTLTexture)
    {
        updateData()
        
        if let mainShader = shaders["MAIN"] {
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherShapeTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
            
            let commandBuffer = mainShader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(mainShader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(prtInstance.screenSize.x), Float(prtInstance.screenSize.y) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

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
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
        }
    }
    
    override func materialPass(texture: MTLTexture)
    {
        if let shader = shaders["MATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let commandBuffer = shader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(prtInstance.screenSize.x), Float(prtInstance.screenSize.y) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            var lightUniforms = prtInstance.utilityShader.createLightStruct()

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
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
        }
    }
    
    override func reflectionPass(texture: MTLTexture)
    {
        if let shader = shaders["REFLECTION"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = prtInstance.otherReflTexture!
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let commandBuffer = shader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(prtInstance.screenSize.x), Float(prtInstance.screenSize.y) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
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
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
        }
    }
    
    override func reflectionMaterialPass(texture: MTLTexture)
    {
        if let shader = shaders["REFLMATERIAL"] {
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .load
            
            let commandBuffer = shader.commandQueue.makeCommandBuffer()!
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            renderEncoder.setViewport( MTLViewport( originX: 0.0, originY: 0.0, width: Double(prtInstance.screenSize.x), height: Double(prtInstance.screenSize.y), znear: -1.0, zfar: 1.0 ) )
            
            let vertexBuffer = getQuadVertexBuffer(MMRect(0, 0, Float(prtInstance.screenSize.x), Float(prtInstance.screenSize.y) ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32(prtInstance.screenSize.x), UInt32(prtInstance.screenSize.y) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = ObjectFragmentUniforms()
            fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
            fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
            fragmentUniforms.screenSize = prtInstance.screenSize

            var lightUniforms = prtInstance.utilityShader.createLightStruct()
            
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
            applyUserFragmentTextures(shader: shader, encoder: renderEncoder)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer.addCompletedHandler { cb in
                globalApp!.executionTime += cb.gpuEndTime - cb.gpuStartTime
            }
            
            commandBuffer.commit()
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
            
            dryRunComponent(material, data.count, patternList: patterns)
            collectProperties(material)
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
            
            if (outShape.z > \(Float(materialIdCounter) - 0.5) && outShape.z < \(Float(materialIdCounter) + 0.5))
            {
            """
            
            materialCode +=
                
            """
               
                material\(materialIdCounter)(rayDirection, hitPosition, outNormal, directionToLight, lightType, lightColor, shadow, occlusion, &materialOut, __funcData);
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
        
        for layer in terrain.layers.reversed() {
            if let material = layer.material {
                processMaterial(materialStageItem: material, processBumps: true)
            } else {
                //currentMaterialId = materialIdCounter
                materialIdCounter += 1
            }
        }
        
        let codeBuilder = CodeBuilder(globalApp!.mmView)
        
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

                let gComponent = codeBuilder.sdfStream.isGroundComponent
                codeBuilder.sdfStream.isGroundComponent = nil
                
                codeBuilder.sdfStream.pushStageItem(object)
                for shape in shapes {
                    codeBuilder.sdfStream.pushComponent(shape)
                }
                processChildren(object)
                codeBuilder.sdfStream.pullStageItem()
                                    
                codeBuilder.sdfStream.mapCode = codeBuilder.sdfStream.mapCode.replacingOccurrences(of: "float4 sceneMap(", with: "float4 sceneMap\(index+1)(")
                codeBuilder.sdfStream.isGroundComponent = gComponent
            }
        }
        return headerCode + materialFuncCode
    }
}
