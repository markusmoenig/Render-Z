//
//  CodeProperties.swift
//  Render-Z
//
//  Created by Markus Moenig on 30/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class CodeProperties    : MMWidget
{
    enum HoverMode : Float {
        case None, NodeUI, NodeUIMouseLocked
    }
    
    var hoverMode       : HoverMode = .None

    var editor          : Editor!
    
    var c1Node          : Node? = nil
    var c2Node          : Node? = nil
    
    var hoverUIItem     : NodeUI? = nil
    var hoverUITitle    : NodeUI? = nil
    
    override init(_ view: MMView)
    {
        super.init(view)
    }
    
    func setSelected(_ comp: CodeComponent,_ ctx: CodeContext)
    {
        c1Node = nil
        c2Node = nil
        
        if let fragment = ctx.selectedFragment {
            
            c1Node = Node()
            c1Node?.rect.x = 10
            c1Node?.rect.y = 10
            
            c2Node = Node()
            c2Node?.rect.x = 200
            c2Node?.rect.y = 10
            
            if fragment.fragmentType == .ConstantValue {
                
                if fragment.typeName == "float" {
                    c1Node?.uiItems.append( NodeUINumber(c1Node!, variable: "value", title: "Value", range: SIMD2<Float>(0,1), value: fragment.values["value"]!) )
                    c1Node?.setupUI(mmView: mmView)
                    c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == "value" {
                            fragment.values["value"] = newValue
                            self.editor.codeEditor.needsUpdate = true
                        }
                    }
                }
            }
            
            if fragment.fragmentType == .ConstantDefinition {
                
                if fragment.typeName == "float4" || fragment.typeName == "float3" {
                    c1Node?.uiItems.append( NodeUIColor(c1Node!, variable: "color", title: "Color", value: SIMD3<Float>(fragment.arguments[0].fragments[0].values["value"]!, fragment.arguments[1].fragments[0].values["value"]!, fragment.arguments[2].fragments[0].values["value"]!)))
                    if fragment.typeName == "float4" {
                        c2Node?.uiItems.append( NodeUINumber(c2Node!, variable: "alpha", title: "Alpha", range: SIMD2<Float>(0,1), value: fragment.arguments[3].fragments[0].values["value"]!) )
                        c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                            if variable == "alpha" {
                                fragment.arguments[3].fragments[0].values["value"] = newValue
                                self.editor.codeEditor.needsUpdate = true
                            }
                        }
                    }
                    c1Node?.float3ChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == "color" {
                            fragment.arguments[0].fragments[0].values["value"] = newValue.x
                            fragment.arguments[1].fragments[0].values["value"] = newValue.y
                            fragment.arguments[2].fragments[0].values["value"] = newValue.z
                            self.editor.codeEditor.needsUpdate = true
                        }
                    }
                }
            }
            
            c1Node?.setupUI(mmView: mmView)
            c2Node?.setupUI(mmView: mmView)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif

        #if os(OSX)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
        
        if hoverMode == .NodeUI {
            hoverUIItem!.mouseDown(event)
            hoverMode = .NodeUIMouseLocked
            //globalApp?.mmView.mouseTrackWidget = self
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if hoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseUp(event)
        }
        
        #if os(iOS)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
        
        hoverMode = .None
        mmView.mouseTrackWidget = nil
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if hoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseMoved(event)
            return
        }
        
        // Disengage hover types for the ui items
        if hoverUIItem != nil {
            hoverUIItem!.mouseLeave()
        }
        
        if hoverUITitle != nil {
            hoverUITitle?.titleHover = false
            hoverUITitle = nil
            mmView.update()
        }
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverMode = .None
                
        func checkNodeUI(_ node: Node)
        {
            // --- Look for NodeUI item under the mouse, master has no UI
            let uiItemX = rect.x + node.rect.x
            var uiItemY = rect.y + node.rect.y
            let uiRect = MMRect()
            
            for uiItem in node.uiItems {
                
                if uiItem.supportsTitleHover {
                    uiRect.x = uiItem.titleLabel!.rect.x - 2
                    uiRect.y = uiItem.titleLabel!.rect.y - 2
                    uiRect.width = uiItem.titleLabel!.rect.width + 4
                    uiRect.height = uiItem.titleLabel!.rect.height + 6
                    
                    if uiRect.contains(event.x, event.y) {
                        uiItem.titleHover = true
                        hoverUITitle = uiItem
                        mmView.update()
                        return
                    }
                }
                
                uiRect.x = uiItemX
                uiRect.y = uiItemY
                uiRect.width = uiItem.rect.width
                uiRect.height = uiItem.rect.height
                
                if uiRect.contains(event.x, event.y) {
                    
                    hoverUIItem = uiItem
                    hoverMode = .NodeUI
                    hoverUIItem!.mouseMoved(event)
                    mmView.update()
                    return
                }
                uiItemY += uiItem.rect.height
            }
        }
        
        if let node = c1Node {
            checkNodeUI(node)
        }
        
        if let node = c2Node, hoverMode == .None {
            checkNodeUI(node)
        }
        
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1) )
        
        if let node = c1Node {
            
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
        
        if let node = c2Node {
            
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
    }
}
