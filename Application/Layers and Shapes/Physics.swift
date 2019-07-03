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
    
    let maxDisks        : Int = 10
    
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
            float       rotate;
            float2      offset;
            float2      fill;
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
        
            DYN_OBJ_DATA dynamicObjects[\(dynaCount*maxDisks)];
        } PHYSICS_DATA;
        
        typedef struct
        {
            float4      objResult[\(dynaCount*maxDisks)];
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
            for _ in 0..<maxDisks {
                instance.data!.append( 0 )
                instance.data!.append( 0 )
                instance.data!.append( 0 )
                instance.data!.append( 0 )
                
                instance.data!.append( 0 )
                instance.data!.append( 0 )
                instance.data!.append( 0 )
                instance.data!.append( 0 )
            }
        }
        
        buildData.source +=
        """
            int outCounter = 0;
        
            float2 hit;
            float4 rc;
        
        """
        
        var totalCollisionChecks : Int = 0
        objectCounter = 0
        for object in instance.dynamicObjects {
            for collisionObject in instance.collisionObjects {
                if collisionObject !== object {

                    buildData.source +=
                    """
                    
                        rc = float4( 0, 100000, 0, 0 );
                    
                        for (int i = 0; i < \(object.disks.count); ++i)
                        {
                            float2 pos =  physicsData->dynamicObjects[i+\(objectCounter*maxDisks)].pos;
                            float radius = physicsData->dynamicObjects[i+\(objectCounter*maxDisks)].radius;
                            float rotate = physicsData->dynamicObjects[i+\(objectCounter*maxDisks)].rotate;
                            float2 offset = physicsData->dynamicObjects[i+\(objectCounter*maxDisks)].offset;
                    
                            pos = rotateCCWWithPivot(pos+offset, rotate, pos);
                    
                            hit = object\(collisionObject.body!.shaderIndex)(pos, physicsData, fontTexture);
                    
                            rc.x = radius - hit.x;
                            rc.y = hit.x;
                            if ( hit.x < radius ) {
                                rc.zw = normal\(collisionObject.body!.shaderIndex)(pos, physicsData, fontTexture);
                            }
                            out[gid + i + \(totalCollisionChecks)] = rc;
                        }
                    
                    """
                    
                    totalCollisionChecks += maxDisks
                }
            }
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
            
            // Object transform
            
            instance.data![instance.objectDataOffset + objectIndex * 8 + 1] = toRadians(object.properties["rotate"]!)

            instance.data![instance.objectDataOffset + objectIndex * 8 + 2] = object.properties["scaleX"]!
            instance.data![instance.objectDataOffset + objectIndex * 8 + 3] = object.properties["scaleY"]!
            
            instance.data![instance.objectDataOffset + objectIndex * 8 + 4] = object.properties["posX"]!
            instance.data![instance.objectDataOffset + objectIndex * 8 + 5] = object.properties["posY"]!

            //
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
        for (index,object) in instance.dynamicObjects.enumerated() {
            
            let objectOffset = offset + index * 8 * maxDisks
            var diskOffset = objectOffset

            for disk in object.disks {
                
                instance.data![diskOffset + 0] = object.properties["posX"]!
                instance.data![diskOffset + 1] = object.properties["posY"]!
                instance.data![diskOffset + 2] = disk.distance
                instance.data![diskOffset + 3] = toRadians(object.properties["trans_rotate"]!)
                instance.data![diskOffset + 4] = disk.xPos
                instance.data![diskOffset + 5] = disk.yPos

                diskOffset += 8
            }
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
                    
                    var contacts : [float4] = []
                    var penetrationDepth : Float = 0
                    var normal : float2 = float2()
                    var normals : [float2] = []

                    for i in 0..<object.disks.count {
                        
                        let diskOffset : Int = offset + i * 4
                        
                        let penetration : Float = result[diskOffset]//object.disks[diskIndex].distance - distance
                        let distance : Float = result[diskOffset+1]
                        
                        func rotateCCWWithPivot(_ pos : float2,_ angle: Float,_ pivot: float2 ) -> float2
                        {
                            let ca : Float = cos(angle), sa = sin(angle)
                            return pivot + (pos-pivot) * float2x2(float2(ca, sa), float2(-sa, ca))
                        }
                        
                        func rotateCCW(_ pos : float2,_ angle: Float,_ pivot: float2 ) -> float2
                        {
                            let ca : Float = cos(angle), sa = sin(angle)
                            return (pos) * float2x2(float2(ca, sa), float2(-sa, ca))
                        }
                        
                        let objectPos : float2 = float2(object.properties["posX"]!, object.properties["posY"]!)
                        let diskPos : float2 = float2(object.disks[i].xPos, object.disks[i].yPos)
                        
                        //print(object.properties["trans_rotate"]!)
                        var contact = rotateCCWWithPivot(objectPos + diskPos, toRadians(object.properties["trans_rotate"]!), objectPos)

                        nodeGraph.debugInstance.addDisk(float2(contact.x,contact.y), object.disks[i].distance, penetration > 0.0 ? float4(1,0,0,1) : float4(1,1,0,1) )

                        if ( penetration > 0.0 )
                        {
                            //print(object.name, collisionObject.name, i, penetration)
                            
                            let localNormal = float2( result[diskOffset + 2], result[diskOffset + 3] )
                            normals.append(localNormal)
                            
                            if penetration > penetrationDepth {
                                penetrationDepth = penetration
                                if normals.count == 1 {
                                    normal = -localNormal
                                }
                            }
                            
                            contact += -localNormal * object.disks[i].distance// distance
                            
                            // Visualize contact point
                            nodeGraph.debugInstance.addDisk(float2(contact.x,contact.y), 4, float4(0,1,0,1) )
                            
                            // Visualize normal
//                            nodeGraph.debugInstance.addDisk(float2(contact.x,contact.y), 10, float4(0,1,0,1) )
                            
                            contacts.append(float4(contact.x, contact.y, -localNormal.x, -localNormal.y))
                        }
                    }
                    
                    if contacts.isEmpty == false {
                        //print("hit", object.name, collisionObject.name, contacts.count)
                     
                        /*
                        normal = float2(0,0)
                        for n in normals {
                            normal += -n
                        }
                        normal /= Float(normals.count)*/
                        
                        let manifold = Manifold(object.body!, collisionObject.body!, penetrationDepth: penetrationDepth, normal: normal, contacts: contacts)//instance.objectMap[Int(id)]!.body!)
                        
                        manifold.resolve()
                        manifolds.append(manifold)
                        
                        /*
                        if collisionObject.getPhysicsMode() == .Static {
                            let staticManifold = Manifold(collisionObject.body!, object.body!, penetrationDepth: penetrationDepth, normal: -normal, contacts: contacts)
                            staticManifold.resolve()
                            manifolds.append(staticManifold)
                        }*/
                    }
                    
                    offset += maxDisks * 4
                }
            }
            
            object.body!.integrateVelocity(delta)
            object.body!.integrateForces(delta)
            
            object.body!.force = float2(0,0)
            object.body!.torque = 0
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
    
    var inertia             : Float = 0
    var invInertia          : Float = 0
    
    var orientation         : Float = 0
    
    var angularVelocity     : Float = 0
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
        
