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
    var zoom            : Float = 1
    
    convenience init(x: Float, y: Float, zoom: Float)
    {
        self.init()
        
        self.xPos = x
        self.yPos = y
        self.zoom = zoom
    }
}

class Builder
{
    var compute         : MMCompute?
    var nodeGraph       : NodeGraph
    
    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
        compute = MMCompute()
    }
    
    /// Build the state for the given objects
    func buildObjects(objects: [Object], camera: Camera, preview: Bool  = false) -> BuilderInstance
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
        
        float mergeSmooth(float d1, float d2, float k) {
            float h = clamp( 0.5 + 0.5*(d2-d1)/k, 0.0, 1.0 );
            return mix( d2, d1, h ) - k*h*(1.0-h);
        }
        
        float subtract(float d1, float d2)
        {
            return max(d1, -d2);
        }
        
        float subtractSmooth( float d1, float d2, float k )
        {
            float h = clamp( 0.5 - 0.5*(d2+d1)/k, 0.0, 1.0 );
            return mix( d2, -d1, h ) + k*h*(1.0-h);
        }
        
        float intersect(float d1, float d2)
        {
            return max(d1, d2);
        }
        
        float intersectSmooth( float d1, float d2, float k )
        {
            float h = clamp( 0.5 - 0.5*(d2-d1)/k, 0.0, 1.0 );
            return mix( d2, d1, h ) + k*h*(1.0-h);
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
        
        float2 rotateCCW (float2 pos, float angle)
        {
            float ca = cos(angle), sa = sin(angle);
            return pos * float2x2(ca, sa, -sa, ca);
        }
        
        typedef struct
        {
            float2      pos;
            float2      size;
            float2      point0;
            float2      point1;
            float2      point2;
            float       rotate;
            float       rounding;
            float       annular;
            float       smoothBoolean;
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
        instance.data!.append( 1/camera.zoom )
        instance.data!.append( 0 )
        
        source +=
        """
        
        kernel void
        layerBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
        constant LAYER_DATA            *layerData   [[ buffer(1) ]],
        texture2d<half, access::read>   inTexture   [[texture(2)]],
        uint2                           gid         [[thread_position_in_grid]])
        {
            float2 size = float2( outTexture.get_width(), outTexture.get_height() );
            float2 fragCoord = float2( gid.x, gid.y );
            float2 uv = fragCoord;
        
            float2 center = size / 2;
            uv = translate(uv, center - float2( layerData->camera.x, layerData->camera.y ) );
            uv.y = -uv.y;
            uv *= layerData->fill.x;
            float2 tuv = uv;
        
            float dist = 1000, newDist;
        """
        
        /// Parse objects and their shapes
        
        var index : Int = 0
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
                
                source += "uv = translate( tuv, layerData->shape[\(index)].pos );"
                if shape.pointCount < 2 {
                    source += "if ( layerData->shape[\(index)].rotate != 0.0 ) uv = rotateCCW( uv, layerData->shape[\(index)].rotate );\n"
                } else
                    if shape.pointCount == 2 {
                        source += "if ( layerData->shape[\(index)].rotate != 0.0 ) { uv = rotateCCW( uv - ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1) / 2, layerData->shape[\(index)].rotate );\n"
                        source += "uv += ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1) / 2;}\n"
                    } else
                        if shape.pointCount == 3 {
                            source += "if ( layerData->shape[\(index)].rotate != 0.0 ) { uv = rotateCCW( uv - ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1 + + layerData->shape[\(index)].point2) / 3, layerData->shape[\(index)].rotate );\n"
                            source += "uv += ( layerData->shape[\(index)].point0 + layerData->shape[\(index)].point1 + layerData->shape[\(index)].point2) / 3;}\n"
                }
                
                var booleanCode = "merge"
                if shape.mode == .Subtract {
                    booleanCode = "subtract"
                } else
                    if shape.mode == .Intersect {
                        booleanCode = "intersect"
                }
                
                source += "newDist = " + shape.createDistanceCode(uvName: "uv", layerIndex: index) + ";\n"

                if shape.supportsRounding {
                    source += "newDist -= layerData->shape[\(index)].rounding;\n"
                }
                
                // --- Annular
                source += "if ( layerData->shape[\(index)].annular != 0.0 ) newDist = abs(newDist) - layerData->shape[\(index)].annular;\n"

                // --- Inverse
                if shape.properties["inverse"] != nil && shape.properties["inverse"]! == 1 {
                    source += "newDist = -newDist;\n"
                }
                
                if booleanCode != "subtract" {
                    source += "if ( layerData->shape[\(index)].smoothBoolean == 0.0 )"
                    source += "  dist = \(booleanCode)( dist, newDist );"
                    source += "  else dist = \(booleanCode)Smooth( dist, newDist, layerData->shape[\(index)].smoothBoolean );"
                } else {
                    source += "if ( layerData->shape[\(index)].smoothBoolean == 0.0 )"
                    source += "  dist = \(booleanCode)( dist, newDist );"
                    source += "  else dist = \(booleanCode)Smooth( newDist, dist, layerData->shape[\(index)].smoothBoolean );"
                }

                let posX = properties["posX"]! + parentPosX
                let posY = properties["posY"]! + parentPosY
                let sizeX = properties[shape.widthProperty]
                let sizeY = properties[shape.heightProperty]
                let rotate = (properties["rotate"]!+parentRotate) * Float.pi / 180
                
                instance.data!.append( posX )
                instance.data!.append( posY )
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
                instance.data!.append( properties["rounding"]! )
                instance.data!.append( properties["annular"]! )
                instance.data!.append( properties["smoothBoolean"]! )
                
                index += 1
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            parentPosX -= object.properties["posX"]!
            parentPosY -= object.properties["posY"]!
            parentRotate -= object.properties["rotate"]!
        }
        
        for object in objects {
            parentPosX = 0
            parentPosY = 0
            parentRotate = 0
            parseObject(object)
        }
        
        source +=
        """
            float4 fillColor = float4( 0.5, 0.5, 0.5, 1);
            float4 borderColor = float4( 1 );
        
            float4 col = float4(0);
        """
        
        if preview {
            // Preview Pattern
            source +=
            """
            float4 checkerColor1 = float4( 0.0, 0.0, 0.0, 1.0 );
            float4 checkerColor2 = float4( 0.2, 0.2, 0.2, 1.0 );
            
            uv = fragCoord;
            uv -= float2( size / 2  - 0.5);
            
            col = checkerColor1;
            
            float cWidth = 12.0;
            float cHeight = 12.0;
            
            if ( fmod( floor( uv.x / cWidth ), 2.0 ) == 0.0 ) {
                if ( fmod( floor( uv.y / cHeight ), 2.0 ) != 0.0 ) col=checkerColor2;
            } else {
                if ( fmod( floor( uv.y / cHeight ), 2.0 ) == 0.0 ) col=checkerColor2;
            }

            """
        }
        
        source +=
        """
        
            col = mix( col, fillColor, fillMask( dist ) * fillColor.w );
            col = mix( col, borderColor, borderMask( dist, 2 ) );
        
        """
        
        if preview {
            // Preview border
            source +=
            """
            
            float2 d = abs( uv ) - float2( 100, 65 );
            float borderDist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            col = mix( col, float4(0,0,0,1), borderMask( borderDist, 2 ) );
            
            """
        }
        
        source +=
        """
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
    @discardableResult func render(width:Float, height:Float, instance: BuilderInstance, camera: Camera, outTexture: MTLTexture? = nil, frame: Int = 0) -> MTLTexture
    {
        if outTexture == nil {
            if compute!.width != width || compute!.height != height {
                compute!.allocateTexture(width: width, height: height)
            }
        }
        
        instance.texture = outTexture == nil ? compute!.texture : outTexture

        instance.data![0] = camera.xPos
        instance.data![1] = camera.yPos
        instance.data![2] = 1/camera.zoom
        let offset : Int = 4
        var index : Int = 0

        // Update Shapes / Objects
        
        var parentPosX : Float = 0
        var parentPosY : Float = 0
        var parentRotate : Float = 0
        let itemSize : Int = 14
        var rootObject : Object!
        
        func parseObject(_ object: Object)
        {
            // Transform Object Properties
            let objectProperties : [String:Float]
            if rootObject.currentSequence != nil {
                objectProperties = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: object.uuid, properties: object.properties, frame: frame)
            } else {
                objectProperties = object.properties
            }
            
            parentPosX += objectProperties["posX"]!
            parentPosY += objectProperties["posY"]!
            parentRotate += objectProperties["rotate"]!
            
            for shape in object.shapes {
                
                let properties : [String:Float]
                if rootObject.currentSequence != nil {
                    properties = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: shape.uuid, properties: shape.properties, frame: frame)
                } else {
                    properties = shape.properties
                }
                
                instance.data![offset + index * itemSize] = properties["posX"]! + parentPosX
                instance.data![offset + index * itemSize+1] = properties["posY"]! + parentPosY
                instance.data![offset + index * itemSize+2] = properties[shape.widthProperty]!
                instance.data![offset + index * itemSize+3] = properties[shape.heightProperty]!
                if ( shape.pointCount == 1 ) {
                    instance.data![offset + index * itemSize+4] = properties["point_0_x"]!
                    instance.data![offset + index * itemSize+5] = properties["point_0_y"]!
                } else
                    if ( shape.pointCount == 2 ) {
                        instance.data![offset + index * itemSize+4] = properties["point_0_x"]!
                        instance.data![offset + index * itemSize+5] = properties["point_0_y"]!
                        instance.data![offset + index * itemSize+6] = properties["point_1_x"]!
                        instance.data![offset + index * itemSize+7] = properties["point_1_y"]!
                    } else
                        if ( shape.pointCount == 3 ) {
                            instance.data![offset + index * itemSize+4] = properties["point_0_x"]!
                            instance.data![offset + index * itemSize+5] = properties["point_0_y"]!
                            instance.data![offset + index * itemSize+6] = properties["point_1_x"]!
                            instance.data![offset + index * itemSize+7] = properties["point_1_y"]!
                            instance.data![offset + index * itemSize+8] = properties["point_2_x"]!
                            instance.data![offset + index * itemSize+9] = properties["point_2_y"]!
                }
                instance.data![offset + index * itemSize+10] = (properties["rotate"]!+parentRotate) * Float.pi / 180
                
                let minSize : Float = min(properties[shape.widthProperty]!,properties[shape.heightProperty]!)
                
                instance.data![offset + index * itemSize+11] = properties["rounding"]! * minSize
                instance.data![offset + index * itemSize+12] = properties["annular"]! * minSize / 1.9
                instance.data![offset + index * itemSize+13] = properties["smoothBoolean"]! * minSize
                
                index += 1
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            parentPosX -= objectProperties["posX"]!
            parentPosY -= objectProperties["posY"]!
            parentRotate -= objectProperties["rotate"]!
        }
        
        for object in instance.objects {
            rootObject = object
            parentPosX = 0
            parentPosY = 0
            parentRotate = 0
            parseObject(object)
        }
        
        memcpy(instance.buffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        if outTexture == nil {
            compute!.run( instance.state, inBuffer: instance.buffer )
            return compute!.texture
        } else {
            compute!.run( instance.state, outTexture: outTexture, inBuffer: instance.buffer )
            return outTexture!
        }
    }
    
    ///
    func getShapeAt( x: Float, y: Float, width: Float, height: Float, multiSelect: Bool = false, instance: BuilderInstance, camera: Camera, frame: Int = 0) -> Object?
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

        float4 mergeSmooth(float4 d1, float4 d2, float k) {
            float h = clamp( 0.5 + 0.5*(d2.x-d1.x)/k, 0.0, 1.0 );
            float rc = mix( d2.x, d1.x, h ) - k*h*(1.0-h);
            
            if ( d1.x < d2.x ) {
                d1.x = rc;
                return d1;
            } else {
                d2.x = rc;
                return d2;
            }
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

        """
        
        source += getGlobalCode(objects:instance.objects)
        
        source +=
        """
        
        kernel void
        selectedAt(device float4  *out [[ buffer(0) ]],
        uint id [[ thread_position_in_grid ]])
        {
            float2 fragCoord = float2( \(x), \(y) );
            float2 uv = fragCoord;
        
            float2 center = float2(\(width/2), \(height/2) );
            uv = translate(uv, center - float2( \(camera.xPos), \(camera.yPos) ) );
            uv.y = -uv.y;
            float2 tuv = uv;
        
            float4 dist = float4(1000, -1, -1, -1);
            float newDist;
        """
        
        var parentPosX : Float = 0
        var parentPosY : Float = 0
        var parentRotate : Float = 0
        
        var objectIndex : Int = 0
        var rootObject : Object!
        
        var objectList : [Int:Object] = [:]
        
        func parseObject(_ object: Object)
        {
            objectList[objectIndex] = object
            
            // Transform Object Properties
            let objectProperties : [String:Float]
            if rootObject.currentSequence != nil {
                objectProperties = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: object.uuid, properties: object.properties, frame: frame)
            } else {
                objectProperties = object.properties
            }
            
            parentPosX += objectProperties["posX"]!
            parentPosY += objectProperties["posY"]!
            parentRotate += objectProperties["rotate"]!
            
            for (shapeIndex, shape) in object.shapes.enumerated() {
                
                let transformed = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: shape.uuid, properties: shape.properties, frame: frame)
                let posX : Float = parentPosX + transformed["posX"]!
                let posY : Float = parentPosY + transformed["posY"]!
                let rotate : Float = (parentRotate + transformed["rotate"]!) * Float.pi / 180
                
                source += "uv = translate( tuv, float2( \(posX), \(posY) ) );\n"
                if rotate != 0.0 {
                    if shape.pointCount < 2 {
                        source += "uv = rotateCCW( uv, \(rotate) );\n"
                    } else
                        if shape.pointCount == 2 {
                            let offX = (transformed["point_0_x"]! + transformed["point_1_x"]!) / 2
                            let offY = (transformed["point_0_y"]! + transformed["point_1_y"]!) / 2
                            source += "uv = rotateCCW( uv - float2( \(offX), \(offY) ), \(rotate) );\n"
                            source += "uv += float2( \(offX), \(offY) );\n"
                        } else
                            if shape.pointCount == 3 {
                                let offX = (transformed["point_0_x"]! + transformed["point_1_x"]! + transformed["point_2_x"]!) / 3
                                let offY = (transformed["point_0_y"]! + transformed["point_1_y"]! + transformed["point_2_y"]!) / 3
                                source += "uv = rotateCCW( uv - float2( \(offX), \(offY) ), \(rotate) );\n"
                                source += "uv += float2( \(offX), \(offY) );\n"
                    }
                }
                
                source += "newDist = " + shape.createDistanceCode(uvName: "uv", transProperties: transformed) + ";\n"
                
                let minSize : Float = min(transformed[shape.widthProperty]!,transformed[shape.heightProperty]!)
                
                if shape.supportsRounding {
                    source += "newDist -= \(transformed["rounding"]!*minSize);\n"
                }
                
                // --- Annular
                if transformed["annular"]! != 0 {
                    source += "newDist = abs(newDist) - \(transformed["annular"]!*minSize / 1.9);\n"
                }

                // --- Inverse
                if shape.properties["inverse"]! == 1 {
                    source += "newDist = -newDist;\n"
                }

                if transformed["smoothBoolean"]! == 0.0 {
                    source += "dist = merge( dist, float4( newDist, \(0), \(objectIndex), \(shapeIndex) ) );"
                } else {
                    source += "dist = mergeSmooth( dist, float4( newDist, \(0), \(objectIndex), \(shapeIndex) ), \(transformed["smoothBoolean"]!*minSize) );"
                }
            }
            
            objectIndex += 1
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            parentPosX -= objectProperties["posX"]!
            parentPosY -= objectProperties["posY"]!
            parentRotate -= objectProperties["rotate"]!
        }
        
        for object in instance.objects {
            rootObject = object
            parentPosX = 0
            parentPosY = 0
            parentRotate = 0
            parseObject(object)
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
        print( result )
        
        if result.x < 0 {
            let objectId : Int = Int(result.z)
            let object = objectList[objectId]!
            
            let shapeId : Int = Int(result.w)
            let shape = object.shapes[shapeId]
            
            if !multiSelect {
                object.selectedShapes = [shape.uuid]
            } else if !object.selectedShapes.contains(shape.uuid) {
                object.selectedShapes.append( shape.uuid )
            }
            return object
        } else {
            if !multiSelect {
                let objectId : Int = Int(result.z)
                let object = objectList[objectId]!
                object.selectedShapes = []
                return object
            }
        }
        return nil
    }
    
    /// Creates the global code for all shapes in this layer
    func getGlobalCode(objects: [Object]) -> String
    {
        var coll : [String] = []
        var result = ""
        
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                if !coll.contains(shape.name) {
                    result += shape.globalCode
                    coll.append( shape.name )
                }
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in objects {
            parseObject(object)
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
