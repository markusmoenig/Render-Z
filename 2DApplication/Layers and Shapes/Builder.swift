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
    var objectMap       : [Int:Object] = [:]
    
    var state           : MTLComputePipelineState? = nil
    var fragmentState   : MTLRenderPipelineState? = nil

    var data            : [Float]? = []
    var buffer          : MTLBuffer? = nil
    
    // Offset of the header data
    var headerOffset    : Int = 0
    // Offset to the point data array
    var pointDataOffset : Int = 0
    // Offset to the object data array
    var objectDataOffset : Int = 0
    // Offset to the material data array
    var materialDataOffset : Int = 0
    // Offset to the profile data / points
    var profileDataOffset : Int = 0
    // Offset to the variables
    var variablesDataOffset : Int = 0
    // Offset to the lights
    var lightsDataOffset : Int = 0
    
    var texture         : MTLTexture? = nil
    var scene           : Scene? = nil
    var font            : MMFont? = nil
}

class BuildData
{
    // Indices while building
    var shapeIndex          : Int = 0
    var objectIndex         : Int = 0
    var materialDataIndex   : Int = 0
    var pointIndex          : Int = 0
    var profileIndex        : Int = 0
    var variableIndex       : Int = 0

    // --- Hierarchy
    var parentPosX          : Float = 0
    var parentPosY          : Float = 0
    var parentScaleX        : Float = 1
    var parentScaleY        : Float = 1
    var parentRotate        : Float = 0
    
    // --- Source
    
    var mainDataName        : String = "layerData->"
    var materialSource      : String = ""
    var materialNormalSource: String = ""
    var objectSpecificSource: [Int:String] = [:]
    var source              : String = ""
    
    // Maximum values
    var maxShapes           : Int = 0
    var maxPoints           : Int = 0
    var maxObjects          : Int = 0
    var maxMaterialData     : Int = 0
    var maxProfileData      : Int = 0
    var maxVariables        : Int = 1
}