//        orientation = toRadians(object.properties["trans_rotate"]!)

        let physicsMode = object.getPhysicsMode()
        if physicsMode == .Dynamic {
            // Get parameters for dynamic objects, statics have a mass of 0
            
            mass = object.properties["physicsMass"]!
            if mass != 0 {
                invMass = 1 / mass
            }
            
            inertia = 0
            for disk in object.disks {
                inertia += mass * disk.distance * disk.distance
            }
            
            if inertia != 0 {
                invInertia = 1 / inertia
            }
            
            restitution = object.properties["physicsRestitution"]!
        }
    }
    
    func getPosition() -> float2
    {
        return float2(object.properties["posX"]!, object.properties["posY"]!)
    }
    
    func integrateForces(_ delta: Float)
    {
        velocity += (force * invMass + gravity) * (delta/2)
        angularVelocity += torque * invInertia * (delta/2)
    }
    
    func applyImpulse(_ impulse: float2,_ contactVector: float2)
    {
        func Cross22(_ a: float2,_ b: float2) -> Float
        {
            return a.x * b.y - a.y * b.x
        }
        
        velocity += invMass * impulse;
        angularVelocity += invInertia * Cross22( contactVector, impulse );
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
        
        orientation += angularVelocity
        object.properties["rotate"] = toDegrees(orientation)
    }
}

class Manifold
{
    var bodyA               : Body
    var bodyB               : Body
    
    var penetrationDepth    : Float = 0
    var normal              : float2 = float2()
    
    var contacts            : [float4] = []

    var staticFriction      : Float
    var dynamicFriction     : Float
    var restitution         : Float

