//
//  Physics3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 18/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation
//import JavaScriptCore
import MetalKit
import SceneKit

class ObjectSpheres3D
{
    // Incoming statics
    var spheres         : [float4]
    var object          : StageItem
    var transform       : CodeComponent
    
    // Refreshed once per frame
    var position        : float4 = float4(0,0,0,0)
    var rotation        : float3 = float3(0,0,0)
    
    // Results per frame
    var transSpheres    : [float4] = []
    var contactPoint    : float3 = float3(0,0,0)
    var hitNormal       : float3 = float3(0,0,0)
    var penetrationDepth: Float = Float.greatestFiniteMagnitude

    var body3D          : RigidBody3D? = nil
    var world           : RigidBody3DWorld? = nil

    var hitObject       : StageItem? = nil
    
    init(spheres: [float4], object: StageItem, transform: CodeComponent)
    {
        self.spheres = spheres
        self.object = object
        self.transform = transform
    }
    
    func updateTransformData() -> [float4]
    {
        var debugSpheres : [float4] = []
        
        position.x = transform.values["_posX"]!
        position.y = transform.values["_posY"]!
        position.z = transform.values["_posZ"]!
        
        rotation.x = transform.values["_rotateX"]!
        rotation.y = transform.values["_rotateY"]!
        rotation.z = transform.values["_rotateZ"]!
        
        transSpheres = spheres
        
        for (i,s) in spheres.enumerated() {
            //let rotated = Physics3D.rotateWithPivot(float3(s.x + position.x, s.y + position.y, s.z + position.z), rotation, float3(position.x, position.y, position.z))
            let rotated = body3D!.transformMatrix.multiplyWithVector(_Vector3(s.x, s.y, s.z))
            print("--", i, rotated.x, rotated.y, rotated.z)

            transSpheres[i].x = rotated.x
            transSpheres[i].y = rotated.y
            transSpheres[i].z = rotated.z
            
            debugSpheres.append(transSpheres[i])
        }
        
        penetrationDepth = -1000
        
        return debugSpheres
    }
}

class Physics3D
{
    var scene           : Scene
    
    var objects         : [StageItem] = []
    var valueCopies     : [[String:Float]] = []
    
    var lastTime        : Double? = nil
    
    var primShader      : PrimitivesShader? = nil
    
    var debug           : Bool = true
    
    var particleWorld   : Particle3DWorld
    var rigidBodyWorld  : RigidBody3DWorld

    var objectSpheres   : [ObjectSpheres3D] = []
    
    var groundShader    : GroundShader? = nil
    var terrainShader   : TerrainShader? = nil
    
    var debugSpheres : [float4] = []

    init(scene: Scene)
    {
        self.scene = scene
        particleWorld = Particle3DWorld()
        rigidBodyWorld = RigidBody3DWorld()
        setup()
    }
    
    func setup()
    {
        func isDisabled(shader: BaseShader) -> Bool
        {
            var disabled = false
            if let root = shader.rootItem {
                if root.values["disabled"] == 1 {
                    disabled = true
                }
            }
            return disabled
        }
        
        let shapeStage = scene.getStage(.ShapeStage)
        for (_, object) in shapeStage.getChildren().enumerated() {
            
            if let ground = object.shader as? GroundShader {
                
                if isDisabled(shader: ground) == false {
                    groundShader = ground
                }
                
                continue
            }
            
            if let shader = object.shader as? TerrainShader {
                
                if isDisabled(shader: shader) == false {
                    terrainShader = shader
                }
                
                continue
            }
            
            let transform = object.components[object.defaultName]!
            if transform.componentType == .Transform3D {
                
                if let shader = object.shader as? ObjectShader, isDisabled(shader: shader) == false {
                    let spheres = shader.buildSpheres()
                                        
                    objects.append(object)
                    valueCopies.append(transform.values)
                    
                    let objectSpheres = ObjectSpheres3D(spheres: spheres, object: object, transform: transform)
                    let body = RigidBody3D(object, objectSpheres)
                    objectSpheres.body3D = body
                    objectSpheres.world = rigidBodyWorld
                    self.objectSpheres.append(objectSpheres)
                    body.setPosition(_Vector3(transform.values["_posX"]!, transform.values["_posY"]!, transform.values["_posZ"]!))
                    
                    let node = SCNNode()
                    node.simdEulerAngles = float3(transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians)
                    body.setOrientation(node.simdOrientation.real, node.simdOrientation.imag.x, node.simdOrientation.imag.y, node.simdOrientation.imag.z)
                    body.orientation.normalise()
                    
                    body.setMass(mass: 5)
                    rigidBodyWorld.addBody(body)
                }
            }
        }
        
        if debug {
            let preStage = scene.getStage(.PreStage)
            let result = getFirstItemOfType(preStage.getChildren(), .Camera3D)
            let cameraComponent = result.1!
            
            primShader = PrimitivesShader(instance: PRTInstance(), camera: cameraComponent)
        }
    }
    
