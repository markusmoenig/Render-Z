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
    
    var instance        : PRTInstance
    
    var id              : Int = -1

    init(scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
        
        instance = PRTInstance()
        
        super.init(instance: instance)
        self.rootItem = object

        let objectShader = object.shader as? ObjectShader
        if let shader = objectShader {
            claimedIds = shader.claimedIds
        }
            
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

            float selectedId = uniforms.ambientColor.x;

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

                    float4 shape = sceneMap(pos, __funcData);
                    dist = shape.x;

                    if (isNotEqual(shape.w, selectedId)) {
                        float3 c = float3(max(0., .001 - abs(dist)) * 4.5);
                        outColor.xyz += c;
                    } else {
                        float3 c = max(0., .001 - abs(dist)) * 4.5 * float3(0.278, 0.553, 0.722);
                        outColor.xyz += c;
                    }

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
            fragmentUniforms.ambientColor.x = Float(id)

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

            let id = claimedIds[componentCounter]

            code +=
            """
             
            float4 shapeA = outShape;
            float4 shapeB = float4((outDistance /*- bump*/) * scale, -1, 0, \(id));
             
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
            //claimedIds.append(id)
            //ids[id] = (hierarchy, component)

            componentCounter += 1
        }
        
        func pushStageItem(_ stageItem: StageItem)
        {
            if stageItem.componentLists["nodes3D"] == nil {
                stageItem.addNodes3D()
            }
            
            hierarchy.append(stageItem)

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
            _ = hierarchy.removeLast()
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

        return headerCode + mapCode
    }
}