    init(_ bodyA: Body, _ bodyB: Body, penetrationDepth: Float, normal: float2, contacts: [float4])
    {
        self.bodyA = bodyA
        self.bodyB = bodyB
        self.penetrationDepth = penetrationDepth
        self.normal = normal
        self.contacts = contacts
        
        restitution = min(bodyA.restitution, bodyB.restitution)
        staticFriction = sqrt(bodyA.staticFriction * bodyB.staticFriction)
        dynamicFriction = sqrt(bodyA.dynamicFriction * bodyB.dynamicFriction)
        
        bodyA.collisionInfos.append( CollisionInfo(collisionWith: bodyB.object) )
        bodyB.collisionInfos.append( CollisionInfo(collisionWith: bodyA.object) )
        
        //
        
        for contact in contacts {
            let ra = float2(contact.x, contact.y) - bodyA.getPosition()
            let rb = float2(contact.x, contact.y) - bodyB.getPosition()
            
            func Cross12(_ a: Float,_ v: float2) -> float2
            {
                return float2( -a * v.y, a * v.x )
            }
            
            func LenSqr(_ v: float2) -> Float
            {
                return v.x * v.x + v.y * v.y;
            }
            
            let rv : float2 = bodyB.velocity + Cross12(bodyB.angularVelocity, rb) - bodyA.velocity - Cross12(bodyA.angularVelocity, ra)
            
            if LenSqr(rv) < LenSqr(1 / 60 * bodyA.gravity) + 0.0001 {
                restitution = 0
            }
        }
    }
    
    func resolve()
    {
        func Cross21(_ v: float2,_ a: Float) -> float2
        {
            return float2( a * v.y, -a * v.x )
        }
        
        func Cross12(_ a: Float,_ v: float2) -> float2
        {
            return float2( -a * v.y, a * v.x )
        }
        
        func Cross22(_ a: float2,_ b: float2) -> Float
        {
            return a.x * b.y - a.y * b.x
        }
        
        for contact in contacts {
            // Calculate radii from COM to contact
            let ra = float2(contact.x, contact.y) - bodyA.getPosition()
            let rb = float2(contact.x, contact.y) - bodyB.getPosition()
            
            let normal = float2(contact.z, contact.w)
            
            // Relative velocity
    //        Vec2 rv = B->velocity + Cross( B->angularVelocity, rb ) -
    //            A->velocity - Cross( A->angularVelocity, ra );
            
            var rv : float2 = bodyB.velocity + Cross12(bodyB.angularVelocity, rb) - bodyA.velocity - Cross12(bodyA.angularVelocity, ra)

            // Relative velocity along the normal
            let contactVel = dot( rv, normal );
            
            // Do not resolve if velocities are separating
            if contactVel > 0 { return }
            
            //real raCrossN = Cross( ra, normal );
            //real rbCrossN = Cross( rb, normal );
            //real invMassSum = A->im + B->im + Sqr( raCrossN ) * A->iI + Sqr( rbCrossN ) * B->iI;
            
            let raCrossN = Cross22(ra, normal)
            let rbCrossN = Cross22(rb, normal)

    //        let invMassSum = bodyA.invMass + bodyB.invMass
            let invMassSum = bodyA.invMass + bodyB.invMass + raCrossN * raCrossN * bodyA.invInertia + rbCrossN * rbCrossN * bodyB.invInertia

            // Calculate impulse scalar
            var j = -(1.0 + restitution) * contactVel
            j /= invMassSum
            j /= Float(contacts.count)
            
            // Apply impulse
            let impulse : float2 = normal * j
            bodyA.applyImpulse( -impulse, ra )
            bodyB.applyImpulse(  impulse, rb )
            
            // Friction impulse
            rv = bodyB.velocity + Cross12(bodyB.angularVelocity, rb) - bodyA.velocity - Cross12(bodyA.angularVelocity, ra)

            var t = rv - (normal * dot( rv, normal ))
            t = normalize(t)
            
            // j tangent magnitude
            var jt = -dot( rv, t )
            jt /= invMassSum
            jt /= Float(contacts.count)
            
            
            //inline bool Equal( real a, real b )
            //{
                // <= instead of < for NaN comparison safety
            //    return std::abs( a - b ) <= EPSILON;
            //}
            
            if abs(jt) <= 0.0001 {
                return
            }
            
            // Coulumb's law
            var tangentImpulse : float2
            if abs( jt ) < j * staticFriction {
                tangentImpulse = t * jt;
            } else {
                tangentImpulse = t * -j * dynamicFriction
            }
            
            bodyA.applyImpulse( -tangentImpulse, ra )
            bodyB.applyImpulse( tangentImpulse, rb )
        }
    }
    
    func positionalCorrection()
    {
        let slop : Float = 0.05
        let percent : Float = 0.4 // 0.4
        
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
