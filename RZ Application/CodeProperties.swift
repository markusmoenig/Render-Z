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

    var editor              : DeveloperEditor!
    
    var c1Node              : Node? = nil
    var c2Node              : Node? = nil
    var c3Node              : Node? = nil

    var hoverUIItem         : NodeUI? = nil
    var hoverUITitle        : NodeUI? = nil
    
    var nodeUIMonitor       : NodeUIMonitor? = nil

    var buttons             : [MMButtonWidget] = []
    var smallButtonSkin     : MMSkinButton
    var buttonWidth         : Float = 190
    
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
        c3Node = nil

        deregisterButtons()
    }
    
    func setSelected(_ comp: CodeComponent,_ ctx: CodeContext)
    {
        c1Node = nil
        c2Node = nil
        c3Node = nil
        
        deregisterButtons()
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 200
        c2Node?.rect.y = 10
        
        c3Node = Node()
        c3Node?.rect.x = 400
        c3Node?.rect.y = 10
        
        nodeUIMonitor = nil
        globalApp!.pipeline.monitorInstance = nil
        globalApp!.pipeline.monitorComponent = nil
        globalApp!.pipeline.monitorFragment = nil

        if let function = ctx.selectedFunction {
            
            c1Node?.uiItems.append( NodeUIText(c1Node!, variable: "comment", title: "Code Comment", value: function.comment) )
            c1Node?.textChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "comment" {
                    function.comment = oldValue
                    let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Comment Changed") : nil
                    function.comment = newValue
                    self.editor.updateOnNextDraw()
                    self.needsUpdate = true
                    if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                }
            }
            
            //if function.functionType != .FreeFlow {
            
            let libraryName = function.functionType == .FreeFlow ? function.libraryName : comp.libraryName
            let libraryComment = function.functionType == .FreeFlow ? function.libraryComment : comp.libraryComment
            let libraryCategory = function.functionType == .FreeFlow ? function.libraryCategory : comp.libraryCategory

            c2Node?.uiItems.append( NodeUIText(c2Node!, variable: "libraryName", title: "Library Name", value: libraryName) )
            c2Node?.uiItems.append( NodeUIText(c2Node!, variable: "libraryComment", title: "Comment", value: libraryComment) )
    
            let items : [String] = ["Hash", "Noise"]
            c2Node?.uiItems.append( NodeUISelector(c2Node!, variable: "libraryCategory", title: "Category", items: items, index: Float(items.firstIndex(of: libraryCategory)!) ) )
        
            c2Node?.uiItems[2].isDisabled = function.functionType != .FreeFlow
                
            c2Node?.textChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "libraryName" {
                    if function.functionType == .FreeFlow {
                        function.libraryName = newValue
                    } else {
                        comp.libraryName = newValue
                    }
                } else
                if variable == "libraryComment" {
                    if function.functionType == .FreeFlow {
                        function.libraryComment = newValue
                    } else {
                        comp.libraryComment = newValue
                    }
                }
            }
            
            c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "libraryCategory" {
                    if function.functionType == .FreeFlow {
                        function.libraryCategory = items[Int(newValue)]
                    } else {
                        comp.libraryCategory = items[Int(newValue)]
                    }
                }
            }
            
            var b1 = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Add to Private Library", fixedWidth: buttonWidth)
            b1.clicked = { (event) in
                uploadToLibrary(comp, true, function.functionType == .FreeFlow ? function : nil)
                b1.removeState(.Checked)
            }
            addButton(b1)
            
            var b2 = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Add to Public", fixedWidth: buttonWidth)
            b2.clicked = { (event) in
                uploadToLibrary(comp, false, function.functionType == .FreeFlow ? function : nil)
                b2.removeState(.Checked)
            }
            addButton(b2)
            //}
        } else
        if let block = ctx.selectedBlock {
            if let function = ctx.cFunction {
                let b1 = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Add Empty Line", fixedWidth: buttonWidth)
                b1.clicked = { (event) in
                    let undo = self.editor.codeEditor.undoStart("Add Line")
                    let newBlock = CodeBlock(.Empty)
                    newBlock.fragment.addProperty(.Selectable)

                    if let pF = block.parentFunction {
                        if let index = pF.body.firstIndex(of: block) {
                            pF.body.insert(newBlock, at: index)
                        }
                    } else
                    if let pB = block.parentBlock {
                        if let index = pB.children.firstIndex(of: block) {
                            pB.children.insert(newBlock, at: index)
                        }
                    }
                    
                    self.editor.updateOnNextDraw()
                    self.needsUpdate = true
                    self.editor.codeEditor.undoEnd(undo)
                
                    b1.removeState(.Checked)
                }
                addButton(b1)
                
                let b2 = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete Content", fixedWidth: buttonWidth)
                b2.clicked = { (event) in
                    let undo = self.editor.codeEditor.undoStart("Delete Content")
                    block.blockType = .Empty
                    block.uuid = UUID()
                    block.fragment.fragmentType = .Undefined
                    block.fragment.arguments = []
                    block.fragment.name = ""
                    block.fragment.qualifier = ""
                    block.fragment.properties = [.Selectable]
                    block.statement = CodeStatement(.Arithmetic)
                    block.children = []

                    self.editor.updateOnNextDraw()
                    self.needsUpdate = true
                    self.clear()
                    self.editor.codeEditor.undoEnd(undo)
                    b2.removeState(.Checked)
                }
                b2.isDisabled = /*block.blockType == .OutVariable ||*/ block.blockType == .Empty || block.blockType == .End
                addButton(b2)
                
                let b3 = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete Line", fixedWidth: buttonWidth)
                b3.clicked = { (event) in

                    let undo = self.editor.codeEditor.undoStart("Delete Line")
                    
                    if let pF = block.parentFunction {
                        if let index = pF.body.firstIndex(of: block) {
                            pF.body.remove(at: index)
                            if index < pF.body.count && pF.body[index].blockType == .ElseHeader {
                                pF.body.remove(at: index)
                            }
                        }
                    } else
                    if let pB = block.parentBlock {
                        if let index = pB.children.firstIndex(of: block) {
                            pB.children.remove(at: index)
                            if index < pB.children.count && pB.children[index].blockType == .ElseHeader {
                                pB.children.remove(at: index)
                            }
                        }
                    }
                    
                    self.editor.updateOnNextDraw()
                    self.needsUpdate = true
                    self.clear()
                    self.editor.codeEditor.undoEnd(undo)

                    b3.removeState(.Checked)
                }
                b3.isDisabled = block.blockType == .End
                addButton(b3)
            }
            
            c1Node?.uiItems.append( NodeUIText(c1Node!, variable: "comment", title: "Comment", value: block.comment) )
            c1Node?.textChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "comment" {
                    block.comment = oldValue
                    let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Comment Changed") : nil
                    block.comment = newValue
                    self.needsUpdate = true
                    self.editor.updateOnNextDraw()
                    if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                }
            }
        }
        
        if let fragment = ctx.selectedFragment {
            
            // --- FreeFlow Function Header
            
            if fragment.fragmentType == .TypeDefinition {
                // Function Parameter and name
                if fragment.parentBlock!.fragment === fragment {
                
                    c1Node?.uiItems.append( NodeUIText(c1Node!, variable: "name", title: "Function Name", value: fragment.name) )
                    c1Node?.uiItems[0].isDisabled = fragment.parentBlock!.parentFunction!.functionType == .Prototype
                    c1Node?.textChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == "name" {
                            let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Function Name Changed") : nil
                            fragment.name = newValue
                            fragment.parentBlock!.parentFunction!.name = newValue
                            self.editor.updateOnNextDraw()
                            if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                        }
                    }
                    
                    let items : [String] = ["int", "uint", "float", "float2", "float3", "float4"]
                    c2Node?.uiItems.append( NodeUISelector(c2Node!, variable: "returnType", title: "Returns", items: items, index: Float(items.firstIndex(of: fragment.typeName)!) ) )
                    
                    let cFunction = fragment.parentBlock!.parentFunction!
                    c2Node?.uiItems[0].isDisabled = cFunction.references > 0 || fragment.parentBlock!.parentFunction!.functionType == .Prototype
                    
                    c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == "returnType" {

                            let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Return Type Changed") : nil
                            fragment.typeName = items[Int(newValue)]
                            cFunction.body[cFunction.body.count-1].statement.fragments = [defaultConstantForType(fragment.typeName)]
                            
                            self.editor.updateOnNextDraw()
                            if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                        }
                    }
                }
            } else
            // --- For loop variable definition
            if fragment.fragmentType == .VariableDefinition && fragment.parentBlock != nil && fragment.parentBlock!.blockType == .ForHeader {
                let items : [String] = ["int", "uint", "float"]
                c1Node?.uiItems.append( NodeUISelector(c1Node!, variable: "type", title: "Type", items: items, index: Float(items.firstIndex(of: fragment.typeName)!) ) )
                                
                c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "type" {

                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Type Changed") : nil
                        fragment.typeName = items[Int(newValue)]
                        if fragment.typeName == "float" {
                            fragment.values["precision"] = 3
                            for stats in fragment.parentBlock!.fragment.arguments {
                                for frag in stats.fragments {
                                    if frag.fragmentType == .ConstantValue {
                                        frag.typeName = "float"
                                        frag.values["precision"] = 3
                                    }
                                }
                            }
                        } else {
                            fragment.values["precision"] = 0
                            for stats in fragment.parentBlock!.fragment.arguments {
                                for frag in stats.fragments {
                                    if frag.fragmentType == .ConstantValue {
                                        frag.typeName = "int"
                                        frag.values["precision"] = 0
                                    }
                                }
                            }
                        }
                        self.editor.updateOnNextDraw(compile: true)
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    }
                }
            } else
            // --- FreeFlow argument
            if fragment.fragmentType == .VariableDefinition && fragment.parentBlock!.parentFunction != nil && fragment.parentBlock!.parentFunction!.functionType == .FreeFlow && fragment.parentBlock!.parentFunction!.header.statement.fragments.contains(fragment) {

                c1Node?.uiItems.append( NodeUIText(c1Node!, variable: "name", title: "Argument Name", value: fragment.name) )
                c1Node?.textChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "name" {
                        fragment.name = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Argument Name Changed") : nil
                        fragment.name = newValue
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    }
                }
                
                let items : [String] = ["int", "uint", "float", "float2", "float3", "float4"]
                c2Node?.uiItems.append( NodeUISelector(c2Node!, variable: "argumentType", title: "Argument Type", items: items, index: Float(items.firstIndex(of: fragment.typeName)!) ) )
                
                let cFunction = fragment.parentBlock!.parentFunction!
                c2Node?.uiItems[0].isDisabled = cFunction.references > 0 || fragment.references > 0
                
                c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "argumentType" {

                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Argument Type Changed") : nil
                        fragment.typeName = items[Int(newValue)]
                        
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    }
                }
                
                let b1 = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete Argument", fixedWidth: buttonWidth)
                b1.isDisabled = cFunction.references > 0 || fragment.references > 0
                b1.clicked = { (event) in
                    let pBlock = fragment.parentBlock!
                    if let pIndex = pBlock.statement.fragments.firstIndex(of: fragment) {
                        let undo = self.editor.codeEditor.undoStart("Deletes Function Argument")
                        pBlock.statement.fragments.remove(at: pIndex)
                        self.editor.updateOnNextDraw(compile: true)
                        self.editor.codeEditor.undoEnd(undo)
                        b1.removeState(.Checked)
                    }
                }
                addButton(b1)
            } else
            // --- Constant Value == Float
            if fragment.fragmentType == .ConstantValue || (fragment.fragmentType == .ConstantDefinition && fragment.isSimplified == true) {
                
                let numberVar = NodeUINumber(c1Node!, variable: "value", title: "Value", range: SIMD2<Float>(fragment.values["min"]!, fragment.values["max"]!), value: fragment.values["value"]!, precision: Int(fragment.values["precision"]!))
                c1Node?.uiItems.append(numberVar)
                c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "value" {
                        fragment.values["value"] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Float Value Changed") : nil
                        fragment.values["value"] = newValue
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    }
                }
                
                if fragment.getBaseType(fragment.typeName) == "float" {
                    c2Node?.uiItems.append( NodeUINumber(c2Node!, variable: "min", title: "Minimum", range: nil, value: fragment.values["min"]!) )
                    c2Node?.uiItems.append( NodeUINumber(c2Node!, variable: "max", title: "Maximum", range: nil, value: fragment.values["max"]!) )
                    c2Node?.uiItems.append( NodeUINumber(c2Node!, variable: "precision", title: "Precision", range: SIMD2<Float>(1,10), int: true, value: fragment.values["precision"]!) )
                } else {
                    c2Node?.uiItems.append( NodeUINumber(c2Node!, variable: "min", title: "Minimum", range: nil, value: fragment.values["min"]!, precision: 0))
                    c2Node?.uiItems.append( NodeUINumber(c2Node!, variable: "max", title: "Maximum", range: nil, value: fragment.values["max"]!, precision: 0))
                }
                c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "min" {
                        fragment.values["min"] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Minimum Changed") : nil
                        fragment.values["min"] = newValue
                        numberVar.range!.x = newValue
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    } else
                    if variable == "max" {
                        fragment.values["max"] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Maximum Changed") : nil
                        fragment.values["max"] = newValue
                        numberVar.range!.y = newValue
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    } else
                    if variable == "precision" {
                        fragment.values["precision"] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Precision Changed") : nil
                        fragment.values["precision"] = newValue
                        numberVar.precision = Int(newValue)
                        numberVar.contentValue = nil
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    }
                }
                
            } else
            // --- Constant Definition (float3) etc
            if fragment.fragmentType == .ConstantDefinition && fragment.isSimplified == false {
                
                if fragment.typeName == "float4" || fragment.typeName == "float3" {
                    c1Node?.uiItems.append( NodeUIColor(c1Node!, variable: "color", title: "Color", value: SIMD3<Float>(fragment.arguments[0].fragments[0].values["value"]!, fragment.arguments[1].fragments[0].values["value"]!, fragment.arguments[2].fragments[0].values["value"]!)))
                    if fragment.typeName == "float4" {
                        c2Node?.uiItems.append( NodeUINumber(c2Node!, variable: "alpha", title: "Alpha", range: SIMD2<Float>(0,1), value: fragment.arguments[3].fragments[0].values["value"]!) )
                        c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                            if variable == "alpha" {
                                fragment.arguments[3].fragments[0].values["value"] = oldValue
                                let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Alpha Value Changed") : nil
                                fragment.arguments[3].fragments[0].values["value"] = newValue
                                self.editor.updateOnNextDraw()
                                if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                            }
                        }
                    }
                    c1Node?.float3ChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                        if variable == "color" {
                            fragment.arguments[0].fragments[0].values["value"] = oldValue.x
                            fragment.arguments[1].fragments[0].values["value"] = oldValue.y
                            fragment.arguments[2].fragments[0].values["value"] = oldValue.z
                            let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Color Value Changed") : nil
                            fragment.arguments[0].fragments[0].values["value"] = newValue.x
                            fragment.arguments[1].fragments[0].values["value"] = newValue.y
                            fragment.arguments[2].fragments[0].values["value"] = newValue.z
                            self.editor.updateOnNextDraw()
                            if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                        }
                    }
                }
            } else
            // --- Variable Definition
            if fragment.fragmentType == .VariableDefinition && fragment.supports(.NotCodeable) == false {
                
                let comp = ctx.cComponent!
                
                c1Node?.uiItems.append( NodeUIText(c1Node!, variable: "name", title: "Variable Name", value: fragment.name) )
                let artistNameUI = NodeUIText(c1Node!, variable: "artistName", title: "Artist Name", value: comp.artistPropertyNames[fragment.uuid] == nil ? "" : comp.artistPropertyNames[fragment.uuid]!)
                c1Node?.uiItems.append( artistNameUI )
                
                c2Node?.uiItems.append( NodeUISelector(c2Node!, variable: "expose", title: "Expose to Artist", items: ["No", "Yes"], index: comp.properties.firstIndex(of: fragment.uuid) == nil ? 0 : 1 ) )
                c1Node?.uiItems[1].isDisabled = comp.properties.firstIndex(of: fragment.uuid) == nil
                
                var mapIndex : Float = 0
                if let mapping = comp.propertyGizmoMap[fragment.uuid] {
                    mapIndex = Float(mapping.rawValue)
                }
                
                let gizmoItems = comp.componentType == .SDF2D ? ["No", "Scale (All)", "Scale X", "Scale Y"] : ["No", "Scale (All)", "Scale X", "Scale Y", "Scale Z"]
                
                let gizmoMappingUI = NodeUISelector(c2Node!, variable: "gizmoMap", title: "Gizmo", items: gizmoItems, index: mapIndex )
                gizmoMappingUI.isDisabled = comp.properties.firstIndex(of: fragment.uuid) == nil
                c2Node?.uiItems.append( gizmoMappingUI )

                c1Node?.textChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "name" {
                        fragment.name = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Variable Name Changed") : nil
                        fragment.name = newValue
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    } else
                    if variable == "artistName" {
                        comp.artistPropertyNames[fragment.uuid] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Artist Name Changed") : nil
                        comp.artistPropertyNames[fragment.uuid] = newValue
                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    }
                }
                
                c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "expose" {
                        let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Expose Variable Changed") : nil
                        if newValue == 0 {
                            comp.properties.removeAll { $0 == fragment.uuid }
                        } else {
                            comp.properties.append(fragment.uuid)
                            if comp.artistPropertyNames[fragment.uuid] == nil {
                                artistNameUI.value = fragment.name
                                comp.artistPropertyNames[fragment.uuid] = fragment.name
                            }
                        }
                        self.c1Node?.uiItems[1].isDisabled = comp.properties.firstIndex(of: fragment.uuid) == nil

                        self.editor.updateOnNextDraw()
                        if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                    } else
                    if variable == "gizmoMap" {
                        comp.propertyGizmoMap[fragment.uuid] = CodeComponent.PropertyGizmoMapping(rawValue: Int(newValue))
                    }
                }
                
                nodeUIMonitor = NodeUIMonitor(c3Node!, variable: "monitor", title: "Variable Monitor")
                c3Node!.uiItems.append(nodeUIMonitor!)
                
            } else
            // --- Variable Reference
            if fragment.fragmentType == .VariableReference || fragment.fragmentType == .OutVariable || fragment.fragmentType == .Primitive {
                let textVar = NodeUIText(c1Node!, variable: "qualifier", title: "Qualifier", value: fragment.qualifier)
                textVar.isDisabled = fragment.evaluateComponents(ignoreQualifiers: true) == 1
                c1Node?.uiItems.append(textVar)
                c1Node?.textChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    if variable == "qualifier" {
                        var newValueToUse = newValue
                        // Remove possible "."
                        if newValueToUse.starts(with: ".") {
                            newValueToUse.remove(at: fragment.qualifier.startIndex)
                        }
                        
                        // TODO Max Components needs to be the maximum components for the destination expression, how to compute ?
                        fragment.qualifier = ""
                        var maxComponents = fragment.evaluateComponents()
                        
                        fragment.qualifier = oldValue
                        let fragComponents = fragment.evaluateComponents()
                        maxComponents = max(maxComponents, fragComponents)
                        
                        var validComponents = fragComponents
                        let qArray = ["x", "y", "z", "w"]
                        
                        var newQualifiersAreValid : Bool = true
                        
                        for q in newValueToUse {
                            if let qIndex = qArray.firstIndex(of: String(q)) {
                                if qIndex >= maxComponents {
                                    // Correct character but out of bounce
                                    newQualifiersAreValid = false
                                }
                            } else {
                                // not in the array, invalid
                                newQualifiersAreValid = false
                            }
                        }
                        if newValueToUse.count > maxComponents {
                            // Too many chars, invalid
                            newQualifiersAreValid = false
                        }

                        if let block = fragment.parentBlock, newQualifiersAreValid {
                            if (block.blockType == .VariableReference || block.blockType == .OutVariable) && block.fragment === fragment {
                                
                                // We change the qualifier on the left side, allow any value as the right side will be reset anyway
                                
                                // But we need to check if the new qualifier has duplicate components
                                var hasDuplicates = false
                                
                                if newValueToUse.count(of: "x") > 1 || newValueToUse.count(of: "y") > 1 || newValueToUse.count(of: "z") > 1 ||
                                    newValueToUse.count(of: "w") > 1 {
                                    hasDuplicates = true
                                }
                                
                                if hasDuplicates == false {
                                    let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Variable Qualifier Changed") : nil
                                    fragment.qualifier = newValueToUse
                                    textVar.value = newValueToUse
                                    
                                    // Reset right side
                                    let constant = defaultConstantForType(fragment.evaluateType())
                                    block.statement.fragments = [constant]
                                    
                                    if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                                    self.editor.updateOnNextDraw()
                                } else {
                                    textVar.value = oldValue
                                }
                            } else {
                                // We are on the right side, either have the same or 1 component
                                if (newValueToUse.count == validComponents || newValueToUse.count == 1) {
                                    // If on the right side, allow when same component count or 1 (float always works)
                                    
                                    let codeUndo : CodeUndoComponent? = continous == false ? self.editor.codeEditor.undoStart("Variable Qualifier Changed") : nil
                                    fragment.qualifier = newValueToUse
                                    textVar.value = newValueToUse
                                    
                                    if let undo = codeUndo { self.editor.codeEditor.undoEnd(undo) }
                                    self.editor.updateOnNextDraw()
                                } else {
                                    textVar.value = oldValue
                                }
                            }
                        } else {
                            textVar.value = oldValue
                        }
                    }
                }
            }
            
            // --- Reset to Const button for primitives and variable references
            if fragment.fragmentType == .Primitive || fragment.fragmentType == .VariableReference {
                let b = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Reset to Const", fixedWidth: buttonWidth)
                b.clicked = { (event) in
                    let undo = self.editor.codeEditor.undoStart("Reset")

                    let constant = defaultConstantForType(fragment.evaluateType())
                    constant.copyTo(fragment)

                    self.needsUpdate = true
                    self.editor.updateOnNextDraw()
                    self.editor.codeEditor.undoEnd(undo)
                    
                    b.removeState(.Checked)
                }
                addButton(b)
            }
            
            // Delete, only if parent statement has enough content
            if let pStatement = fragment.parentStatement, fragment.parentBlock != nil && fragment.parentBlock!.blockType != .ForHeader {
                
                var canDelete : Bool = false
                var contentCount : Int = 0
                for f in pStatement.fragments {
                    if f.fragmentType != .Arithmetic && f.fragmentType != .OpeningRoundBracket && f.fragmentType != .ClosingRoundBracket {
                    contentCount += 1
                    }
                }
                    
                var type : Int = -1
                if fragment.fragmentType != .Arithmetic && fragment.fragmentType != .OpeningRoundBracket && fragment.fragmentType != .ClosingRoundBracket && contentCount > 1 {
                    canDelete = true
                    type = 0
                } else
                if fragment.fragmentType == .OpeningRoundBracket || fragment.fragmentType == .ClosingRoundBracket {
                    canDelete = true
                    type = 1
                }

                let b = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete", fixedWidth: buttonWidth)
                b.clicked = { (event) in
                    let undo = self.editor.codeEditor.undoStart("Delete")

                    // Delete the brackets of the given uuid
                    func deleteBrackets(_ uuid: UUID)
                    {
                        for (index, f) in pStatement.fragments.enumerated() {
                            if f.uuid == uuid {
                                pStatement.fragments.remove(at: index)
                                break
                            }
                        }
                        for (index, f) in pStatement.fragments.enumerated() {
                            if f.uuid == uuid {
                                pStatement.fragments.remove(at: index)
                                break
                            }
                        }
                    }
                    
                    if type == 0 {
                        // Value

                        // First step check if there are brackets around the fragment and if yes, recursively delete them
                        var index = pStatement.fragments.firstIndex(of: fragment)!
                        while index > 0 && pStatement.fragments[index-1].fragmentType == .OpeningRoundBracket && pStatement.fragments[index+1].fragmentType == .ClosingRoundBracket {
                            deleteBrackets(pStatement.fragments[index-1].uuid)
                            index = pStatement.fragments.firstIndex(of: fragment)!
                        }

                        // Delete the value plus its arithmetic operator
                        if let index = pStatement.fragments.firstIndex(of: fragment) {
                            
                            if index == 0 || pStatement.fragments[index-1].fragmentType == .OpeningRoundBracket {
                                // Case of ( 1.00 + ...
                                pStatement.fragments.remove(at: index)
                                pStatement.fragments.remove(at: index)
                            } else {
                                pStatement.fragments.remove(at: index-1)
                                pStatement.fragments.remove(at: index-1)
                            }
                        }
                    } else
                    if type == 1 {
                        // Delete Brackets
                        deleteBrackets(fragment.uuid)
                    }

                    ctx.selectedFragment = nil
                    comp.selected = nil
                    
                    self.needsUpdate = true
                    self.editor.updateOnNextDraw()
                    self.editor.codeEditor.undoEnd(undo)
                    
                    b.removeState(.Checked)
                }
                b.isDisabled = !canDelete
                addButton(b)
            }

            // Setup the monitor
            if fragment.supports(.Monitorable) && fragment.fragmentType != .VariableReference {
                //setupMonitorData(comp, fragment, ctx)                
                if nodeUIMonitor == nil {
                    nodeUIMonitor = NodeUIMonitor(c2Node!, variable: "monitor", title: "Variable Monitor")
                    c2Node!.uiItems.append(nodeUIMonitor!)
                }
                
                globalApp!.pipeline.monitorComponent = comp
                globalApp!.pipeline.monitorFragment = fragment
            }
        }
        
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
        
        if let node = c3Node, hoverMode == .None {
            checkNodeUI(node)
        }
        
        if oldHoverMode != hoverMode {
            mmView.update()
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
        
        if let node = c3Node {
            
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
