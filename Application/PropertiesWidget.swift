//
//  PropertiesWidget.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/4/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PropertiesWidget      : MMWidget
{
    enum HoverMode : Float {
        case None, NodeUI, NodeUIMouseLocked
    }
    
    var hoverMode           : HoverMode = .None
    
    var c1Node              : Node? = nil
    var c2Node              : Node? = nil
    var c3Node              : Node? = nil

    var hoverUIItem         : NodeUI? = nil
    var hoverUITitle        : NodeUI? = nil
    
    var buttons             : [MMButtonWidget] = []
    var smallButtonSkin     : MMSkinButton
    var buttonWidth         : Float = 190
    
    var buttonStartX        : Float = 20
    var buttonStartY        : Float = 20

    var needsUpdate         : Bool = false

    override init(_ view: MMView)
    {
        smallButtonSkin = MMSkinButton()

        super.init(view)
        
        smallButtonSkin.height = mmView.skin.Button.height
        smallButtonSkin.round = mmView.skin.Button.round
        smallButtonSkin.fontScale = mmView.skin.Button.fontScale
    }
    
    func isUIActive() -> Bool
    {
        return hoverMode != .None || hoverUITitle != nil
    }
    
    func deregisterButtons()
    {
        for w in buttons {
            mmView.deregisterWidget(w)
        }
        buttons = []
    }
    
    func addButton(_ b: MMButtonWidget)
    {
        mmView.registerWidgetAt(b, at: 0)
        buttons.append(b)
    }
    
    /// Clears the property area
    func clear()
    {
        if c1Node != nil { c1Node!.uiItems = []; c1Node!.floatChangedCB = nil; c1Node!.float3ChangedCB = nil }
        if c2Node != nil { c2Node!.uiItems = []; c2Node!.floatChangedCB = nil; c2Node!.float3ChangedCB = nil }
        if c3Node != nil { c3Node!.uiItems = []; c3Node!.floatChangedCB = nil; c3Node!.float3ChangedCB = nil }

        c1Node = nil
        c2Node = nil
        c3Node = nil

        deregisterButtons()
    }
    
    func setSelected()
    {
        clear()
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 200
        c2Node?.rect.y = 10
        
        c3Node = Node()
        c3Node?.rect.x = 400
        c3Node?.rect.y = 10
        
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
        c3Node?.setupUI(mmView: mmView)

        needsUpdate = false
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
            globalApp?.mmView.mouseTrackWidget = self
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
        
        #if os(OSX)
        mouseMoved(event)
        #endif
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
        
        let oldHoverMode = hoverMode
        
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
                uiItemY += uiItem.rect.height + uiItem.additionalSpacing
            }
        }
        
        if let node = c1Node {
            checkNodeUI(node)
        }
        
        if let node = c2Node, hoverMode == .None {
            checkNodeUI(node)
        }
        
        if let node = c3Node, hoverMode == .None {
            checkNodeUI(node)
        }
        
        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if let node = c1Node {
            
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height + uiItem.additionalSpacing
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
                uiItemY += uiItem.rect.height + uiItem.additionalSpacing
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
        
        if let node = c3Node {
            
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height + uiItem.additionalSpacing
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
        
        // --- Draw buttons
        
        //var bY = buttonStartY
        for b in buttons {
            //b.rect.x = rect.x + buttonStartX
            //b.rect.y = bY
            
            b.draw()
            //bY += b.rect.height + 10
        }
    }
}
