//
//  Builder.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class BuilderInstance
{
    var objects         : [Object] = []
    var state           : MTLComputePipelineState? = nil
    
    var data            : [Float]? = []
    var buffer          : MTLBuffer? = nil
    
    var texture         : MTLTexture? = nil
}

class Camera
{
    var xPos            : Float = 0
    var yPos            : Float = 0
    var zoom            : Float = 0
}

class Builder
{
    /// The default sequence for all objects and shapes in the layer
    var sequence        : MMTlSequence
    
    var compute         : MMCompute?
    
    init()
    {
        compute = MMCompute()
        sequence = MMTlSequence()
    }
    
    /// Build the state for the given objects
    func buildObjects(objects: [Object], camera: Camera, timeline: MMTimeline) -> BuilderInstance
    {
        var instance = BuilderInstance()
        
        instance.objects = objects
        let shapeCount = getShapeCount(objects:objects)
        
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
            //dist += 1.0;
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
            float2      size;
            float2      point0;
            float2      point1;
            float2      point2;
            float       rotate;
            float       filler;
        } SHAPE_DATA;
        
        typedef struct
        {
            float2      camera;
            float2      fill;
        
            SHAPE_DATA  shape[\(max(shapeCount,1))];
        } LAYER_DATA;
        
        """
        
        source += getGlobalCode(objects:objects)
        
        instance.data!.append( camera.xPos )
        instance.data!.append( camera.yPos )
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        source +=
        """
        
