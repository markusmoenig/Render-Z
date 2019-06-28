//
//  Physics.swift
//  Shape-Z
//
//  Created by Markus Moenig on 06.03.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

import MetalKit

class PhysicsInstance : BuilderInstance
{
    var dynamicObjects  : [Object] = []
    var collisionObjects: [Object] = []

    var inBuffer        : MTLBuffer? = nil
    var outBuffer       : MTLBuffer? = nil
    
    var physicsOffset   : Int = 0
}

class Physics
{
    var compute         : MMCompute?
    var nodeGraph       : NodeGraph
    
    var accumulator     : Float = 0
    
    var lastTime        : Double = 0
    var delta           : Float = 1 / 60
    
    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
        compute = MMCompute()
    }
    
    /// Build the state for the given objects
    func buildPhysics(objects: [Object], builder: Builder, camera: Camera) -> PhysicsInstance?
    {
        let dynamicObjects = getDynamicObjects(objects: objects)
        //for object in dynamicObjects {
            //nodeGraph.diskBuilder.getDisksFor(object, builder: nodeGraph.builder)
        //}
        // ---
        
        let instance = PhysicsInstance()
        let buildData = BuildData()
        buildData.mainDataName = "physicsData->"

        builder.computeMaxCounts(objects: objects, buildData: buildData, physics: true)
        instance.dynamicObjects = dynamicObjects
        
        let dynaCount = instance.dynamicObjects.count
        if dynaCount == 0 { return nil }
        
        instance.objects = objects
        
        buildData.source += builder.getCommonCode()
        buildData.source += builder.getGlobalCode(objects: objects, includeMaterials: false)
        //buildData.source += Material.getMaterialStructCode()
        buildData.source +=
        """
        typedef struct
        {
            float2      pos;
            float       radius;
            float       fill;
        } DYN_OBJ_DATA;
        
        typedef struct
        {
            float2      size;
            float2      objectCount;
            float4      camera;
        
            float4      general; // .x == time, .y == renderSampling
        
            SHAPE_DATA  shapes[\(max(buildData.maxShapes, 1))];
            float4      points[\(max(buildData.maxPoints, 1))];
            OBJECT_DATA objects[\(max(buildData.maxObjects, 1))];
            VARIABLE    variables[\(max(buildData.maxVariables, 1))];
        
            DYN_OBJ_DATA dynamicObjects[\(dynaCount)];
        } PHYSICS_DATA;
        
        typedef struct
        {
            float4      objResult[\(dynaCount)];
        } PHYSICS_RESULT;
        
        """
        
        instance.data!.append( 0 ) // Size
        instance.data!.append( 0 )
        instance.data!.append( Float(dynaCount) ) // objectCount
        instance.data!.append( 0 )
        
        instance.data!.append( camera.xPos )
        instance.data!.append( camera.yPos )
        instance.data!.append( 1/camera.zoom )
        instance.data!.append( 0 )
        
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        instance.headerOffset = instance.data!.count
        
        // --- Build overall static code
        
        /*
        buildData.source +=
        """
        
        float2 sdf( float2 uv, constant PHYSICS_DATA *physicsData, texture2d<half, access::sample> fontTexture )
        {
            float2 tuv = uv, pAverage;
            float dist = 100000, newDist, objectDistance = 100000;

            int materialId = -1, objectId = -1;
            constant SHAPE_DATA *shape;

        """
        
        for object in objects {
            let physicsMode = object.getPhysicsMode()
            if physicsMode == .Static {
                object.body = Body(object)
                builder.parseObject(object, instance: instance, buildData: buildData, physics: true)
            }
        }
        
        buildData.source +=
        """
        
            return float2(objectDistance,objectId);
        }
        
        """
        */
 
        // --- Build sdf code for all dynamic, static objects
        
        var objectCounter : Int = 0
        for object in objects {
            let physicsMode = object.getPhysicsMode()
            if physicsMode == .Dynamic || physicsMode == .Static {
                
//                object.body = Body(object)

                buildData.source +=
                """
                
                float2 object\(objectCounter)( float2 uv, constant PHYSICS_DATA *physicsData, texture2d<half, access::sample> fontTexture )
                {
                    float2 tuv = uv, pAverage;
                    float dist = 100000, newDist, objectDistance = 100000;
                
                    int materialId = -1, objectId = -1;
                    constant SHAPE_DATA *shape;
                
                """
                
                builder.parseObject(object, instance: instance, buildData: buildData, physics: true)
                
                buildData.source +=
                """
                
                    return float2(objectDistance,objectId);
                }
                
                float2 normal\(objectCounter)(float2 uv, constant PHYSICS_DATA *physicsData, texture2d<half, access::sample> fontTexture) {
                    float2 eps = float2( 0.0005, 0.0 );
                    return normalize(
                        float2(object\(objectCounter)(uv+eps.xy, physicsData, fontTexture).x - object\(objectCounter)(uv-eps.xy, physicsData, fontTexture).x,
                        object\(objectCounter)(uv+eps.yx, physicsData, fontTexture).x - object\(objectCounter)(uv-eps.yx, physicsData, fontTexture).x));
                }
                
                """
                
                object.body!.shaderIndex = objectCounter
                objectCounter += 1
                instance.collisionObjects.append(object)
            }
        }
        
        // Fill up the data
        instance.pointDataOffset = instance.data!.count
        
        // Fill up the points
        let pointCount = max(buildData.maxPoints,1)
        for _ in 0..<pointCount {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.objectDataOffset = instance.data!.count
        
        // Fill up the objects
        let objectCount = max(buildData.maxObjects,1)
        for _ in 0..<objectCount {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.variablesDataOffset = instance.data!.count

        // Fill up the variables
        let variablesDataCount = max(buildData.maxVariables,1) * builder.maxVarSize
        for _ in 0..<variablesDataCount {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.physicsOffset = instance.data!.count
        
        // ---

        buildData.source +=
        """
        
        kernel void layerPhysics(constant PHYSICS_DATA *physicsData [[ buffer(1) ]],
                        texture2d<half, access::sample> fontTexture [[ texture(2) ]],
                                        device float4  *out [[ buffer(0) ]],
                                                  uint  gid [[thread_position_in_grid]])
        {
        """
        
        for _ in instance.dynamicObjects {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        buildData.source +=
        """
            float dynaCount = physicsData->objectCount.x;
            int outCounter = 0;

            float2 pos =  physicsData->dynamicObjects[0].pos;
            float radius = physicsData->dynamicObjects[0].radius;
        
            float2 hit;// = sdf(pos, physicsData, fontTexture);
            float4 rc;// = float4( hit.y, 0, 0, 0 );

        """
        
        var totalCollisionChecks : Int = 0
        objectCounter = 1
        for object in instance.dynamicObjects {
            for collisionObject in instance.collisionObjects {
                if collisionObject !== object {

                    buildData.source +=
                    """
                    
                        hit = object\(collisionObject.body!.shaderIndex)(pos, physicsData, fontTexture);
                        rc = float4( pos.x, 0, 0, 0 );
                    
                        if ( hit.x < radius ) {
                            rc.y = radius - hit.x;
                            rc.zw = normal\(collisionObject.body!.shaderIndex)(pos, physicsData, fontTexture);
                        }
                        out[gid + outCounter++] = rc;
                    
                    """
                    totalCollisionChecks += 1
                }
            }
            buildData.source +=
            """
            
                pos =  physicsData->dynamicObjects[\(objectCounter)].pos;
                radius = physicsData->dynamicObjects[\(objectCounter)].radius;
            
            """
            objectCounter += 1
        }
        
        buildData.source +=
        """
        
        }

        """
        
        instance.inBuffer = compute!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!
        
        instance.outBuffer = compute!.device.makeBuffer(length: totalCollisionChecks * 4 * MemoryLayout<Float>.stride, options: [])!
        
        let library = compute!.createLibraryFromSource(source: buildData.source)
        instance.state = compute!.createState(library: library, name: "layerPhysics")
        
        accumulator = 0
        lastTime = getCurrentTime()

        return instance
    }
    
    /// Render
    func render(width:Float, height:Float, instance: PhysicsInstance, builderInstance: BuilderInstance, camera: Camera)
    {
        // Update Buffer to update animation data
        instance.data![0] = width
        instance.data![1] = height
        instance.data![2] = Float(instance.dynamicObjects.count)
        instance.data![3] = 0
        
        instance.data![4] = camera.xPos
        instance.data![5] = camera.yPos
        instance.data![6] = 1/camera.zoom
        instance.data![7] = 0
        
        var objectIndex : Int = 0
        
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                
                for index in 0..<12 {
                    instance.data![shape.physicShapeOffset+index] = builderInstance.data![shape.buildShapeOffset+index]
                }
        
                for index in 0..<shape.pointCount {
                    instance.data![instance.pointDataOffset + (object.physicPointOffset+index) * 4] = builderInstance.data![builderInstance.pointDataOffset + (object.buildPointOffset+index) * 4]
                    instance.data![instance.pointDataOffset + (object.physicPointOffset+index) * 4 + 1] = builderInstance.data![builderInstance.pointDataOffset + (object.buildPointOffset+index) * 4 + 1]
                }
            }
            
            instance.data![instance.objectDataOffset + objectIndex * 4 + 2] = object.properties["trans_scaleX"]!
            instance.data![instance.objectDataOffset + objectIndex * 4 + 3] = object.properties["trans_scaleY"]!
            
            objectIndex += 1
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in instance.collisionObjects {
            parseObject(object)
        }
        
        //builder.updateInstanceData(instance: builderInstance, camera: camera, doMaterials: false, frame: 0)

        var offset : Int = instance.physicsOffset
        for object in instance.dynamicObjects {
            
            var radius : Float = 1
            var xOff : Float = 0
            var yOff : Float = 0

            // --- Get the disk parameters
            if object.disks.count > 0 {
                //print("instance disk", object.disks![0].z)
                xOff = object.disks[0].xPos
                yOff = object.disks[0].yPos
                radius = object.disks[0].distance
            }
            
            instance.data![offset + 0] = object.properties["posX"]! + xOff
            instance.data![offset + 1] = object.properties["posY"]! + yOff
            instance.data![offset + 2] = radius
            
            offset += 4
        }
        
        memcpy(instance.inBuffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)

        // Step
        
        //accumulator += getDeltaTime()
        //accumulator = simd_clamp( 0, 0.1, accumulator )
        
        compute!.runBuffer( instance.state, outBuffer: instance.outBuffer!, inBuffer: instance.inBuffer, inTexture: nodeGraph.mmView.openSans!.atlas )
        
        let result = instance.outBuffer!.contents().bindMemory(to: Float.self, capacity: 4)
        
        /// Reset collision infos
        for object in instance.dynamicObjects {
            object.body?.collisionInfos = []
        }
        
        offset = 0
        var manifolds : [Manifold] = []
        for object in instance.dynamicObjects {
            
            for collisionObject in instance.collisionObjects {
                if collisionObject !== object {
                    
                    //let distance : Float = result[offset]
                    let penetration : Float = result[offset+1]
                    
                    //print(object.name, collisionObject.name, distance, penetration)

                    if ( penetration > 0.0 )
                    {
                        //print("hit", object.name, collisionObject.name, distance, penetration)

                        let normal = float2( result[offset + 2], result[offset + 3] )
                        
                        let manifold = Manifold(object.body!, collisionObject.body!)//instance.objectMap[Int(id)]!.body!)
                        manifold.penetrationDepth = penetration
                        manifold.normal = -normal
                        manifold.resolve()
                        manifolds.append(manifold)
                    }
                    
                    offset += 4
                }
            }
            object.body!.integrateForces(delta)
            object.body!.integrateVelocity(delta)
            
            object.body!.force = float2(0,0)
        }
        //accumulator -= delta
        
        for manifold in manifolds {
            manifold.positionalCorrection()
        }
    }
    
    func getCurrentTime()->Double {
        return Double(Date().timeIntervalSince1970)
    }
    
    func getDeltaTime() -> Float
    {
        let time = getCurrentTime()
        let delta : Float = Float(time - lastTime)
        lastTime = time
        return delta
    }
    
    /// Creates the global code for all shapes
    func getDynamicObjects(objects: [Object]) -> [Object]
    {
        var result : [Object] = []
        
        for object in objects {
            if object.getPhysicsMode() == .Dynamic {
                result.append(object)
            }
        }
        return result
    }
}

class Body
{
    var velocity            : float2 = float2(0,0)
    var force               : float2 = float2(0,0)
    
    var mass                : Float = 0
    var invMass             : Float = 0
    
    var inertia             : Float = 1
    var invInertia          : Float = 1
    
    var angularVelocity     : Float = 1
    var torque              : Float = 0
    
    var staticFriction      : Float = 0.5
    var dynamicFriction     : Float = 0.3

    var restitution         : Float = 1
    
    var gravity             : float2 = float2(0, -10 * 5)
    
    var object              : Object
    
    var collisionInfos      : [CollisionInfo] = []
    
    var shaderIndex         : Int = -1
    
    init(_ object: Object)
    {
        self.object = object
        
        let physicsMode = object.getPhysicsMode()
        if physicsMode == .Dynamic {
            // Get parameters for dynamic objects, statics have a mass of 0
            
            mass = object.properties["physicsMass"]!
            if mass != 0 {
                invMass = 1 / mass
            }
            restitution = object.properties["physicsRestitution"]!
        }
    }
    
    func integrateForces(_ delta: Float)
    {
        velocity += (force * invMass + gravity) * (delta/2)
    }
    
    func applyImpulse(_ impulse: float2)
    {
        velocity += invMass * impulse;
    }
    
    func applyToPosition(_ value: float2)
    {
        object.properties["posX"] = object.properties["posX"]! + value.x * invMass
        object.properties["posY"] = object.properties["posY"]! + value.y * invMass
    }
    
    func integrateVelocity(_ delta: Float)
    {
        object.properties["posX"] = object.properties["posX"]! + velocity.x
        object.properties["posY"] = object.properties["posY"]! + velocity.y
    }
}

class Manifold
{
    var bodyA               : Body
    var bodyB               : Body
    
    var penetrationDepth    : Float = 0
    var normal              : float2 = float2()

    var staticFriction      : Float
    var dynamicFriction     : Float
    var restitution         : Float

    init(_ bodyA: Body, _ bodyB: Body)
    {
        self.bodyA = bodyA
        self.bodyB = bodyB
        
        restitution = min(bodyA.restitution, bodyB.restitution)
        staticFriction = sqrt(bodyA.staticFriction * bodyB.staticFriction)
        dynamicFriction = sqrt(bodyA.dynamicFriction * bodyB.dynamicFriction)
        
        bodyA.collisionInfos.append( CollisionInfo(collisionWith: bodyB.object) )
        bodyB.collisionInfos.append( CollisionInfo(collisionWith: bodyA.object) )
    }
    
    func resolve()
    {
        // Relative velocity
//        let rv = -normal //+ Cross( B->angularVelocity, rb ) -
//            - bodyA.velocity //- Cross( A->angularVelocity, ra );
        
        let rv : float2 = bodyB.velocity - bodyA.velocity

        /*
        if bodyB.object.properties["isAnimating"] != nil &&  bodyB.object.properties["isAnimating"]! == 1 {
//            rv = -normal - bodyA.velocity
            restitution = 2.5
            //bodyA.force = -normal * 5
        }*/
        
        // Relative velocity along the normal
        let contactVel = simd_dot( rv, normal );
        
        // Do not resolve if velocities are separating
        if contactVel > 0 { return }
        
        //real raCrossN = Cross( ra, normal );
        //real rbCrossN = Cross( rb, normal );
        //real invMassSum = A->im + B->im + Sqr( raCrossN ) * A->iI + Sqr( rbCrossN ) * B->iI;
        
        let invMassSum = bodyA.invMass + bodyB.invMass
        
        // Calculate impulse scalar
        var j = -(1.0 + restitution) * contactVel
        j /= invMassSum
        //j /= (real)contact_count;
        
        // Apply impulse
        let impulse : float2 = normal * j;
        bodyA.applyImpulse( -impulse )//, ra );
        bodyB.applyImpulse(  impulse )//, rb );
    }
    
    func positionalCorrection()
    {
        let slop : Float = 0.05
        let percent : Float = 1 // 0.4
        
        let correction = max( penetrationDepth - slop, 0.0 ) / (bodyA.invMass + bodyB.invMass) * normal * percent;
        bodyA.applyToPosition(-correction)
        bodyB.applyToPosition(correction)
    }
}

/// Collision Info
class CollisionInfo
{
    var     collisionWith   : Object
    
    init(collisionWith: Object)
    {
        self.collisionWith = collisionWith
    }
}
