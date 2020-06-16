//
//  ObjectShader.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectShader  : BaseShader
{
    var scene       : Scene
    var object      : StageItem
    var camera      : CodeComponent
    
    var bbTriangles : [Float] = []
    
    init(instance: PRTInstance, scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
        
        super.init(instance: instance)
        
        buildShader()
    }
    
    func buildShader()
    {
        let vertexShader =
        """
        
        typedef struct {
            matrix_float4x4     modelMatrix;
            matrix_float4x4     viewMatrix;
            matrix_float4x4     projectionMatrix;
        } ObjectVertexUniforms;

        typedef struct {
            simd_float3         cameraOrigin;
            simd_float3         cameraLookAt;
            
            simd_float2         screenSize;
        } ObjectFragmentUniforms;

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
            //out.screenPosition = uniforms.projectionMatrix * uniforms.viewMatrix * float4(triangles[vid]);

            return out;
        }

        """
        
        var headerCode = ""
        let mapCode = createMapCode()
        print(mapCode)
        
        let rayMarch = findDefaultComponentForStageChildren(stageType: .RenderStage, componentType: .RayMarch3D)!
        
        dryRunComponent(rayMarch, data.count)
        collectProperties(rayMarch)
        if let globalCode = rayMarch.globalCode {
            headerCode += globalCode
        }
        
        let fragmentShader =
        """
        
        \(mapCode)

        fragment half4 procFragment(VertexOut vertexIn [[stage_in]],
                                    constant float4 *__data [[ buffer(2) ]],
                                    constant ObjectFragmentUniforms &uniforms [[ buffer(3) ]])
        //                                    texture2d<half, access::write> depthTexture [[texture(0)]] )
        {
            //constexpr sampler sampler(mag_filter::linear, min_filter::linear);
        
            __INITIALIZE_FUNC_DATA__
        
            
            float2 size = uniforms.screenSize;
            /*
            float2 uv = (vertexIn.screenPosition.xyz / vertexIn.screenPosition.w).xy;
            uv = uv * 0.5 + 0.5;
            uv.y = 1 - uv.y;
        
            float3 outPosition = float3(0,0,0);
            float3 outDirection = float3(0,0,0);
            float2 jitter = float2(0.5);
        
            */
            float3 position = vertexIn.worldPosition.xyz;
        
            float3 rayOrigin = position;//uniforms.cameraOrigin;//position;
            float3 rayDirection = normalize(position - uniforms.cameraOrigin);

            float4 outShape = float4(1000, 1000, -1, -1);
            float maxDistance = 1000;

            //__funcData->inShape = float4(1000, 1000, -1, -1);
            //__funcData->inHitPoint = rayOrigin + rayDirection * outShape.y;

            \(rayMarch.code!)

            float4 outColor = float4(0);
        
            if (outShape.w >= 0) {
                outColor = float4(1);
            }
        
            //return half4(uv.x, uv.y, 0, 1);
            //return half4(half3(outShape.w), 1.0);
            //return half4(half3(outColor.xyz), 1.0);
        
            return half4(outColor);
        }

        """
                
        compile(vertexCode: vertexShader, fragmentCode: fragmentShader, textureOffset: 2)
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

    override func render(texture: MTLTexture)
    {
        updateData()

        if bbTriangles.count == 0 { return }
        let dataSize = bbTriangles.count * MemoryLayout<Float>.size
        let vertexBuffer = device.makeBuffer(bytes: bbTriangles, length: dataSize, options: [])

        var mTranslation = matrix_identity_float4x4
        var mRotation = matrix_identity_float4x4
        var mScale = matrix_identity_float4x4

        if let transform = self.object.components[self.object.defaultName] {
            let scale = transform.values["_scale"]!
            
            mTranslation = float4x4(translation: [transform.values["_posX"]!, transform.values["_posY"]!, transform.values["_posZ"]!])
            mRotation = float4x4(rotation: [transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians])
            
            if transform.values["_bb_x"] == nil {
                transform.values["_bb_x"] = 1
                transform.values["_bb_y"] = 1
                transform.values["_bb_z"] = 1
            }
            
            mScale = float4x4(scaling: [(transform.values["_bb_x"]! * scale), (transform.values["_bb_y"]! * scale), (transform.values["_bb_z"]! * scale)])
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        
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
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 2)
        renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<ObjectFragmentUniforms>.stride, index: 3)

        //renderEncoder.setFragmentTexture(prtInstance.depthTexture!, index: 0)
        
        // ---
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: bbTriangles.count / 4)
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    func createMapCode() -> String
    {
        var hierarchy           : [StageItem] = []
        
        var headerCode = ""
        var mapCode = """

        float4 sceneMap( float3 __origin, thread struct FuncData *__funcData )
        {
            float3 __originBackupForScaling = __origin;
            float3 __objectPosition = float3(0);
            float outDistance = 10;
            float bump = 0;
            float scale = 1;

            //float4 outShape = __funcData->inShape;
            //outShape.x = length(__origin - __funcData->inHitPoint) + 0.5;

            float4 outShape = float4(1000, 1000, -1, -1);

            constant float4 *__data = __funcData->__data;
            float GlobalTime = __funcData->GlobalTime;
            float GlobalSeed = __funcData->GlobalSeed;

        """
                        
        func pushComponent(component: CodeComponent)
        {
            dryRunComponent(component, data.count)
            collectProperties(component)//, hierarchy)
            
            if let globalCode = component.globalCode {
                headerCode += globalCode
            }
            
            if let code = component.code {
                
                let posX = getTransformPropertyIndex(component, "_posX")
                let posY = getTransformPropertyIndex(component, "_posY")
                let posZ = getTransformPropertyIndex(component, "_posZ")
                
                let rotateX = getTransformPropertyIndex(component, "_rotateX")
                let rotateY = getTransformPropertyIndex(component, "_rotateY")
                let rotateZ = getTransformPropertyIndex(component, "_rotateZ")
                
                mapCode += """
                
                    {
                        float3 __originalPosition = float3(__data[\(posX)].x, __data[\(posY)].x, __data[\(posZ)].x);
                        float3 position = __translate(__origin, __originalPosition);
                        float3 __offsetFromCenter = __objectPosition - __originalPosition;

                        position.yz = rotatePivot( position.yz, radians(__data[\(rotateX)].x\(getInstantiationModifier("_rotateRandomX", component.values))), __offsetFromCenter.yz );
                        position.xz = rotatePivot( position.xz, radians(__data[\(rotateY)].x\(getInstantiationModifier("_rotateRandomY", component.values))), __offsetFromCenter.xz );
                        position.xy = rotatePivot( position.xy, radians(__data[\(rotateZ)].x\(getInstantiationModifier("_rotateRandomZ", component.values))), __offsetFromCenter.xy );
                
                """
                mapCode += code
                
                mapCode += """
                
                    float4 shapeA = outShape;
                    float4 shapeB = float4((outDistance - bump) * scale, 0, 1, 1);
                
                """
                
                if let subComponent = component.subComponent {
                    dryRunComponent(subComponent, data.count)
                    collectProperties(subComponent)
                    mapCode += subComponent.code!
                }
                
                mapCode += """
                
                }
                
                """
            }
        }
        
        if let shapes = object.getComponentList("shapes") {
            for shape in shapes {
                pushComponent(component: shape)
            }
        }
        
        mapCode += """

            return outShape;
        }
        
        """
        
        return headerCode + mapCode
    }

}
