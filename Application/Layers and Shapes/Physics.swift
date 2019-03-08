//
//  Physics.swift
//  Shape-Z
//
//  Created by Markus Moenig on 06.03.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

import MetalKit

class PhysicsInstance
{
    var objects         : [Object] = []
    var dynamicObjects  : [Object] = []
    
    var state           : MTLComputePipelineState? = nil
    
    var data            : [Float]? = []
    var inBuffer        : MTLBuffer? = nil
    var outBuffer       : MTLBuffer? = nil
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
    func buildPhysics(objects: [Object], camera: Camera) -> PhysicsInstance?
    {
        let instance = PhysicsInstance()
        
        instance.dynamicObjects = getDynamicObjects(objects: objects)
        let dynaCount = instance.dynamicObjects.count
        if dynaCount == 0 { return nil }
        
        instance.objects = objects
        
        var source =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;
        
        float merge(float d1, float d2)
        {
            return min(d1, d2);
        }
        
        float subtract(float d1, float d2)
        {
            return max(d1, -d2);
        }
        
        float intersect(float d1, float d2)
        {
            return max(d1, d2);
        }
        
        float fillMask(float dist)
        {
            return clamp(-dist, 0.0, 1.0);
        }
        
        float borderMask(float dist, float width)
        {
            return clamp(dist + width, 0.0, 1.0) - clamp(dist, 0.0, 1.0);
        }
        
        float2 translate(float2 p, float2 t)
        {
            return p - t;
        }
        
        float2 rotateCW(float2 pos, float angle)
        {
            float ca = cos(angle), sa = sin(angle);
            return pos * float2x2(ca, -sa, sa, ca);
        }
        
        float2 rotateCCW (float2 pos, float angle)
        {
            float ca = cos(angle), sa = sin(angle);
            return pos * float2x2(ca, sa, -sa, ca);
        }
        
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
        
        source += getGlobalCode(objects:objects)
        source += buildStaticObjectCode(objects:objects)

        source +=
        """
        float2 normal(float2 uv) {
            float2 eps = float2( 0.0005, 0.0 );
            return normalize(
                float2(sdf(uv+eps.xy) - sdf(uv-eps.xy),
                sdf(uv+eps.yx) - sdf(uv-eps.yx)));
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
        
        source +=
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
                    if ( sdf(pos) < radius )
                    {
                        velocity = length(velocity) * reflect(normalize(velocity), -normal(pos)) * 0.99;
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
        
        let library = compute!.createLibraryFromSource(source: source)
        instance.state = compute!.createState(library: library, name: "layerPhysics")
        
        return instance
    }
    
    /// Render
    func render(width:Float, height:Float, instance: PhysicsInstance, camera: Camera)
    {
        instance.data![0] = width
        instance.data![1] = height
        instance.data![2] = Float(instance.dynamicObjects.count)
        instance.data![3] = 0
        
        instance.data![4] = camera.xPos
        instance.data![5] = camera.yPos
        instance.data![6] = 1/camera.zoom
        instance.data![7] = 0

        var offset : Int = 8
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
    
    /// Creates the global code for all shapes
    func getGlobalCode(objects: [Object]) -> String
    {
        var coll : [String] = []
        var result = ""
        
        for object in objects {
            for shape in object.shapes {
                
                if !coll.contains(shape.name) {
                    result += shape.globalCode
                    coll.append( shape.name )
                }
            }
        }
        
        return result
    }
    
    /// Builds the sdf() function which returns the distance to the static physic objects
    func buildStaticObjectCode(objects: [Object]) -> String
    {
        var source =
        """
        
        float sdf( float2 uv )
        {
            float2 tuv = uv;
            float dist = 1000;
        
        """
        
        var parentPosX : Float = 0
        var parentPosY : Float = 0
        var parentRotate : Float = 0
        func parseObject(_ object: Object)
        {
            parentPosX += object.properties["posX"]!
            parentPosY += object.properties["posY"]!
            parentRotate += object.properties["rotate"]!
            
            for shape in object.shapes {
                
                let properties : [String:Float]
                if object.currentSequence != nil {
                    properties = nodeGraph.timeline.transformProperties(sequence: object.currentSequence!, uuid: shape.uuid, properties: shape.properties)
                } else {
                    properties = shape.properties
                }
                
                let posX = properties["posX"]! + parentPosX
                let posY = properties["posY"]! + parentPosY
                //let sizeX = properties[shape.widthProperty]
                //let sizeY = properties[shape.heightProperty]
                let rotate = (properties["rotate"]!+parentRotate) * Float.pi / 180
                
                source += "uv = translate( tuv, float2( \(posX), \(posY) ) );"
                
                if shape.pointCount < 2 {
                    source += "if ( \(rotate) != 0.0 ) uv = rotateCCW( uv, \(rotate) );\n"
                } else
                if shape.pointCount == 2 {
                    let p0X = properties["point_0_x"]!
                    let p0Y = properties["point_0_y"]!
                    let p1X = properties["point_1_x"]!
                    let p1Y = properties["point_1_y"]!

                    source += "if ( \(rotate) != 0.0 ) { uv = rotateCCW( uv - ( float2( \(p0X), \(p0Y) ) + float2( \(p1X), \(p1Y) ) ) / 2, \(rotate) );\n"
                    source += "uv += ( float2( \(p0X), \(p0Y) ) + float2( \(p1X), \(p1Y) )) / 2;}\n"
                } else
                if shape.pointCount == 3 {
                    let p0X = properties["point_0_x"]!
                    let p0Y = properties["point_0_y"]!
                    let p1X = properties["point_1_x"]!
                    let p1Y = properties["point_1_y"]!
                    let p2X = properties["point_2_x"]!
                    let p2Y = properties["point_2_y"]!
                    
                    source += "if ( \(rotate) != 0.0 ) { uv = rotateCCW( uv - ( float2( \(p0X), \(p0Y) ) + float2( \(p1X), \(p1Y) ) + float2( \(p2X), \(p2Y) ) ) / 3, \(rotate) );\n"
                    source += "uv += ( float2( \(p0X), \(p0Y) ) + float2( \(p1X), \(p1Y) ) + float2( \(p2X), \(p2Y) ) ) / 3;}\n"
                }
                
                var booleanCode = "merge"
                if shape.mode == .Subtract {
                    booleanCode = "subtract"
                } else
                    if shape.mode == .Intersect {
                        booleanCode = "intersect"
                }
                
                source += "dist = \(booleanCode)( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            parentPosX -= object.properties["posX"]!
            parentPosY -= object.properties["posY"]!
            parentRotate -= object.properties["rotate"]!
        }
        
        for object in objects {
            let physicsMode = object.properties["physicsMode"]
            if physicsMode != nil && physicsMode! == 1 {
                parseObject(object)
            }
        }

        source +=
        """
        
            return dist;
        }
        
        """
        
        print( source )
        
        return source;
    }
}
