//
//  ShapeSelector.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct ShapeSelectorDrag : MMDragSource
{
    var id              : String = ""
    var sourceWidget    : MMWidget? = nil
    var previewWidget   : MMWidget? = nil
    var pWidgetOffset   : float2? = float2()
    var shape           : Shape? = nil
    var name            : String = ""
}

class ShapeSelector
{
    var mmView          : MMView
    var shapes          : [Shape]
    var shapeFactory    : ShapeFactory
    
    var shapeRects      : [MMRect]

    var fragment        : MMFragment?
    
    var width, height   : Float
    var spacing         : Float
    var unitSize        : Float
    
    var selectedIndex   : Int
    var selectedShape   : Shape!
    
    var zoom            : Float = 2
    
    init(_ view: MMView, width: Float )
    {
        mmView = view
        
        shapes = []
        shapeFactory = ShapeFactory()
        
        shapeRects = []
        fragment = MMFragment(view)

        spacing = 10
        unitSize = (width - spacing * 3) / 2
        
        selectedIndex = 0
        
        // --- Shapes

        for shapeDef in shapeFactory.shapes {
            let shape = shapeFactory.createShape(shapeDef.name, size: unitSize / 2 - 2)
            if shape.name == "Box" {
                selectedShape = shape
            }
            shapes.append( shape )
        }
        
        // ---
        
        self.width = width * zoom
        height = 0//spacing * 4
        let length : Int = shapes.count
        let lines : Float = Float((length / 2 + length % 2))
        height += Float(lines * Float(unitSize) + lines * Float(20) + (lines) * spacing + spacing) 
//        print( unitSize, height, length.truncatingRemainder(dividingBy: 2.0), length )
        
        height = height * zoom
        build()
    }
    
    /// Build the source
    func build()
    {
        var source =
        """
            typedef struct
            {
                float2  charPos;
                float2  charSize;
                float2  charOffset;
                float2  charAdvance;
                float4  stringInfo;
            } FontChar;

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
        
        for (index,shape) in shapes.enumerated() {
            source += shape.globalCode;
            if shape.dynamicCode != nil {
                var dyn = shape.dynamicCode!
                dyn = dyn.replacingOccurrences(of: "__shapeIndex__", with: String(index))
                dyn = dyn.replacingOccurrences(of: "__pointCount__", with: String(shape.pointCount))
                source += dyn
            }
        }
        
        source +=
        """
        
            fragment float4 shapeBuilder(RasterizerData in [[stage_in]],
               texture2d<half, access::sample>   fontTexture [[texture(1)]])
            {
                float2 size = float2( \(width), \(height) );
                float2 uvOrigin = in.textureCoordinate * size - size / 2;
                uvOrigin.y = 1 - uvOrigin.y;
                float2 uv;
        
                float2 limitD;
                float limit;
        
                float dist = 10000;
        
        """

        var counter : Int = 0
        var left : Float = (spacing + unitSize / 2) * zoom
        var top : Float = (spacing + unitSize / 2) * zoom
        
        shapeRects = []
        for (index, shape) in shapes.enumerated() {

            source += "uv = uvOrigin; uv.x += size.x / 2 - \(left); uv.y += size.y / 2 - \(top);\n"
            
            source += "uv /= \(zoom);\n"
            
            if shape.pointsVariable {
                source += shape.createPointsVariableCode(shapeIndex: index)
            }
            
            if shape.name == "Text" {
                source += createStaticTextSource(mmView.defaultFont, "Abc", varCounter: index)
            } else
            if shape.name == "Variable" {
                source += createStaticTextSource(mmView.defaultFont, "123", varCounter: index)
            }
            if shape.name == "Horseshoe" || shape.name == "Pie" || shape.name == "Spring" || shape.name == "Wave" || shape.name == "Noise" {
                source += "uv.y = -uv.y;\n"
            }
            
            source +=
            """
                limitD = abs(uv) - float2(\(unitSize/2));
                limit = length(max(limitD,float2(0))) + min(max(limitD.x,limitD.y),0.0);
            """
            
            source += "dist = merge( dist, max(limit, " + shape.createDistanceCode(uvName: "uv", shapeIndex: index) + "));"
            
            shapeRects.append( MMRect(left/zoom - unitSize / 2, top / zoom - unitSize / 2, unitSize, unitSize ) )
            
            counter += 1
            if counter % 2 == 0 {
                top += (unitSize + spacing + 20) * zoom
                left = (spacing + unitSize / 2) * zoom
            } else {
                left += (unitSize + spacing) * zoom
            }
        }
        
        source +=
        """
                float4 fillColor = float4( 0.5, 0.5, 0.5, 1);
                float4 borderColor = float4( 1 );
        
                float4 col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );
                col = mix( col, borderColor, borderMask( dist, 2 ) );
                return float4(col.x / col.w, col.y / col.w, col.z / col.w, col.w);
            }
        """
        
        let library = fragment!.createLibraryFromSource(source: source)
        let fragmentState = fragment!.createState(library: library, name: "shapeBuilder")
        
        if fragment!.width != width || fragment!.height != height {
            fragment!.allocateTexture(width: width, height: height)
        }
        
        if fragment!.encoderStart() {

            fragment!.encodeRun(fragmentState, inTexture: mmView.defaultFont.atlas)
            
            left = spacing
            top = spacing + unitSize - 4
            counter = 0
            let fontScale : Float = 0.256 // 26
            
            var fontRect = MMRect()
            
            for shape in shapes {
                
                fontRect = mmView.openSans.getTextRect(text: shape.name, scale: fontScale * zoom, rectToUse: fontRect)
                mmView.drawText.drawText(mmView.openSans, text: shape.name, x: left + (unitSize - fontRect.width) / 2, y: top + 4, scale: fontScale * zoom, fragment: fragment)
                
                counter += 1
                if counter % 2 == 0 {
                    top += (unitSize + spacing + 20)
                    left = spacing
                } else {
                    left += unitSize + spacing
                }
            }
            
            fragment!.encodeEnd()
        }
    }
    
    /// Creates a thumbnail for the given shape name
    func createShapeThumbnail(_ shape: Shape) -> MTLTexture?
    {
        let comp = MMCompute()
        comp.allocateTexture(width: unitSize, height: unitSize)
        
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
        
        source += shape.globalCode
        if shape.dynamicCode != nil {
            var dyn = shape.dynamicCode!
            dyn = dyn.replacingOccurrences(of: "__shapeIndex__", with: "0")
            dyn = dyn.replacingOccurrences(of: "__pointCount__", with: String(shape.pointCount))
            source += dyn
        }
        
        source +=
        """
        
