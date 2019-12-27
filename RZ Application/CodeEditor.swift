//
//  CodeEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 27/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class CodeEditor        : MMWidget
{
    var fragment        : MMFragment
    var textureWidget   : MMTextureWidget
    var scrollArea      : MMScrollArea
    
    var codeComponent   : CodeComponent? = nil
    
    var needsUpdate     : Bool = false

    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .Vertical)

        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        textureWidget = MMTextureWidget( view, texture: fragment.texture )
        
        super.init(view)

        zoom = mmView.scaleFactor
        textureWidget.zoom = zoom
        
        dropTargets.append( "SourceItem" )
        
        codeComponent = CodeComponent()
        codeComponent?.createFunction(.FreeFlow, "main")
        needsUpdate = true
        
        print(mmView.scaleFactor)
    }
    
    /// Drag and Drop Target
    override func dragEnded(event: MMMouseEvent, dragSource: MMDragSource)
    {
        if dragSource.id == "SourceItem"
        {
            // Source Item
            if let drag = dragSource as? SourceListDrag {
                //codeEditor.sourceDrop(event, drag.
            }
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if let comp = codeComponent {
            for f in comp.functions {
                f.hoverArea = .None

                if f.rects["body"]!.contains((event.x - rect.x), (event.y - rect.y)) {
                 
                    //print(event.x - rect.x, event.y - rect.y)
                    f.hoverArea = .Body

                }
            }
        }
        needsUpdate = true
        mmView.update()
    }
    
    override func update()
    {
        let height : Float = 1000
        if fragment.width != rect.width * zoom || fragment.height != 1000 * zoom {
            fragment.allocateTexture(width: rect.width * zoom, height: 1000 * zoom)
        }
        textureWidget.setTexture(fragment.texture)
                
        func trans(_ coord: Float) -> Float {
            return coord // zoom// * zoom / mmView.scaleFactor
        }
        
        print(rect.width, rect.height, fragment.width, fragment.height)
        
        if fragment.encoderStart()
        {
            let fontScale   : Float = 0.6
            let factor      : Float = 1

            var lineY       : Float = 40 / factor

            var fontRect = MMRect()
            fontRect = mmView.openSans.getTextRect(text: "()", scale: fontScale, rectToUse: fontRect)
            let lineHeight : Float = fontRect.height

            if let comp = codeComponent {

                let startX: Float = 5 / factor
                var lineX : Float = startX
                let gapX  : Float = 5 / factor
                let gapY  : Float = 1 / factor

                for f in comp.functions {
                
                    mmView.drawBox.draw( x: 0, y: 0, width: trans(100), height: trans(40), round: 0, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: fragment )
                    
                    let returnType = f.returnType()
                    fontRect = mmView.openSans.getTextRect(text: returnType, scale: fontScale, rectToUse: fontRect)
                    mmView.drawText.drawText(mmView.openSans, text: returnType, x: trans(lineX), y: trans(lineY), scale: fontScale, color: mmView.skin.Code.reserved, fragment: fragment)

                    lineX += fontRect.width + gapX
                    fontRect = mmView.openSans.getTextRect(text: f.name, scale: fontScale, rectToUse: fontRect)

                    mmView.drawText.drawText(mmView.openSans, text: f.name, x: trans(lineX), y: trans(lineY), scale: fontScale, color: mmView.skin.Code.nameHighlighted, fragment: fragment)
                    
                    lineX += fontRect.width + gapX
                    mmView.drawText.drawText(mmView.openSans, text: "(  )", x: trans(lineX), y: trans(lineY), scale: fontScale, fragment: fragment)
                    
                    lineX = startX
                    lineY += lineHeight + gapY
                    
                    f.rects["body"]!.x = lineX
                    f.rects["body"]!.y = lineY

                    mmView.drawText.drawText(mmView.openSans, text: "[", x: trans(lineX), y: trans(lineY), scale: fontScale, fragment: fragment)
                    
                    lineY += lineHeight + gapY
                    
                    mmView.drawText.drawText(mmView.openSans, text: "]", x: trans(lineX), y: trans(lineY), scale: fontScale, fragment: fragment)
                    
                    lineY += lineHeight + gapY
                    f.rects["body"]!.width = rect.width - f.rects["body"]!.x + 2 / factor
                    f.rects["body"]!.height = lineY - f.rects["body"]!.y + 2 / factor
                    
                    if f.hoverArea == .Body {
                     
                        mmView.drawBox.draw( x: trans(f.rects["body"]!.x), y: trans(f.rects["body"]!.y), width: trans(f.rects["body"]!.width), height: trans(f.rects["body"]!.height), round: 0, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, 0.6), borderColor: SIMD4<Float>( 0, 0, 0, 1 ), fragment: fragment )
                    }
                }
            }
           /*
            let left        : Float = 6 * zoom
            var top         : Float = 0
            var indent      : Float = 0
            let indentSize  : Float = 4
            let fontScale   : Float = 0.22
            
            //var fontRect = MMRect()
            
            func drawItem(_ item: MMTreeWidgetItem) {
                
                if selectedItems.contains(item.uuid) {
                    mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: shadeColor(item.color!, selectionShade), fragment: fragment!)
                } else {
                    mmView.drawBox.draw( x: 0, y: top, width: width, height: unitSize, round: 4, borderSize: 0, fillColor: item.color!, fragment: fragment!)
                }

                //fontRect = mmView.openSans.getTextRect(text: text, scale: fontScale, rectToUse: fontRect)
                
                if item.children != nil {
                    let text : String = item.folderOpen == false ? "+" : "-"
                    mmView.drawText.drawText(mmView.openSans, text: text, x: left + indent, y: top + 4 * zoom, scale: fontScale * zoom, fragment: fragment)
                    mmView.drawText.drawText(mmView.openSans, text: item.name, x: left + indent + 15, y: top + 4 * zoom, scale: fontScale * zoom, fragment: fragment)
                } else {
                    mmView.drawText.drawText(mmView.openSans, text: item.name, x: left + indent, y: top + 4 * zoom, scale: fontScale * zoom, fragment: fragment)
                }
                
                top += (unitSize / 2) * zoom
            }
            
            func drawChildren(_ item: MMTreeWidgetItem) {
                indent += indentSize
                for item in item.children! {
                    drawItem(item)
                    if item.folderOpen == true {
                        drawChildren(item)
                    }
                    height += spacing
                }
                indent -= indentSize
            }
            
            for item in items {
                drawItem(item)
                if item.folderOpen == true {
                    drawChildren(item)
                }
            }*/
            
            fragment.encodeEnd()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if needsUpdate {
            update()
        }
        
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.background, borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        
        //scrollArea.rect.copy(rect)
        //scrollArea.build(widget: textureWidget, area: rect, xOffset: xOffset)
        
        mmView.drawTexture.draw(fragment.texture, x: rect.x, y: rect.y, zoom: zoom)
    }
}
