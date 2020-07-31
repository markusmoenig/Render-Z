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
    var worldPosition   : float3 = float3(0,0,0)
    var hitNormal       : float3 = float3(0,0,0)
    var penetrationDepth: Float = Float.greatestFiniteMagnitude

    var particle3D      : Particle3D? = nil
    var body3D          : RigidBody3D? = nil

    var hitObject       : StageItem? = nil
    
    init(spheres: [float4], object: StageItem, transform: CodeComponent)
    {
        self.spheres = spheres
        self.object = object
        self.transform = transform
    }
    
    func updateTransformData()
    {
        position.x = transform.values["_posX"]!
        position.y = transform.values["_posY"]!
        position.z = transform.values["_posZ"]!
        
        rotation.x = transform.values["_rotateX"]!
        rotation.y = transform.values["_rotateY"]!
        rotation.z = transform.values["_rotateZ"]!
        
        penetrationDepth = Float.greatestFiniteMagnitude
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
                    //let particle = Particle3D(object, objectSpheres)
                    let body = RigidBody3D(object, objectSpheres)
                    //objectSpheres.particle3D = particle
                    objectSpheres.body3D = body
                    self.objectSpheres.append(objectSpheres)
                    body.setPosition(_Vector3(transform.values["_posX"]!, transform.values["_posY"]!, transform.values["_posZ"]!))
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

        if let lTime = lastTime {
            let duration = Float(time - lTime)

            // Update the transform data of the spheres
            for s in objectSpheres {
                s.updateTransformData()
            }
            
            // Do the contact resolution
            if let ground = groundShader {
                ground.sphereContacts(objectSpheres: objectSpheres)
                for oS in objectSpheres {
                    if oS.penetrationDepth < 0 {
                        //print( oS.penetrationDepth )
                        let penetration = -oS.penetrationDepth
                        var contactPoint : _Vector3 = _Vector3(oS.position.x, oS.position.y, oS.position.z)
                        let hitNormal : _Vector3 = _Vector3(oS.hitNormal.x, oS.hitNormal.y, oS.hitNormal.z)
                        contactPoint += -hitNormal * (oS.position.w - penetration)
                        let contact = RigidBody3DContact(body: [oS.body3D, nil], contactPoint: contactPoint, normal: hitNormal, penetration: penetration)
                        rigidBodyWorld.contacts.append(contact)
                    }
                }
            }
            
            if let terrain = terrainShader {
                terrain.sphereContacts(objectSpheres: objectSpheres)
                for oS in objectSpheres {
                    if oS.penetrationDepth < 0 {
                        print( oS.penetrationDepth )
                        //let contact = Particle3DContact(particle: (oS.particle3D!, nil), normal: oS.hitNormal, penetration: oS.penetrationDepth)
                        //particleWorld.contacts.append(contact)
                        let penetration = -oS.penetrationDepth
                        var contactPoint : _Vector3 = _Vector3(oS.position.x, oS.position.y, oS.position.z)
                        let hitNormal : _Vector3 = _Vector3(oS.hitNormal.x, oS.hitNormal.y, oS.hitNormal.z)
                        contactPoint += -hitNormal * (oS.position.w - penetration)
                        let contact = RigidBody3DContact(body: [oS.body3D, nil], contactPoint: contactPoint, normal: hitNormal, penetration: penetration)
                        rigidBodyWorld.contacts.append(contact)
                    }
                }
            }
            
            // Step
            rigidBodyWorld.runPhysics(duration: duration)

            for body in rigidBodyWorld.bodies {
                let transform = body.object.components[body.object.defaultName]!

                transform.values["_posX"] = body.position.x
                transform.values["_posY"] = body.position.y
                transform.values["_posZ"] = body.position.z
                
                let node = SCNNode()
                node.simdOrientation.real = body.orientation.r
                node.simdOrientation.imag = float3(body.orientation.i, body.orientation.j, body.orientation.k)

                print(body.orientation.r,body.orientation.i, body.orientation.j, body.orientation.k)
                
                //print(body.getTransform().data)
                
                transform.values["_rotateX"] = node.simdRotation.x// body.rotation.x
                transform.values["_rotateY"] = node.simdRotation.y// body.rotation.y
                transform.values["_rotateZ"] = node.simdRotation.z//body.rotation.z
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

            for object in objects {
                /*
                let pos = context.evaluateScript("""
                    
                \(object.physicsName).quaternion.toEuler( rotation );
                [\(object.physicsName).position.x, \(object.physicsName).position.y, \(object.physicsName).position.z,
                (-rotation.x) * 180/Math.PI, (-rotation.z) * 180/Math.PI, (-rotation.y) * 180/Math.PI]
                
                """).toArray()!

                sphereData.append(SIMD4<Float>((pos[0] as! NSNumber).floatValue, (pos[2] as! NSNumber).floatValue, (pos[1] as! NSNumber).floatValue, 1))
                */
                
                if let spheres = (object.shader as? ObjectShader)?.spheres {
                    if let transform = object.components[object.defaultName] {
                        
                        let x = transform.values["_posX"]!
                        let y = transform.values["_posY"]!
                        let z = transform.values["_posZ"]!

                        for (_,sphere) in spheres.enumerated() {
                            let mRotation = float4x4(rotation: [transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians])
                            
                            let rotated = /*float4x4(translation: [-x, -y, -z]) **/ float4x4(translation: [x, y, z]) * mRotation * SIMD4<Float>(sphere.x, sphere.y, sphere.z, 1)
                            sphereData.append(SIMD4<Float>(rotated.x, rotated.y, rotated.z, sphere.w))
                        }
                    }
                }
            }
            sphereData.append(SIMD4<Float>(-1,-1,-1,-1))

            prim.drawSpheres(texture: texture, sphereData: sphereData)
        }
    }
}
