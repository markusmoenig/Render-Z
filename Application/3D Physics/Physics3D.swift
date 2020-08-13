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
    var sphereHits      : [Bool] = []

    var body3D          : RigidBody3D? = nil
    var world           : RigidBody3DWorld? = nil

    var hitObject       : StageItem? = nil
    
    init(spheres: [float4], object: StageItem, transform: CodeComponent)
    {
        self.spheres = spheres
        self.object = object
        self.transform = transform
        sphereHits = Array<Bool>(repeating: false, count: spheres.count)
    }
    
    func updateSpheres(spheres: [float4])
    {
        self.spheres = spheres
        sphereHits = Array<Bool>(repeating: false, count: spheres.count)
    }
    
    func updateTransformData()
    {
        position.x = transform.values["_posX"]!
        position.y = transform.values["_posY"]!
        position.z = transform.values["_posZ"]!
        
        rotation.x = transform.values["_rotateX"]!
        rotation.y = transform.values["_rotateY"]!
        rotation.z = transform.values["_rotateZ"]!
        
        transSpheres = spheres
        
        for (i,s) in spheres.enumerated() {
            //let rotated1 = Physics3D.rotateWithPivot(float3(s.x + position.x, s.y + position.y, s.z + position.z), rotation, float3(position.x, position.y, position.z))
            body3D!.calculateDerivedData()
            let rotated = body3D!.transformMatrix.multiplyWithVector(_Vector3(Double(s.x), Double(s.y), Double(s.z)))
            
            transSpheres[i].x = Float(rotated.x)
            transSpheres[i].y = Float(rotated.y)
            transSpheres[i].z = Float(rotated.z)
            
            sphereHits[i] = false
        }
    }
}

class Physics3D
{
    enum ObjectMode : Int {
        case Off, Dynamic, Static
    }
    
    var scene           : Scene
    
    var objects         : [StageItem] = []
    var valueCopies     : [[String:Float]] = []

    var startTime       : Double = 0
    var renderdFrames   : Double = 0
    var lastTime        : Double? = nil
    
    var primShader      : PrimitivesShader? = nil
    
    var debug           : Bool = false
    
    var particleWorld   : Particle3DWorld
    var rigidBodyWorld  : RigidBody3DWorld

    var objectSpheres   : [ObjectSpheres3D] = []
    
    var groundShader    : GroundShader? = nil
    var terrainShader   : TerrainShader? = nil
    
    var staticObjects   : [ObjectShader] = []
    
    var debugSpheres    : [float4] = []
    var debugIsValid    : Bool = false

    var fixedDuration   : Double = 0

    init(scene: Scene)
    {
        self.scene = scene
        particleWorld = Particle3DWorld()
        rigidBodyWorld = RigidBody3DWorld()
        setup()
    }
    
