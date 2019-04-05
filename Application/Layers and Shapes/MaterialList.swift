//
//  MaterialList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 23/3/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class MaterialList
{
    enum HoverState {
        case None, HoverUp, HoverDown, Close
    }
    
    var hoverState      : HoverState = .None
    
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
        let materials : [Material] = object.bodyMaterials
        
        let count : Float = Float(materials.count)
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

        typedef struct {
            float4      baseColor;
        } MATERIAL_DATA;

        """
        
        source += getGlobalCode(object: object)
        
        source +=
        """

        kernel void
        materialListBuilder(texture2d<half, access::write>  outTexture  [[texture(0)]],
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
        
        for (index, material) in materials.enumerated() {

            source += "uv = uvOrigin; uv.x += outTexture.get_width() / 2.0 - \(left) + borderSize/2; uv.y += outTexture.get_height() / 2.0 - \(top) + borderSize/2;\n"
            //source += "dist = merge( dist, " + shape.createDistanceCode(uvName: "uv") + ");"
            
            source += "d = abs( uv ) - float2( \((width)/2) - borderSize, \(unitSize/2) - borderSize ) + float2( round );\n"
            source += "dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - round;\n"

            if object.selectedMaterials.contains( material.uuid ) {
                source += "col = float4( \(mmView.skin.Widget.selectionColor.x), \(mmView.skin.Widget.selectionColor.y), \(mmView.skin.Widget.selectionColor.z), fillMask( dist ) * \(mmView.skin.Widget.selectionColor.w) );\n"
            } else {
                source += "col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );\n"
            }
            source += "col = mix( col, borderColor, borderMask( dist, 1.5 ) );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            source += "uv -= float2( -128., 0. );\n"
            
            source += "col = float4( primitiveColor.x, primitiveColor.y, primitiveColor.z, fillMask( dist ) * primitiveColor.w );\n"
            
            source += "d = abs(uv)-float2(14,14);\n"
            source += "dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);\n"
            source += "if ( dist <= 0 ) "
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Modes
            
            // --- Merge
            source += "uv -= float2( 50., 0. );\n"
            
            // --- Subtract
            source += "uv -= float2( 25., 0. );\n"
            
            // --- Intersect
            source += "uv -= float2( 30., 0. );\n"

            //source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Up / Down Arrows
            
            // --- Up
            source += "uv -= float2( 50., 0. );\n" // 105
            source += "dist = sdLineScroller( uv, float2( 0, 6 ), float2( 10, -4), 2);\n"
            source += "dist = min( dist, sdLineScroller( uv, float2( 10, -4), float2( 20, 6), 2) );\n"
            if index == 0 || materials.count < 2 {
                source += "col = float4( scrollInactiveColor.xyz, fillMask( dist ) * scrollInactiveColor.w );\n"
            } else {
                source += "if (\(index*3) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"
            }
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Down
            source += "uv -= float2( 35., 0. );\n"
            source += "dist = sdLineScroller( uv, float2( 0, -4 ), float2( 10, 6), 2);\n"
            source += "dist = min( dist, sdLineScroller( uv, float2( 10, 6 ), float2( 20, -4), 2) );\n"
            if index == materials.count - 1 || materials.count < 2 {
                source += "col = float4( scrollInactiveColor.xyz, fillMask( dist ) * scrollInactiveColor.w );\n"
            } else {
                source += "if (\(index*3+1) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"            }
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            // --- Close Button
            source += "uv -= float2( 65., 0. );\n"
            source += "dist = sdLineScroller( uv, float2( -8, -8 ), float2( 8, 8), 2);\n"
            source += "dist = min( dist, sdLineScroller( uv, float2( -8, 8 ), float2( 8, -8), 2) );\n"
            source += "if (\(index*3+2) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"
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
        state = compute!.createState(library: library, name: "materialListBuilder")
        
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
    
    /// Selected the material at the given relative mouse position
    @discardableResult func selectAt(_ x: Float,_ y: Float, multiSelect: Bool = false) -> Bool
    {
        let index : Float = y / (unitSize+spacing)
        let selectedIndex = Int(index)
        var changed  = false
        
        let materials : [Material] = currentObject!.bodyMaterials

        if currentObject != nil {
            if selectedIndex >= 0 && selectedIndex < materials.count {
                if !multiSelect {
                    
                    let material = materials[selectedIndex]
                    let sameMaterialSelected = currentObject!.selectedMaterials.count == 0 || (currentObject!.selectedMaterials.count > 0 && currentObject!.selectedMaterials[0] == material.uuid)
                    
                    currentObject!.selectedMaterials = [material.uuid]

                    if sameMaterialSelected {
                    
                    }
                } else if !currentObject!.selectedMaterials.contains( materials[selectedIndex].uuid ) {
                    currentObject!.selectedMaterials.append( materials[selectedIndex].uuid )
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
        hoverState = .None
        
        let materials : [Material] = currentObject!.bodyMaterials

        if currentObject != nil {
            if hoverIndex >= 0 && hoverIndex < materials.count {
                
                if x >= 172 && x <= 201 {
                    hoverData[0] = Float(hoverIndex*3)
                    hoverState = .HoverUp
                } else
                if x >= 207 && x <= 235 {
                    hoverData[0] = Float(hoverIndex*3+1)
                    hoverState = .HoverDown
                }
            }
            
            if x >= 262 && x <= 291 {
                hoverData[0] = Float(hoverIndex*3+2)
                hoverState = .Close
            }
        }
        
        return hoverData[0] != oldIndex
    }
    
    func getGlobalCode(object: Object) -> String
    {
        var coll : [String] = []
        var result = ""
        
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
        
        return result
    }
}
