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
    
    // Offset to the point data array
    var pointDataOffset : Int = 0
    // Offset to the object data array
    var objectDataOffset : Int = 0
    // Offset to the material data array
    var materialDataOffset : Int = 0
    
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
        let shapeAndPointCount = getShapeAndPointCount(objects:objects)
        
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
            float       rotate;
            float       rounding;
            float       annular;
            float       smoothBoolean;
        } SHAPE_DATA;
        
        typedef struct
        {
            float       border;
            float       fill1;
            float2      fill2;
        } OBJECT_DATA;
        
        typedef struct
        {
            float2      camera;
            float2      fill;
        
            SHAPE_DATA  shapes[\(max(shapeAndPointCount.0, 1))];
            float2      points[\(max(shapeAndPointCount.1, 1))];
            OBJECT_DATA objects[\(max(shapeAndPointCount.2, 1))];
            float4      materialData[\(max(shapeAndPointCount.3, 1))];
        } LAYER_DATA;
        
        """
        
        source += Material.getMaterialStructCode()
        source += getGlobalCode(objects:objects)
        source += getRenderSourceCode();

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
            float2 tuv = uv, pAverage;
        
            float dist = 100000, newDist;
            MATERIAL_DATA bodyMaterial;
            bodyMaterial.baseColor = float4(0.5, 0.5, 0.5, 1);
            clearMaterial( &bodyMaterial );
            MATERIAL_DATA borderMaterial;
            borderMaterial.baseColor = float4(1);
            clearMaterial( &borderMaterial );
            int materialId = -1;
        
        """
        
        /// Parse objects and their shapes
        
        var index : Int = 0 // shape index
        var objectIndex : Int = 0 // object index
        var materialDataIndex : Int = 0
        var pointIndex : Int = 0
        var parentPosX : Float = 0
        var parentPosY : Float = 0
        var parentRotate : Float = 0
        
        var materialSource : String = ""
        
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
                
                source += "tuv = translate( uv, layerData->shapes[\(index)].pos );"
                if shape.pointCount == 0 {
                    source += "if ( layerData->shapes[\(index)].rotate != 0.0 ) tuv = rotateCCW( tuv, layerData->shapes[\(index)].rotate );\n"
                } else {
                    source += "if ( layerData->shapes[\(index)].rotate != 0.0 ) {\n"
                    source += "pAverage = float2(0);\n"
                    source += "for (int i = \(pointIndex); i < \(pointIndex + shape.pointCount); ++i) \n"
                    source += "pAverage += layerData->points[i];\n"
                    source += "pAverage /= \(shape.pointCount);\n"
                    source += "tuv = rotateCCW( tuv - pAverage, layerData->shapes[\(index)].rotate );\n"
                    source += "tuv += pAverage;\n"
                    source += "}\n"
                }
                
                var booleanCode = "merge"
                if shape.mode == .Subtract {
                    booleanCode = "subtract"
                } else
                    if shape.mode == .Intersect {
                        booleanCode = "intersect"
                }
                
                if shape.pointsVariable {
                    source += shape.createPointsVariableCode(shapeIndex: index, pointIndex: pointIndex)
                }
                source += "newDist = " + shape.createDistanceCode(uvName: "tuv", layerIndex: index, pointIndex: pointIndex, shapeIndex: index) + ";\n"

                if shape.supportsRounding {
                    source += "newDist -= layerData->shapes[\(index)].rounding;\n"
                }
                
                // --- Annular
                source += "if ( layerData->shapes[\(index)].annular != 0.0 ) newDist = abs(newDist) - layerData->shapes[\(index)].annular;\n"

                // --- Inverse
                if shape.properties["inverse"] != nil && shape.properties["inverse"]! == 1 {
                    source += "newDist = -newDist;\n"
                }
                
                source += "if (newDist < dist) materialId = \(objectIndex);\n"
                
                if booleanCode != "subtract" {
                    source += "if ( layerData->shapes[\(index)].smoothBoolean == 0.0 )"
                    source += "  dist = \(booleanCode)( dist, newDist );"
                    source += "  else dist = \(booleanCode)Smooth( dist, newDist, layerData->shapes[\(index)].smoothBoolean );"
                } else {
                    source += "if ( layerData->shapes[\(index)].smoothBoolean == 0.0 )"
                    source += "  dist = \(booleanCode)( dist, newDist );"
                    source += "  else dist = \(booleanCode)Smooth( newDist, dist, layerData->shapes[\(index)].smoothBoolean );"
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
                instance.data!.append( rotate )
                instance.data!.append( properties["rounding"]! )
                instance.data!.append( properties["annular"]! )
                instance.data!.append( properties["smoothBoolean"]! )

                index += 1
                pointIndex += shape.pointCount
            }
            
            // --- Material Code
            
            func createMaterialCode(_ material: Material, _ materialName: String)
            {
                var channelCode = materialName + "."
                var materialProperty : String = ""
                let channel = material.properties["channel"]
                switch channel
                {
                    case 0: materialProperty = "baseColor"
                    case 1: materialProperty = "subsurface"
                    case 2: materialProperty = "roughness"
                    case 3: materialProperty = "metallic"
                    case 4: materialProperty = "specular"
                    case 5: materialProperty = "specularTint"
                    case 6: materialProperty = "clearcoat"
                    case 7: materialProperty = "clearcoatGloss"
                    case 8: materialProperty = "anisotropic"
                    case 9: materialProperty = "sheen"
                    case 10: materialProperty = "sheenTint"
                    default: print("Invalid Channel")
                }
                channelCode += materialProperty
                let limiterType = material.properties["limiterType"]
                let materialExt = channel == 0 ? "" : ".x"

                // --- Translate material uv
                materialSource += "tuv = translate( uv, layerData->materialData[\(materialDataIndex)].xy );"
                
                // --- Rotate material uv
                materialSource += "if ( layerData->materialData[\(materialDataIndex+1)].x != 0.0 ) tuv = rotateCCW( tuv, layerData->materialData[\(materialDataIndex+1)].x );\n"
                
                materialSource += "value = " + material.createCode(uvName: "tuv", materialDataIndex: materialDataIndex+2) + ";\n"
                
                if limiterType == 0 {
                    // --- No Limiter
                    materialSource += "  " + channelCode + " = mix( " + channelCode + ", value, value.w)" + materialExt + ";\n"
                } else
                if limiterType == 1 {
                    // --- Rectangle
                    materialSource += "  d = abs( tuv ) - layerData->materialData[\(materialDataIndex)].zw;\n"
                    materialSource += "  limiterDist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);\n"
                    materialSource += "  " + channelCode + " = mix(" + channelCode + ", value\(materialExt), fillMask(limiterDist) * value.w );\n"
                } else
                if limiterType == 2 {
                    // --- Sphere
                    materialSource += "  limiterDist = length( tuv ) - layerData->materialData[\(materialDataIndex)].z;\n"
                    materialSource += "  " + channelCode + " = mix(" + channelCode + ", value\(materialExt), fillMask(limiterDist) * value.w );\n"
                } else
                if limiterType == 3 {
                    // --- Border
                    materialSource += "  limiterDist = -dist - layerData->materialData[\(materialDataIndex)].z;\n"
                    materialSource += "  " + channelCode + " = mix(" + channelCode + ", value\(materialExt), fillMask(limiterDist) * value.w );\n"
                }
            }
            
            materialSource += "if (materialId == \(objectIndex)) { float2 d; float limiterDist; float4 value;\n"
            for material in object.bodyMaterials {
                createMaterialCode(material, "bodyMaterial")
                if material.pointCount == 0 {
                    materialDataIndex += 3
                } else {
                    materialDataIndex += 2 + material.pointCount * 2
                }
            }
            for material in object.borderMaterials {
                createMaterialCode(material, "borderMaterial")
                if material.pointCount == 0 {
                    materialDataIndex += 3
                } else {
                    materialDataIndex += 2 + material.pointCount * 2
                }
            }

            materialSource += "}\n"
            objectIndex += 1
            
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
        
        instance.pointDataOffset = instance.data!.count
        
        // Fill up the points
        let pointCount = max(shapeAndPointCount.1,1)
        for _ in 0..<pointCount {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.objectDataOffset = instance.data!.count
        
        // Fill up the objects
        let objectCount = max(shapeAndPointCount.2,1)
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
        
        instance.materialDataOffset = instance.data!.count

        // Fill up the material data
        let materialDataCount = max(shapeAndPointCount.3,1)
        for _ in 0..<materialDataCount {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        source += materialSource        
        source +=
        """
        
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
        
            float fm = fillMask( dist ) * bodyMaterial.baseColor.w;
            float bm = 0;
            bodyMaterial.baseColor.w = fm;
        
            if ( materialId >= 0 )
            {
                bm = borderMask( dist, layerData->objects[materialId].border );
                if ( bm > 0.0 ) {
                    bodyMaterial.baseColor = mix( bodyMaterial.baseColor, borderMaterial.baseColor, bm * borderMaterial.baseColor.w );
                    bodyMaterial.subsurface = mix( bodyMaterial.subsurface, borderMaterial.subsurface, bm );
                    bodyMaterial.roughness = mix( bodyMaterial.roughness, borderMaterial.roughness, bm );
                    bodyMaterial.metallic = mix( bodyMaterial.metallic, borderMaterial.metallic, bm );
                    bodyMaterial.specular = mix( bodyMaterial.specular, borderMaterial.specular, bm );
                }
            }
        
            if (fm != 0 || bm != 0) col = calculatePixelColor( fragCoord, bodyMaterial );
        
        """
        
        /*
        if preview {
            // Preview border
            source +=
            """
            
            float2 d = abs( uv ) - float2( 100, 65 );
            float borderDist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            col = mix( col, float4(0,0,0,1), borderMask( borderDist, 2 ) );
            
            """
        }*/
        
        source +=
        """
            outTexture.write(half4(col.x, col.y, col.z, col.w), gid);
        }
        """
        
        //print( source )
        
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
        var pointIndex : Int = 0
        var objectIndex : Int = 0
        var materialDataIndex : Int = 0

        // Update Shapes / Objects
        
        var parentPosX : Float = 0
        var parentPosY : Float = 0
        var parentRotate : Float = 0
        let itemSize : Int = 8
        var rootObject : Object!
        var currentFrame : Int = frame
        
        func parseObject(_ object: Object)
        {
            // Transform Object Properties
            let objectProperties : [String:Float]
            if rootObject.currentSequence != nil {
                objectProperties = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: object.uuid, properties: object.properties, frame: currentFrame)
            } else {
                objectProperties = object.properties
            }
            
            parentPosX += objectProperties["posX"]!
            parentPosY += objectProperties["posY"]!
            parentRotate += objectProperties["rotate"]!
            
            for shape in object.shapes {
                
                let properties : [String:Float]
                if rootObject.currentSequence != nil {
                    properties = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: shape.uuid, properties: shape.properties, frame: currentFrame)
                } else {
                    properties = shape.properties
                }
                
                instance.data![offset + index * itemSize] = properties["posX"]! + parentPosX
                instance.data![offset + index * itemSize+1] = properties["posY"]! + parentPosY
                instance.data![offset + index * itemSize+2] = properties[shape.widthProperty]!
                instance.data![offset + index * itemSize+3] = properties[shape.heightProperty]!

                instance.data![offset + index * itemSize+4] = (properties["rotate"]!+parentRotate) * Float.pi / 180
                
                let minSize : Float = min(shape.properties["sizeX"]!,shape.properties["sizeY"]!)
                
                instance.data![offset + index * itemSize+5] = properties["rounding"]! * minSize / 2
                instance.data![offset + index * itemSize+6] = properties["annular"]! * minSize / 3.5
                instance.data![offset + index * itemSize+7] = properties["smoothBoolean"]! * minSize
                
                for i in 0..<shape.pointCount {
                    let ptConn = object.getPointConnections(shape: shape, index: i)

                    if ptConn.1 == nil {
                        // The point controls itself
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 2] = properties["point_\(i)_x"]!
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 2 + 1] = properties["point_\(i)_y"]!
                    }
                    
                    if ptConn.0 != nil {
                        // The point controls other point(s)
                        ptConn.0!.valueX = properties["posX"]! + parentPosX + properties["point_\(i)_x"]!
                        ptConn.0!.valueY = properties["posY"]! + parentPosY + properties["point_\(i)_y"]!
                    }
                    
                    if ptConn.1 != nil {
                        // The point is being controlled by another point
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 2] = ptConn.1!.valueX - properties["posX"]! - parentPosX
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 2 + 1] = ptConn.1!.valueY - properties["posY"]! - parentPosY
                    }
                }
                
                index += 1
                pointIndex += shape.pointCount
            }
            
            // --- Fill in Object Data
            instance.data![instance.objectDataOffset + (objectIndex) * 4] = objectProperties["border"]!
            objectIndex += 1
            
            // --- Fill in Material Data
            func fillInMaterialData(_ materials: [Material] )
            {
                for material in materials {
                    let properties : [String:Float]
                    if rootObject.currentSequence != nil {
                        properties = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: material.uuid, properties: material.properties, frame: frame)
                    } else {
                        properties = material.properties
                    }
                    
                    // pos + size
                    instance.data![instance.materialDataOffset + (materialDataIndex) * 4] = properties["posX"]! + parentPosX
                    instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 1] = properties["posY"]! + parentPosY
                    instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 2] = properties[material.widthProperty]!
                    instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 3] = properties[material.heightProperty]!
                    materialDataIndex += 1
                    // rotation, space for 3 more values
                    instance.data![instance.materialDataOffset + (materialDataIndex) * 4] = (properties["rotate"]!+parentRotate) * Float.pi / 180
                    materialDataIndex += 1

                    // --- values
                    if material.pointCount == 0 {
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4] = properties["value_x"]!
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 1] = properties["value_y"]!
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 2] = properties["value_z"]!
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 3] = properties["value_w"]!
                        materialDataIndex += 1
                    } else {
                        for index in 0..<material.pointCount {
                            instance.data![instance.materialDataOffset + (materialDataIndex) * 4] = properties["point_\(index)_x"]!// + properties["posX"]! + parentPosX
                            instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 1] = properties["point_\(index)_y"]!// + properties["posY"]! + parentPosY
                            materialDataIndex += 1
                        }
                        for index in 0..<material.pointCount {
                            instance.data![instance.materialDataOffset + (materialDataIndex) * 4] = properties["pointvalue_\(index)_x"]!
                            instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 1] = properties["pointvalue_\(index)_y"]!
                            instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 2] = properties["pointvalue_\(index)_z"]!
                            instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 3] = properties["pointvalue_\(index)_w"]!
                            materialDataIndex += 1
                        }
                    }
                }
            }
            fillInMaterialData(object.bodyMaterials)
            fillInMaterialData(object.borderMaterials)

            // --- End Material Data
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            parentPosX -= objectProperties["posX"]!
            parentPosY -= objectProperties["posY"]!
            parentRotate -= objectProperties["rotate"]!
        }
        
        for object in instance.objects {
            rootObject = object
            if object.instanceOf != nil {
                //print("here", object.maxFrame, object.frame)
                // If object is an instance, frame is controlled by the object itself
                currentFrame = Int(object.frame)
            } else {
                currentFrame = frame
            }
            parentPosX = 0
            parentPosY = 0
            parentRotate = 0
            parseObject(object)
            if object.instanceOf != nil {
                let frames : Float = 1 * object.animationScale
                
                if object.animationMode == .Loop {
                    object.frame += frames
                    if object.frame > object.maxFrame {
                        object.frame = 0
                    }
                } else
                if object.animationMode == .InverseLoop {
                    object.frame -= frames
                    if object.frame < 0 {
                        object.frame = object.maxFrame
                    }
                } else
                if object.animationMode == .GotoStart {
                    object.frame -= frames
                    if object.frame < 0 {
                        object.frame = 0
                    }
                } else
                if object.animationMode == .GotoEnd {
                    object.frame += frames
                    if object.frame > object.maxFrame {
                        object.frame = object.maxFrame
                    }
                }
            }
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
        
        source += Material.getMaterialStructCode()
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
        var totalShapeIndex : Int = 0
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
                
                var transformed = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: shape.uuid, properties: shape.properties, frame: frame)
                let posX : Float = parentPosX + transformed["posX"]!
                let posY : Float = parentPosY + transformed["posY"]!
                let rotate : Float = (parentRotate + transformed["rotate"]!) * Float.pi / 180
                
                // --- Correct slave point positions
                for i in 0..<shape.pointCount {
                    let ptConn = object.getPointConnections(shape: shape, index: i)
                    
                    if ptConn.0 != nil {
                        // The point controls other point(s)
                        ptConn.0!.valueX = transformed["point_\(i)_x"]! + posX
                        ptConn.0!.valueY = transformed["point_\(i)_y"]! + posY
                    }
                    
                    if ptConn.1 != nil {
                        // The point is being controlled by another point
                        transformed["point_\(i)_x"] = ptConn.1!.valueX - posX
                        transformed["point_\(i)_y"] = ptConn.1!.valueY - posY
                    }
                }
                
                // --- Rotate
                source += "uv = translate( tuv, float2( \(posX), \(posY) ) );\n"
                if rotate != 0.0 {
                    if shape.pointCount == 0 {
                        source += "uv = rotateCCW( uv, \(rotate) );\n"
                    } else {
                        var offX : Float = 0
                        var offY : Float = 0
                        for i in 0..<shape.pointCount {
                            offX += transformed["point_\(i)_x"]!
                            offY += transformed["point_\(i)_y"]!
                        }
                        offX /= Float(shape.pointCount)
                        offY /= Float(shape.pointCount)
                        source += "uv = rotateCCW( uv - float2( \(offX), \(offY) ), \(rotate) );\n"
                        source += "uv += float2( \(offX), \(offY) );\n"
                    }
                }
                
                if shape.pointsVariable {
                    source += shape.createPointsVariableCode(shapeIndex: totalShapeIndex)
                }
                source += "newDist = " + shape.createDistanceCode(uvName: "uv", transProperties: transformed, shapeIndex: totalShapeIndex) + ";\n"
                
                let minSize : Float = min(shape.properties["sizeX"]!,shape.properties["sizeY"]!)
                
                if shape.supportsRounding {
                    source += "newDist -= \(transformed["rounding"]!*minSize/2);\n"
                }
                
                // --- Annular
                if transformed["annular"]! != 0 {
                    source += "newDist = abs(newDist) - \(transformed["annular"]!*minSize / 3.5);\n"
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
                
                totalShapeIndex += 1
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
//        print( result )
        
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
                if objectList[objectId] != nil {
                    let object = objectList[objectId]!
                    object.selectedShapes = []
                    return object
                }
            }
        }
        return nil
    }
    
    /// Creates the global code for all shapes in this layer
    func getGlobalCode(objects: [Object]) -> String
    {
        var coll : [String] = []
        var result = ""
        var shapeIndex : Int = 0
        
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                if !coll.contains(shape.name) {
                    result += shape.globalCode
                    coll.append( shape.name )
                }
                
                // --- Dynamic Code
                
                if shape.dynamicCode != nil {
                    var dyn = shape.dynamicCode!
                    dyn = dyn.replacingOccurrences(of: "__shapeIndex__", with: String(shapeIndex))
                    dyn = dyn.replacingOccurrences(of: "__pointCount__", with: String(shape.pointCount))
                    result += dyn
                }
                
                shapeIndex += 1
            }
            
            // --- Global Material Code
            for material in object.bodyMaterials {
                if !coll.contains(material.name) {
                    result += material.globalCode
                    coll.append( material.name )
                }
            }
            for material in object.borderMaterials {
                if !coll.contains(material.name) {
                    result += material.globalCode
                    coll.append( material.name )
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
    func getShapeAndPointCount(objects: [Object]) -> (Int,Int,Int,Int) {
        var index : Int = 0
        var objectIndex : Int = 0
        var pointIndex : Int = 0
        var materialIndex : Int = 0
        
        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                index += 1
                pointIndex += shape.pointCount
            }
            
            for material in object.bodyMaterials {
                if material.pointCount == 0 {
                    materialIndex += 3 // value + 2 for pos, size, rotation
                } else {
                    materialIndex += 2 + material.pointCount * 2
                }
            }
            for material in object.borderMaterials {
                if material.pointCount == 0 {
                    materialIndex += 3
                } else {
                    materialIndex += 2 + material.pointCount * 2
                }
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            objectIndex += 1
        }
        
        for object in objects {
            parseObject(object)
        }
        
        return (index, pointIndex, objectIndex, materialIndex)
    }
    
    func getRenderSourceCode() -> String
    {
        let code =
        """

        #define PI 3.14159265359
        #define TWO_PI 6.28318

        #define LIGHT_TYPE_SPHERE 0
        #define LIGHT_TYPE_SUN    1

        #define clearCoatBoost 1.

        #define EPSILON 0.0001

        #define MaterialInfo MATERIAL_DATA

        struct LightInfo {
            float3 L;
            float3 position;
            float3 direction;
            float radius;
            int type;
            bool enabled;
        };

        struct SurfaceInteraction {
            float3 incomingRayDir;
            float3 point;
            float3 normal;
            float3 tangent;
            float3 binormal;
        };

        float3 linearToGamma(float3 linearColor) {
            return pow(linearColor, float3(0.4545));
        }

        float3 gammaToLinear(float3 gammaColor) {
            return pow(gammaColor, float3(2.2));
        }

        #define HASHSCALE3 float3(.1031, .1030, .0973)
        float2 hash21(const float p) {
            float3 p3 = fract(float3(p) * HASHSCALE3);
            p3 += dot(p3, p3.yzx + 19.19);
            return fract(float2((p3.x + p3.y)*p3.z, (p3.x+p3.z)*p3.y));
        }

        #define HASHSCALE1 .1031
        float hash12(const float2 p) {
            float3 p3  = fract(float3(p.xyx) * HASHSCALE1);
            p3 += dot(p3, p3.yzx + 19.19);
            return fract((p3.x + p3.y) * p3.z);
        }

        float random() {
            float seed = 0;
            return fract(sin(seed++)*43758.5453123);
        }

        float distanceSq(float3 v1, float3 v2) {
            float3 d = v1 - v2;
            return dot(d, d);
        }

        float pow2(float x) {
            return x*x;
        }

        void createBasis(float3 normal, thread float3 *tangent, thread float3* binormal){
            if (abs(normal.x) > abs(normal.y)) {
                *tangent = normalize(float3(0., normal.z, -normal.y));
            }
            else {
                *tangent = normalize(float3(-normal.z, 0., normal.x));
            }
            
            *binormal = cross(normal, *tangent);
        }

        void directionOfAnisotropicity(float3 normal, thread float3 *tangent, thread float3 *binormal){
            *tangent = cross(normal, float3(1.,0.,1.));
            *binormal = normalize(cross(normal, *tangent));
            *tangent = normalize(cross(normal, *binormal));
        }

        float3 sphericalDirection(float sinTheta, float cosTheta, float sinPhi, float cosPhi) {
            return float3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta);
        }

        float3 uniformSampleCone(float2 u12, float cosThetaMax, float3 xbasis, float3 ybasis, float3 zbasis) {
            float cosTheta = (1. - u12.x) + u12.x * cosThetaMax;
            float sinTheta = sqrt(1. - cosTheta * cosTheta);
            float phi = u12.y * TWO_PI;
            float3 samplev = sphericalDirection(sinTheta, cosTheta, sin(phi), cos(phi));
            return samplev.x * xbasis + samplev.y * ybasis + samplev.z * zbasis;
        }

        bool sameHemiSphere(const float3 wo, const float3 wi, const float3 normal) {
            return dot(wo, normal) * dot(wi, normal) > 0.0;
        }

        float2 concentricSampleDisk(const float2 u) {
            float2 uOffset = 2. * u - float2(1., 1.);
            
            if (uOffset.x == 0. && uOffset.y == 0.) return float2(0., 0.);
            
            float theta, r;
            if (abs(uOffset.x) > abs(uOffset.y)) {
                r = uOffset.x;
                theta = PI/4. * (uOffset.y / uOffset.x);
            } else {
                r = uOffset.y;
                theta = PI/2. - PI/4. * (uOffset.x / uOffset.y);
            }
            return r * float2(cos(theta), sin(theta));
        }

        float3 cosineSampleHemisphere(const float2 u) {
            float2 d = concentricSampleDisk(u);
            float z = sqrt(max(EPSILON, 1. - d.x * d.x - d.y * d.y));
            return float3(d.x, d.y, z);
        }

        float3 uniformSampleHemisphere(const float2 u) {
            float z = u[0];
            float r = sqrt(max(EPSILON, 1. - z * z));
            float phi = 2. * PI * u[1];
            return float3(r * cos(phi), r * sin(phi), z);
        }

        float visibilityTest(float3 ro, float3 rd) {
            float softShadowValue = 1.;
        //    SurfaceInteraction interaction;// = calcSoftshadow(ro, rd, 0.01, 3., 3, softShadowValue);
            return softShadowValue;
        }

        float visibilityTestSun(float3 ro, float3 rd) {
            float softShadowValue = 1.;
        //    SurfaceInteraction interaction = calcSoftshadow(ro, rd, 0.01, 3., 0, softShadowValue);
            return softShadowValue;//IS_SAME_MATERIAL(interaction.objId, 0.) ? 1. : 0.;
        }

        float powerHeuristic(float nf, float fPdf, float ng, float gPdf){
            float f = nf * fPdf;
            float g = ng * gPdf;
            return (f*f)/(f*f + g*g);
        }

        float schlickWeight(float cosTheta) {
            float m = clamp(1. - cosTheta, 0., 1.);
            return (m * m) * (m * m) * m;
        }

        float GTR1(float NdotH, float a) {
            if (a >= 1.) return 1./PI;
            float a2 = a*a;
            float t = 1. + (a2-1.)*NdotH*NdotH;
            return (a2-1.) / (PI*log(a2)*t);
        }

        float GTR2(float NdotH, float a) {
            float a2 = a*a;
            float t = 1. + (a2-1.)*NdotH*NdotH;
            return a2 / (PI * t*t);
        }

        float GTR2_aniso(float NdotH, float HdotX, float HdotY, float ax, float ay) {
            return 1. / (PI * ax*ay * pow2( pow2(HdotX/ax) + pow2(HdotY/ay) + NdotH*NdotH ));
        }

        float smithG_GGX(float NdotV, float alphaG) {
            float a = alphaG*alphaG;
            float b = NdotV*NdotV;
            return 1. / (abs(NdotV) + max(sqrt(a + b - a*b), EPSILON));
        }

        float smithG_GGX_aniso(float NdotV, float VdotX, float VdotY, float ax, float ay) {
            return 1. / (NdotV + sqrt( pow2(VdotX*ax) + pow2(VdotY*ay) + pow2(NdotV) ));
        }

        float pdfLambertianReflection(const float3 wi, const float3 wo, const float3 normal) {
            return sameHemiSphere(wo, wi, normal) ? abs(dot(normal, wi))/PI : 0.;
        }

        float pdfMicrofacet(const float3 wi, const float3 wo, const SurfaceInteraction interaction, const MaterialInfo material) {
            if (!sameHemiSphere(wo, wi, interaction.normal)) return 0.;
            float3 wh = normalize(wo + wi);
            
            float NdotH = dot(interaction.normal, wh);
            float alpha2 = material.roughness * material.roughness;
            alpha2 *= alpha2;
            
            float cos2Theta = NdotH * NdotH;
            float denom = cos2Theta * ( alpha2 - 1.) + 1.;
            if( denom == 0. ) return 0.;
            float pdfDistribution = alpha2 * NdotH /(PI * denom * denom);
            return pdfDistribution/(4. * dot(wo, wh));
        }

        float pdfMicrofacetAniso(const float3 wi, const float3 wo, const float3 X, const float3 Y, const SurfaceInteraction interaction, const MaterialInfo material) {
            if (!sameHemiSphere(wo, wi, interaction.normal)) return 0.;
            float3 wh = normalize(wo + wi);
            
            float aspect = sqrt(1.-material.anisotropic*.9);
            float alphax = max(.001, pow2(material.roughness)/aspect);
            float alphay = max(.001, pow2(material.roughness)*aspect);
            
            float alphax2 = alphax * alphax;
            float alphay2 = alphax * alphay;
            
            float hDotX = dot(wh, X);
            float hDotY = dot(wh, Y);
            float NdotH = dot(interaction.normal, wh);
            
            float denom = hDotX * hDotX/alphax2 + hDotY * hDotY/alphay2 + NdotH * NdotH;
            if( denom == 0. ) return 0.;
            float pdfDistribution = NdotH /(PI * alphax * alphay * denom * denom);
            return pdfDistribution/(4. * dot(wo, wh));
        }

        float pdfClearCoat(const float3 wi, const float3 wo, const SurfaceInteraction interaction, const MaterialInfo material) {
            if (!sameHemiSphere(wo, wi, interaction.normal)) return 0.;
            
            float3 wh = wi + wo;
            wh = normalize(wh);
            
            float NdotH = abs(dot(wh, interaction.normal));
            float Dr = GTR1(NdotH, mix(.1,.001,material.clearcoatGloss));
            return Dr * NdotH/ (4. * dot(wo, wh));
        }

        float3 disneyDiffuse(const float NdotL, const float NdotV, const float LdotH, const MaterialInfo material) {
            
            float FL = schlickWeight(NdotL), FV = schlickWeight(NdotV);
            
            float Fd90 = 0.5 + 2. * LdotH*LdotH * material.roughness;
            float Fd = mix(1.0, Fd90, FL) * mix(1.0, Fd90, FV);
            
            return (1./PI) * Fd * material.baseColor.xyz;
        }

        float3 disneySubsurface(const float NdotL, const float NdotV, const float LdotH, const MaterialInfo material) {
            
            float FL = schlickWeight(NdotL), FV = schlickWeight(NdotV);
            float Fss90 = LdotH*LdotH*material.roughness;
            float Fss = mix(1.0, Fss90, FL) * mix(1.0, Fss90, FV);
            float ss = 1.25 * (Fss * (1. / (NdotL + NdotV) - .5) + .5);
            
            return (1./PI) * ss * material.baseColor.xyz;
        }

        float3 disneyMicrofacetIsotropic(float NdotL, float NdotV, float NdotH, float LdotH, const MaterialInfo material) {
            
            float Cdlum = .3*material.baseColor.r + .6*material.baseColor.g + .1*material.baseColor.b; // luminance approx.
            
            float3 Ctint = Cdlum > 0. ? material.baseColor.xyz/Cdlum : float3(1.); // normalize lum. to isolate hue+sat
            float3 Cspec0 = mix(material.specular *.08 * mix(float3(1.), Ctint, material.specularTint), material.baseColor.xyz, material.metallic);
            
            float a = max(.001, pow2(material.roughness));
            float Ds = GTR2(NdotH, a);
            float FH = schlickWeight(LdotH);
            float3 Fs = mix(Cspec0, float3(1), FH);
            float Gs;
            Gs  = smithG_GGX(NdotL, a);
            Gs *= smithG_GGX(NdotV, a);
            
            return Gs*Fs*Ds;
        }

        float3 disneyMicrofacetAnisotropic(float NdotL, float NdotV, float NdotH, float LdotH,
                                         const float3 L, const float3 V,
                                         const float3 H, const float3 X, const float3 Y,
                                         const MaterialInfo material) {
            
            float Cdlum = .3*material.baseColor.r + .6*material.baseColor.g + .1*material.baseColor.b;
            
            float3 Ctint = Cdlum > 0. ? material.baseColor.xyz/Cdlum : float3(1.);
            float3 Cspec0 = mix(material.specular *.08 * mix(float3(1.), Ctint, material.specularTint), material.baseColor.xyz, material.metallic);
            
            float aspect = sqrt(1.-material.anisotropic*.9);
            float ax = max(.001, pow2(material.roughness)/aspect);
            float ay = max(.001, pow2(material.roughness)*aspect);
            float Ds = GTR2_aniso(NdotH, dot(H, X), dot(H, Y), ax, ay);
            float FH = schlickWeight(LdotH);
            float3 Fs = mix(Cspec0, float3(1), FH);
            float Gs;
            Gs  = smithG_GGX_aniso(NdotL, dot(L, X), dot(L, Y), ax, ay);
            Gs *= smithG_GGX_aniso(NdotV, dot(V, X), dot(V, Y), ax, ay);
            
            return Gs*Fs*Ds;
        }

        float disneyClearCoat(float NdotL, float NdotV, float NdotH, float LdotH, const MaterialInfo material) {
            float gloss = mix(.1,.001,material.clearcoatGloss);
            float Dr = GTR1(abs(NdotH), gloss);
            float FH = schlickWeight(LdotH);
            float Fr = mix(.04, 1.0, FH);
            float Gr = smithG_GGX(NdotL, .25) * smithG_GGX(NdotV, .25);
            return clearCoatBoost * material.clearcoat * Fr * Gr * Dr;
        }

        float3 disneySheen(float LdotH, const MaterialInfo material) {
            float FH = schlickWeight(LdotH);
            float Cdlum = .3*material.baseColor.r + .6*material.baseColor.g  + .1*material.baseColor.b;
            
            float3 Ctint = Cdlum > 0. ? material.baseColor.xyz/Cdlum : float3(1.);
            float3 Csheen = mix(float3(1.), Ctint, material.sheenTint);
            //float3 Fsheen = FH * material.sheen * Csheen;
            return FH * material.sheen * Csheen;
        }

        float3 lightSample( const LightInfo light, const SurfaceInteraction interaction, thread float3 *wi, thread float *lightPdf, float seed, const MaterialInfo material) {
            float3 L = (light.position - interaction.point);
            float3 V = -normalize(interaction.incomingRayDir);
            float3 r = reflect(V, interaction.normal);
            float3 centerToRay = dot( L, r ) * r - L;
            float3 closestPoint = L + centerToRay * clamp( light.radius / length( centerToRay ), 0.0, 1.0 );
            *wi = normalize(closestPoint);
            
            return light.L/dot(L, L);
        }

        float3 sampleSun(const LightInfo light, const SurfaceInteraction interaction, thread float3 *wi, thread float *lightPdf, float seed) {
            *wi = light.direction;
            return light.L;
        }

        float lightPdf(const float4 light, const SurfaceInteraction interaction) {
            float sinThetaMax2 = light.w * light.w / distanceSq(light.xyz, interaction.point);
            float cosThetaMax = sqrt(max(EPSILON, 1. - sinThetaMax2));
            return 1. / (TWO_PI * (1. - cosThetaMax));
        }


        float3 bsdfEvaluate(const float3 wi, const float3 wo, const float3 X, const float3 Y, const SurfaceInteraction interaction, const MaterialInfo material)
        {
            if( !sameHemiSphere(wo, wi, interaction.normal) )
                return float3(0.);
            
            float NdotL = dot(interaction.normal, wo);
            float NdotV = dot(interaction.normal, wi);
            
            if (NdotL < 0. || NdotV < 0.) return float3(0.);
            
            float3 H = normalize(wo+wi);
            float NdotH = dot(interaction.normal,H);
            float LdotH = dot(wo,H);
            
            float3 diffuse = disneyDiffuse(NdotL, NdotV, LdotH, material);
            float3 subSurface = disneySubsurface(NdotL, NdotV, LdotH, material);
            float3 glossy = disneyMicrofacetAnisotropic(NdotL, NdotV, NdotH, LdotH, wi, wo, H, X, Y, material);
            float clearCoat = disneyClearCoat(NdotL, NdotV, NdotH, LdotH, material);
            float3 sheen = disneySheen(LdotH, material);
            
            float3 f = ( mix(diffuse, subSurface, material.subsurface) + sheen ) * (1. - material.metallic);
            f += glossy;
            f += clearCoat;
            //f = material.specular * Lr + (1.f - material.specular) * f;
            return f;
        }



        float3 sampleLightType( const LightInfo light, const SurfaceInteraction interaction, thread float3 *wi, thread float *lightPdf, thread float *visibility, float seed, const MaterialInfo material)
        {
            if( !light.enabled ) return float3(0.);
            
            if( light.type == LIGHT_TYPE_SPHERE ) {
                float3 L = lightSample(light, interaction, wi, lightPdf, seed, material);
                float3 shadowRayDir =normalize(light.position - interaction.point);
                *visibility = visibilityTest(interaction.point + shadowRayDir * .01, shadowRayDir);
                return L;
            }
            else if( light.type == LIGHT_TYPE_SUN ) {
                float3 L = sampleSun(light, interaction, wi, lightPdf, seed);
                *visibility = visibilityTestSun(interaction.point + *wi * .01, *wi);
                return L;
            }
            else {
                return float3(0.);
            }
        }

        // From https://www.shadertoy.com/view/XlKSDR

        float3 Irradiance_SphericalHarmonics(const float3 n) {
            // Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
            return max(
                       float3( 0.754554516862612,  0.748542953903366,  0.790921515418539)
                       + float3(0.3,  0.3,  0.3) * (n.y)
                       + float3( 0.35,  0.36,  0.35) * (n.z)
                       + float3(-0.2, -0.24, -0.24) * (n.x)
                       , 0.0);
        }

        float2 PrefilteredDFG_Karis(float roughness, float NoV) {
            // Karis 2014, "Physically Based Material on Mobile"
            const float4 c0 = float4(-1.0, -0.0275, -0.572,  0.022);
            const float4 c1 = float4( 1.0,  0.0425,  1.040, -0.040);
            
            float4 r = roughness * c0 + c1;
            float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
            
            return float2(-1.04, 1.04) * a004 + r.zw;
        }

        float3 calculateDirectLight(const LightInfo light, const SurfaceInteraction interaction, const MaterialInfo material, thread float3 *wi, thread float3 *f, thread float *scatteringPdf, float seed)
        {
            float3 wo = -interaction.incomingRayDir;
            float3 Ld = float3(0.);
            float lightPdf = 0., visibility = 1.;
            
            float3 Li = sampleLightType( light, interaction, wi, &lightPdf, &visibility, seed, material);
            Li *= visibility;
            
            *f = bsdfEvaluate(*wi, wo, interaction.tangent, interaction.binormal, interaction, material) * abs(dot(*wi, interaction.normal));
            Ld += Li * *f;
            
            return Ld;
        }

        float4 calculatePixelColor(const float2 uv, MaterialInfo material)
        {
            float4 color = material.baseColor;//float4(1);
            
            float3 L = float3(0);
            float3 beta = float3(1);
            
            float seed = hash12(uv);

            SurfaceInteraction interaction;
            interaction.normal = float3(0,1,0);
            interaction.incomingRayDir = float3(0,-1,0);
            interaction.point = float3(uv.x,0,uv.y);

            float3 X = float3(0.), Y = float3(0.);
            directionOfAnisotropicity(interaction.normal, &X, &Y);
            interaction.tangent = X;
            interaction.binormal = Y;

            float3 wi;
            float3 f = float3(0.);
            float scatteringPdf = 0.;

            LightInfo light;
            light.L = float3(3.15);//float3(5.4);
            light.position = float3(0, 0, 0);
            light.direction = normalize(float3(0, 1, 0));//normalize(float3(-1.,1.,1.));
            light.radius = 0;
            light.type = LIGHT_TYPE_SUN;
            light.enabled = true;

            float3 Ld = beta * calculateDirectLight(light, interaction, material, &wi, &f, &scatteringPdf, seed);
            //Ld += beta * calculateDirectLight(light, interaction, material, &wi, &f, &scatteringPdf, seed);
            L += Ld;

            // Add indirect diffuse light from an env map
            //float3 diffuseColor = (1.0 - material.metallic) * material.baseColor.rgb ;
            //L += diffuseColor * Irradiance_SphericalHarmonics(interaction.normal)/3.14;

            return float4(L, material.baseColor.w);
        }

        """
        
        return code
    }
}
