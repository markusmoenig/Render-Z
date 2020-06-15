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
    
    init(scene: Scene, object: StageItem, camera: CodeComponent)
    {
        self.scene = scene
        self.object = object
        self.camera = camera
        
        super.init()
        
        buildShader()
    }
    
    func buildShader()
    {
        let vertexShader =
        """
        
        typedef struct {
            matrix_float4x4 modelMatrix;
            matrix_float4x4 viewMatrix;
            matrix_float4x4 projectionMatrix;
        } ObjectUniforms;

        struct VertexOut{
            float4 position[[position]];
        };

        vertex VertexOut procVertex(const device packed_float4 *points [[ buffer(0) ]],
                                    constant ObjectUniforms &uniforms [[ buffer(1) ]],
                                    unsigned int vid [[ vertex_id ]] )
        {
            VertexOut out;

            out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * float4(points[vid]);
            
            return out;
        }

        """
        
        let fragmentShader =
        """

        fragment half4 procFragment()
        {
            return half4(1.0);
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
        if bbTriangles.count == 0 { return }
        let dataSize = bbTriangles.count * MemoryLayout<Float>.size
        let vertexBuffer = device.makeBuffer(bytes: bbTriangles, length: dataSize, options: [])
        
        let camHelper = CamHelper3D()
        camHelper.initFromComponent(aspect: Float(texture.width) / Float(texture.height), component: camera)
        //var matrix = camHelper.getTransform()
        //memcpy(renderParams?.contents(), camHelper.getMatrix().m, MemoryLayout<matrix_float4x4>.size)
        
        camHelper.updateProjection()

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
        
        var uniforms = ObjectUniforms();
        uniforms.projectionMatrix = camHelper.projMatrix
        uniforms.modelMatrix = mTranslation * mRotation * mScale
        uniforms.viewMatrix = camHelper.getTransform().inverse
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<ObjectUniforms>.stride, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: bbTriangles.count / 4)
        renderEncoder.endEncoding()
        
        commandBuffer.commit()
    }
}
