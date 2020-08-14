//
//  XRayShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/8/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import simd
import MetalKit

class XRayShader      : BaseShader
{
    var scene           : Scene
    var object          : StageItem
    var camera          : CodeComponent
    
    // bbox buffer
    var P               = SIMD3<Float>(0,0,0)
    var L               = SIMD3<Float>(0,0,0)
    var F               : matrix_float3x3 = matrix_identity_float3x3

    var materialCode     = ""
    var materialBumpCode = ""
    
    var bbTriangles     : [Float] = []
    var claimedIds      : [Int] = []
    
    var instance        : PRTInstance

    init(scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
        
        instance = PRTInstance()
        
        super.init(instance: instance)
        self.rootItem = object

        buildShader()
    }
    
    deinit {
    }
    
    func buildShader()
    {
        dryRunComponent(camera, data.count)
        collectProperties(camera)
        
        var headerCode = ""
        
        let mapCode = createMapCode()

        if claimedIds.first != nil {
            idStart = Float(claimedIds.first!)
            idEnd = Float(claimedIds.last!)
        }
                
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
         
        let fragmentShader =
        """
        
        \(prtInstance.fragmentUniforms)
        \(camera.globalCode!)

        \(headerCode)
        \(mapCode)
        
        \(BaseShader.getQuadVertexSource())
        
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
        
        fragment float4 fullFragment(RasterizerData vertexIn [[stage_in]],
                                    constant float4 *__data [[ buffer(0) ]],
                                    constant FragmentUniforms &uniforms [[ buffer(1) ]])
        {
            __MAINFULL_INITIALIZE_FUNC_DATA__
        
            float2 uv = float2(vertexIn.textureCoordinate.x, vertexIn.textureCoordinate.y);
            float2 size = uniforms.screenSize;

            float4 outColor = float4( 0.125, 0.129, 0.137, 1);
            float maxDistance = uniforms.maxDistance;
        
            float3 outPosition = float3(0,0,0);
            float3 outDirection = float3(0,0,0);
            float2 jitter = float2(0.5);

            \(camera.code!)
            
            float d = bbox( outPosition, outDirection, uniforms.P, uniforms.L, uniforms.F );
            if (d > -0.5)
            {
                float3 rayOrigin = outPosition + (d - 1.0) * outDirection;
                float3 rayDirection = outDirection;

                float rayLength = 0.;
                float dist = 0.;

                for (float i = 0.; i < 400; i++)
                {
                    rayLength += max(0.0001, abs(dist) * 0.25);
                    float3 pos = rayOrigin + rayDirection * rayLength;

                    dist = sceneMap(pos, __funcData).x;

                    float3 c = float3(max(0., .001 - abs(dist)) * 1.5);

                    outColor.xyz += c;

                    if (rayLength > maxDistance + 2.0)
                        break;
                }

                //outColor.xyz = pow(outColor.xyz, float3(1. / 2.2));
            }
            return outColor;
        }
        
        """
        
        //print(fragmentShader)
                        
        compile(code: fragmentShader, shaders: [
            Shader(id: "MAINFULL", fragmentName: "fullFragment", textureOffset: 0, pixelFormat: .rgba16Float, blending: false)
        ], sync: false, drawWhenFinished: true)
    }
 
    override func render(texture: MTLTexture)
    {
        let oldData = rootItem!.components[rootItem!.defaultName]!.values
        rootItem!.components[rootItem!.defaultName]!.values["_posX"] = 0
        rootItem!.components[rootItem!.defaultName]!.values["_posY"] = 0
        rootItem!.components[rootItem!.defaultName]!.values["_posZ"] = 0
        rootItem!.components[rootItem!.defaultName]!.values["_rotateX"] = 0
        rootItem!.components[rootItem!.defaultName]!.values["_rotateY"] = 0
        rootItem!.components[rootItem!.defaultName]!.values["_rotateZ"] = 0
        rootItem!.components[rootItem!.defaultName]!.values["_scale"] = 1
        updateData()

        if let shader = shaders["MAINFULL"] {
            
            prtInstance.commandQueue = nil
            prtInstance.commandBuffer = nil
            
            let width : Float = Float(texture.width)
            let height : Float = Float(texture.height)
            
            prtInstance.screenSize.x = width
            prtInstance.screenSize.y = height

            prtInstance.commandQueue = globalApp!.mmView.device!.makeCommandQueue()
            prtInstance.commandBuffer = prtInstance.commandQueue!.makeCommandBuffer()
            
            let origin = getTransformedComponentProperty(camera, "origin")
            let lookAt = getTransformedComponentProperty(camera, "lookAt")
            
            prtInstance.cameraOrigin = SIMD3<Float>(origin.x, origin.y, origin.z)
            prtInstance.cameraLookAt = SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z)
            
            let renderPassDescriptor = MTLRenderPassDescriptor()
            renderPassDescriptor.colorAttachments[0].texture = texture
            renderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0, blue: 0, alpha: 0.0)
            