        kernel void
        layerBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
        constant LAYER_DATA            *layerData   [[ buffer(1) ]],
        texture2d<half, access::read>   inTexture   [[texture(2)]],
        uint2                           gid         [[thread_position_in_grid]])
        {
            float2 fragCoord = float2( gid.x, gid.y );
            float2 uv = 700. * (fragCoord.xy + float(0.5)) / outTexture.get_width();
        
            float2 center = float2( 350., 350. * outTexture.get_height() / outTexture.get_width() );
            uv = translate(uv, center - float2( layerData->camera.x, layerData->camera.y ) );
            float2 tuv = uv;
        
            float dist = 1000;
        """
        
        /// Parse objects and their shapes
        
        var index : Int = 0
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                
                let properties = timeline.transformProperties(sequence: sequence, uuid: shape.uuid, properties: shape.properties)
                
                source += "uv = translate( tuv, layerData->shape[\(index)].pos );"
                if shape.pointCount < 2 {
                    source += "if ( layerData->shape[\(index)].rotate != 0.0 ) uv = rotateCW( uv, layerData->shape[\(index)].rotate );\n"
                } else
                    if shape.pointCount == 2 {
                        source += "if ( layerData->shape[\(index)].rotate != 0.0 ) { uv = rotateCW( uv - ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1) / 2, layerData->shape[\(index)].rotate );\n"
                        source += "uv += ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1) / 2;}\n"
                    } else
                        if shape.pointCount == 3 {
                            source += "if ( layerData->shape[\(index)].rotate != 0.0 ) { uv = rotateCW( uv - ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1 + + layerData->shape[\(index)].point2) / 3, layerData->shape[\(index)].rotate );\n"
                            source += "uv += ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1 + layerData->shape[\(index)].point2) / 3;}\n"
                }
                
                var booleanCode = "merge"
                if shape.mode == .Subtract {
                    booleanCode = "subtract"
                } else
                    if shape.mode == .Intersect {
                        booleanCode = "intersect"
                }
                
                source += "dist = \(booleanCode)( dist, " + shape.createDistanceCode(uvName: "uv", layerIndex: index) + ");"
                
                let posX = properties["posX"]
                let posY = properties["posY"]
                let sizeX = properties[shape.widthProperty]
                let sizeY = properties[shape.heightProperty]
                let rotate = (properties["rotate"]!) * Float.pi / 180
                
                instance.data!.append( posX! )
                instance.data!.append( posY! )
                instance.data!.append( sizeX! )
                instance.data!.append( sizeY! )
                if shape.pointCount == 0 {
                    instance.data!.append( 0 )
                    instance.data!.append( 0 )
                    instance.data!.append( 0 )
                    instance.data!.append( 0 )
                    instance.data!.append( 0 )
                    instance.data!.append( 0 )
                } else
                    if shape.pointCount == 1 {
                        instance.data!.append( properties["point_0_x"]! )
                        instance.data!.append( properties["point_0_y"]! )
                        instance.data!.append( 0 )
                        instance.data!.append( 0 )
                        instance.data!.append( 0 )
                        instance.data!.append( 0 )
                    } else
                        if shape.pointCount == 2 {
                            instance.data!.append( properties["point_0_x"]! )
                            instance.data!.append( properties["point_0_y"]! )
                            instance.data!.append( properties["point_1_x"]! )
                            instance.data!.append( properties["point_1_y"]! )
                            instance.data!.append( 0 )
                            instance.data!.append( 0 )
                        } else
                            if shape.pointCount == 3 {
                                instance.data!.append( properties["point_0_x"]! )
                                instance.data!.append( properties["point_0_y"]! )
                                instance.data!.append( properties["point_1_x"]! )
                                instance.data!.append( properties["point_1_y"]! )
                                instance.data!.append( properties["point_2_x"]! )
                                instance.data!.append( properties["point_2_y"]! )
                }
                instance.data!.append( rotate )
                instance.data!.append( 0 )
                
                index += 1
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in objects {
            parseObject(object)
        }
        
        source +=
        """
            float4 fillColor = float4( 0.5, 0.5, 0.5, 1);
            float4 borderColor = float4( 1 );
        
            float4 col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );
            col = mix( col, borderColor, borderMask( dist, 2 ) );
        
            outTexture.write(half4(col.x, col.y, col.z, col.w), gid);
        }
        """
        
//        print( source )
        
        instance.buffer = compute!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!
        
        let library = compute!.createLibraryFromSource(source: source)
        instance.state = compute!.createState(library: library, name: "layerBuilder")
        
        return instance
    }
    
    /// Render the layer
    @discardableResult func render(width:Float, height:Float, instance: BuilderInstance, camera: Camera, timeline: MMTimeline) -> MTLTexture
    {
        if compute!.width != width || compute!.height != height {
            compute!.allocateTexture(width: width, height: height)
        }
        
        instance.texture = compute!.texture

        instance.data![0] = camera.xPos
        instance.data![1] = camera.yPos
        let offset : Int = 4
        var index : Int = 0

        // Update Shapes / Objects
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                let properties = timeline.transformProperties(sequence: sequence, uuid: shape.uuid, properties: shape.properties)
                
                instance.data![offset + index * 12] = properties["posX"]!
                instance.data![offset + index * 12+1] = properties["posY"]!
                instance.data![offset + index * 12+2] = properties[shape.widthProperty]!
                instance.data![offset + index * 12+3] = properties[shape.heightProperty]!
                if ( shape.pointCount == 1 ) {
                    instance.data![offset + index * 12+4] = properties["point_0_x"]!
                    instance.data![offset + index * 12+5] = properties["point_0_y"]!
                } else
                    if ( shape.pointCount == 2 ) {
                        instance.data![offset + index * 12+4] = properties["point_0_x"]!
                        instance.data![offset + index * 12+5] = properties["point_0_y"]!
                        instance.data![offset + index * 12+6] = properties["point_1_x"]!
                        instance.data![offset + index * 12+7] = properties["point_1_y"]!
                    } else
                        if ( shape.pointCount == 3 ) {
                            instance.data![offset + index * 12+4] = properties["point_0_x"]!
                            instance.data![offset + index * 12+5] = properties["point_0_y"]!
                            instance.data![offset + index * 12+6] = properties["point_1_x"]!
                            instance.data![offset + index * 12+7] = properties["point_1_y"]!
                            instance.data![offset + index * 12+8] = properties["point_2_x"]!
                            instance.data![offset + index * 12+9] = properties["point_2_y"]!
                }
                instance.data![offset + index * 12+10] = properties["rotate"]! * Float.pi / 180
                
                index += 1
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in instance.objects {
            parseObject(object)
        }
        
        memcpy(instance.buffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        compute!.run( instance.state, inBuffer: instance.buffer )
        return compute!.texture
    }
    
    ///
    func getShapeAt( x: Float, y: Float, width: Float, height: Float, multiSelect: Bool = false, instance: BuilderInstance, camera: Camera, timeline: MMTimeline)
    {
        var source =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

        float4 merge(float4 d1, float4 d2)
        {
            if ( d1.x < d2.x ) return d1;
            else return d2;
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

        float2 rotateCCW(float2 pos, float angle)
        {
            float ca = cos(angle),  sa = sin(angle);
            return pos * float2x2(ca, sa, -sa, ca);
        }

        """
        
        source += getGlobalCode(objects:instance.objects)
        
        source +=
        """
        
        kernel void
        selectedAt(device float4  *out [[ buffer(0) ]],
        uint id [[ thread_position_in_grid ]])
        {
            float2 fragCoord = float2( \(x), \(y) );
            float2 uv = 700. * (fragCoord.xy + float(0.5)) / \(width);
        
            float2 center = float2( 350., 350. * \(height) / \(width) );
            uv = translate(uv, center - float2( \(camera.xPos), \(camera.yPos) ) );
            float2 tuv = uv;
        
            float4 dist = float4(1000, -1, -1, -1);
        
        """
        
        for (objectIndex, object) in instance.objects.enumerated() {
            for (shapeIndex, shape) in object.shapes.enumerated() {
                
                let transformed = timeline.transformProperties(sequence:sequence, uuid:shape.uuid, properties:shape.properties)
                let posX : Float = transformed["posX"]!
                let posY : Float = transformed["posY"]!
                let rotate : Float = transformed["rotate"]! * Float.pi / 180
                
                source += "uv = translate( tuv, float2( \(posX), \(posY) ) );\n"
                if rotate != 0.0 {
                    if shape.pointCount < 2 {
                        source += "uv = rotateCW( uv, \(rotate) );\n"
                    } else
                        if shape.pointCount == 2 {
                            let offX = (transformed["point_0_x"]! + transformed["point_1_x"]!) / 2
                            let offY = (transformed["point_0_y"]! + transformed["point_1_y"]!) / 2
                            source += "uv = rotateCW( uv - float2( \(offX), \(offY) ), \(rotate) );\n"
                            source += "uv += float2( \(offX), \(offY) );\n"
                        } else
                            if shape.pointCount == 3 {
                                let offX = (transformed["point_0_x"]! + transformed["point_1_x"]! + transformed["point_2_x"]!) / 3
                                let offY = (transformed["point_0_y"]! + transformed["point_1_y"]! + transformed["point_2_y"]!) / 3
                                source += "uv = rotateCW( uv - float2( \(offX), \(offY) ), \(rotate) );\n"
                                source += "uv += float2( \(offX), \(offY) );\n"
                    }
                }
                source += "dist = merge( dist, float4(" + shape.createDistanceCode(uvName: "uv", transProperties: transformed) + ", \(0), \(objectIndex), \(shapeIndex) ) );"
            }
        }
        
        source +=
        """
        
            out[id] = dist;
        }
        """
        
        let library = compute!.createLibraryFromSource(source: source)
        let state = compute!.createState(library: library, name: "selectedAt")
        
        let outBuffer = compute!.device.makeBuffer(length: MemoryLayout<float4>.stride, options: [])!
        compute!.runBuffer(state, outBuffer: outBuffer)
        
        let result = outBuffer.contents().load(as: float4.self)
        //        print( result )
        
        if result.x < 0 {
            let objectId : Int = Int(result.z)
            let object = instance.objects[objectId]
            
            let shapeId : Int = Int(result.w)
            let shape = object.shapes[shapeId]
            
            if !multiSelect {
                object.selectedShapes = [shape.uuid]
            } else if !object.selectedShapes.contains(shape.uuid) {
                object.selectedShapes.append( shape.uuid )
            }
        } else {
            if !multiSelect {
                let object = instance.objects[0]
                object.selectedShapes = []
            }
        }
    }
    
    /// Creates the global code for all shapes in this layer
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
    
    /// Retuns the shape count for the given objects
    func getShapeCount(objects: [Object]) -> Int {
        var index : Int = 0
        
        func parseObject(_ object: Object)
        {
            for _ in object.shapes {
                index += 1
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in objects {
            parseObject(object)
        }
        
        return index
    }
}
