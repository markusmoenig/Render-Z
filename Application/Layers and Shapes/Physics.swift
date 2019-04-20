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
    
    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
        compute = MMCompute()
    }
    
    /// Build the state for the given objects
    func buildPhysics(objects: [Object], builder: Builder, camera: Camera) -> PhysicsInstance?
    {
        let instance = PhysicsInstance()
        let buildData = BuildData()
        buildData.mainDataName = "physicsData->"

        builder.computeMaxCounts(objects: objects, buildData: buildData, physics: true)

        instance.dynamicObjects = getDynamicObjects(objects: objects)
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
            float2      velocity;
            float       radius;
            float       fill;
        } DYN_OBJ_DATA;
        
        typedef struct
        {
            float2      size;
            float2      objectCount;
            float4      camera;
        
            SHAPE_DATA  shapes[\(max(buildData.maxShapes, 1))];
            float2      points[\(max(buildData.maxPoints, 1))];
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
        
        float sdf( float2 uv, constant PHYSICS_DATA *physicsData )
        {
            float2 tuv = uv, pAverage;
            float dist = 100000, newDist;

            int materialId = -1;
            constant SHAPE_DATA *shape;

        """
        
        for object in objects {
            let physicsMode = object.properties["physicsMode"]
            if physicsMode != nil && physicsMode! == 1 {
                builder.parseObject(object, instance: instance, buildData: buildData, physics: true)
            }
        }
        
        buildData.source +=
        """
        
            return dist;
        }
        
        """
        
        //print( buildData.source )
        
        // Fill up the data
        instance.pointDataOffset = instance.data!.count
        
        // Fill up the points
        let pointCount = max(buildData.maxPoints,1)
        for _ in 0..<pointCount {
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
        
        // Test if we need to align memory based on the pointCount
        if (pointCount % 2) == 1 {
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
                float2(sdf(uv+eps.xy, physicsData) - sdf(uv-eps.xy, physicsData),
                sdf(uv+eps.yx, physicsData) - sdf(uv-eps.yx, physicsData)));
        }
        
        kernel void layerPhysics(constant PHYSICS_DATA *physicsData [[ buffer(1) ]],
                                        device float4  *out [[ buffer(0) ]],
                                                  uint  gid [[thread_position_in_grid]])
        {
        """
        
        for object in instance.dynamicObjects {
         
            instance.data!.append( object.properties["posX"]! )
            instance.data!.append( object.properties["posY"]! )
            instance.data!.append( object.properties["velocityX"]! )
            instance.data!.append( object.properties["velocityY"]! )

            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        buildData.source +=
        """
            float dynaCount = physicsData->objectCount.x;
            for (uint i = 0; i < dynaCount; i += 1 )
            {
                float2 pos =  physicsData->dynamicObjects[i].pos;
                float2 velocity =  physicsData->dynamicObjects[i].velocity;
                float radius =  physicsData->dynamicObjects[i].radius;

                float dt = 0.26 / 16;//float(SUB_STEPS);
        
                for(int i = 0; i < 16; i++)
                {
                    // Collisions
                    if ( sdf(pos, physicsData) < radius )
                    {
                        velocity = length(velocity) * reflect(normalize(velocity), -normal(pos, physicsData)) * 0.99;
                    } else
        
                    // Gravity
                    velocity.y -= 0.05 * dt;
        
                    // Add velocity
                    pos += velocity * dt * 100.0;
                }
        
                out[gid+i] = float4( pos.x, pos.y, velocity.x, velocity.y );
            }
        }

        """
        
        instance.inBuffer = compute!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!
        
        instance.outBuffer = compute!.device.makeBuffer(length: dynaCount * 4 * MemoryLayout<Float>.stride, options: [])!
        
        let library = compute!.createLibraryFromSource(source: buildData.source)
        instance.state = compute!.createState(library: library, name: "layerPhysics")
        
        return instance
    }
    
    /// Render
    func render(width:Float, height:Float, instance: PhysicsInstance, builderInstance: BuilderInstance, camera: Camera)
    {
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
                    instance.data![object.physicShapeOffset+index] = builderInstance.data![object.buildShapeOffset+index]
                }
                
                for index in 0..<shape.pointCount {
                    instance.data![instance.pointDataOffset + (object.physicPointOffset+index) * 2] = builderInstance.data![builderInstance.pointDataOffset + (object.buildPointOffset+index) * 2]
                        instance.data![instance.pointDataOffset + (object.physicPointOffset+index) * 2 + 1] = builderInstance.data![builderInstance.pointDataOffset + (object.buildPointOffset+index) * 2 + 1]
                }
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in instance.objects {
            parseObject(object)
        }

        var offset : Int = instance.physicsOffset
        for object in instance.dynamicObjects {
            instance.data![offset + 0] = object.properties["posX"]!
            instance.data![offset + 1] = object.properties["posY"]!
            instance.data![offset + 2] = object.properties["velocityX"]!
            instance.data![offset + 3] = object.properties["velocityY"]!
            
            instance.data![offset + 4] = 40;//object.properties["radius"]!

            offset += 6
        }
        
        memcpy(instance.inBuffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        compute!.runBuffer( instance.state, outBuffer: instance.outBuffer!, inBuffer: instance.inBuffer )
        
        let result = instance.outBuffer!.contents().bindMemory(to: Float.self, capacity: 4)
        
        offset = 0
        for object in instance.dynamicObjects {
            object.properties["posX"]  = result[offset]
            object.properties["posY"]  = result[offset + 1]
            object.properties["velocityX"]  = result[offset + 2]
            object.properties["velocityY"]  = result[offset + 3]
            
//            print( "dist", result[offset + 2] )
            offset += 4
        }
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