class Camera : Codable
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
    enum RenderMode {
        case Color, PBR, Distance
    }
    
    var compute                 : MMCompute?
    var nodeGraph               : NodeGraph
    var maxVarSize              : Int = 10

    var buildRootObjectIndex    : Int = 0
    var buildRootObjectId       : Int = 0
    
    init(_ nodeGraph: NodeGraph)
    {
        self.nodeGraph = nodeGraph
        compute = MMCompute()
    }
    
    /// Build the state for the given objects
    func buildObjects(objects: [Object], camera: Camera, fragment: MMFragment? = nil, renderMode: RenderMode = .PBR ) -> BuilderInstance
    {
        let instance = BuilderInstance()
        let buildData = BuildData()
        
        instance.font = nodeGraph.mmView.defaultFont
        
        instance.objects = objects
        computeMaxCounts(objects: objects, buildData: buildData)
        
        buildData.source += getCommonCode()
        buildData.source +=
        """
        
        typedef struct
        {
            float4      camera;
            float2      position;
            float2      limiterSize;
            float4      general; // .x == time, .y == normalSampling, .z numberOfLights

            SHAPE_DATA  shapes[\(max(buildData.maxShapes, 1))];
            float4      points[\(max(buildData.maxPoints, 1))];
            OBJECT_DATA objects[\(max(buildData.maxObjects, 1))];
            float4      materialData[\(max(buildData.maxMaterialData, 1))];
            float4      profileData[\(max(buildData.maxProfileData, 1))];
            VARIABLE    variables[\(max(buildData.maxVariables, 1))];
            LIGHT_INFO  lights[5];
        } LAYER_DATA;
        
        """
        
        buildData.source += Material.getMaterialStructCode()
        buildData.source += getGlobalCode(objects:objects)
        buildData.source += getRenderCode();

        instance.data!.append( camera.xPos )
        instance.data!.append( camera.yPos )
        instance.data!.append( 1/camera.zoom )
        instance.data!.append( 0 )
        
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        instance.data!.append( 0 )
        
        instance.headerOffset = instance.data!.count

        // Global layer limiter
        
        /*
        buildData.source +=
        """
        
            //float2 d = abs(uv) - layerData->limiterSize;// * layerData->camera.z;
            //float ldist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            //if ( ldist < 0.0 )
            //{
        
        """*/
        
        // Parse objects and their shapes
        
        for (index,object) in objects.enumerated() {
            if object.shapes.count == 0 { continue }

            buildData.parentPosX = 0
            buildData.parentPosY = 0
            buildData.parentScaleX = 1
            buildData.parentScaleY = 1
            buildData.parentRotate = 0
            
            buildData.source +=
            """
            
            float4 sdf\(index)( float2 uv, constant LAYER_DATA *layerData, texture2d<half, access::sample> fontTexture )
            {
                float2 tuv = uv, pAverage;
            
                float dist[2];
                float newDist, objectDistance = 100000;
                int materialId = -1, objectId  = -1;
                constant SHAPE_DATA *shape;
                int shapeLayer = -1;
            
                dist[0] = 100000; dist[1] = 100000;
            
            """
            
            buildRootObjectIndex = index
            parseObject(object, instance: instance, buildData: buildData)
            
            buildData.source +=
            """
            
                return float4(dist[0], objectId, materialId, dist[1]);
            }
            
            """
        }
        
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
            
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.materialDataOffset = instance.data!.count

        // Fill up the material data
        let materialDataCount = max(buildData.maxMaterialData,1)
        for _ in 0..<materialDataCount {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.profileDataOffset = instance.data!.count
        
        // Fill up the profile data
        let profileDataCount = max(buildData.maxProfileData,1)
        for _ in 0..<profileDataCount {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        instance.variablesDataOffset = instance.data!.count

        // Fill up the variables
        let variablesDataCount = max(buildData.maxVariables,1) * maxVarSize
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
        
        instance.lightsDataOffset = instance.data!.count
        
        // Lights
        for _ in 0..<(6 * 4) {
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
        }
        
        let headerSource = buildData.source
        
        if fragment == nil {
            buildData.source =
            """
            
            kernel void layerBuilder(
            texture2d<half, access::write>  outTexture  [[texture(0)]],
            constant LAYER_DATA            *layerData   [[ buffer(1) ]],
            texture2d<half, access::sample>   fontTexture [[texture(2)]],
            uint2                           gid         [[thread_position_in_grid]])
            {
                float2 size = float2( outTexture.get_width(), outTexture.get_height() );
                float2 fragCoord = float2( gid.x, gid.y );
            """
        } else {
            buildData.source =
            """
            
            fragment float4 layerBuilder(RasterizerData in [[stage_in]],
            constant LAYER_DATA            *layerData   [[ buffer(2) ]],
            texture2d<half, access::sample>   fontTexture [[texture(1)]])
            {
                float2 size = float2(layerData->limiterSize.x, layerData->limiterSize.y);//float2( outTexture.get_width(), outTexture.get_height() );
                float2 fragCoord = float2(in.textureCoordinate.x, 1. - in.textureCoordinate.y) * size;
            """
        }
        
        // Get the Anti-Aliasing Level
        var AA : Int = 1
        if objects.count > 0 && objects[0].properties["aaLevel"] != nil {
            let aaLevel = objects[0].properties["aaLevel"]!
            switch(aaLevel) {
                case 1: AA = 2; break;
                case 2: AA = 3; break;
                default: AA = 1; break;
            }
            //print("aa level for", objects[0].name, AA)
        }
        
        buildData.source +=
        """

            float4 total = float4(0);
            int AA = \(AA);
        
            for( int mm=0; mm<AA; mm++ )
            for( int nn=0; nn<AA; nn++ )
            {
            float2 uv = fragCoord;
            float2 off = float2(mm,nn)/float(AA);
            uv += off;

            float2 center = size / 2;
            uv = translate(uv, center - float2( layerData->position.x + layerData->camera.x, layerData->position.y + layerData->camera.y ) );
            uv.y = -uv.y;
            uv *= layerData->camera.z;
        
            float4 col = float4(0), glowColor = float4(0);
            float4 rc = float4(100000, -1, -1, 100000), objectRC;
        """

        for (index, object) in objects.enumerated() {
            if object.shapes.count == 0 { continue }
            buildData.source +=
            """
            
                objectRC = sdf\(index)( uv, layerData, fontTexture );
                if (objectRC.x < rc.x || objectRC.w < rc.w) rc = objectRC;

            """
            
            // --- Object specific code like glow
            
            if buildData.objectSpecificSource[index] != nil {
                buildData.source += buildData.objectSpecificSource[index]!
            }
        }
        
        buildData.source +=
        """
        
            MATERIAL_DATA bodyMaterial;
            bodyMaterial.baseColor = float4(0.5, 0.5, 0.5, 1);
            clearMaterial( &bodyMaterial );
            MATERIAL_DATA borderMaterial;
            borderMaterial.baseColor = float4(1);
            clearMaterial( &borderMaterial );
        
            float3 normal = float3(0,1,0);
            bodyMaterial.border = layerData->objects[0].border / 30.;

            float dist = rc.x;
            float backDist = rc.w;
            int objectId = (int) rc.y;
            int materialId = (int) rc.z;
            float2 tuv = uv;
        
        """
        
        buildData.source += buildData.materialSource
        let renderModeText : String// = renderMode == .PBR ? "calculatePixelColor_PBR" : "calculatePixelColor_Color"
        switch(renderMode)
        {
            case .Color:
                renderModeText = "calculatePixelColor_Color"
            break;
            
            case .Distance:
                renderModeText = "calculatePixelColor_Distance"
            break;
            
            default:
                renderModeText = "calculatePixelColor_PBR"
            break;
        }
        
        buildData.source +=
        """
            LightInfo lights[5];
        
            int numberOfLights = int(layerData->general.z);
            for( int i = 0; i < 5; ++i) {
                lights[i].L = layerData->lights[i].L.xyz;
                lights[i].position = layerData->lights[i].position.xyz;
                lights[i].position.xz += center - layerData->camera.xy;
                lights[i].direction = layerData->lights[i].direction.xyz;
                lights[i].radius = layerData->lights[i].radiusTypeEnabled.x;
                lights[i].type = layerData->lights[i].radiusTypeEnabled.y;
                lights[i].enabled = layerData->lights[i].radiusTypeEnabled.z;
            }
        
            float4 foreground = float4(0);
            float4 background = float4(0);
        
            // --- Foreground
        
            float bm = 0;
            float border = bodyMaterial.border * 30;

            float fm = fillMask( dist );//1.0 - smoothstep( 0.00, 4.0, dist );
            bodyMaterial.baseColor.w = fm;

            if ( materialId >= 0 && border > 0 )
            {
                bm = borderMask( dist, border );
                borderMaterial.baseColor.w = 1;
                if ( bm > 0.0 ) {
                    bodyMaterial.baseColor = mix( bodyMaterial.baseColor, borderMaterial.baseColor, bm );
                    bodyMaterial.subsurface = mix( bodyMaterial.subsurface, borderMaterial.subsurface, bm );
                    bodyMaterial.roughness = mix( bodyMaterial.roughness, borderMaterial.roughness, bm );
                    bodyMaterial.metallic = mix( bodyMaterial.metallic, borderMaterial.metallic, bm );
                    bodyMaterial.specular = mix( bodyMaterial.specular, borderMaterial.specular, bm );
                }
            }
        
            if (fm != 0 || bm != 0) {
                foreground = \(renderModeText)( fragCoord, bodyMaterial, normal, lights, dist );
                if ( objectId >= 0 ) {
                    foreground.w *= layerData->objects[objectId].opacity;
                }
            }
        
            // --- Background
        
            fm =  fillMask( backDist );// * bodyMaterial.baseColor.w;//1.0 - smoothstep( 0.00, 4.0, backDist );
            bm = 0;
            bodyMaterial.baseColor.w = fm;
            border = bodyMaterial.border * 30;
        
            if ( materialId >= 0 && border > 0 )
            {
                bm = borderMask( backDist, border );
                borderMaterial.baseColor.w = 1;
                if ( bm > 0.0 ) {
                    bodyMaterial.baseColor = mix( bodyMaterial.baseColor, borderMaterial.baseColor, bm );
                    bodyMaterial.subsurface = mix( bodyMaterial.subsurface, borderMaterial.subsurface, bm );
                    bodyMaterial.roughness = mix( bodyMaterial.roughness, borderMaterial.roughness, bm );
                    bodyMaterial.metallic = mix( bodyMaterial.metallic, borderMaterial.metallic, bm );
                    bodyMaterial.specular = mix( bodyMaterial.specular, borderMaterial.specular, bm );
                }
            }
        
            if (fm != 0 || bm != 0) {
                background = \(renderModeText)( fragCoord, bodyMaterial, normal, lights, backDist );
                if ( objectId >= 0 ) {
                    background.w *= layerData->objects[objectId].opacity;
                }
            }
        
            col = mix(background, foreground, foreground.w);
            col.w = max(foreground.w, background.w);
        
        """
        
        buildData.source +=
        """
        
            col = mix(glowColor, col, col.w);
            total += col;
            }
            total = total/float(AA*AA);
        
        """
        
        if fragment == nil {
            buildData.source +=
            """
                outTexture.write(half4(total.x, total.y, total.z, total.w), gid);
            }
            
            """
        } else {
            buildData.source +=
            """
                //return col;
                return float4(total.x / total.w, total.y / total.w, total.z / total.w, total.w);
            }
            
            """
        }
        
        //print( buildData.source)
        
        buildData.source = headerSource + buildData.materialNormalSource + buildData.source
        
        if fragment == nil {
            instance.buffer = compute!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!
        
            let library = compute!.createLibraryFromSource(source: buildData.source)
            instance.state = compute!.createState(library: library, name: "layerBuilder")
        } else {
            instance.buffer = fragment!.device.makeBuffer(bytes: instance.data!, length: instance.data!.count * MemoryLayout<Float>.stride, options: [])!

            let library = fragment!.createLibraryFromSource(source: buildData.source)
            instance.fragmentState = fragment!.createState(library: library, name: "layerBuilder")
        }
        
        return instance
    }
    
    /// Recursively create the objects source code
    func parseObject(_ object: Object, instance: BuilderInstance, buildData: BuildData, physics: Bool = false, buildMaterials: Bool = true, rootObject: Bool = true)
    {
        if rootObject {
            object.builderData = instance.data
        }
        
        buildData.parentPosX += object.properties["posX"]!
        buildData.parentPosY += object.properties["posY"]!
        buildData.parentScaleX *= object.properties["scaleX"]!
        buildData.parentScaleY *= object.properties["scaleY"]!
        buildData.parentRotate += object.properties["rotate"]!
        
        instance.objectMap[buildData.objectIndex] = object
        
        if rootObject {
            // So that we always have a reference to the id of the current root object
            buildRootObjectId = buildData.objectIndex
        }
        
        for shape in object.shapes {
            
            let properties : [String:Float]
            if object.currentSequence != nil {
                properties = nodeGraph.timeline.transformProperties(sequence: object.currentSequence!, uuid: shape.uuid, properties: shape.properties)
            } else {
                properties = shape.properties
            }

            buildData.source += "shape = &\(buildData.mainDataName)shapes[\(buildData.shapeIndex)];\n"
            buildData.source += "shapeLayer = int(shape->properties.x);\n"

            // Object transforms
            buildData.source += "tuv = translate( uv, \(buildData.mainDataName)objects[\(buildData.objectIndex)].pos);"
            buildData.source += "tuv /= \(buildData.mainDataName)objects[\(buildData.objectIndex)].scale;\n"
            buildData.source += "if ( \(buildData.mainDataName)objects[\(buildData.objectIndex)].rotate != 0.0 ) tuv = rotateCW( tuv, \(buildData.mainDataName)objects[\(buildData.objectIndex)].rotate);\n"
            // ---

            buildData.source += "tuv = translate( tuv, shape->pos );"
            if shape.pointCount == 0 {
                buildData.source += "if ( shape->rotate != 0.0 ) tuv = rotateCW( tuv, shape->rotate );\n"
            } else {
                buildData.source += "if ( shape->rotate != 0.0 ) {\n"
                buildData.source += "pAverage = float2(0);\n"
                buildData.source += "for (int i = \(buildData.pointIndex); i < \(buildData.pointIndex + shape.pointCount); ++i) \n"
                buildData.source += "pAverage += \(buildData.mainDataName)points[i].xy;\n"
                buildData.source += "pAverage /= \(shape.pointCount);\n"
                buildData.source += "tuv = rotateCW( tuv - pAverage, shape->rotate );\n"
                buildData.source += "tuv += pAverage;\n"
                buildData.source += "}\n"
            }
            
            var booleanCode = "merge"
            
            if shape.mode == .Subtract {
                booleanCode = "subtract"
            } else
                if shape.mode == .Intersect {
                    booleanCode = "intersect"
            }
            
            if shape.pointsVariable {
                buildData.source += shape.createPointsVariableCode(shapeIndex: buildData.shapeIndex, pointIndex: buildData.pointIndex, mainDataName: buildData.mainDataName)
            }
            
            // --- Setup the custom properties table
            shape.customProperties = []
            for (key, _) in shape.properties {
                if key.starts(with: "custom_") {
                    shape.customProperties.append(key)
                }
            }
            
            //if shape.name == "Text" {
             //   buildData.source += createStaticTextSource(instance.font!, shape.customText!, varCounter: buildData.shapeIndex)
            //}
            
            let distanceCode = "newDist = " + shape.createDistanceCode(uvName: "tuv", layerIndex: buildData.shapeIndex, pointIndex: buildData.pointIndex, shapeIndex: buildData.shapeIndex, mainDataName: buildData.mainDataName, variableIndex: buildData.variableIndex) + ";\n"
            buildData.source += distanceCode
            
            if shape.name == "Variable" || shape.name == "Text" {
                buildData.variableIndex += 1
            }
            
            if shape.supportsRounding {
                buildData.source += "newDist -= shape->rounding;\n"
            }
            
            // --- Annular
            buildData.source += "if ( shape->annular != 0.0 ) newDist = abs(newDist) - shape->annular;\n"
            
            // --- Inverse
            if shape.properties["inverse"] != nil && shape.properties["inverse"]! == 1 {
                buildData.source += "newDist = -newDist;\n"
            }
            
            // --- Apply the material id to the closest shape regardless of boolean mode
            if !physics {
                buildData.source += "if (newDist < dist[shapeLayer]) materialId = \(buildData.objectIndex);\n"
            }
            
            if booleanCode != "subtract" {
                buildData.source += "if ( shape->smoothBoolean == 0.0 )"
                buildData.source += "  dist[shapeLayer] = \(booleanCode)( dist[shapeLayer], newDist );"
                buildData.source += "  else dist[shapeLayer] = \(booleanCode)Smooth( dist[shapeLayer], newDist, shape->smoothBoolean );\n"
            } else {
                buildData.source += "if ( shape->smoothBoolean == 0.0 )"
                buildData.source += "  dist[shapeLayer] = \(booleanCode)( dist[shapeLayer], newDist );"
                buildData.source += "  else dist[shapeLayer] = \(booleanCode)Smooth( newDist, dist[shapeLayer], shape->smoothBoolean );\n"
            }
            
            let posX = properties["posX"]! + buildData.parentPosX
            let posY = properties["posY"]! + buildData.parentPosY
            let sizeX = properties[shape.widthProperty]!
            let sizeY = properties[shape.heightProperty]!
            let rotate = (properties["rotate"]!+buildData.parentRotate) * Float.pi / 180
            
            instance.data!.append( posX )
            instance.data!.append( posY )
            instance.data!.append( sizeX )
            instance.data!.append( sizeY )
            instance.data!.append( rotate )
            instance.data!.append( properties["rounding"]! )
            instance.data!.append( properties["annular"]! )
            instance.data!.append( properties["smoothBoolean"]! )
            // Custom data
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            // Properties x = layer
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            instance.data!.append( 0 )
            // --
            
            buildData.shapeIndex += 1
            buildData.pointIndex += shape.pointCount
        }
        
        // --- Apply the object id
        buildData.source += "if (dist[shapeLayer] < objectDistance) { objectId = \(buildData.objectIndex); objectDistance = dist[shapeLayer]; }\n"
        
        // --- Sub-objects overrule main object
        if rootObject == false {
            buildData.source += "if (newDist <= 0.0) { materialId = \(buildData.objectIndex); }\n"
        }
    
        if !physics && buildMaterials {
            // --- Outside Code
            
            if rootObject && object.properties["glowMode"] == 1 {
                var outside = ""
                outside +=
                """
                
                    {
                        float glowSize = \(buildData.mainDataName)objects[\(buildData.objectIndex)].glowSize;
                        float glow = 1.0 / (objectRC.x / glowSize);
                        float4 color = \(buildData.mainDataName)objects[\(buildData.objectIndex)].glowColor;
                        glowColor = mix( glowColor, color, glow );
                    }
                
                """
                
                buildData.objectSpecificSource[buildRootObjectIndex] = outside
            }
            
            // --- Material Code
            func createMaterialCode(_ material: Material, _ materialName: String, normal: Bool = false) -> String
            {
                var source = ""
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
                    case 11: materialProperty = "border"
                    default: print("Invalid Channel")
                }
                channelCode += materialProperty
                let limiterType = material.properties["limiterType"]
                let opacity = material.properties["opacity"]!
                let materialExt = channel == 0 ? "" : ".x"
                
                if normal {
                    channelCode = "mixValue"
                    source += "mixValue = float4(0);\n"
                }
                
                // --- Setup the custom properties table
                material.customProperties = []
                for (key, _) in material.properties {
                    if key.starts(with: "custom_") {
                        material.customProperties.append(key)
                    }
                }
                
                // --- Translate material uv
                
                // Object transforms
                source += "tuv = translate( uv, \(buildData.mainDataName)objects[\(buildData.objectIndex)].pos);"
                source += "tuv /= \(buildData.mainDataName)objects[\(buildData.objectIndex)].scale;\n"
                source += "if ( \(buildData.mainDataName)objects[\(buildData.objectIndex)].rotate != 0.0 ) tuv = rotateCW( tuv, \(buildData.mainDataName)objects[\(buildData.objectIndex)].rotate);\n"
                // ---
                
                source += "tuv = translate( tuv, \(buildData.mainDataName)materialData[\(buildData.materialDataIndex)].xy );"
                
                // --- Rotate material uv
                source += "if ( \(buildData.mainDataName)materialData[\(buildData.materialDataIndex+1)].x != 0.0 ) tuv = rotateCW( tuv, \(buildData.mainDataName)materialData[\(buildData.materialDataIndex+1)].x );\n"
                
                if !material.isCompound {
                    source += "value = " + material.createCode(uvName: "tuv", materialDataIndex: buildData.materialDataIndex+3) + ";\n"
                    
                    if limiterType == 0 || channel == 11 {
                        // --- No Limiter
                        if channel == 11 && material.name == "Static" {
                            // Static border gets multiplicated to allow scaling
                            source += "  " + channelCode + " = " + channelCode + " * value.x * 10.0;\n"
                        } else {
                            source += "  " + channelCode + " = mix( " + channelCode + ", value, value.w * \(opacity))" + materialExt + ";\n"
                        }
                    } else
                    if limiterType == 1 {
                        // --- Rectangle
                        source += "  d = abs( tuv ) - \(buildData.mainDataName)materialData[\(buildData.materialDataIndex+1)].zw;\n"
                        source += "  limiterDist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);\n"
                        source += "  " + channelCode + " = mix(" + channelCode + ", value\(materialExt), fillMask(limiterDist) * value.w );\n"
                    } else
                    if limiterType == 2 {
                        // --- Sphere
                        source += "  limiterDist = length( tuv ) - \(buildData.mainDataName)materialData[\(buildData.materialDataIndex+1)].z;\n"
                        source += "  " + channelCode + " = mix(" + channelCode + ", value\(materialExt), fillMask(limiterDist) * value.w );\n"
                    } else
                    if limiterType == 3 {
                        // --- Border
                        source += "  limiterDist = -dist - \(buildData.mainDataName)materialData[\(buildData.materialDataIndex+1)].z;\n"
                        source += "  " + channelCode + " = mix(" + channelCode + ", value\(materialExt), fillMask(limiterDist) * value.w );\n"
                    }
                    
                    if normal {
                        source += "alpha += mixValue.w;\n"
                    } else {
                        source += "componentBlend = value.w;\n"
                    }
                    
                } else {
                    if !normal {
                        source += material.createCode(uvName: "tuv", materialDataIndex: buildData.materialDataIndex+3, materialName: materialName) + ";\n"
                    }
                }
                
                return source;
            }
            
            // Insert normal calculation code for the profile data
            //if object.profile != nil {
                buildData.materialSource += "if (dist <= 0 && objectId == \(buildData.objectIndex)) { \n"
                buildData.materialSource += "normal = calculateNormalForObject\(buildData.objectIndex)(uv, layerData, fontTexture, dist, size);"
                buildData.materialSource += "}\n"
                //buildData.profileIndex += object.profile!.count
            //}
            
            // --- Normal
            
            buildData.materialNormalSource += "\nfloat calculateBumpForObject\(buildData.objectIndex)( float2 uv, constant LAYER_DATA *layerData, float dist, float2 size ) {\n float2 tuv; float4 value, mixValue; float2 d; float limiterDist; float alpha = 0; MATERIAL_DATA bodyMaterial; MATERIAL_DATA borderMaterial;\n "
            
            let indexBuffer = buildData.materialDataIndex
            for material in object.bodyMaterials {
                let bumpValue = material.properties["bump"]!
                if bumpValue > 0 && !material.isCompound {
                    buildData.materialNormalSource += createMaterialCode(material, "bodyMaterial", normal: true)
                }
                
                if material.pointCount == 0 {
                    buildData.materialDataIndex += 4
                } else {
                    buildData.materialDataIndex += 3 + material.pointCount * 2
                }
            }
            for material in object.borderMaterials {
                let bumpValue = material.properties["bump"]!
                if bumpValue > 0 && !material.isCompound {
                    buildData.materialNormalSource += createMaterialCode(material, "borderMaterial", normal: true)
                }
                
                if material.pointCount == 0 {
                    buildData.materialDataIndex += 4
                } else {
                    buildData.materialDataIndex += 3 + material.pointCount * 2
                }
            }
            buildData.materialDataIndex = indexBuffer
            
            buildData.materialNormalSource += "\nreturn alpha;\n}"
            
            buildData.materialNormalSource += """
            
            float3 calculateNormalForObject\(buildData.objectIndex)(float2 uv, constant LAYER_DATA *layerData, texture2d<half, access::sample> fontTexture, float dist, float2 size)
            {
                float p = layerData->general.y;//min(.3, .0005+.00005 * distance*distance);
                float3 nor = float3(0.0, calculateBumpForObject\(buildData.objectIndex)(uv, layerData, dist*25, size), 0.0);
            
                float3 v2 = nor - float3(p, calculateBumpForObject\(buildData.objectIndex)(uv+float2(p,0.0), layerData, sdf\(buildRootObjectIndex)(uv+float2(p,0.0), layerData, fontTexture).x*25, size), 0.0);
            
                float3 v3 = nor - float3(0.0, calculateBumpForObject\(buildData.objectIndex)(uv+float2(0.0,-p), layerData, sdf\(buildRootObjectIndex)(uv+float2(0.0,-p), layerData, fontTexture).x*25, size), -p);
                nor = cross(v2, v3);
                return normalize(nor);
            }
            
            """
            
            //
            
            buildData.materialSource += "if (materialId == \(buildData.objectIndex)) { float2 d; float limiterDist; float componentBlend = 1.0; float4 value = float4(0);\n"
            for material in object.bodyMaterials {
                let bumpValue = material.properties["bump"]!
                if bumpValue != 2 {
                    buildData.materialSource += createMaterialCode(material, "bodyMaterial")
                }
                
                if material.pointCount == 0 {
                    buildData.materialDataIndex += 4
                } else {
                    buildData.materialDataIndex += 3 + material.pointCount * 2
                }
            }
            for material in object.borderMaterials {
                let bumpValue = material.properties["bump"]!
                if bumpValue != 2 {
                    buildData.materialSource += createMaterialCode(material, "borderMaterial")
                }
                
                if material.pointCount == 0 {
                    buildData.materialDataIndex += 4
                } else {
                    buildData.materialDataIndex += 3 + material.pointCount * 2
                }
            }
            
            buildData.materialSource += "}\n"
        }

        buildData.objectIndex += 1

        for childObject in object.childObjects {
            parseObject(childObject, instance: instance, buildData: buildData, physics: physics, rootObject: false)
        }
        
        buildData.parentPosX -= object.properties["posX"]!
        buildData.parentPosY -= object.properties["posY"]!
        buildData.parentScaleX /= object.properties["scaleX"]!
        buildData.parentScaleY /= object.properties["scaleY"]!
        buildData.parentRotate -= object.properties["rotate"]!
    }
    
    /// Render the layer
    @discardableResult func render(width: Float, height: Float, instance: BuilderInstance, camera: Camera, outTexture: MTLTexture? = nil, frame: Int = 0) -> MTLTexture
    {
        if outTexture == nil {
            if compute!.texture == nil || compute!.width != width || compute!.height != height {
                compute!.allocateTexture(width: width, height: height)
            }
        }
        
        instance.texture = outTexture == nil ? compute!.texture : outTexture

        instance.data![0] = camera.xPos
        instance.data![1] = camera.yPos
        instance.data![2] = 1/camera.zoom

        //instance.data![4] = instance.layerGlobals!.position.x
        //instance.data![5] = instance.layerGlobals!.position.y

        //instance.data![6] = instance.layerGlobals!.limiterSize.x / 2
        //instance.data![7] = instance.layerGlobals!.limiterSize.y / 2
        
        instance.data![8] = instance.data![8] + (1000/60) / 1000 // Time
        instance.data![9] = 0.1 // Sampling
        instance.data![10] = 1 // Number of lights

        updateInstanceData(instance: instance, camera: camera, frame: frame)
        
        memcpy(instance.buffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
        
        if outTexture == nil {
            compute!.run( instance.state, inBuffer: instance.buffer, inTexture: instance.font!.atlas )
            return compute!.texture
        } else {
            if let state = instance.state {
                compute!.run( state, outTexture: outTexture, inBuffer: instance.buffer, inTexture: instance.font!.atlas )
            }
            return outTexture!
        }
    }
    
    /// Update the instance data of the builder instance for the given frame
    func updateInstanceData(instance: BuilderInstance, camera: Camera, doMaterials: Bool = true, frame: Int = 0)
    {
        // Set the lights
        
        if doMaterials {
            
            func setLight(index: Int, L: SIMD3<Float>, pos: SIMD3<Float>, dir: SIMD3<Float>, radius: Float, type: Int, enabled: Bool)
            {
                let offset = instance.lightsDataOffset + index * 4 * 4

                instance.data![offset] = L.x
                instance.data![offset + 1] = L.y
                instance.data![offset + 2] = L.z
                
                instance.data![offset + 4] = pos.x
                instance.data![offset + 5] = pos.y
                instance.data![offset + 6] = pos.z
                
                instance.data![offset + 8] = dir.x
                instance.data![offset + 9] = dir.y
                instance.data![offset + 10] = dir.z
                
                instance.data![offset + 12] = radius
                instance.data![offset + 13] = type == 0 ? 0.0 : 1.0
                instance.data![offset + 14] = enabled ? 1 : 0
            }
            
            if let scene = instance.scene, scene.properties["numberOfLights"] != nil && scene.properties["numberOfLights"]! > 0 {
                let numberOfLights : Int = Int(scene.properties["numberOfLights"]!)
                
                for i in 0..<numberOfLights {
                    
                    let power = scene.properties["light_\(i)_power"]! * camera.zoom

                    let color : SIMD3<Float> = SIMD3<Float>(scene.properties["light_\(i)_color_x"]! * power, scene.properties["light_\(i)_color_y"]! * power, scene.properties["light_\(i)_color_z"]! * power)
                    
                    var pos : SIMD3<Float> = SIMD3<Float>(-scene.properties["light_\(i)_posX"]! * camera.zoom, -scene.properties["light_\(i)_posZ"]!, -scene.properties["light_\(i)_posY"]! * camera.zoom)
                    var dir : SIMD3<Float> = SIMD3<Float>(0,0,0)

                    let type = Int(scene.properties["light_\(i)_type"]!)
                    
                    var radius : Float = 0
                    if type == 0 {
                        radius = scene.properties["light_\(i)_radius"]! * camera.zoom
                        pos.x = -pos.x
                    } else {
                        dir = simd_normalize(SIMD3<Float>(0, 0, 0) - pos)
                    }
                    
                    let enabled : Bool = power == 0 ? false : true
                    setLight(index: i, L: SIMD3<Float>(color), pos: pos, dir: dir, radius: radius, type: type, enabled: enabled)
                }
            } else {
                let pos : SIMD3<Float> = SIMD3<Float>(10, -100, 0)
                let dir : SIMD3<Float> = simd_normalize(SIMD3<Float>(0, 0, 0) - pos)
                setLight(index: 0, L: SIMD3<Float>(repeating: 3.15), pos: pos, dir: dir, radius: 0, type: 1, enabled: true)
            }
        }
        
        // ---
        
        let offset : Int = instance.headerOffset
        var index : Int = 0
        var pointIndex : Int = 0
        var objectIndex : Int = 0
        var materialDataIndex : Int = 0
        var profileDataIndex : Int = 0
        var variablesDataIndex : Int = 0

        // Update Shapes / Objects
        
        var parentPosX : Float = 0
        var parentPosY : Float = 0
        var parentRotate : Float = 0
        var parentScaleX : Float = 1
        var parentScaleY : Float = 1
        let shapeSize : Int = 16
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
            parentScaleX *= objectProperties["scaleX"]!
            parentScaleY *= objectProperties["scaleY"]!
            parentRotate += objectProperties["rotate"]!
            
            for shape in object.shapes {
                
                let properties : [String:Float]
                if rootObject.currentSequence != nil {
                    properties = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: shape.uuid, properties: shape.properties, frame: currentFrame)
                } else {
                    properties = shape.properties
                }
                
                instance.data![offset + index * shapeSize] = properties["posX"]!
                instance.data![offset + index * shapeSize+1] = properties["posY"]!
                instance.data![offset + index * shapeSize+2] = properties[shape.widthProperty]!
                instance.data![offset + index * shapeSize+3] = properties[shape.heightProperty]!
                
                instance.data![offset + index * shapeSize+4] = properties["rotate"]! * Float.pi / 180
                
                let minSize : Float = min(shape.properties["sizeX"]!,shape.properties["sizeY"]!)
                
                instance.data![offset + index * shapeSize+5] = properties["rounding"]! * minSize / 2
                instance.data![offset + index * shapeSize+6] = properties["annular"]! * minSize / 3.5
                instance.data![offset + index * shapeSize+7] = properties["smoothBoolean"]! * minSize
                
                // --- Custom shape properties
                for (customIndex,value) in shape.customProperties.enumerated() {
                    if customIndex > 3 {
                        break
                    }
                    instance.data![offset + index * shapeSize + 8 + customIndex] = properties[value]!
                }
                
                // --- Properties
                // Layer
                instance.data![offset + index * shapeSize + 12] = Float(shape.layer!.rawValue)

                //
                for i in 0..<shape.pointCount {
                    let ptConn = object.getPointConnections(shape: shape, index: i)
                    
                    if ptConn.1 == nil {
                        // The point controls itself
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 4] = properties["point_\(i)_x"]!
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 4 + 1] = properties["point_\(i)_y"]!
                    }
                    
                    if ptConn.0 != nil {
                        // The point controls other point(s)
                        ptConn.0!.valueX = properties["posX"]! + parentPosX + properties["point_\(i)_x"]!
                        ptConn.0!.valueY = properties["posY"]! + parentPosY + properties["point_\(i)_y"]!
                    }
                    
                    if ptConn.1 != nil {
                        // The point is being controlled by another point
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 4] = ptConn.1!.valueX - properties["posX"]! - parentPosX
                        instance.data![instance.pointDataOffset + (pointIndex+i) * 4 + 1] = ptConn.1!.valueY - properties["posY"]! - parentPosY
                    }
                }
                
                // Build variable
                if shape.name == "Variable" || shape.name == "Text" {
                    
                    var offset = instance.variablesDataOffset + variablesDataIndex * 12 * maxVarSize

                    var text : String = ""
                    let font = instance.font!

                    var valid = false

                    if shape.name == "Variable" {
                        if let uuid = shape.customReference {
                        
                            if let varNode = nodeGraph.getNodeForUUID(uuid) {
                                text = String(format: "%.0\(Int(shape.properties["custom_precision"]!))f",varNode.properties["value"]!)
                            }
                        }
                    } else {
                        text = shape.customText!
                    }
                
                    if text.count > 0 {
                        valid = true
                        
                        var totalWidth : Float = 0
                        var totalHeight : Float = 0
                    
                        for (index,c) in text.enumerated() {
                            let bmFont = font.getItemForChar(c)!
                            
                            instance.data![offset] = bmFont.x
                            instance.data![offset + 1] = bmFont.y
                            instance.data![offset + 2] = bmFont.width
                            instance.data![offset + 3] = bmFont.height

                            instance.data![offset + 4] = bmFont.xoffset
                            instance.data![offset + 5] = bmFont.yoffset
                            instance.data![offset + 6] = bmFont.xadvance

                            instance.data![offset + 8] = totalWidth
                            instance.data![offset + 9] = totalHeight
                            
                            instance.data![offset + 11] = index == text.count-1 ? 1 : 0
                            
                            totalWidth += bmFont.width + bmFont.xadvance
                            totalHeight = max(totalHeight,bmFont.height)
                            
                            offset += 12
                        }
                    
                        offset = instance.variablesDataOffset + variablesDataIndex * 12 * maxVarSize

                        for (index,_) in text.enumerated() {
                            
                            instance.data![offset + 8] = totalWidth
                            instance.data![offset + 9] = totalHeight
                            
                            offset += 12
                        }
                    }
                    
                    if valid == false {
                        instance.data![offset + 11] = 1
                        
                        let text = " "
                        let font = instance.font!

                        for (index,c) in text.enumerated() {
                            let bmFont = font.getItemForChar(c)!
                            
                            instance.data![offset] = bmFont.x
                            instance.data![offset + 1] = bmFont.y
                            instance.data![offset + 2] = bmFont.width
                            instance.data![offset + 3] = bmFont.height
                            
                            instance.data![offset + 4] = bmFont.xoffset
                            instance.data![offset + 5] = bmFont.yoffset
                            instance.data![offset + 6] = bmFont.xadvance
                            
                            instance.data![offset + 8] = 0
                            instance.data![offset + 9] = 0
                            
                            instance.data![offset + 11] = 1
                        }
                    }
                    variablesDataIndex += 1
                }
                
                // Shape processing finished
                index += 1
                pointIndex += shape.pointCount
            }
            
            // --- Fill in Object Transformation Data
            if doMaterials {
                instance.data![instance.objectDataOffset + (objectIndex) * 12] = object.properties["border"]!
            }
            instance.data![instance.objectDataOffset + (objectIndex) * 12 + 1] = parentRotate * Float.pi / 180
            instance.data![instance.objectDataOffset + (objectIndex) * 12 + 2] = parentScaleX
            instance.data![instance.objectDataOffset + (objectIndex) * 12 + 3] = parentScaleY
            instance.data![instance.objectDataOffset + (objectIndex) * 12 + 4] = parentPosX
            instance.data![instance.objectDataOffset + (objectIndex) * 12 + 5] = parentPosY

            // Opacity
            instance.data![instance.objectDataOffset + (objectIndex) * 12 + 6] = object.properties["opacity"] != nil ? object.properties["opacity"]! : 1.0

            if let glowSize = object.properties["glowSize"] {
                instance.data![instance.objectDataOffset + (objectIndex) * 12 + 7] = glowSize

                instance.data![instance.objectDataOffset + (objectIndex) * 12 + 8] = object.properties["glowColor_x"]!
                instance.data![instance.objectDataOffset + (objectIndex) * 12 + 9] = object.properties["glowColor_y"]!
                instance.data![instance.objectDataOffset + (objectIndex) * 12 + 10] = object.properties["glowColor_z"]!
                instance.data![instance.objectDataOffset + (objectIndex) * 12 + 11] = object.properties["glowOpacity"]!
            }

            object.properties["trans_rotate"] = parentRotate

            object.properties["trans_scaleX"] = parentScaleX
            object.properties["trans_scaleY"] = parentScaleY

            object.properties["trans_posX"] = parentPosX
            object.properties["trans_posY"] = parentPosY
            
            objectIndex += 1
            
            if instance.materialDataOffset != 0 {
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
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4] = properties["posX"]!
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 1] = properties["posY"]!
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 2] = properties[material.widthProperty]!
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 3] = properties[material.heightProperty]!
                        materialDataIndex += 1
                        // rotation, space for 3 more values
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4] = properties["rotate"]! * Float.pi / 180
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 2] = properties["limiterWidth"]!
                        instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + 3] = properties["limiterHeight"]!
                        materialDataIndex += 1
                        
                        // --- Custom material properties
                        for (customIndex,value) in material.customProperties.enumerated() {
                            if customIndex > 3 {
                                break
                            }
                            instance.data![instance.materialDataOffset + (materialDataIndex) * 4 + customIndex] = properties[value]!
                        }
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
                
                // --- Fill in the profile data
                
                if object.profile != nil {
                    for index in 0..<object.profile!.count {
                        instance.data![instance.profileDataOffset + (profileDataIndex) * 4] = object.profile![index].x
                        instance.data![instance.profileDataOffset + (profileDataIndex) * 4 + 1] = object.profile![index].y
                        instance.data![instance.profileDataOffset + (profileDataIndex) * 4 + 2] = object.profile![index].z
                        instance.data![instance.profileDataOffset + (profileDataIndex) * 4 + 3] = object.profile![index].w
                        profileDataIndex += 1
                    }
                }
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            parentPosX -= objectProperties["posX"]!
            parentPosY -= objectProperties["posY"]!
            parentScaleX /= objectProperties["scaleX"]!
            parentScaleY /= objectProperties["scaleY"]!
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
            parentScaleX = 1
            parentScaleY = 1
            parentRotate = 0
            parseObject(object)
            if object.instanceOf != nil && object.maxFrame > 0 {
                let frames : Float = 1 * object.animationScale
                
                if object.animationMode == .Loop {
                    object.frame += frames
                    object.animationState = .GoingForward
                    if object.frame > object.maxFrame {
                        object.frame = 0
                    }
                } else
                if object.animationMode == .InverseLoop {
                    object.frame -= frames
                    object.animationState = .GoingBackward
                    if object.frame < 0 {
                        object.frame = object.maxFrame
                    }
                } else
                if object.animationMode == .GotoStart {
                    object.frame -= frames
                    object.animationState = .GoingBackward
                    if object.frame < 0 {
                        object.frame = 0
                        object.animationState = .AtStart
                    }
                } else
                if object.animationMode == .GotoEnd {
                    object.frame += frames
                    object.animationState = .GoingForward
                    if object.frame > object.maxFrame {
                        object.frame = object.maxFrame
                        object.animationState = .AtEnd
                    }
                }
            } else {
                object.animationState = .NotAnimating
            }
        }
    }
    
    /// Builds a shader for object / shape selection
    func getShapeAt( x: Float, y: Float, width: Float, height: Float, multiSelect: Bool = false, instance: BuilderInstance, camera: Camera, frame: Int = 0) -> Object?
    {
        var source =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

        typedef struct
        {
            float2  charPos;
            float2  charSize;
            float2  charOffset;
            float2  charAdvance;
            float4  stringInfo;
        } FontChar;

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

        float2 rotateCWWithPivot(float2 pos, float angle, float2 pivot)
        {
            float ca = cos(angle), sa = sin(angle);
            return pivot + (pos-pivot) * float2x2(ca, -sa, sa, ca);
        }

        float2 rotateCCW (float2 pos, float angle)
        {
            float ca = cos(angle), sa = sin(angle);
            return pos * float2x2(ca, sa, -sa, ca);
        }

        float2 rotateCCWWithPivot (float2 pos, float angle, float2 pivot)
        {
            float ca = cos(angle), sa = sin(angle);
            return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
        }

        """
        
        source += Builder.getNoiseLibrarySource()
        source += Material.getMaterialStructCode()
        source += getGlobalCode(objects:instance.objects)
        
        source +=
        """
        
        kernel void
        selectedAt(device float4  *out [[ buffer(0) ]],
        texture2d<half, access::sample>   fontTexture [[texture(2)]],
        uint id [[ thread_position_in_grid ]])
        {
            float2 fragCoord = float2( \(x), \(y) );
            float2 uv = fragCoord;
        
            float2 center = float2(\(width/2), \(height/2) );
            uv = translate(uv, center - float2( \(camera.xPos), \(camera.yPos) ) );
            uv.y = -uv.y;
            uv /= \(camera.zoom);
            float2 tuv = uv;
        
            float4 dist = float4(1000, -1, -1, -1);
            float newDist;
        """
        
        var parentPosX : Float = 0
        var parentPosY : Float = 0
        var parentScaleX : Float = 1
        var parentScaleY : Float = 1
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
            parentScaleX *= objectProperties["scaleX"]!
            parentScaleY *= objectProperties["scaleY"]!
            parentRotate += objectProperties["rotate"]!
            
            for (shapeIndex, shape) in object.shapes.enumerated() {
                
                var transformed = nodeGraph.timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: shape.uuid, properties: shape.properties, frame: frame)
                let posX : Float = /*parentPosX +*/ transformed["posX"]!
                let posY : Float = /*parentPosY +*/ transformed["posY"]!
                let rotate : Float = (/*parentRotate +*/ transformed["rotate"]!) * Float.pi / 180
                
                // --- Transform Object
                
                source += "uv = translate( tuv, float2( \(parentPosX), \(parentPosY) ) );\n"
                source += "uv /= float2( \(parentScaleX), \(parentScaleY) );\n"
                source += "uv = rotateCW( uv, \(parentRotate * Float.pi / 180) );\n"

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
                
                // --- Transform Shape
                source += "uv = translate( uv, float2( \(posX), \(posY) ) );\n"
                //source += "uv /= float2( \(parentScaleX), \(parentScaleY) );\n"
                if rotate != 0.0 {
                    if shape.pointCount == 0 {
                        source += "uv = rotateCW( uv, \(rotate) );\n"
                    } else {
                        var offX : Float = 0
                        var offY : Float = 0
                        for i in 0..<shape.pointCount {
                            offX += transformed["point_\(i)_x"]!
                            offY += transformed["point_\(i)_y"]!
                        }
                        offX /= Float(shape.pointCount)
                        offY /= Float(shape.pointCount)
                        source += "uv = rotateCW( uv - float2( \(offX), \(offY) ), \(rotate) );\n"
                        source += "uv += float2( \(offX), \(offY) );\n"
                    }
                }
                
                if shape.pointsVariable {
                    source += shape.createPointsVariableCode(shapeIndex: totalShapeIndex)
                }
                
                if shape.name == "Text" || shape.name == "Variable" {
                    source += createStaticTextSource(instance.font!, shape.customText!, varCounter: totalShapeIndex)
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
            parentScaleX /= objectProperties["scaleX"]!
            parentScaleY /= objectProperties["scaleY"]!
            parentRotate -= objectProperties["rotate"]!
        }
        
        for object in instance.objects {
            rootObject = object
            parentPosX = 0
            parentPosY = 0
            parentScaleX = 1
            parentScaleY = 1
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
        compute!.runBuffer(state, outBuffer: outBuffer, inTexture: instance.font!.atlas)
        
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
    func getGlobalCode(objects: [Object], includeMaterials: Bool = true) -> String
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
            
            if includeMaterials {
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
    func computeMaxCounts(objects: [Object], buildData: BuildData, physics: Bool = false)  {
        var shapeIndex : Int = 0
        var objectIndex : Int = 0
        var pointIndex : Int = 0
        var materialIndex : Int = 0
        var profileIndex : Int = 0
        var variableIndex : Int = 0

        func parseObject(_ object: Object)
        {
            for shape in object.shapes {
                shapeIndex += 1
                pointIndex += shape.pointCount
                
                if shape.name == "Variable" || shape.name == "Text" {
                    variableIndex += 1
                }
            }
            
            if object.profile != nil {
                profileIndex += object.profile!.count
            }
            
            for material in object.bodyMaterials {
                if material.pointCount == 0 {
                    materialIndex += 4 // value + 2 for pos, size, rotation
                } else {
                    materialIndex += 4 + material.pointCount * 2
                }
            }
            for material in object.borderMaterials {
                if material.pointCount == 0 {
                    materialIndex += 4
                } else {
                    materialIndex += 3 + material.pointCount * 2
                }
            }
            
            for childObject in object.childObjects {
                parseObject(childObject)
            }
            
            objectIndex += 1
        }
        
        for object in objects {
            if !physics {
                parseObject(object)
            } else {
                let physicsMode = object.getPhysicsMode()
                /// Dynamic and static objects only in physics mode
                if physicsMode == .Static || physicsMode == .Dynamic {
                    parseObject(object)
                }
            }
        }
        
        buildData.maxShapes = shapeIndex
        buildData.maxPoints = pointIndex
        buildData.maxObjects = objectIndex
        buildData.maxMaterialData = materialIndex
        buildData.maxProfileData = profileIndex
        buildData.maxVariables = variableIndex
    }
    
    /// Returns the common code for all shaders
    func getCommonCode() -> String
    {
        var code =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

        typedef struct
        {
            float2  charPos;
            float2  charSize;
            float2  charOffset;
            float2  charAdvance;
            float4  stringInfo;
        } FontChar;

        typedef struct
        {
            FontChar chars[\(maxVarSize)];
        } VARIABLE;
        
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
        
        float outerBorderMask(float dist, float width)
        {
            //dist += 1.0;
            return clamp(dist, 0.0, 1.0) - clamp(dist - width, 0.0, 1.0); // outer
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
        
        float2 rotateCWWithPivot(float2 pos, float angle, float2 pivot)
        {
            float ca = cos(angle), sa = sin(angle);
            return pivot + (pos-pivot) * float2x2(ca, -sa, sa, ca);
        }
        
        float2 rotateCCW (float2 pos, float angle)
        {
            float ca = cos(angle), sa = sin(angle);
            return pos * float2x2(ca, sa, -sa, ca);
        }
        
        float2 rotateCCWWithPivot (float2 pos, float angle, float2 pivot)
        {
            float ca = cos(angle), sa = sin(angle);
            return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
        }
        
        typedef struct
        {
            float2      pos;
            float2      size;
            float       rotate;
            float       rounding;
            float       annular;
            float       smoothBoolean;
            float4      customProperties;
            float4      properties; // .x == layer
        } SHAPE_DATA;
        
        typedef struct
        {
            float       border;
            float       rotate;
            float2      scale;
            float2      pos;
            float       opacity;
            float       glowSize;
            float4      glowColor;
        } OBJECT_DATA;
        
        typedef struct
        {
            float4      L;
            float4      position;
            float4      direction;
            float4      radiusTypeEnabled;
        } LIGHT_INFO;

        """
        
        code += Builder.getNoiseLibrarySource()
        
        return code
    }
    
    /// Returns the PBR Disney Render Code
    func getRenderCode() -> String
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
            float3 closestPoint = L  * clamp( light.radius / length( centerToRay ), 0.0, 1.0 );
            *wi = float3(1000);//normalize(closestPoint);
            
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
                //float3 shadowRayDir =normalize(light.position - interaction.point);
                //*visibility = 1.;//visibilityTest(interaction.point + shadowRayDir * .01, shadowRayDir);
                return L;
            }
            else if( light.type == LIGHT_TYPE_SUN ) {
                float3 L = sampleSun(light, interaction, wi, lightPdf, seed);
                //*visibility = visibilityTestSun(interaction.point + *wi * .01, *wi);
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
            //Li *= visibility;
            
            *f = bsdfEvaluate(*wi, wo, interaction.tangent, interaction.binormal, interaction, material) * abs(dot(*wi, interaction.normal));
            Ld += Li * *f;
            
            return Ld;
        }

        float4 calculatePixelColor_PBR(const float2 uv, MaterialInfo material, float3 normal, thread LightInfo lights[5], float distance)
        {
            material.baseColor = float4(pow(material.baseColor.xyz, 2.2),material.baseColor.w);//float4(1);
            
            float3 L = float3(0);
            float3 beta = float3(1);
            
            float seed = hash12(uv);

            SurfaceInteraction interaction;
            interaction.normal = normal;
            interaction.incomingRayDir = float3(0,-1,0);
            interaction.point = float3(uv.x,0,uv.y);

            float3 X = float3(0.), Y = float3(0.);
            directionOfAnisotropicity(interaction.normal, &X, &Y);
            interaction.tangent = X;
            interaction.binormal = Y;

            float3 wi = float3(0.);
            float3 f = float3(0.);
            float scatteringPdf = 0.;

            float3 Ld = float3(0);
            for( int i = 0; i < 5; ++i) {
                if (lights[i].enabled)
                    Ld += beta * calculateDirectLight(lights[i], interaction, material, &wi, &f, &scatteringPdf, seed);
            }

            //float3 Ld = beta * calculateDirectLight(light, interaction, material, &wi, &f, &scatteringPdf, seed);
            //Ld += beta * calculateDirectLight(light2, interaction, material, &wi, &f, &scatteringPdf, seed);
            L += Ld;

            // Add indirect diffuse light from an env map
            //float3 diffuseColor = (1.0 - material.metallic) * material.baseColor.rgb ;
            //L += diffuseColor * Irradiance_SphericalHarmonics(interaction.normal)/3.14;

            return float4(clamp(pow(L, 0.4545), 0, 1), material.baseColor.w);
        }

        float4 calculatePixelColor_Color(const float2 uv, MaterialInfo material, float3 normal, thread LightInfo lights[5], float distance)
        {
            return material.baseColor;
        }

        float4 calculatePixelColor_Distance(const float2 uv, MaterialInfo material, float3 normal, thread LightInfo lights[5], float distance)
        {
            float3 col = float3(1.0) + sign(distance) * float3(0.1,0.4,0.7);
            col *= 1.0 - exp(-2.0 * abs(distance));
            col *= 0.8 + 0.2 * cos(distance);
            col = mix( col, float3(1.0), 1.0-smoothstep(0.0,0.02,abs(distance)) );

            return float4(col, 1);
        }

        """
        
        return code
    }
    
    static func getNoiseLibrarySource() -> String
    {
        let code =
        """

        // Noises

        // https://www.shadertoy.com/view/4dS3Wd
        float valueNoise2DHash(float2 p) { return fract(1e4 * sin(17.0 * p.x + p.y * 0.1) * (0.1 + abs(sin(p.y * 13.0 + p.x)))); }
        float valueNoise2D( float2 x)
        {
            float2 i = floor(x);
            float2 f = fract(x);

            // Four corners in 2D of a tile
            float a = valueNoise2DHash(i);
            float b = valueNoise2DHash(i + float2(1.0, 0.0));
            float c = valueNoise2DHash(i + float2(0.0, 1.0));
            float d = valueNoise2DHash(i + float2(1.0, 1.0));

            // Simple 2D lerp using smoothstep envelope between the values.
            // return vec3(mix(mix(a, b, smoothstep(0.0, 1.0, f.x)),
            //            mix(c, d, smoothstep(0.0, 1.0, f.x)),
            //            smoothstep(0.0, 1.0, f.y)));

            // Same code, with the clamps in smoothstep and common subexpressions
            // optimized away.
            float2 u = f * f * (3.0 - 2.0 * f);
            return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
        }
        float valueNoise2DFBM(float2 x, int octaves = 5)
        {
            float v = 0.0;
            float a = 0.5;
            float2 shift = float2(100);
            // Rotate to reduce axial bias
            float2x2 rot = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.50));
            for (int i = 0; i < octaves; ++i) {
                v += a * valueNoise2D(x);
                x = rot * x * 2.0 + shift;
                a *= 0.5;
            }
            return v;
        }
        
        """
        
        return code
    }
}
