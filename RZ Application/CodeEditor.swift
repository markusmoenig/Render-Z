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
    var codeContext     : CodeContext
    
    var needsUpdate     : Bool = false

    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .Vertical)

        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        textureWidget = MMTextureWidget( view, texture: fragment.texture )
        
        codeContext = CodeContext(view, fragment, view.openSans, 0.5)

        super.init(view)

        zoom = mmView.scaleFactor
        textureWidget.zoom = zoom
        
        dropTargets.append( "SourceItem" )
        
        codeComponent = CodeComponent()
        codeComponent?.createDefaultFunction(.ScreenObjectColorize)
        needsUpdate = true
    }
    
    /// Drag and Drop Target
    override func dragEnded(event: MMMouseEvent, dragSource: MMDragSource)
    {
        if dragSource.id == "SourceItem"
        {
            // Source Item
            //if let drag = dragSource as? SourceListDrag {
                //codeEditor.sourceDrop(event, drag.
            //}
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        //if let dragSource = mmView.dragSource {
        //} else {
        //}
        
        if let comp = codeComponent {
            let oldFunc = codeContext.hoverFunction
            let oldBlock = codeContext.hoverBlock
            let oldFrag = codeContext.hoverFragment
            
            comp.codeAt(mmView, event.x - rect.x, event.y - rect.y, codeContext)
            
            if oldFunc !== codeContext.hoverFunction || oldBlock !== codeContext.hoverBlock || oldFrag !== codeContext.hoverFragment {
                needsUpdate = true
                mmView.update()
            }
        }
    }
    
    override func update()
    {
        let height : Float = 1000
        if fragment.width != rect.width * zoom || fragment.height != height * zoom {
            fragment.allocateTexture(width: rect.width * zoom, height: height * zoom)
        }
        textureWidget.setTexture(fragment.texture)
                
        if fragment.encoderStart()
        {
            if let comp = codeComponent {
                
                codeContext.reset(rect.width)

                comp.draw(mmView, codeContext)
            }
   
            fragment.encodeEnd()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if needsUpdate {
            update()
        }
        
        mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.background)
        
        scrollArea.rect.copy(rect)
        scrollArea.build(widget: textureWidget, area: rect, xOffset: xOffset)
        
        //mmView.drawTexture.draw(fragment.texture, x: rect.x, y: rect.y, zoom: zoom)
    }
}
