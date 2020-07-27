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

class Physics3D
{
    
    //var context         : JSContext
    var scene           : Scene
    
    var objects         : [StageItem] = []
    var valueCopies     : [[String:Float]] = []
    
    var lastTime        : Double? = nil
    
    var primShader      : PrimitivesShader? = nil
    
    var debug           : Bool = true
    
    var particleWorld   : Particle3DWorld
    
    init(scene: Scene)
    {
        self.scene = scene
        particleWorld = Particle3DWorld()
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
                }
                
                continue
            }
            
            if let shader = object.shader as? TerrainShader {
                
                if isDisabled(shader: shader) == false {
                }
                
                continue
            }
            
            let transform = object.components[object.defaultName]!
            if transform.componentType == .Transform3D {
                
                if let shader = object.shader as? ObjectShader, isDisabled(shader: shader) == false {
                    //let spheres = shader.buildSpheres()
                                        
                    objects.append(object)
                    valueCopies.append(transform.values)
                    
                    let particle = Particle3D(object)
                    particle.setPosition(position: float3(transform.values["_posX"]!, transform.values["_posY"]!, transform.values["_posZ"]!))
                    particleWorld.addParticle(particle: particle)
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

            particleWorld.runPhysics(duration: duration)

            for particle in particleWorld.particles {
                let transform = particle.object.components[particle.object.defaultName]!

                transform.values["_posX"] = particle.position.x
                transform.values["_posY"] = particle.position.y
                transform.values["_posZ"] = particle.position.z
            }
        }
        lastTime = time
    }
    
    #if false

    init(scene: Scene)
    {
        self.scene = scene
        context = JSContext()!
        
        context.exceptionHandler = { context, exception in
            print(exception!.toString()!)
        }
        
        let path = Bundle.main.path(forResource: "oimo", ofType: "js")!
        let data = NSData(contentsOfFile: path)! as Data
        
        context.evaluateScript(String(data: data,  encoding: String.Encoding.utf8))
        setup()
    }
        
    func setup()
    {
        context.evaluateScript("""

        world = new OIMO.World({
            timestep: 1/60,
            iterations: 8,
            broadphase: 2, // 1 brute force, 2 sweep and prune, 3 volume tree
            worldscale: 1, // scale full world
            random: true,  // randomize sample
            info: false,   // calculate statistic or not
            gravity: [0,-9.8,0]
        });

        function qte(quat) {

          const q0 = quat[0];
          const q1 = quat[1];
          const q2 = quat[2];
          const q3 = quat[3];

          const Rx = Math.atan2(2 * (q0 * q1 + q2 * q3), 1 - (2 * (q1 * q1 + q2 * q2)));
          const Ry = Math.asin(2 * (q0 * q2 - q3 * q1));
          const Rz = Math.atan2(2 * (q0 * q3 + q1 * q2), 1 - (2  * (q2 * q2 + q3 * q3)));

          const euler = [Rx, Ry, Rz];

          return(euler);
        };

        """)?.toArray()
        
        let node = SCNNode()
        
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
        for (index, object) in shapeStage.getChildren().enumerated() {
            
            if let ground = object.shader as? GroundShader {
                
                if isDisabled(shader: ground) == false {
                    context.evaluateScript("""

                    var plane = world.add({
                        type:'plane',
                    });
                        
                    """)
                }
                
                continue
            }
            
            if let shader = object.shader as? TerrainShader {
                
                if isDisabled(shader: shader) == false {

                    let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                    let terrain = shapeStage.terrain!
                    
                    func getValue(_ location: SIMD2<Float>) -> Int8
                    {
                        var loc = location
                        var value : Int8 = 0;
                        
                        loc.x += terrain.terrainSize / terrain.terrainScale / 2.0 * terrain.terrainScale
                        loc.y += terrain.terrainSize / terrain.terrainScale / 2.0 * terrain.terrainScale
                        
                        let x : Int = Int(loc.x)
                        let y : Int = Int(loc.y)
                                
                        if x >= 0 && x < Int(terrain.terrainSize) && y >= 0 && y < Int(terrain.terrainSize) {
                            let region = MTLRegionMake2D(min(Int(x), Int(terrain.terrainSize)-1), min(Int(y), Int(terrain.terrainSize)-1), 1, 1)
                            var texArray = Array<Int8>(repeating: Int8(0), count: 1)
                            texArray.withUnsafeMutableBytes { texArrayPtr in
                                if let ptr = texArrayPtr.baseAddress {
                                    if let texture = terrain.getTexture() {
                                        texture.getBytes(ptr, bytesPerRow: (MemoryLayout<Int8>.size * texture.width), from: region, mipmapLevel: 0)
                                    }
                                }
                            }
                            value = texArray[0]
                        }
                        
                        return value
                    }
                    
                    let width = terrain.getTexture()!.width
                    let height = terrain.getTexture()!.height

                    print(width, height, width * height)
                    
                    context.evaluateScript("""

                    var plane = world.add({
                        type:'plane',
                    });
                        
                    """)
                    
                    for w in 0..<width {
                        
                        for h in 0..<height {
                            
                            let value = Float(getValue(SIMD2<Float>(Float(w),Float(h)))) * terrain.terrainHeightScale
                            
                            if value != 0.0 {
                                
                                print("adding at", w, h, value)
                                
                                context.evaluateScript("""

                                world.add({type:'sphere', size:[60], pos:[\(w), \(value - 60), \(h)] })

                                """)
                            }
                        }
                    }
                }
                
                continue
            }
            
            
            let transform = object.components[object.defaultName]!
            if transform.componentType == .Transform3D {
                
                if let shader = object.shader as? ObjectShader, isDisabled(shader: shader) == false {
                    let spheres = shader.buildSpheres()
                    
                    object.physicsName = "object\(index)"
                    
                    objects.append(object)
                    valueCopies.append(transform.values)
                    
                    node.simdEulerAngles = SIMD3<Float>(transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians)
                    let quat = node.simdOrientation
                    
                    /*
                    context.evaluateScript("""
                        
                        var \(object.physicsName) = new OIMO.RigidBody( new OIMO.Vec3(\(transform.values["_posX"]!), \(transform.values["_posY"]!), \(transform.values["_posZ"]!)), new OIMO.Quat().setFromEuler( -\(transform.values["_rotateZ"]!.degreesToRadians), -\(transform.values["_rotateY"]!.degreesToRadians), \(transform.values["_rotateX"]!.degreesToRadians) ) );
                        
                    """)*/
                    
                    context.evaluateScript("""
                        
                        var \(object.physicsName) = new OIMO.RigidBody( new OIMO.Vec3(\(transform.values["_posX"]!), \(transform.values["_posY"]!), \(transform.values["_posZ"]!)), new OIMO.Quat(\(quat.imag.x), \(quat.imag.y), \(quat.imag.z), \(quat.real)) );
                        
                    """)
                    
                    for sphere in spheres {
                        
                        context.evaluateScript("""

                        var sc = new OIMO.ShapeConfig();
                        sc.relativePosition.set( \(sphere.x), \(sphere.y), \(sphere.z) );
                        \(object.physicsName).addShape(new OIMO.Sphere( sc, \(sphere.w)));
                            
                        """)
                    }
                    
                    context.evaluateScript("""

                    \(object.physicsName).setupMass( OIMO.BODY_DYNAMIC, true );
                    world.addRigidBody( \(object.physicsName) );
                        
                    """)
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
            
            context.evaluateScript("""

            world.step();

            """)
            
            let node = SCNNode()

            for object in objects {
                /*
                let pos = context.evaluateScript("""
                    
                \(object.physicsName).quaternion.toEuler( rotation );
                [\(object.physicsName).position.x, \(object.physicsName).position.y, \(object.physicsName).position.z,
                rotation.x, rotation.y, rotation.z,
                \(object.physicsName).quaternion.x, \(object.physicsName).quaternion.y, \(object.physicsName).quaternion.z, \(object.physicsName).quaternion.w]
                
                """).toArray()!*/
                
                let pos = context.evaluateScript("""
                
                //var euler = qte([\(object.physicsName).quaternion.x, \(object.physicsName).quaternion.y, \(object.physicsName).quaternion.z, \(object.physicsName).quaternion.w]);
                    
                [\(object.physicsName).pos.x, \(object.physicsName).pos.y, \(object.physicsName).pos.z,
                //euler[0], euler[1], euler[2],
                \(object.physicsName).quaternion.x, \(object.physicsName).quaternion.y, \(object.physicsName).quaternion.z, \(object.physicsName).quaternion.w]

                """).toArray()!

                let transform = object.components[object.defaultName]!

                transform.values["_posX"] = (pos[0] as! NSNumber).floatValue
                transform.values["_posY"] = (pos[1] as! NSNumber).floatValue
                transform.values["_posZ"] = (pos[2] as! NSNumber).floatValue
                
                //transform.values["_rotateX"] = (pos[3] as! NSNumber).floatValue.radiansToDegrees
                //transform.values["_rotateY"] = (pos[4] as! NSNumber).floatValue.radiansToDegrees
                //transform.values["_rotateZ"] = (pos[5] as! NSNumber).floatValue.radiansToDegrees
                
                node.simdOrientation = simd_quatf(ix: (pos[3] as! NSNumber).floatValue, iy: (pos[4] as! NSNumber).floatValue, iz: (pos[5] as! NSNumber).floatValue, r: (pos[6] as! NSNumber).floatValue)
                
                let euler = node.simdEulerAngles
                
                transform.values["_rotateX"] = euler.x.radiansToDegrees
                transform.values["_rotateY"] = euler.y.radiansToDegrees
                transform.values["_rotateZ"] = euler.z.radiansToDegrees
            }
        }
        lastTime = time
    }
        
    init(scene: Scene)
    {
        self.scene = scene
        context = JSContext()!
        
        context.exceptionHandler = { context, exception in
            print(exception!.toString()!)
        }
        
        let path = Bundle.main.path(forResource: "cannon", ofType: "js")!
        let data = NSData(contentsOfFile: path)! as Data
        
        context.evaluateScript(String(data: data,  encoding: String.Encoding.utf8))
        setup()
    }
    
    func setup()
    {
        context.evaluateScript("""

        var world = new CANNON.World();
        world.gravity.set(0, 0, -9.82); // m/s²

        // Create a plane
        var groundBody = new CANNON.Body({
            mass: 0 // mass == 0 makes the body static
        });

        var groundShape = new CANNON.Plane();
        groundBody.addShape(groundShape);
        world.addBody(groundBody);

        var fixedTimeStep = 1.0 / 60.0;
        var maxSubSteps = 3;

        var rotation = new CANNON.Vec3();

        """)?.toArray()
        
        let node = SCNNode()

        let shapeStage = scene.getStage(.ShapeStage)
        for (index, object) in shapeStage.getChildren().enumerated() {
            
            let transform = object.components[object.defaultName]!
            if transform.componentType == .Transform3D {
                
                if let shader = object.shader as? ObjectShader {
                    let spheres = shader.buildSpheres()
                    
                    object.physicsName = "object\(index)"
                    
                    objects.append(object)
                    valueCopies.append(transform.values)
                                    
                    node.simdEulerAngles = SIMD3<Float>(transform.values["_rotateX"]!.degreesToRadians, transform.values["_rotateY"]!.degreesToRadians, transform.values["_rotateZ"]!.degreesToRadians)
                    let quat = node.simdOrientation
                        
                    context.evaluateScript("""

                    //var quaternion = new CANNON.Quaternion();
                    //    quaternion.setFromEuler( \(transform.values["_rotateX"]!.degreesToRadians), \(transform.values["_rotateY"]!.degreesToRadians), \(transform.values["_rotateZ"]!.degreesToRadians), 'ZYX');
                    var \(object.physicsName) = new CANNON.Body({
                        mass: 20, // kg
                        position: new CANNON.Vec3(\(transform.values["_posX"]!), \(transform.values["_posZ"]!), \(transform.values["_posY"]!)),
                        quaternion: new CANNON.Quaternion(\(quat.imag.x), \(quat.imag.y), \(quat.imag.z), \(quat.real))
                    });
                    world.addBody(\(object.physicsName));
                        
                    """)
                    
                    for sphere in spheres {
                        
                        print("\(object.physicsName).addShape(new CANNON.Sphere(\(sphere.w)), new CANNON.Vec3(\(sphere.x), \(sphere.y), \(sphere.z)))")
                        context.evaluateScript("""

                        \(object.physicsName).addShape(new CANNON.Sphere(\(sphere.w)), new CANNON.Vec3(\(sphere.x), \(sphere.z), \(sphere.y)));
                            
                        """)
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

        if let lTime = lastTime {
            
            context.evaluateScript("""

            world.step(fixedTimeStep, \(time - lTime), maxSubSteps);

            """)
            
            let node = SCNNode()

            for object in objects {
                let pos = context.evaluateScript("""
                    
                \(object.physicsName).quaternion.toEuler( rotation );
                [\(object.physicsName).position.x, \(object.physicsName).position.y, \(object.physicsName).position.z,
                rotation.x, rotation.y, rotation.z,
                \(object.physicsName).quaternion.x, \(object.physicsName).quaternion.y, \(object.physicsName).quaternion.z, \(object.physicsName).quaternion.w]
                
                """).toArray()!

                let transform = object.components[object.defaultName]!

                transform.values["_posX"] = (pos[0] as! NSNumber).floatValue
                transform.values["_posY"] = (pos[2] as! NSNumber).floatValue
                transform.values["_posZ"] = (pos[1] as! NSNumber).floatValue
                
                transform.values["_rotateX"] = (pos[3] as! NSNumber).floatValue.radiansToDegrees
                transform.values["_rotateY"] = (pos[4] as! NSNumber).floatValue.radiansToDegrees
                transform.values["_rotateZ"] = (pos[5] as! NSNumber).floatValue.radiansToDegrees
                
                node.simdOrientation = simd_quatf(ix: (pos[6] as! NSNumber).floatValue, iy: (pos[7] as! NSNumber).floatValue, iz: (pos[8] as! NSNumber).floatValue, r: (pos[9] as! NSNumber).floatValue)
                
                let euler = node.simdEulerAngles
                
                transform.values["_rotateX"] = euler.x.radiansToDegrees
                transform.values["_rotateY"] = euler.y.radiansToDegrees
                transform.values["_rotateZ"] = euler.z.radiansToDegrees
            }
        }
        lastTime = time
    }
    
    #endif
    
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
