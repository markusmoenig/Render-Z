//
//  Physics.swift
//  Shape-Z
//
//  Created by Markus Moenig on 06.03.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

import MetalKit

class DiskInstance : BuilderInstance
{
    var dynamicObjects  : [Object] = []
    
    var inBuffer        : MTLBuffer? = nil
    var outBuffer       : MTLBuffer? = nil
    
    var maxDisks        : Int = 0
}

class DiskBuilder
{
    var compute         : MMCompute?
    var nodeGraph       : NodeGraph
    
    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
        compute = MMCompute()
    }
    
    func getDisksFor(_ object: Object, builder: Builder, async: (()->())? = nil)
    {
        if async == nil {
            executeDisks(object, builder: builder)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.executeDisks(object, builder: builder)
                async!()
            }
        }
    }
    
    func executeDisks(_ object: Object, builder: Builder)
    {
        let camera = Camera()
        if let instance = buildShader(objects: [object], camera: camera, maxDisks: 10) {
            render(width: 800, height: 800, instance: instance, camera: camera)
        }
    }
    
    /// Build the state for the given objects
    func buildShader(objects: [Object], camera: Camera, maxDisks: Int = 10) -> DiskInstance?
    {
        let builder = nodeGraph.builder!
        let instance = DiskInstance()
        let buildData = BuildData()
        
        instance.maxDisks = maxDisks
        buildData.mainDataName = "diskBuilderData->"

        builder.computeMaxCounts(objects: objects, buildData: buildData, physics: false)
        if buildData.maxShapes == 0 { return nil }
        
        instance.objects = objects
        
        buildData.source += Material.getMaterialStructCode()
        buildData.source += builder.getCommonCode()
        buildData.source += builder.getGlobalCode(objects: objects)
        buildData.source +=
        """
        typedef struct
        {
            float2      size;
            float2      maxDisks;
            float4      camera;
        
            SHAPE_DATA  shapes[\(max(buildData.maxShapes, 1))];
            float4      points[\(max(buildData.maxPoints, 1))];
            OBJECT_DATA objects[\(max(buildData.maxObjects, 1))];
        
        } DISK_BUILDER_DATA;
        
        typedef struct
        {
            float4      objResult[\(maxDisks)];
        } DISK_BUILDER_RESULT;
        
        """
        
        instance.data!.append( 0 ) // Size
        instance.data!.append( 0 )
        instance.data!.append( Float(maxDisks) )
        instance.data!.append( 0 )
        
        instance.data!.append( camera.xPos )
        instance.data!.append( camera.yPos )
        instance.data!.append( 1/camera.zoom )
        instance.data!.append( 0 )
        
        instance.headerOffset = instance.data!.count
        
        // --- Build static code
        
        buildData.source +=
        """
        
        float sdf( float2 uv, constant DISK_BUILDER_DATA *diskBuilderData )
        {
            float2 tuv = uv, pAverage;
            float dist = 100000, newDist, objectDistance = 100000;

            int materialId = -1, objectId = -1;
            constant SHAPE_DATA *shape;

        """
        
        for object in objects {
            builder.parseObject(object, instance: instance, buildData: buildData, buildMaterials: false)
        }
        
        buildData.source +=
        """
        
            return dist;
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
        
        // ---

        buildData.source +=
        """
        kernel void diskBuilder(constant DISK_BUILDER_DATA *diskBuilderData [[ buffer(1) ]],
                                        device float *out [[ buffer(0) ]],
                                                uint2 id [[ thread_position_in_grid ]],
                                                uint tid [[ thread_index_in_threadgroup ]],
                                                uint2 bid [[ threadgroup_position_in_grid ]],
                                                uint2 blockDim [[ threads_per_threadgroup ]])

        {
        """
        
        buildData.source +=
        """
        
            float width = diskBuilderData->size.x;
            float height = diskBuilderData->size.y;
            //int maxDisks = (int) diskBuilderData->maxDisks.x;
        
            uint2 i = bid * blockDim + tid;
            float dist = sdf(float2(i) - float2(width,height)/2, diskBuilderData);
            out[i.y * 800 + i.x] = dist;
        }

        """

        instance.inBuffer = compute!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!
        
        instance.outBuffer = compute!.device.makeBuffer(length: 800 * 800 * MemoryLayout<Float>.stride, options: [])!
        
        let library = compute!.createLibraryFromSource(source: buildData.source)
        instance.state = compute!.createState(library: library, name: "diskBuilder")

        return instance
    }
    
    /// Render
    func render(width:Float, height:Float, instance: DiskInstance, camera: Camera)
    {
        let builder = nodeGraph.builder!

        // Update Buffer to update animation data
        instance.data![0] = width
        instance.data![1] = height
        instance.data![2] = Float(instance.maxDisks)
        instance.data![3] = 0
        
        instance.data![4] = camera.xPos
        instance.data![5] = camera.yPos
        instance.data![6] = 1/camera.zoom
        instance.data![7] = 0
        
        builder.updateInstanceData(instance: instance, camera: camera, frame: 0)

        memcpy(instance.inBuffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        compute!.runBuffer( instance.state, outBuffer: instance.outBuffer!, inBuffer: instance.inBuffer, size: float2(800, 800) )
        
        let result = instance.outBuffer!.contents().bindMemory(to: Float.self, capacity: 800*800)
        
        let object = instance.objects[0]
        object.disks = []
        
        var smallest : Float = 10000
        var x : Int = 0
        var y : Int = 0
        for h in 0..<800 {
            for w in 0..<800 {
                let off = h * 800 + w
                if result[off] < smallest {
                    smallest = result[off]
                    x = w
                    y = h
                }
            }
        }
        
        print( smallest, x, y )
        object.disks.append(Disk(Float(x) - width/2, Float(y) - height/2, abs(smallest)))
    }
}
