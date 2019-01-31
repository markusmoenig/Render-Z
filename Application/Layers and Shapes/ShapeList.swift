//
//  ShapeList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 17/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ShapeList
{
    var mmView          : MMView
    
    var compute         : MMCompute?
    var state           : MTLComputePipelineState?
    
    var width, height   : Float
    var spacing         : Float
    var unitSize        : Float
    
    var textureWidget   : MMTextureWidget

    var currentObject   : Object?
    
    init(_ view: MMView )
    {
        mmView = view
        
        width = 0
        height = 0
        
        compute = MMCompute()
        compute!.allocateTexture(width: 10, height: 10)
        
        spacing = 0
        unitSize = 40
        
        currentObject = nil
        
        textureWidget = MMTextureWidget( view, texture: compute!.texture )

        // ---
    }
    
    /// Build the source
    func build( width: Float, object: Object )
    {
        let count : Float = Float(object.shapes.count)
        height = count * unitSize + (count > 0 ? (count-1) * spacing : Float(0))
        if height == 0 {
            height = 1
        }
        
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
        """
        
        source += getGlobalCode(object: object)
        
        source +=
        """

            kernel void
            shapeListBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
                         texture2d<half, access::read>   inTexture   [[texture(1)]],
                         uint2                           gid         [[thread_position_in_grid]])
            {
                float2 uvOrigin = float2( gid.x - outTexture.get_width() / 2.,
                                          gid.y - outTexture.get_height() / 2. );
                float2 uv;

                float dist = 10000;
                float2 d;
        
                float borderSize = 2;
                float round = 4;
        
                float4 fillColor = float4(0.275, 0.275, 0.275, 1.000);
                float4 borderColor = float4( 0.5, 0.5, 0.5, 1 );
                float4 primitiveColor = float4(1, 1, 1, 1.000);

                float4 finalCol = float4( 0 ), col = float4( 0 );
        """

        let left : Float = width / 2
        var top : Float = unitSize / 2
        
        for (_, shape) in object.shapes.enumerated() {

            source += "uv = uvOrigin; uv.x += outTexture.get_width() / 2.0 - \(left) + borderSize/2; uv.y += outTexture.get_height() / 2.0 - \(top) + borderSize/2;\n"
            //source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
            
            source += "d = abs( uv ) - float2( \((width)/2) - borderSize, \(unitSize/2) - borderSize ) + float2( round );\n"
            source += "dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - round;\n"

            if object.selectedShapes.contains( shape.uuid ) {
                source += "col = float4( \(mmView.skin.Widget.selectionColor.x), \(mmView.skin.Widget.selectionColor.y), \(mmView.skin.Widget.selectionColor.z), fillMask( dist ) * \(mmView.skin.Widget.selectionColor.w) );\n"
            } else {
                source += "col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );\n"
            }
            source += "col = mix( col, borderColor, borderMask( dist, 1.5 ) );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            source += "uv -= float2( -130., 0. );\n"
            source += "dist = " + shape.createDistanceCode(uvName: "uv", transProperties: transformPropertySize(of: shape.properties, size: 12)) + ";"

            source += "col = float4( primitiveColor.x, primitiveColor.y, primitiveColor.z, fillMask( dist ) * primitiveColor.w );\n"
//            source += "col = mix( col, borderColor, borderMask( dist, 1.5 ) );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            top += unitSize + spacing
        }
        
        source +=
        """
        
                outTexture.write(half4(finalCol.x, finalCol.y, finalCol.z, finalCol.w), gid);
            }
        """
        
        let library = compute!.createLibraryFromSource(source: source)
        state = compute!.createState(library: library, name: "shapeListBuilder")
        
        if compute!.width != width || compute!.height != height {
            compute!.allocateTexture(width: width, height: height)
            textureWidget.setTexture(compute!.texture)
        }
        
        compute!.run(state)
        
        currentObject = object
    }
    
    /// Selected the shape at the given relative mouse position
    @discardableResult func selectAt(_ x: Float,_ y: Float) -> Bool
    {
        let index : Float = y / (unitSize+spacing)
        let selectedIndex = Int(index)
        var changed  = false
        
        if selectedIndex >= 0 && selectedIndex < currentObject!.shapes.count {
            currentObject!.selectedShapes = [currentObject!.shapes[selectedIndex].uuid]
            changed = true
        }
        
        return changed
    }
    
    func transformPropertySize( of: [String:Float], size: Float ) -> [String:Float]
    {
        var properties : [String:Float] = [:]
        
        for (name, value) in of {
            var v = value
            if name == "radius" {
                v = size
            } else
            if name == "width" {
                v = size
            } else
            if name == "height" {
                v = size
            }
            properties[name] = v
        }
        
        return properties
    }
    
    /// Create a drag item for the given position
    /*
    func createDragSource(_ x: Float,_ y: Float) -> ShapeSelectorDrag
    {
        var drag = ShapeSelectorDrag()
        for (index, rect) in shapeRects.enumerated() {
            if rect.contains( x, y ) {
                drag.id = "ShapeSelectorItem"
                drag.name = shapes[index].name
                drag.pWidgetOffset!.x = x - rect.x
                drag.pWidgetOffset!.y = y - rect.y
                drag.shape = shapeFactory.createShape(drag.name, size: unitSize / 2 - 2)

                let texture = createShapeThumbnail(drag.shape!)
                drag.previewWidget = MMTextureWidget(mmView, texture: texture)
                break
            }
        }
        return drag
    }*/
    
    func getGlobalCode(object: Object) -> String
    {
        var coll : [String] = []
        var result = ""
        
        for shape in object.shapes {
            
            if !coll.contains(shape.name) {
                result += shape.globalCode
                coll.append( shape.name )
            }
        }
        
        return result
    }
}
