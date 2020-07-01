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
    
    var fragment        : MMFragment?
    var state           : MTLRenderPipelineState?
    
    var width, height   : Float
    var spacing         : Float
    var unitSize        : Float
    
    var textureWidget   : MMTextureWidget

    var currentObject   : Object?
    var currentType     : Object.MaterialType = .Body
    
    var hoverData       : [Float]
    var hoverBuffer     : MTLBuffer?
    var hoverIndex      : Int = -1
    
    var zoom            : Float = 2
    
    init(_ view: MMView )
    {
        mmView = view
        
        width = 0
        height = 0
        
        fragment = MMFragment(view)
        fragment!.allocateTexture(width: 10, height: 10)

        spacing = 0
        unitSize = 45
        
        currentObject = nil
        
        textureWidget = MMTextureWidget( view, texture: fragment!.texture )
        
        hoverData = [-1,0]
        hoverBuffer = fragment!.device.makeBuffer(bytes: hoverData, length: hoverData.count * MemoryLayout<Float>.stride, options: [])!

        textureWidget.zoom = zoom
    }
    
    /// Build the source
    func build(width: Float, object: Object, type: Object.MaterialType)
    {
        let materials : [Material] = type == .Body ? object.bodyMaterials : object.borderMaterials
        let selectedMaterials : [UUID] = type == .Body ? object.selectedBodyMaterials : object.selectedBorderMaterials

        let count : Float = Float(materials.count)
        height = count * unitSize + (count > 0 ? (count-1) * spacing : Float(0))
        if height == 0 {
            height = 1
        }
        
        height *= zoom
        
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
    
        source += Builder.getNoiseLibrarySource()
        source += Material.getMaterialStructCode()
        source += getGlobalCode(object: object)
        
        source +=
        """
        
        fragment float4 materialListBuilder(RasterizerData in [[stage_in]],
                         constant SHAPELIST_HOVER_DATA *hoverData [[ buffer(2) ]])
        {
            float2 size = float2( \(width*zoom), \(height) );
        
            float2 uvOrigin = float2( in.textureCoordinate.x * size.x - size.x / 2., size.y - in.textureCoordinate.y * size.y - size.y / 2. );
            float2 uv;

            float dist = 10000, limit;
            float2 d, limitD;
        
            float borderSize = 0;
            float round = 18;
        
            float4 fillColor = float4(0.275, 0.275, 0.275, 1.000);
            float4 borderColor = float4( 0.5, 0.5, 0.5, 1 );
            float4 primitiveColor = float4(1, 1, 1, 1.000);

            float4 modeInactiveColor = float4(0.5, 0.5, 0.5, 1.000);
            float4 modeActiveColor = float4(1);
        
            float4 scrollInactiveColor = float4(0.5, 0.5, 0.5, 0.2);
            float4 scrollHoverColor = float4(1);
            float4 scrollActiveColor = float4(0.5, 0.5, 0.5, 1);

            float4 finalCol = float4( 0 ), col = float4( 0 );
        
            MATERIAL_DATA material;
        
            float componentBlend = 1.0;
        
        """

        let left : Float = (width/2) * zoom
        var top : Float = (unitSize / 2) * zoom
        
        for (index, material) in materials.enumerated() {

            source += "uv = uvOrigin; uv.x += size.x / 2.0 - \(left) + borderSize/2; uv.y += size.y / 2.0 - \(top) + borderSize/2;\n"
            source += "uv /= \(zoom);\n"
            
            source += "d = abs( uv ) - float2( \((width)/2) - borderSize - 2, \(unitSize/2) - borderSize ) + float2( round );\n"
            source += "dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0) - round;\n"

            if selectedMaterials.contains( material.uuid ) {
//                source += "col = float4( \(mmView.skin.Widget.selectionColor.x), \(mmView.skin.Widget.selectionColor.y), \(mmView.skin.Widget.selectionColor.z), fillMask( dist ) * \(mmView.skin.Widget.selectionColor.w) );\n"
                source += "col = float4(0.354, 0.358, 0.362, fillMask( dist ) );\n"
            } else {
                source += "col = float4( fillColor.x, fillColor.y, fillColor.z, fillMask( dist ) * fillColor.w );\n"
            }
            //source += "col = mix( col, borderColor, borderMask( dist, 1.5 ) );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
            
            source += "uv -= float2( -125.5, 0. );\n"
            
            if !material.isCompound {
                if material.properties["channel"]! == 0 {
                    source += "primitiveColor = " + material.createCode(uvName: "uv") + ";\n"
                } else {
                    source += "primitiveColor = float4( float3(" + material.createCode(uvName: "uv") + ".x), 1 );\n"
                }
            } else {
                source += material.createCode(uvName: "uv", materialName: "material") + ";\n"
                source += "primitiveColor = material.baseColor;\n"
            }
            
            source +=
            """
            
            limitD = abs(uv - float2(3-2.5,0)) - float2(\(unitSize/2-2)) + float2( 16. );
            limit = length(max(limitD,float2(0))) + min(max(limitD.x,limitD.y),0.0) - 16.;
            finalCol = mix( finalCol, float4(0,0,0,1), fillMask( limit ) );
            dist = max(limit,dist);
            
            """

            source += "col = float4( primitiveColor.x, primitiveColor.y, primitiveColor.z, fillMask( dist ) * primitiveColor.w );\n"
            
            //source += "d = abs(uv)-float2(14,14);\n"
            //source += "dist = length(max(d,float2(0))) + min(max(d.x,d.y),0.0);\n"
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
            source += "uv -= float2( 60., 0. );\n"
            source += "dist = sdLineScroller( uv, float2( -8, -8 ), float2( 8, 8), 2);\n"
            source += "dist = min( dist, sdLineScroller( uv, float2( -8, 8 ), float2( 8, -8), 2) );\n"
            source += "if (\(index*3+2) == hoverData->hoverOffset ) col = float4( scrollHoverColor.xyz, fillMask( dist ) * scrollHoverColor.w ); else col = float4( scrollActiveColor.xyz, fillMask( dist ) * scrollActiveColor.w );\n"
            source += "finalCol = mix( finalCol, col, col.a );\n"
                        
            top += (unitSize + spacing) * zoom
        }
        
        source +=
        """
                //return finalCol;
                return float4( finalCol.x / finalCol.w, finalCol.y / finalCol.w, finalCol.z / finalCol.w, finalCol.w);
            }
        """
        
        let library = fragment!.createLibraryFromSource(source: source)
        state = fragment!.createState(library: library, name: "materialListBuilder")
        
        if fragment!.width != width * zoom || fragment!.height != height {
            fragment!.allocateTexture(width: width * zoom, height: height)
            textureWidget.setTexture(fragment!.texture)
        }
        
        currentObject = object
        currentType = type
        
        update()
    }
    
    func update()
    {
        memcpy(hoverBuffer!.contents(), hoverData, hoverData.count * MemoryLayout<Float>.stride)
        
        if fragment!.encoderStart() {
            
            fragment!.encodeRun(state, inBuffer: hoverBuffer)

            let materials : [Material] = currentType == .Body ? currentObject!.bodyMaterials : currentObject!.borderMaterials
                        
            let left : Float = 26 * zoom
            var top : Float = 6 * zoom
            let fontScale : Float = 0.22
            
            var fontRect = MMRect()
            
            for material in materials {
                
                var text = ""
                if !material.isCompound {
                    let channel = material.properties["channel"]
                    switch channel
                    {
                        case 0: text += "Base Color"
                        case 1: text += "Subsurface"
                        case 2: text += "Roughness"
                        case 3: text += "Metallic"
                        case 4: text += "Specular"
                        case 5: text += "Spec. Tint"
                        case 6: text += "Clearcoat"
                        case 7: text += "Clearc. Gloss"
                        case 8: text += "Anisotropic"
                        case 9: text += "Sheen"
                        case 10: text += "Sheen Tint"
                        case 11: text += "Border"
                        default: print("Wrong Channel")
                    }
                } else {
                    text = material.name
                }
                
                fontRect = mmView.openSans.getTextRect(text: text, scale: fontScale, rectToUse: fontRect)
                mmView.drawText.drawText(mmView.openSans, text: text, x: left, y: top, scale: fontScale * zoom, color: float4(1, 1, 1, 1), fragment: fragment)
                
                top += (unitSize / 2) * zoom
            }
            
            fragment!.encodeEnd()
        }
    }
    
    /// Selected the material at the given relative mouse position
    @discardableResult func selectAt(_ x: Float,_ y: Float, multiSelect: Bool = false) -> Bool
    {
        let index : Float = y / (unitSize+spacing)
        let selectedIndex = Int(index)
        var changed  = false
        
        let materials : [Material] = currentType == .Body ? currentObject!.bodyMaterials : currentObject!.borderMaterials
        let selectedMaterials : [UUID] = currentType == .Body ? currentObject!.selectedBodyMaterials : currentObject!.selectedBorderMaterials
        
        if currentObject != nil {
            if selectedIndex >= 0 && selectedIndex < materials.count {
                if !multiSelect {
                    
                    let material = materials[selectedIndex]
                    let sameMaterialSelected = selectedMaterials.count == 0 || (selectedMaterials.count > 0 && selectedMaterials[0] == material.uuid)
                    
                    if currentType == .Body {
                        currentObject!.selectedBodyMaterials = [material.uuid]
                    } else {
                        currentObject!.selectedBorderMaterials = [material.uuid]
                    }

                    if sameMaterialSelected {
                    
                    }
                } else if !selectedMaterials.contains( materials[selectedIndex].uuid )
                {
                    if currentType == .Body {
                        currentObject!.selectedBodyMaterials.append( materials[selectedIndex].uuid )
                    } else {
                        currentObject!.selectedBorderMaterials.append( materials[selectedIndex].uuid )
                    }
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
            
            if x >= 260 && x <= 288 {
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
