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
    
    var hoverMode           : HoverMode = .None

    var editor              : Editor!
    
    var c1Node              : Node? = nil
    var c2Node              : Node? = nil
    
    var hoverUIItem         : NodeUI? = nil
    var hoverUITitle        : NodeUI? = nil
    
    var monitorInstance     : CodeBuilderInstance? = nil
    var monitorData         : [SIMD4<Float>] = []
    let totalMonitorData    : Float = 300
    var monitorRange        : SIMD2<Float> = SIMD2<Float>(0, 0)
    
    var buttons             : [MMButtonWidget] = []
    var smallButtonSkin     : MMSkinButton
    var buttonWidth         : Float = 180


    override init(_ view: MMView)
    {
        smallButtonSkin = MMSkinButton()
        
        super.init(view)
        
        smallButtonSkin.height = mmView.skin.Button.height
        smallButtonSkin.round = mmView.skin.Button.round
        smallButtonSkin.fontScale = mmView.skin.Button.fontScale
    }
    
    func unregisterButtons()
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
        
        unregisterButtons()
    }
    
    func setSelected(_ comp: CodeComponent,_ ctx: CodeContext)
    {
        c1Node = nil
        c2Node = nil
        
        unregisterButtons()
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 200
        c2Node?.rect.y = 10
        
        monitorInstance = nil
        
        if let block = ctx.selectedBlock {
            if let function = ctx.cFunction {
                var b = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Add Empty Line", fixedWidth: buttonWidth)
                b.clicked = { (event) in
                    for (index, b) in function.body.enumerated() {
                        if block === b {
                            let newBlock = CodeBlock(.Empty)
                            newBlock.fragment.addProperty(.Selectable)
                            function.body.insert(newBlock, at: index)
                            self.updateCode()
                            break
                        }
                    }
                    b.removeState(.Checked)
                }
                addButton(b)
                
                b = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete Line", fixedWidth: buttonWidth)
                b.clicked = { (event) in
                    for (index, b) in function.body.enumerated() {
                        if block === b {
                            function.body.remove(at: index)
                            self.updateCode()
                            self.clear()
                            break
                        }
                    }
                    b.removeState(.Checked)
                }
                b.isDisabled = block.blockType == .OutVariable
                addButton(b)
            }
        }
        
        if let fragment = ctx.selectedFragment {
            
            if fragment.fragmentType == .ConstantValue {
                
                if fragment.typeName == "float" {
                    c1Node?.uiItems.append( NodeUINumber(c1Node!, variable: "value", title: "Value", range: SIMD2<Float>(0,1), value: fragment.values["value"]!) )
                    c1Node?.setupUI(mmView: mmView)
                    c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == "value" {
                            fragment.values["value"] = newValue
                            self.updateCode()
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
                                self.updateCode()
                            }
                        }
                    }
                    c1Node?.float3ChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == "color" {
                            fragment.arguments[0].fragments[0].values["value"] = newValue.x
                            fragment.arguments[1].fragments[0].values["value"] = newValue.y
                            fragment.arguments[2].fragments[0].values["value"] = newValue.z
                            self.updateCode()
                        }
                    }
                }
            }

            // Setup the monitor
            if fragment.supports(.Monitorable) {
                setupMonitorData(comp, fragment, ctx)
            }
        }
        
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
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
                    //mmView.update()
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
    
    func updateCode()
    {
        editor.codeEditor.needsUpdate = true
        editor.codeEditor.codeChanged = true
        mmView.update()
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
        
        // --- Draw Monitor
        if let inst = monitorInstance {
            let border      : Float = 10
            let mOffsetX    : Float = 200

            mmView.drawBox.draw(x: rect.x + mOffsetX, y: rect.y + border, width: totalMonitorData + 2 * border, height: rect.height - border*2, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1, 1, 1, 0.3))
            
            mmView.drawPointGraph.draw(x: rect.x + mOffsetX, y: rect.y + 2*border, width: totalMonitorData, height: rect.height - border*4, points: monitorData, range: monitorRange, components: inst.computeComponents)
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
    
    // Clear the monitor data
    func setupMonitorData(_ comp: CodeComponent,_ fragment: CodeFragment,_ ctx: CodeContext)
    {
        monitorInstance = globalApp!.codeBuilder.build(comp, fragment)
        
        monitorData = []
        monitorRange = SIMD2<Float>(0, 0)
        updateMonitor()
    }
    
    // Clear the monitor data
    func resetMonitorData()
    {
        monitorData = []
        monitorRange = SIMD2<Float>(0, 0)
        updateMonitor()
    }
    
    // Append data to the monitor
    func updateMonitor()
    {
        if let inst = monitorInstance {
            globalApp!.codeBuilder.compute(inst)
            let result = inst.computeResult
            
            if Float(monitorData.count) >= totalMonitorData {
                monitorData.removeFirst()
            }
            monitorData.append( result )

            func checkRange(_ f: Float)
            {
                if f < monitorRange.x {
                    monitorRange.x = f
                }
                if f > monitorRange.y {
                    monitorRange.y = f
                }
            }
            
            checkRange(result.x)
            //print("result", result.x, monitorRange.x, monitorRange.y, monitorRange.y - monitorRange.x )
            checkRange(result.y)
            checkRange(result.z)
            checkRange(result.w)
        }
    }
}
