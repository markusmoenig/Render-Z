//
//  Layer.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Layer : Codable
{
    var layerManager    : LayerManager?
    var objects         : [Object]
    
    var uuid            : UUID
    var active          : Bool
    var currentUUID     : UUID?
    
    /// The default sequence for all objects and shapes in the layer
    var sequence        : MMTlSequence

    var compute         : MMCompute?
    var state           : MTLComputePipelineState?
    
    var layerData       : [Float]?
    var layerBuffer     : MTLBuffer?
    
    private enum CodingKeys: String, CodingKey {
        case objects
        case uuid
        case active
        case currentUUID
        case sequence
    }
    
    init(layerManager: LayerManager)
    {
        objects = []
        active = true
        
        uuid = UUID()
        currentUUID = nil
        
        sequence = MMTlSequence()

        self.layerManager = layerManager

        let object = Object()
        addObject( object )
        
        currentUUID = object.uuid
    }
    
    func addObject(_ object: Object)
    {
        objects.append( object )
        object.name = "Object #" + String(objects.count)
    }
    
    /// Build the source for the layer
    func build()
    {
        layerData = []
        
        let shapeCount = assignShapeIndices()

        var source =
        """
            #include <metal_stdlib>
            #include <simd/simd.h>
            using namespace metal;

            float merge(float d1, float d2)
            {
                return min(d1, d2);
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
                float2      scale;
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
            
            source += getGlobalCode()
        
            layerData!.append( layerManager!.camera[0] )
            layerData!.append( layerManager!.camera[1] )
            layerData!.append( 0 )
            layerData!.append( 0 )

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
        
//        var index : Int = 0
        
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
//                shape.flatLayerIndex = index
//                index += 1
                
                let properties = layerManager!.app?.bottomRegion?.timeline.transformProperties(sequence: sequence, uuid: shape.uuid, properties: shape.properties)
                
                source += "uv = translate( tuv, layerData->shape[\(shape.flatLayerIndex!)].pos );"
                source += "if ( layerData->shape[\(shape.flatLayerIndex!)].rotate != 0.0 ) uv = rotateCW( uv, layerData->shape[\(shape.flatLayerIndex!)].rotate );\n"
                source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
                
                let posX = properties!["posX"]
                let posY = properties!["posY"]
                let scaleX = properties!["scaleX"]
                let scaleY = properties!["scaleY"]
                let rotate = (properties!["rotate"]!) * Float.pi / 180
                
                layerData!.append( posX! )
                layerData!.append( posY! )
                layerData!.append( scaleX! )
                layerData!.append( scaleY! )
                layerData!.append( rotate )
                layerData!.append( 0 )
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in objects {
            parseObject(object)
        }
        

        /*
        for object in objects {
            for shape in object.shapes {
                let posX = shape.properties["posX"]
                let posY = shape.properties["posY"]
                source += "uv = translate( tuv, float2( \(posX ?? 0), \(posY ?? 0) ) );"
                source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
                
                layerData!.append( posX! )
                layerData!.append( posY! )
            }
        }*/
        
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
        
        layerBuffer = compute!.device.makeBuffer(bytes: layerData!, length: layerData!.count * MemoryLayout<Float>.stride, options: [])!
        
        let library = compute!.createLibraryFromSource(source: source)
        state = compute!.createState(library: library, name: "layerBuilder")
    }
    
    /// Render the layer
    @discardableResult func render(width:Float, height:Float) -> MTLTexture
    {
        if compute == nil {
            compute = MMCompute()
            build()
        }
        
        if compute!.width != width || compute!.height != height {
            compute!.allocateTexture(width: width, height: height)
        }
        
        layerData![0] = layerManager!.camera[0]
        layerData![1] = layerManager!.camera[1]
        let offset : Int = 4
        
        // Update Shapes / Objects
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                //                shape.flatLayerIndex = index
                //                index += 1
                
                let properties = layerManager!.app?.bottomRegion?.timeline.transformProperties(sequence: sequence, uuid: shape.uuid, properties: shape.properties)
                
                layerData![offset + shape.flatLayerIndex! * 6] = properties!["posX"]!
                layerData![offset + shape.flatLayerIndex! * 6+1] = properties!["posY"]!
                layerData![offset + shape.flatLayerIndex! * 6+2] = properties!["scaleX"]!
                layerData![offset + shape.flatLayerIndex! * 6+3] = properties!["scaleY"]!
                layerData![offset + shape.flatLayerIndex! * 6+4] = properties!["rotate"]! * Float.pi / 180
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
        }
        
        for object in objects {
            parseObject(object)
        }
        
        memcpy(layerBuffer?.contents(), layerData, layerData!.count * MemoryLayout<Float>.stride)

        compute!.run( state, inBuffer: layerBuffer )
        return compute!.texture
    }
    
    /// Creates the global code for all shapes in this layer
    func getGlobalCode() -> String
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
    
    /// Returns the object with the given id
    func getObjectFromUUID(_ uuid: UUID ) -> Object?
    {
        for object in objects {
            if object.uuid == uuid {
                return object
            }
        }
        return nil
    }
    
    /// Returns the currently selected object
    func getCurrentObject() -> Object?
    {
        if currentUUID == nil { return nil }
        return getObjectFromUUID( currentUUID! )
    }
    
    /// Assigns each shape an index
    func assignShapeIndices() -> Int {
        var index : Int = 0
        
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                shape.flatLayerIndex = index
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
    
    /// Writes the shape's data into the layerData
    func updateShape(_ shape: Shape)
    {
        let offset : Int = 4 + 6 * shape.flatLayerIndex!
        
        layerData![offset]   = shape.properties["posX"]!
        layerData![offset+1] = shape.properties["posY"]!
        layerData![offset+2] = shape.properties["scaleX"]!
        layerData![offset+3] = shape.properties["scaleY"]!
        layerData![offset+4] = shape.properties["rotate"]! * Float.pi / 180
    }
}