            let renderEncoder = prtInstance.commandBuffer!.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
            renderEncoder.setRenderPipelineState(shader.pipelineState)
            
            // --- Vertex
            let vertexData = getQuadVertexData(MMRect(0, 0, Float(texture.width), Float(texture.height) ) )
            renderEncoder.setVertexBytes(vertexData, length: vertexData.count * MemoryLayout<Float>.stride, index: 0)
            
            var viewportSize : vector_uint2 = vector_uint2( UInt32( texture.width ), UInt32( texture.height ) )
            renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, index: 1)
            
            // --- Fragment
            var fragmentUniforms = createFragmentUniform()

            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 1)
            // ---
            
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            prtInstance.commandBuffer!.commit()
            prtInstance.commandBuffer!.waitUntilCompleted()
        }
        rootItem!.components[rootItem!.defaultName]!.values = oldData
    }
    
    func isXrayValid() -> Bool
    {
        var rc : Bool = false

        if shaders["MAINFULL"] != nil {
            rc = true
        }
        return rc
    }
 
    override func createFragmentUniform() -> ObjectFragmentUniforms
    {
        var fragmentUniforms = ObjectFragmentUniforms()

        fragmentUniforms.cameraOrigin = prtInstance.cameraOrigin
        fragmentUniforms.cameraLookAt = prtInstance.cameraLookAt
        fragmentUniforms.screenSize = prtInstance.screenSize

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
    
    /// Returns the list of types inside the CodeComponent list
    func getComponentOfTypeFromList(_ list: [CodeComponent],_ type: CodeComponent.ComponentType) -> [CodeComponent]
    {
        var out : [CodeComponent] = []
        
        for c in list {
            if c.componentType == type {
                out.append(c)
            }
        }
        return out
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
            if component.components.count == 0 && hierarchy.last != nil {
                component.components = hierarchy.last!.createDefaultNodes()
            }
            
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
                    float3 position = __origin;

            """
            
            // Domain Modifiers (Both for the object and the component)
            var domainList : [CodeComponent] = []
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["nodes3D"] {
                    domainList += getComponentOfTypeFromList(list, .Domain3D)
                }
            }
            domainList += getComponentOfTypeFromList(component.components, .Domain3D)
            for domain in domainList {

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
            
            code +=
            """

                    float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                    position = __translate(position, __originalPosition);
                    float3 __offsetFromCenter = __objectPosition - __originalPosition;

                    position.yz = rotatePivot( position.yz, radians(__data[\(rotateX)].x\(getInstantiationModifier("_rotateRandomX", component.values))), __offsetFromCenter.yz );
                    position.xz = rotatePivot( position.xz, radians(__data[\(rotateY)].x\(getInstantiationModifier("_rotateRandomY", component.values))), __offsetFromCenter.xz );
                    position.xy = rotatePivot( position.xy, radians(__data[\(rotateZ)].x\(getInstantiationModifier("_rotateRandomZ", component.values))), __offsetFromCenter.xy );

            """
              
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
            
            
            // Domain Modifiers (Both for the object and the component)
            var modifierList : [CodeComponent] = []
            if let stageItem = hierarchy.last {
                if let list = stageItem.componentLists["nodes3D"] {
                    modifierList += getComponentOfTypeFromList(list, .Modifier3D)
                }
            }
            modifierList += getComponentOfTypeFromList(component.components, .Modifier3D)
            if modifierList.count > 0 {
                             
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

                for modifier in modifierList {
                         
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

            let id = prtInstance.claimId()

            code +=
            """
             
            float4 shapeA = outShape;
            float4 shapeB = float4((outDistance /*- bump*/) * scale, -1, \(currentMaterialId), \(id));
             
            """
            
            // Apply the boolean for the component
            let booleanList = getComponentOfTypeFromList(component.components, .Boolean)
            if booleanList.count > 0 {
                dryRunComponent(booleanList[0], data.count)
                collectProperties(booleanList[0])
                code += booleanList[0].code!
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
            if stageItem.componentLists["nodes3D"] == nil {
                stageItem.addNodes3D()
            }
            
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
}
