//
//  Physics3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 18/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation
import JavaScriptCore
import MetalKit

class Physics3D
{
    
    var context         : JSContext
    var scene           : Scene
    
    var objects         : [StageItem] = []
    var valueCopies     : [[String:Float]] = []
    
    var lastTime        : Double? = nil
    
    var primShader      : PrimitivesShader? = nil
    
    var debug           : Bool = true
    
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
        
        let shapeStage = scene.getStage(.ShapeStage)
        for (index, object) in shapeStage.getChildren().enumerated() {
            
            let transform = object.components[object.defaultName]!
            if transform.componentType == .Transform3D {
                
                object.physicsName = "object\(index)"
                
                objects.append(object)
                valueCopies.append(transform.values)
                                
                context.evaluateScript("""

                var radius = 1; // m
                var \(object.physicsName) = new CANNON.Body({
                    mass: 20, // kg
                    position: new CANNON.Vec3(\(transform.values["_posX"]!), \(transform.values["_posZ"]!), \(transform.values["_posY"]!)),
                    rotation: new CANNON.Vec3(\(transform.values["_rotateX"]!), \(transform.values["_rotateZ"]!), \(transform.values["_rotateY"]!)),
                    shape: new CANNON.Sphere(radius)
                });
                world.addBody(\(object.physicsName));
                """)
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
            
            for object in objects {
                let pos = context.evaluateScript("""
                    
                \(object.physicsName).quaternion.toEuler( rotation );
                [\(object.physicsName).position.x, \(object.physicsName).position.y, \(object.physicsName).position.z,
                (-rotation.x) * 180/Math.PI, (-rotation.z) * 180/Math.PI, (-rotation.y) * 180/Math.PI]
                
                """).toArray()!

                let transform = object.components[object.defaultName]!

                transform.values["_posX"] = (pos[0] as! NSNumber).floatValue
                transform.values["_posY"] = (pos[2] as! NSNumber).floatValue
                transform.values["_posZ"] = (pos[1] as! NSNumber).floatValue
                
                transform.values["_rotateX"] = (pos[3] as! NSNumber).floatValue
                transform.values["_rotateY"] = (pos[5] as! NSNumber).floatValue
                transform.values["_rotateZ"] = (pos[4] as! NSNumber).floatValue
            }
        }
        lastTime = time
    }
    
    func drawDebug(texture: MTLTexture)
    {
        if let prim = primShader {
            
            var sphereData  : [SIMD4<Float>] = []
            sphereData.append(SIMD4<Float>(1,0,0,0.5))

            for object in objects {
                let pos = context.evaluateScript("""
                    
                \(object.physicsName).quaternion.toEuler( rotation );
                [\(object.physicsName).position.x, \(object.physicsName).position.y, \(object.physicsName).position.z,
                (-rotation.x) * 180/Math.PI, (-rotation.z) * 180/Math.PI, (-rotation.y) * 180/Math.PI]
                
                """).toArray()!

                sphereData.append(SIMD4<Float>((pos[0] as! NSNumber).floatValue, (pos[2] as! NSNumber).floatValue, (pos[1] as! NSNumber).floatValue, 1))
            }
            
            sphereData.append(SIMD4<Float>(-1,-1,-1,-1))

            prim.drawSpheres(texture: texture, sphereData: sphereData)
        }
    }
}
