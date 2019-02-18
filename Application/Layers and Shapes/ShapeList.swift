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
    
    var hoverData       : [Float]
    var hoverBuffer     : MTLBuffer?
    var hoverIndex      : Int = -1
    var hoverUp         : Bool = false
    
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
        
        hoverData = [-1,0]
        hoverBuffer = compute!.device.makeBuffer(bytes: hoverData, length: hoverData.count * MemoryLayout<Float>.stride, options: [])!

        // ---
    }
    
    /// Build the source
    func build(width: Float, object: Object)
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

        float sdLineScroller( float2 uv, float2 pa, float2 pb, float r) {
            float2 o = uv-pa;
            float2 l = pb-pa;
            float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
            return -(r-distance(o,l*h));
        }

        typedef struct
        {
            float      hoverOffset;
            float      fill;
        } SHAPELIST_HOVER_DATA;

        """
        
        source += getGlobalCode(object: object)
        
        source +=
        """

        kernel void
        shapeListBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
                         constant SHAPELIST_HOVER_DATA  *hoverData   [[ buffer(1) ]],
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

            float4 modeInactiveColor = float4(0.5, 0.5, 0.5, 1.000);
            float4 modeActiveColor = float4(1);
        
            float4 scrollInactiveColor = float4(0.5, 0.5, 0.5, 0.2);
            float4 scrollHoverColor = float4(1);
            float4 scrollActiveColor = float4(0.5, 0.5, 0.5, 1);

            float4 finalCol = float4( 0 ), col = float4( 0 );
        
        """

        let left : Float = width / 2
        var top : Float = unitSize / 2
        
        for (index, shape) in object.shapes.enumerated() {

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
            source += "dist = " + shape.createDistanceCode(uvName: "uv", transProperties: transformPropertySize(shape: shape, size: 12)) + ";"

            source += "col = float4( primitiveColor.x, primitiveColor.y, primitiveColor.z, fillMask( dist ) * primitiveColor.w );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Modes
            
            // --- Merge
            source += "uv -= float2( 50., 0. );\n"
            source += "dist = min( length(uv) - 10, length(uv - float2(10,0)) - 10);"
            source += shape.mode == .Merge ? "col = float4( modeActiveColor.xyz, fillMask( dist ) * modeActiveColor.w );\n" : "col = float4( modeInactiveColor.xyz, fillMask( dist ) * modeInactiveColor.w );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Subtract
            source += "uv -= float2( 25., 0. );\n"
            source += "dist = max( -(length(uv) - 10), length(uv - float2(10,0)) - 10);"
            source += shape.mode == .Subtract ? "col = float4( modeActiveColor.xyz, fillMask( dist ) * modeActiveColor.w );\n" : "col = float4( modeInactiveColor.xyz, fillMask( dist ) * modeInactiveColor.w );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Intersect
            source += "uv -= float2( 30., 0. );\n"
            source += "dist = max( length(uv) - 10, length(uv - float2(10,0)) - 10);"
            source += shape.mode == .Intersect ? "col = float4( modeActiveColor.xyz, fillMask( dist ) * modeActiveColor.w );\n" : "col = float4( modeInactiveColor.xyz, fillMask( dist ) * modeInactiveColor.w );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Up / Down Arrows
            
            // --- Up
            source += "uv -= float2( 105., 0. );\n"
            source += "dist = sdLineScroller( uv, float2( 0, 6 ), float2( 10, -4), 2);\n"
            source += "dist = min( dist, sdLineScroller( uv, float2( 10, -4), float2( 20, 6), 2) );\n"
            if index == 0 || object.shapes.count < 2 {
                source += "col = float4( scrollInactiveColor.xyz, fillMask( dist ) * scrollInactiveColor.w );\n"
            } else {
                source += "if (\(index*2) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"
            }
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Down
            source += "uv -= float2( 35., 0. );\n"
            source += "dist = sdLineScroller( uv, float2( 0, -4 ), float2( 10, 6), 2);\n"
            source += "dist = min( dist, sdLineScroller( uv, float2( 10, 6 ), float2( 20, -4), 2) );\n"
            if index == object.shapes.count - 1 || object.shapes.count < 2 {
                source += "col = float4( scrollInactiveColor.xyz, fillMask( dist ) * scrollInactiveColor.w );\n"
            } else {
                source += "if (\(index*2+1) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"            }
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // ---
            
//            source += "col = float4( primitiveColor.x, primitiveColor.y, primitiveColor.z, fillMask( dist ) * primitiveColor.w );\n"
//            source += "finalCol = mix( finalCol, col, col.a );\n"
            
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
        
        currentObject = object
        
        update()
    }
    
    func update()
    {
        memcpy(hoverBuffer?.contents(), hoverData, hoverData.count * MemoryLayout<Float>.stride)
        compute!.run(state, inBuffer: hoverBuffer)
    }
    
    /// Selected the shape at the given relative mouse position
    @discardableResult func selectAt(_ x: Float,_ y: Float, multiSelect: Bool = false) -> Bool
    {
        let index : Float = y / (unitSize+spacing)
        let selectedIndex = Int(index)
        var changed  = false
        
        if currentObject != nil {
            if selectedIndex >= 0 && selectedIndex < currentObject!.shapes.count {
                if !multiSelect {
                    
                    let shape = currentObject!.shapes[selectedIndex]
                    
                    currentObject!.selectedShapes = [shape.uuid]
                    
    //                print( x )
                    
                    if x >= 60 && x <= 92 {
                        shape.mode = .Merge
                    } else
                    if x >= 95 && x <= 119 {
                        shape.mode = .Subtract
                    } else
                    if x >= 122 && x <= 139 {
                        shape.mode = .Intersect
                    }
                    
                } else if !currentObject!.selectedShapes.contains( currentObject!.shapes[selectedIndex].uuid ) {
                    currentObject!.selectedShapes.append( currentObject!.shapes[selectedIndex].uuid )
                }
                changed = true
            }
        }
        return changed
    }
    
    /// Sets the hover index for the given mouse position
    @discardableResult func hoverAt(_ x: Float,_ y: Float) -> Bool
    {
        let index : Float = y / (unitSize+spacing)
        hoverIndex = Int(index)
        let oldIndex = hoverData[0]
        hoverData[0] = -1
        
        if currentObject != nil {
            if hoverIndex >= 0 && hoverIndex < currentObject!.shapes.count {

    //            print( x )
                
                if x >= 227 && x <= 255 {
                    hoverData[0] = Float(hoverIndex*2)
                    hoverUp = true
                } else
                if x >= 262 && x <= 289 {
                    hoverData[0] = Float(hoverIndex*2+1)
                    hoverUp = false
                }
            }
        }
        
        return hoverData[0] != oldIndex
    }
    
    func transformPropertySize( shape: Shape, size: Float ) -> [String:Float]
    {
        var properties : [String:Float] = shape.properties
        
        properties[shape.widthProperty] = size
        properties[shape.heightProperty] = size

        if shape.name == "Ellipse" {
            properties[shape.heightProperty] = size / 1.5
        } else
        if shape.name == "Triangle" {
            properties["point_0_x"] = 0
            properties["point_0_y"] = -size
            properties["point_1_x"] = -size
            properties["point_1_y"] = size
            properties["point_2_x"] = size
            properties["point_2_y"] = size
        } else
        if shape.name == "Line" {
            properties["point_0_x"] = -size/2
            properties["point_0_y"] = 0
            properties["point_1_x"] = size/2
            properties["point_1_y"] = 0
            properties["lineWidth"] = 6
        } else
        if shape.name == "Capsule" {
            properties["point_0_x"] = -size/2
            properties["point_0_y"] = 0
            properties["point_1_x"] = size/2
            properties["point_1_y"] = 0
            properties["radius1"] = 4
            properties["radius2"] = 8
        } else
        if shape.name == "Bezier" {
            properties["lineWidth"] = 2
            properties["point_0_x"] = 0
            properties["point_0_y"] = -size
            properties["point_1_x"] = -size
            properties["point_1_y"] = size
            properties["point_2_x"] = size
            properties["point_2_y"] = size
        }
        
        /*
        for (name, value) in of.properties {
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
        }*/
        
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