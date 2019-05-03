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
        // Build the disks for dynamic objects
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
        buildData.source += builder.getGlobalCode(objects: objects)
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
        
            SHAPE_DATA  shapes[\(max(buildData.maxShapes, 1))];
            float4      points[\(max(buildData.maxPoints, 1))];
            OBJECT_DATA objects[\(max(buildData.maxObjects, 1))];
        
            DYN_OBJ_DATA  dynamicObjects[\(dynaCount)];
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
        
        instance.headerOffset = instance.data!.count
        
        // --- Build static code
        
        buildData.source +=
        """
        
        float2 sdf( float2 uv, constant PHYSICS_DATA *physicsData )
        {
            float2 tuv = uv, pAverage;
            float dist = 100000, newDist, objectDistance = 100000;

            int materialId = -1, objectId = -1;
            constant SHAPE_DATA *shape;

        """
        
        for object in objects {
            let physicsMode = object.properties["physicsMode"]
            if physicsMode != nil {
                if physicsMode! == 1 {
                    builder.parseObject(object, instance: instance, buildData: buildData, physics: true)
                }
            }
        }
        
        buildData.source +=
        """
        
            return float2(objectDistance,objectId);
        }
        
        """
        
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
        
        instance.physicsOffset = instance.data!.count
        
        // ---

        buildData.source +=
        """
        float2 normal(float2 uv, constant PHYSICS_DATA *physicsData) {
            float2 eps = float2( 0.0005, 0.0 );
            return normalize(
                float2(sdf(uv+eps.xy, physicsData).x - sdf(uv-eps.xy, physicsData).x,
                sdf(uv+eps.yx, physicsData).x - sdf(uv-eps.yx, physicsData).x));
        }
        
        kernel void layerPhysics(constant PHYSICS_DATA *physicsData [[ buffer(1) ]],
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
            for (uint i = 0; i < dynaCount; i += 1 )
            {
                float2 pos =  physicsData->dynamicObjects[i].pos;
                float radius = physicsData->dynamicObjects[i].radius;
        
                float2 hit = sdf(pos, physicsData);
                float4 rc = float4( hit.y, 0, 0, 0 );

                if ( hit.x < radius ) {
                    rc.y = radius - hit.x;
                    rc.zw = normal(pos, physicsData);
                }
                out[gid+i] = rc;//float4( pos.x, pos.y, velocity.x, velocity.y );
            }
        }

        """
        
        instance.inBuffer = compute!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!
        
        instance.outBuffer = compute!.device.makeBuffer(length: dynaCount * 4 * MemoryLayout<Float>.stride, options: [])!
        
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
        
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                
                for index in 0..<8 {
                    //print(shapeIndex, index, shape.physicShapeOffset+index, builderInstance.data![shape.buildShapeOffset+index] )
                    instance.data![shape.physicShapeOffset+index] = builderInstance.data![shape.buildShapeOffset+index]
                }
        
                for index in 0..<shape.pointCount {
                    instance.data![instance.pointDataOffset + (object.physicPointOffset+index) * 4] = builderInstance.data![builderInstance.pointDataOffset + (object.buildPointOffset+index) * 4]
                    instance.data![instance.pointDataOffset + (object.physicPointOffset+index) * 4 + 1] = builderInstance.data![builderInstance.pointDataOffset + (object.buildPointOffset+index) * 4 + 1]
                }
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in instance.objects {
            let physicsMode = object.properties["physicsMode"]
            if physicsMode != nil {
                if physicsMode! == 1 {
                    parseObject(object)
                }
            }
        }
        
        var offset : Int = instance.physicsOffset
        for object in instance.dynamicObjects {
            
            if object.body == nil {
                object.body = Body(object)
            }
            
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
        
        compute!.runBuffer( instance.state, outBuffer: instance.outBuffer!, inBuffer: instance.inBuffer )
        
        let result = instance.outBuffer!.contents().bindMemory(to: Float.self, capacity: 4)
        
        offset = 0
        var manifolds : [Manifold] = []
        for object in instance.dynamicObjects {
            
            let id : Float = result[offset]
            let penetration : Float = result[offset+1]
            
//            print( id, penetration, result[offset+2] )
            
            if ( penetration > 0.0 )
            {
                let normal = float2( result[offset + 2], result[offset + 3] )
                
                let manifold = Manifold(object.body!,instance.objectMap[Int(id)]!.body!)
                manifold.penetrationDepth = penetration
                manifold.normal = -normal
                manifold.resolve()
                manifolds.append(manifold)
            }
            
            object.body!.integrateForces(delta)
            object.body!.integrateVelocity(delta)
            
            for manifold in manifolds {
                manifold.positionalCorrection()
            }
            
            object.body!.force = float2(0,0)
            
            offset += 4
        }
        //accumulator -= delta
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
            let physicsMode = object.properties["physicsMode"]
            if physicsMode != nil && physicsMode! == 2 {
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
    
    init(_ object: Object)
    {
        self.object = object
        
        let physicsMode = object.properties["physicsMode"]
        if physicsMode != nil && physicsMode! == 2 {
            // Get parameters for dynamic objects
            
            mass = object.properties["physicsMass"]!
            if mass != 0 {
                invMass = 1 / mass
            }
            restitution = object.properties["physicsRestitution"]!
            force.y = 3000
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
    }
    
    func resolve()
    {
        // Relative velocity
//        let rv = -normal //+ Cross( B->angularVelocity, rb ) -
//            - bodyA.velocity //- Cross( A->angularVelocity, ra );
        
        let rv : float2 = bodyB.velocity - bodyA.velocity

        
        if bodyB.object.properties["isAnimating"] != nil &&  bodyB.object.properties["isAnimating"]! == 1 {
//            rv = -normal - bodyA.velocity
            restitution = 2.5
            //bodyA.force = -normal * 5
        }
        
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