    func end()
    {
        for (index, object) in objects.enumerated() {
            let transform = object.components[object.defaultName]!
            transform.values = valueCopies[index]
        }
        globalApp!.currentEditor.render()
    }
    
    func step()
    {
        let time = Double(Date().timeIntervalSince1970)
        debugSpheres = []
        
        if let lTime = lastTime {
            let duration = Float(time - lTime)

            // Update the transform data of the spheres
            for s in objectSpheres {
                debugSpheres += s.updateTransformData()
            }
            
            // Do the contact resolution
            if let ground = groundShader {
                ground.sphereContacts(objectSpheres: objectSpheres)
            }
            
            if let terrain = terrainShader {
                terrain.sphereContacts(objectSpheres: objectSpheres)
            }
            
            // Step
            rigidBodyWorld.runPhysics(duration: duration)

            for body in rigidBodyWorld.bodies {
                let transform = body.object.components[body.object.defaultName]!

                transform.values["_posX"] = body.position.x
                transform.values["_posY"] = body.position.y
                transform.values["_posZ"] = body.position.z
                                
                let angles = body.transformMatrix.extractEulerAngleXYZ()
                transform.values["_rotateX"] = angles.x.radiansToDegrees
                transform.values["_rotateY"] = angles.y.radiansToDegrees
                transform.values["_rotateZ"] = angles.z.radiansToDegrees
            }
        } else {
            rigidBodyWorld.startFrame()
        }
        lastTime = time
    }
    
    func drawDebug(texture: MTLTexture)
    {
        if let prim = primShader {
            
            var sphereData  : [SIMD4<Float>] = []
            sphereData.append(SIMD4<Float>(1,0,0,0.5))
            sphereData += debugSpheres
            sphereData.append(SIMD4<Float>(-1,-1,-1,-1))

            prim.drawSpheres(texture: texture, sphereData: sphereData)
        }
    }
    
    static func rotateWithPivot(_ position: float3,_ angle: float3,_ pivot: float3) -> float3
    {
        func rotateCWWithPivot(_ pos : float2,_ angle: Float,_ pivot: float2 ) -> float2
        {
            let ca : Float = cos(angle), sa = sin(angle)
            return pivot + (pos-pivot) * float2x2(float2(ca, -sa), float2(sa, ca))
        }
        
        var pos = position
        
        
        let yz = rotateCWWithPivot(float2(pos.y, pos.z), angle.x.degreesToRadians, float2(pivot.y, pivot.z))
        pos.y = yz.x
        pos.z = yz.y
        let xz = rotateCWWithPivot(float2(pos.x, pos.z), angle.y.degreesToRadians, float2(pivot.x, pivot.z))
        pos.x = xz.x
        pos.z = xz.y
        let xy = rotateCWWithPivot(float2(pos.x, pos.y), angle.z.degreesToRadians, float2(pivot.x, pivot.y))
        pos.x = xy.x
        pos.y = xy.y
        
        /*
        let xy = rotateCWWithPivot(float2(pos.x, pos.y), angle.z.degreesToRadians, float2(pivot.x, pivot.y))
        pos.x = xy.x
        pos.y = xy.y
        
        let xz = rotateCWWithPivot(float2(pos.x, pos.z), angle.y.degreesToRadians, float2(pivot.x, pivot.z))
        pos.x = xz.x
        pos.z = xz.y
        
        let yz = rotateCWWithPivot(float2(pos.y, pos.z), angle.x.degreesToRadians, float2(pivot.y, pivot.z))
        pos.y = yz.x
        pos.z = yz.y*/
        

        return pos
    }
}