    func setup()
    {
        fixedDuration = 1.0 / Double(globalApp!.mmView.preferredFramesPerSecond)
        
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
                    let physicsMode = getPhysicsMode(object: object)
                    if physicsMode == .Dynamic {
                        let spheres = shader.buildSpheres()
                                            
                        objects.append(object)
                        valueCopies.append(transform.values)
                        
                        let objectSpheres = ObjectSpheres3D(spheres: spheres, object: object, transform: transform)
                        let body = RigidBody3D(object, objectSpheres)
                        objectSpheres.body3D = body
                        objectSpheres.world = rigidBodyWorld
                        self.objectSpheres.append(objectSpheres)
                        body.setPosition(_Vector3(Double(transform.values["_posX"]!), Double(transform.values["_posY"]!), Double(transform.values["_posZ"]!)))
                        
                        let node = SCNNode()
                        node.simdEulerAngles = float3(transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians)
                        body.setOrientation(Double(node.simdOrientation.real), Double(node.simdOrientation.imag.x), Double(node.simdOrientation.imag.y), Double(node.simdOrientation.imag.z))
                        body.orientation.normalise()
                        
                        let mass = transform.values["mass"] == nil ? 5 : transform.values["mass"]!
                        body.setMass(mass: Double(mass))
                        
                        let elasticity = transform.values["elasticity"] == nil ? 0 : transform.values["elasticity"]!
                        body.setElasticity(elasticity)
                        
                        rigidBodyWorld.addBody(body)
                    } else
                    if physicsMode == .Static {
                        staticObjects.append(shader)
                    }
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
            
            //let timeSinceStart = time - startTime
            //let fps = renderdFrames / timeSinceStart
            //print(fps)
            
            var duration = time - lTime
            duration = fixedDuration//1.0 / fps

            // Update the transform data of the spheres
            for s in objectSpheres {
                s.updateTransformData()
            }
            
            // Do the contact resolution
            if objectSpheres.count > 0 {
                if let ground = groundShader {
                    ground.sphereContacts(objectSpheres: objectSpheres)
                }
                
                if let terrain = terrainShader {
                    terrain.sphereContacts(objectSpheres: objectSpheres)
                }
                
                for object in staticObjects {
                    object.sphereContacts(objectSpheres: objectSpheres)
                }
            }
            
            // Step
            rigidBodyWorld.runPhysics(duration: duration)

            for body in rigidBodyWorld.bodies {
                let transform = body.object.components[body.object.defaultName]!
                
                //print("vel", body.velocity.x, body.velocity.y, body.velocity.z)

                if let object = body.object.shader as? ObjectShader {
                    body.objectSpheres.updateSpheres(spheres: object.buildSpheres())
                }
                
                transform.values["_posX"] = Float(body.position.x)
                transform.values["_posY"] = Float(body.position.y)
                transform.values["_posZ"] = Float(body.position.z)
                
                body.object.shader!.velocity = body.velocity
                body.object.shader!.elasticity = body.elasticity

                let angles = body.transformMatrix.extractEulerAngleXYZ()
                transform.values["_rotateX"] = Float(angles.x.radiansToDegrees)
                transform.values["_rotateY"] = Float(angles.y.radiansToDegrees)
                transform.values["_rotateZ"] = Float(angles.z.radiansToDegrees)
            }
            
            debugIsValid = true
            renderdFrames += 1.0
        } else {
            rigidBodyWorld.startFrame()
            debugIsValid = false
            startTime = time
            renderdFrames = 1
        }
        lastTime = time
    }
    
    func drawDebug(texture: MTLTexture)
    {
        if debugIsValid == false { return }
        
        if let prim = primShader {
            var debugSpheres : [float4] = []
            for oS in objectSpheres {
                for (index,s) in oS.spheres.enumerated() {
                    
                    let rotated = Physics3D.rotateWithPivot(float3(s.x + oS.position.x, s.y + oS.position.y, s.z + oS.position.z), oS.rotation, float3(oS.position.x, oS.position.y, oS.position.z))
                    
                    debugSpheres.append(float4(rotated.x, rotated.y, rotated.z, s.w))

                    if oS.sphereHits[index] == false {
                        debugSpheres.append(float4(1,0,0,0.5))
                    } else {
                        debugSpheres.append(float4(1,1,0,0.5))
                    }
                }
            }
            debugSpheres.append(SIMD4<Float>(-1,-1,-1,-1))
            prim.drawSpheres(texture: texture, sphereData: debugSpheres)
        }
    }
    
    /// Returns the ObjectMode of the given object
    func getPhysicsMode(object: StageItem) -> ObjectMode
    {
        if let comp = object.components[object.defaultName] {
            if comp.values["physics"] != nil {
                return ObjectMode(rawValue: Int(comp.values["physics"]!))!
            }
        }
        return .Off
    }
    
    static func rotateWithPivot(_ position: float3,_ angle: float3,_ pivot: float3) -> float3
    {
        func rotateCWWithPivot(_ pos : float2,_ angle: Float,_ pivot: float2 ) -> float2
        {
            let ca : Float = cos(angle), sa = sin(angle)
            return pivot + (pos-pivot) * float2x2(float2(ca, -sa), float2(sa, ca))
        }
        
        var pos = position
        
        /*
        let yz = rotateCWWithPivot(float2(pos.y, pos.z), angle.x.degreesToRadians, float2(pivot.y, pivot.z))
        pos.y = yz.x
        pos.z = yz.y
        let xz = rotateCWWithPivot(float2(pos.x, pos.z), angle.y.degreesToRadians, float2(pivot.x, pivot.z))
        pos.x = xz.x
        pos.z = xz.y
        let xy = rotateCWWithPivot(float2(pos.x, pos.y), angle.z.degreesToRadians, float2(pivot.x, pivot.y))
        pos.x = xy.x
        pos.y = xy.y*/
        
        
        let xy = rotateCWWithPivot(float2(pos.x, pos.y), angle.z.degreesToRadians, float2(pivot.x, pivot.y))
        pos.x = xy.x
        pos.y = xy.y
        
        let xz = rotateCWWithPivot(float2(pos.x, pos.z), angle.y.degreesToRadians, float2(pivot.x, pivot.z))
        pos.x = xz.x
        pos.z = xz.y
        
        let yz = rotateCWWithPivot(float2(pos.y, pos.z), angle.x.degreesToRadians, float2(pivot.y, pivot.z))
        pos.y = yz.x
        pos.z = yz.y
        
        return pos
    }
}
