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

        source +=
        """
        
        kernel void layerPhysics(constant PHYSICS_DATA *physicsData [[ buffer(1) ]],
                                        device float4  *out [[ buffer(0) ]],
                                                  uint  gid [[thread_position_in_grid]])
        {
            /*
            float2 size = physicsData->size;
            float2 fragCoord = float2( gid.x, gid.y );
            float2 uv = fragCoord;
        
            float2 center = size / 2;
            uv = translate(uv, center - float2( layerData->camera.x, layerData->camera.y ) );
            uv *= layerData->fill.x;
            float2 tuv = uv;
        
            float dist = 1000;*/
        """
        
        for object in instance.dynamicObjects {
         
            instance.data!.append( object.properties["posX"]! )
            instance.data!.append( object.properties["posY"]! )
            instance.data!.append( 0 )
            instance.data!.append( 0 )

            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        print( instance.data!.count, instance.dynamicObjects.count )
        
        source +=
        """
            float dynaCount = physicsData->objectCount.x;
            for (uint i = 0; i < dynaCount; i += 1 )
            {
                float2 pos = physicsData->dynamicObjects[i].pos;
                out[gid+i] = float4( pos.x, pos.y + 0.8, 0, 0 );
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

            offset += 6
        }
        
        memcpy(instance.inBuffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        compute!.runBuffer( instance.state, outBuffer: instance.outBuffer!, inBuffer: instance.inBuffer )
        
        let result = instance.outBuffer!.contents().bindMemory(to: Float.self, capacity: 4)
        
        offset = 0
        for object in instance.dynamicObjects {
            object.properties["posX"]  = result[offset]
            object.properties["posY"]  = result[offset + 1]
            
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
}
