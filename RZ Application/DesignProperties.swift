//
//  ArtistProperties.swift
//  Render-Z
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class DesignProperties      : MMWidget
{
    enum HoverMode          : Float {
        case None, NodeUI, NodeUIMouseLocked
    }
    
    var hoverMode           : HoverMode = .None

    var editor              : ArtistEditor!
    
    var c1Node              : Node? = nil
    var c2Node              : Node? = nil
    
    var hoverUIItem         : NodeUI? = nil
    var hoverUITitle        : NodeUI? = nil

    var buttons             : [MMButtonWidget] = []
    var smallButtonSkin     : MMSkinButton
    var buttonWidth         : Float = 180
    
    var needsUpdate         : Bool = false

    override init(_ view: MMView)
    {
        smallButtonSkin = MMSkinButton()

        super.init(view)
        
        smallButtonSkin.height = mmView.skin.Button.height
        smallButtonSkin.round = mmView.skin.Button.round
        smallButtonSkin.fontScale = mmView.skin.Button.fontScale
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
        c1Node = nil
        c2Node = nil
        
        deregisterButtons()
    }
    
    func setSelected(_ comp: CodeComponent)
    {
        c1Node = nil
        c2Node = nil
                
        deregisterButtons()
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 200
        c2Node?.rect.y = 10

        for uuid in comp.properties {
            let rc = comp.getPropertyOfUUID(uuid)
            if let frag = rc.0 {
                let components = frag.evaluateComponents()
                let data = extractValueFromFragment(rc.1!)
                if components == 1 {
                    let numberVar = NodeUINumber(c1Node!, variable: frag.name, title: comp.artistPropertyNames[uuid]!, range: SIMD2<Float>(rc.1!.values["min"]!, rc.1!.values["max"]!), value: data.x)
                    c1Node?.uiItems.append(numberVar)
                    c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == frag.name {
                            rc.1!.values["value"] = oldValue
                            let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                            rc.1!.values["value"] = newValue
                            self.updatePreview()
                            self.addKey([frag.name:newValue])
                            if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
                        }
                    }
                } else
                if components == 4 {
                    
                    c1Node?.uiItems.append( NodeUIColor(c1Node!, variable: frag.name, title: comp.artistPropertyNames[uuid]!, value: SIMD3<Float>(data.x, data.y, data.z)))
                    
                    c1Node?.float3ChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == frag.name {
                            insertValueToFragment(rc.1!, oldValue)
                            let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Color Value Changed") : nil
                            insertValueToFragment(rc.1!, newValue)
                            self.updatePreview()
                            var props : [String:Float] = [:]
                            props[frag.name + "_x"] = newValue.x
                            props[frag.name + "_y"] = newValue.y
                            props[frag.name + "_z"] = newValue.z
                            self.addKey(props)
                            if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
                        }
                    }

                }
            }
        }
        
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
        
        needsUpdate = false
    }
    
    /// Update the properties when timeline is moving or playing
    func updateTransformedProperty(_ name: String, data: SIMD4<Float>)
    {
        func updateNode(_ node: Node)
        {
            for item in node.uiItems {
                if item.variable == name {
                    if let number = item as? NodeUINumber {
                        number.setValue(data.x)
                    } else
                    if let color = item as? NodeUIColor {
                        color.setValue(SIMD3<Float>(data.x, data.y, data.z))
                    }
                }
            }
        }
        
        if let node = c1Node {
            updateNode(node)
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
                uiItemY += uiItem.rect.height
            }
        }
        
        if let node = c1Node {
            checkNodeUI(node)
        }
        
        if let node = c2Node, hoverMode == .None {
            checkNodeUI(node)
        }
        
        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    func updatePreview()
    {
        editor.updateOnNextDraw(compile: false)
    }
    
    func addKey(_ properties: [String:Float])
    {
        if editor.timeline.isRecording{
            let component = editor.designEditor.designComponent!
            editor.timeline.addKeyProperties(sequence: component.sequence, uuid: component.uuid, properties: properties)
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        //mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1) )
        
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
        
        // --- Draw buttons
        var bY = rect.y + 20
        for b in buttons {
            b.rect.x = rect.x + rect.width - 200
            b.rect.y = bY
            
            b.draw()
            bY += b.rect.height + 10
        }
    }
}
