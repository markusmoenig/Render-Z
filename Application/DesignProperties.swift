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
    var hoverUIRandom       : NodeUI? = nil

    var buttons             : [MMButtonWidget] = []
    var smallButtonSkin     : MMSkinButton
    var buttonWidth         : Float = 180
    
    var needsUpdate         : Bool = false
    
    var propMap             : [String:CodeFragment] = [:]
    
    var selected            : CodeComponent? = nil
    
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
        if c1Node != nil { c1Node!.uiItems = []; c1Node!.floatChangedCB = nil; c1Node!.float3ChangedCB = nil }
        if c2Node != nil { c2Node!.uiItems = []; c2Node!.floatChangedCB = nil; c2Node!.float3ChangedCB = nil }

        c1Node = nil
        c2Node = nil
        
        deregisterButtons()
    }
    
    func setSelected(_ comp: CodeComponent)
    {
        selected = comp
                
        clear()
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 200
        c2Node?.rect.y = 10

        propMap = [:]
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverUIRandom = nil
        hoverMode = .None
        
        
        if comp.componentType == .Render3D {
            return
            /*
            let renderModeVar = NodeUISelector(c1Node!, variable: "renderMode", title: "Output", items: ["Final Image", "Depth Map", "Occlusion", "Shadows", "Fog Density"], index: 0, shadows: true)
            c1Node?.uiItems.append(renderModeVar)
            */
        }
        
        if comp.componentType == .Transform3D {
            
            let bbX : Float = comp.values["_bb_x"] == nil ? 1 : comp.values["_bb_x"]!
            let bbY : Float = comp.values["_bb_y"] == nil ? 1 : comp.values["_bb_y"]!
            let bbZ : Float = comp.values["_bb_z"] == nil ? 1 : comp.values["_bb_z"]!

            let bboxVar = NodeUINumber3(c1Node!, variable: "_bb", title: "Bounding Box", range: SIMD2<Float>(0, 10), value: SIMD3<Float>(bbX, bbY, bbZ), precision: 3)
            bboxVar.titleShadows = true
            c1Node?.uiItems.append(bboxVar)
            
            let physics = comp.values["physics"] == nil ? 0.0 : comp.values["physics"]!
            let physicsVar = NodeUISelector(c1Node!, variable: "physics", title: "Physics", items: ["Off", "Dynamic", "Static"], index: physics, shadows: false)
            physicsVar.titleShadows = true
            c1Node!.uiItems.append(physicsVar)
            
            if physics == 1 {
                let resitution = comp.values["restitution"] == nil ? 0.4 : comp.values["restitution"]!
                let restituitonVar = NodeUINumber(c1Node!, variable: "restitution", title: "Restitution", range: SIMD2<Float>(0, 1), value: resitution, precision: Int(3))
                restituitonVar.titleShadows = true
                restituitonVar.autoAdjustMargin = true
                c1Node!.uiItems.append(restituitonVar)
                
                let friction = comp.values["friction"] == nil ? 0.3 : comp.values["friction"]!
                let frictionVar = NodeUINumber(c1Node!, variable: "friction", title: "Friction", range: SIMD2<Float>(0, 1), value: friction, precision: Int(2))
                frictionVar.titleShadows = true
                c1Node!.uiItems.append(frictionVar)
                
                let mass = comp.values["mass"] == nil ? 5 : comp.values["mass"]!
                let massVar = NodeUINumber(c1Node!, variable: "mass", title: "Mass", range: SIMD2<Float>(0.1, 1000), value: mass, precision: Int(2))
                massVar.titleShadows = true
                c1Node!.uiItems.append(massVar)
                
                let elasticity = comp.values["elasticity"] == nil ? 0 : comp.values["elasticity"]!
                let elasticityVar = NodeUINumber(c1Node!, variable: "elasticity", title: "Elasticity", range: SIMD2<Float>(0, 1), value: elasticity, precision: Int(2))
                elasticityVar.titleShadows = true
                c1Node!.uiItems.append(elasticityVar)
            }
        }

        for uuid in comp.properties {
            let rc = comp.getPropertyOfUUID(uuid)
            if let frag = rc.0 {
                propMap[frag.name] = rc.1!
                let components = frag.evaluateComponents()
                let data = extractValueFromFragment(rc.1!)
                                
                if frag.name == "bump" {
                    continue
                }
                
                var isDisabled : Bool = false
                for t in comp.connections {
                    if t.key == uuid {
                        isDisabled = true
                    }
                }
                
                let supportsRandom : Bool = true
                
                var random : Float? = nil
                if supportsRandom {
                    random = rc.1!.values["random"] == nil ? 0 : rc.1!.values["random"]!
                }
                
                if components == 1 {
                    if rc.1!.fragmentType == .Primitive && rc.1!.name == "noise3D" {
                        propMap["noise3D"] = rc.1!
                        let noiseUI = setupNoise3DUI(c1Node!, rc.1!, title: comp.artistPropertyNames[uuid]!)
                        noiseUI.titleShadows = true
                        noiseUI.isDisabled = isDisabled
                        c1Node!.uiItems.append(noiseUI)
                    } else
                    if rc.1!.fragmentType == .Primitive && rc.1!.name == "noise2D" {
                        propMap["noise2D"] = rc.1!
                        let noiseUI = setupNoise2DUI(c1Node!, rc.1!, title: comp.artistPropertyNames[uuid]!)
                        noiseUI.titleShadows = true
                        noiseUI.isDisabled = isDisabled
                        c1Node!.uiItems.append(noiseUI)
                    } else {
                        let numberVar = NodeUINumber(c1Node!, variable: frag.name, title: comp.artistPropertyNames[uuid]!, range: SIMD2<Float>(rc.1!.values["min"]!, rc.1!.values["max"]!), int: frag.typeName == "int", value: data.x, precision: Int(rc.1!.values["precision"]!), valueRandom: random)
                        numberVar.titleShadows = true
                        numberVar.autoAdjustMargin = true
                        numberVar.isDisabled = isDisabled
                        c1Node!.uiItems.append(numberVar)
                    }
                } else
                if components == 2 {
                    var range : SIMD2<Float>? = nil

                    let fragment = rc.1!
                    if fragment.arguments.count == 2 && fragment.fragmentType == .ConstantDefinition {
                        range = SIMD2<Float>(fragment.arguments[0].fragments[0].values["min"]!, fragment.arguments[0].fragments[0].values["max"]!)
                    }
                    
                    let numberVar = NodeUINumber2(c1Node!, variable: frag.name, title: comp.artistPropertyNames[uuid]!, range: range, value: SIMD2<Float>(data.x, data.y), precision: Int(frag.values["precision"]!))
                    numberVar.titleShadows = true
                    numberVar.isDisabled = isDisabled
                    c1Node?.uiItems.append(numberVar)
                } else
                if components == 3 {
                    var range : SIMD2<Float>? = nil

                    if comp.properties.contains(frag.uuid) == true {
                        if let name = comp.propertyGizmoName[frag.uuid] {
                            if name == "Direction" {
                                range = SIMD2<Float>(-1,1)
                            }
                        }
                    }
                    
                    let numberVar = NodeUINumber3(c1Node!, variable: frag.name, title: comp.artistPropertyNames[uuid]!, range: range, value: SIMD3<Float>(data.x, data.y, data.z), precision: Int(frag.values["precision"]!))
                    numberVar.titleShadows = true
                    numberVar.isDisabled = isDisabled
                    c1Node?.uiItems.append(numberVar)
                } else
                if components == 4 {
                    if rc.1!.fragmentType == .Primitive && rc.1!.name == "image" {
                        propMap["image"] = rc.1!
                        let imageUI = setupImageUI(c1Node!, rc.1!, title: comp.artistPropertyNames[uuid]!)
                        imageUI.titleShadows = true
                        imageUI.isDisabled = isDisabled
                        c1Node!.uiItems.append(imageUI)
                    } else {
                        let colorItem = NodeUIColor(c1Node!, variable: frag.name, title: comp.artistPropertyNames[uuid]!, value: SIMD3<Float>(data.x, data.y, data.z), valueRandom: random)
                        colorItem.titleShadows = true
                        colorItem.isDisabled = isDisabled
                        c1Node?.uiItems.append(colorItem)
                    }
                }
            }
        }
        
        c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
            
            /*
            if variable == "physics" {
                comp.values[variable] = oldValue
                let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                comp.values[variable] = newValue
                self.setSelected(comp)
                globalApp!.artistEditor.designEditor.updateGizmo()
                if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
            }*/
            
            if variable == "restitution" || variable == "friction" || variable == "mass" || variable == "elasticity" {
                comp.values[variable] = oldValue
                let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                comp.values[variable] = newValue
                if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
            }
            
            if variable == "renderMode" {
                globalApp!.currentPipeline!.outputType = Pipeline.OutputType(rawValue: Int(newValue))!
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
                return
            }
            
            if variable.hasSuffix("Random") {
                if let frag = self.propMap[variable.replacingOccurrences(of: "Random", with: "")] {
                    frag.values["random"] = newValue
                } else {
                    comp.values[variable] = newValue
                }
                globalApp!.developerEditor.codeEditor.markComponentInvalid(comp)
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                return
            }
                        
            if variable.starts(with: "noise") || variable.starts(with: "image") {
                if let fragment = self.propMap["image"] {
                    fragment.values[variable] = oldValue
                    let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Image Changed") : nil
                    fragment.values[variable] = newValue
                    if variable == "imageIndex" {
                        //globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(comp)
                        self.editor.updateOnNextDraw(compile: true)
                    } else {
                        self.editor.updateOnNextDraw(compile: false)
                    }
                    if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                } else
                if let fragment = self.propMap["noise3D"] {
                    fragment.values[variable] = oldValue
                    let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Noise Changed") : nil
                    fragment.values[variable] = newValue
                    if variable == "noise3D" || variable == "noiseMix3D" {
                        globalApp!.developerEditor.codeEditor.markComponentInvalid(comp)
                        self.editor.updateOnNextDraw(compile: true)
                    } else {
                        self.editor.updateOnNextDraw(compile: false)
                    }
                    if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                } else
                if let fragment = self.propMap["noise2D"] {
                    fragment.values[variable] = oldValue
                    let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Noise Changed") : nil
                    fragment.values[variable] = newValue
                    if variable == "noise2D" || variable == "noiseMix2D" {
                        globalApp!.developerEditor.codeEditor.markComponentInvalid(comp)
                        self.editor.updateOnNextDraw(compile: true)
                    } else {
                        self.editor.updateOnNextDraw(compile: false)
                    }
                    if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                }
                return
            }
            
            if let frag = self.propMap[variable] {
                frag.values["value"] = oldValue
                let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                frag.values["value"] = newValue
                self.updatePreview()
                self.addKey([variable:newValue])
                if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
            }
        }
        
        c1Node?.float2ChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
            if let frag = self.propMap[variable] {
                insertValueToFragment2(frag, oldValue)
                let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                insertValueToFragment2(frag, newValue)
                self.updatePreview()
                var props : [String:Float] = [:]
                props[variable + "_x"] = newValue.x
                props[variable + "_y"] = newValue.y
                
                self.addKey(props)
                if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
            }
        }
        
        c1Node?.float3ChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
            
            if variable == "_bb" {
                comp.values["_bb_x"] = oldValue.x
                comp.values["_bb_y"] = oldValue.y
                comp.values["_bb_z"] = oldValue.z
                let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                comp.values["_bb_x"] = newValue.x
                comp.values["_bb_y"] = newValue.y
                comp.values["_bb_z"] = newValue.z
                self.updatePreview()
                var props : [String:Float] = [:]
                props[variable + "_x"] = newValue.x
                props[variable + "_y"] = newValue.y
                props[variable + "_z"] = newValue.z
                
                self.addKey(props)
                if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
                return
            }
            
            if let frag = self.propMap[variable] {
                insertValueToFragment3(frag, oldValue)
                let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                insertValueToFragment3(frag, newValue)
                self.updatePreview()
                var props : [String:Float] = [:]                
                props[variable + "_x"] = newValue.x
                props[variable + "_y"] = newValue.y
                props[variable + "_z"] = newValue.z
                
                self.addKey(props)
                if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
            }
        }
        
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
        
        needsUpdate = false
    }
    
    /// Update the properties when timeline is moving or playing
    func updateTransformedProperty(component: CodeComponent, name: String, data: SIMD4<Float>)
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
                    } else
                    if let number3 = item as? NodeUINumber3 {
                        number3.setValue(SIMD3<Float>(data.x, data.y, data.z))
                    } else
                    if let number2 = item as? NodeUINumber2 {
                        number2.setValue(SIMD2<Float>(data.x, data.y))
                    }
                } else
                if item.variable.starts(with: name) {
                    // Update the invidual elements
                    if let number = item as? NodeUINumber {
                        if item.variable.hasSuffix("_x") {
                            number.setValue(data.x)
                        } else
                        if item.variable.hasSuffix("_y") {
                            number.setValue(data.y)
                        } else
                        if item.variable.hasSuffix("_z") {
                            number.setValue(data.z)
                        }
                    }
                }
            }
        }
        
        if let node = c1Node, component === selected {
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
        
        #if os(OSX)
        if hoverUIRandom != nil {
            hoverUIRandom?.randomClicked()
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
        if hoverUIRandom != nil {
            hoverUIRandom?.randomClicked()
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
        
        if hoverUIRandom != nil {
            hoverUIRandom?.randomHover = false
            hoverUIRandom = nil
            mmView.update()
        }
        
        let oldHoverMode = hoverMode
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverUIRandom = nil
        hoverMode = .None
                
        func checkNodeUI(_ node: Node)
        {
            // --- Look for NodeUI item under the mouse, master has no UI
            var uiItemX = rect.x + node.rect.x
            var uiItemY = rect.y + node.rect.y
            let uiRect = MMRect()
            
            for uiItem in node.uiItems {
                
                if uiItemY + uiItem.rect.height > rect.bottom() {
                    uiItemX += node.uiArea.width
                    uiItemY = rect.y + node.rect.y
                }
                
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
                
                if uiItem.supportsRandom && uiItem.randomLabel != nil {
                    uiRect.x = uiItem.randomLabel!.rect.x - 2
                    uiRect.y = uiItem.randomLabel!.rect.y - 2
                    uiRect.width = uiItem.randomLabel!.rect.width + 4
                    uiRect.height = uiItem.randomLabel!.rect.height + 6
                    
                    if uiRect.contains(event.x, event.y) {
                        uiItem.randomHover = true
                        hoverUIRandom = uiItem
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
            
            var uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                
                if uiItemY + uiItem.rect.height > rect.bottom() {
                    uiItemX += node.uiArea.width
                    uiItemY = rect.y + node.rect.y
                }
                
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
        
        if let node = c2Node {
            
            node.rect.x = rect.right() - node.uiArea.width - 10
            
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
