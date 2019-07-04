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

    var maxDisks        : Int = 10

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
            DispatchQueue.main.async {
                self.executeDisks(object, builder: builder)
                async!()
            }
        }
    }
    
    func executeDisks(_ object: Object, builder: Builder)
    {
        let camera = Camera()
        if let instance = buildShader(objects: [object], camera: camera) {
            
            object.disks = []
            for i in 0..<instance.maxDisks {
                let rc = render(width: 800, height: 800, instance: instance, camera: camera, pass: i)
                if rc == false {
                    break
                }
            }
        }
    }
    
    /// Build the state for the given objects
    func buildShader(objects: [Object], camera: Camera) -> DiskInstance?
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
            float4      general; // .x == time, .y == renderSampling
        
            float4      diskData[\(maxDisks)];

            SHAPE_DATA  shapes[\(max(buildData.maxShapes, 1))];
            float4      points[\(max(buildData.maxPoints, 1))];
            OBJECT_DATA objects[\(max(buildData.maxObjects, 1))];
            VARIABLE    variables[\(max(buildData.maxVariables, 1))];
        
        } DISK_BUILDER_DATA;
        
        typedef struct
        {
            float4      objResult[1];
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
        
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        for _ in 0..<maxDisks {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.headerOffset = instance.data!.count
        
        // --- Build static code
        
        buildData.source +=
        """
        
        float sdf( float2 uv, constant DISK_BUILDER_DATA *diskBuilderData,                         texture2d<half, access::sample> fontTexture)
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
        
        // ---

        buildData.source +=
        """
        
        kernel void diskBuilder(constant DISK_BUILDER_DATA *diskBuilderData [[ buffer(1) ]],
                                        device float *out [[ buffer(0) ]],
                      texture2d<half, access::sample> fontTexture [[ texture(2) ]],
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
            int pass = (int) diskBuilderData->maxDisks.y;

            uint2 i = bid * blockDim + tid;
            float2 uv = float2(i) - float2(width,height)/2;
            float dist = sdf(uv, diskBuilderData, fontTexture);
            for( int iter = 0; iter < pass; ++iter ) {
                float diskX = diskBuilderData->diskData[iter].x;
                float diskY = diskBuilderData->diskData[iter].y;
                float diskRadius = diskBuilderData->diskData[iter].z;
        
                float diskDist = length(uv - (float2(diskX,diskY) - float2(width,height)/2) ) - diskRadius;

                dist = subtract(dist, diskDist);
            }
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
    func render(width:Float, height:Float, instance: DiskInstance, camera: Camera, pass: Int) -> Bool
    {
        let builder = nodeGraph.builder!

        // Update Buffer to update animation data
        instance.data![0] = width
        instance.data![1] = height
        instance.data![2] = Float(instance.maxDisks)
        instance.data![3] = Float(pass)
        
        instance.data![4] = camera.xPos
        instance.data![5] = camera.yPos
        instance.data![6] = 1/camera.zoom
        instance.data![7] = 0
        
        builder.updateInstanceData(instance: instance, camera: camera, frame: 0)

        memcpy(instance.inBuffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        compute!.runBuffer( instance.state, outBuffer: instance.outBuffer!, inBuffer: instance.inBuffer, size: float2(800,800), inTexture: nodeGraph.mmView.openSans.atlas )
        
        let result = instance.outBuffer!.contents().bindMemory(to: Float.self, capacity: 800*800)
        
        let object = instance.objects[0]
        
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
        
        let radius = abs(smallest)
        let offset : Int = 12 + pass * 4
        
        instance.data![offset] = Float(x)
        instance.data![offset+1] = Float(y)
        instance.data![offset+2] = radius
        
        if radius < 4 {
            return false
        } else {
            object.disks.append(Disk(Float(x) - width/2, Float(y) - height/2, radius))
            print( pass, radius, Float(x) - width/2, Float(y) - height/2 )

            return true
        }
    }
}