        kernel void
        iconBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
        texture2d<half, access::sample>   fontTexture   [[texture(2)]],
        uint2                           gid         [[thread_position_in_grid]])
        {
            float2 uv = float2( gid.x - outTexture.get_width() / 2., gid.y - outTexture.get_height() / 2. );
            float dist = 10000;
        """
        
        if shape.pointsVariable {
            source += shape.createPointsVariableCode(shapeIndex: 0)
        }
        
        if shape.name == "Text" {
            source += createStaticTextSource(mmView.defaultFont, "Abc")
        } else
        if shape.name == "Variable" {
            source += createStaticTextSource(mmView.defaultFont, "123")
        }
        if shape.name == "Horseshoe" || shape.name == "Pie" || shape.name == "Spring" || shape.name == "Wave" || shape.name == "Noise" {
            source += "uv.y = -uv.y;\n"
        }
        source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv", shapeIndex: 0) + ");"
        source +=
        """
            float4 fillColor = float4( 0.5, 0.5, 0.5, 1);
            float4 borderColor = float4( 1 );
        
            float4 col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );
            col = mix( col, borderColor, borderMask( dist, 2 ) );
        
            outTexture.write(half4(col.x, col.y, col.z, col.w), gid);
        }
        """
        
        let library = comp.createLibraryFromSource(source: source)
        let state = comp.createState(library: library, name: "iconBuilder")
        
        comp.run( state, inTexture: mmView.defaultFont!.atlas )
        
        return comp.texture
    }
    
    /// Selected the shape at the given relative mouse position
    func selectAt(_ x: Float,_ y: Float) -> Shape?
    {
        for (index, rect) in shapeRects.enumerated() {
            if rect.contains( x, y ) {
                selectedIndex = index
                selectedShape = shapes[index]
                return selectedShape
            }
        }
        return nil
    }
    
    /// Create a drag item for the given position
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
    }
    
    /// Create an instance of the currently selected shape
    func createSelected() -> Shape
    {
        return shapeFactory.createShape(selectedShape.name)
    }
}
