//
//  CodeAccess.swift
//  Render-Z
//
//  Created by Markus Moenig on 08/01/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class AccessButton
{
    var name        : String
    var rect        : MMRect = MMRect()
    var isLeft      : Bool = false
    
    var label       : MMTextLabel
    
    init(_ view: MMView,_ font: MMFont,_ name: String,_ fontScale: Float = 0.5)
    {
        label = MMTextLabel(view, font: font, text: name, scale: fontScale, color: view.skin.Widget.textColor)
        self.name = name
    }
}

class CodeAccess            : MMWidget
{
    enum AccessState {
        case Closed, Arithmetic, ArithmeticOperator, AssignmentOperator, ComparisonOperator, FreeFlowFunctionArgument
    }
    
    var accessState             : AccessState = .Closed

    var codeEditor              : CodeEditor
    
    var leftButtons             : [AccessButton] = []
    var rightButtons            : [AccessButton] = []
    var middleButtons           : [AccessButton] = []

    var font                    : MMFont
    var fontScale               : Float = 0.5
    var maxButtonSize           : Float = 0
    
    var hoverButton             : AccessButton? = nil
    var selectedButton          : AccessButton? = nil
    
    let arithmetics             : [String] = ["+", "-", "*", "/"]
    let assignments             : [String] = ["=", "+=", "-=", "*=", "/="]
    let comparisons             : [String] = ["==", "!=", "<", ">", "<=", ">="]
    let freeFlowArguments       : [String] = ["int", "float", "float2", "float3", "float4"]

    init(_ view: MMView,_ codeEditor: CodeEditor)
    {
        self.codeEditor = codeEditor
        font = view.sourceCodePro
        fontScale = 0.5
        
        super.init(view)

        rect.height = 26
    }
    
    /// Clears the buttons
    func clear()
    {
        leftButtons = []
        rightButtons = []
        middleButtons = []
    }
    
    func setSelected(_ comp: CodeComponent,_ ctx: CodeContext)
    {
        accessState = .Closed
        maxButtonSize = 0
        clear()
        
        func addButtonBothSides(_ name: String) {
            let b = AccessButton(mmView, mmView.sourceCodePro, name)
            if b.label.rect.width > maxButtonSize {
                maxButtonSize = b.label.rect.width
            }
            leftButtons.append(b)
            rightButtons.append(AccessButton(mmView, mmView.sourceCodePro, name))
        }
        
        func addOpenSansButtonBothSides(_ name: String) {
            let b = AccessButton(mmView, mmView.openSans, name, 0.4)
            if b.label.rect.width > maxButtonSize {
                maxButtonSize = b.label.rect.width
            }
            leftButtons.append(b)
            rightButtons.append(AccessButton(mmView, mmView.openSans, name, 0.4))
        }
        
        func addLeftButton(_ name: String) {
            let b = AccessButton(mmView, mmView.sourceCodePro, name)
            if b.label.rect.width > maxButtonSize {
                maxButtonSize = b.label.rect.width
            }
            leftButtons.append(b)
        }
        
        func addRightButton(_ name: String) {
            let b = AccessButton(mmView, mmView.sourceCodePro, name)
            if b.label.rect.width > maxButtonSize {
                maxButtonSize = b.label.rect.width
            }
            rightButtons.append(b)
        }
        
        if let fragment = ctx.selectedFragment {
            
            // --- FreeFlow argument
            if fragment.fragmentType == .VariableDefinition && fragment.parentBlock!.parentFunction != nil && fragment.parentBlock!.parentFunction!.functionType == .FreeFlow {
                accessState = .FreeFlowFunctionArgument
                
                let cFunction = fragment.parentBlock!.parentFunction!
                if cFunction.references == 0 && fragment.references == 0 {
                    for a in freeFlowArguments {
                        addOpenSansButtonBothSides(a)
                    }
                }
            } else
            if fragment.fragmentType == .ConstantDefinition || fragment.fragmentType == .ConstantValue || fragment.fragmentType == .Primitive || (fragment.fragmentType == .VariableReference && fragment.parentStatement != nil) || fragment.fragmentType == .OpeningRoundBracket || fragment.fragmentType == .ClosingRoundBracket  {
                accessState = .Arithmetic
                
                for a in arithmetics {
                    addButtonBothSides(a)
                }
                if fragment.fragmentType != .OpeningRoundBracket && fragment.fragmentType != .ClosingRoundBracket {
                    addLeftButton("(")
                    addRightButton(")")
                }
                
                if fragment.fragmentType == .ConstantValue || fragment.fragmentType == .ConstantDefinition || fragment.fragmentType == .VariableReference || fragment.fragmentType == .Primitive {
                    middleButtons.append(AccessButton(mmView, mmView.openSans, "Negate", 0.4))
                }

                if fragment.fragmentType == .ConstantDefinition && fragment.typeName != "float" {
                    if fragment.isSimplified == true {
                        middleButtons.append(AccessButton(mmView, mmView.openSans, "Expand", 0.4))
                    } else {
                        middleButtons.append(AccessButton(mmView, mmView.openSans, "Shorten", 0.4))
                    }
                }
            } else
            if fragment.fragmentType == .Arithmetic {
                accessState = .ArithmeticOperator
                
                for a in arithmetics {
                    addLeftButton(a)
                }
            } else
            if fragment.fragmentType == .Assignment {
                accessState = .AssignmentOperator
                
                for a in assignments {
                    addLeftButton(a)
                }
            } else
            if fragment.fragmentType == .Comparison {
                accessState = .ComparisonOperator
                
                for a in comparisons {
                    addLeftButton(a)
                }
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif
        if let button = hoverButton {
            selectedButton = hoverButton
            perform(button)
            mmView.update()
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if selectedButton != nil {
            selectedButton = nil
            mmView.update()
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        let oldHoverButton = hoverButton
        hoverButton = nil
        for b in leftButtons {
            if b.rect.contains(event.x, event.y) {
                hoverButton = b
                b.isLeft = true
                break
            }
        }
        for b in middleButtons {
            if b.rect.contains(event.x, event.y) {
                hoverButton = b
                b.isLeft = false
                break
            }
        }
        for b in rightButtons {
            if b.rect.contains(event.x, event.y) {
                hoverButton = b
                b.isLeft = false
                break
            }
        }
        
        if oldHoverButton !== hoverButton {
            mmView.update()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 0.5) )
        
        let lineHeight = font.getLineHeight(fontScale)

        var cX : Float = rect.x + 4
        let cY : Float = rect.y + 2
        
        let tempRect = MMRect()
        
        let bWidth = max(maxButtonSize, lineHeight)
        
        for b in leftButtons {
            b.rect.x = cX
            b.rect.y = cY
            b.rect.width = bWidth
            b.rect.height = lineHeight
            
            b.label.rect.x = cX + (bWidth - b.label.rect.width)/2
            b.label.rect.y = cY
            b.label.draw()

            if hoverButton === b || selectedButton === b {
                let alpha : Float = selectedButton === b ? 0.7 : 0.5
                mmView.drawBox.draw( x: b.rect.x, y: b.rect.y, width: b.rect.width, height: b.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
            }
            
            cX += bWidth + 6
        }
        
        cX = rect.x + rect.width - 4 - bWidth
        for b in rightButtons {
            b.rect.x = cX
            b.rect.y = cY
            b.rect.width = bWidth
            b.rect.height = lineHeight
            
            b.label.rect.x = cX + (bWidth - b.label.rect.width)/2
            b.label.rect.y = cY
            b.label.draw()
            
            if hoverButton === b || selectedButton === b {
                let alpha : Float = selectedButton === b ? 0.7 : 0.5
                mmView.drawBox.draw( x: b.rect.x, y: b.rect.y, width: b.rect.width, height: b.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
            }
            
            cX -= bWidth + 6
        }
        
        var totalWidth : Float = 0
        for b in middleButtons {
            totalWidth += b.label.rect.width + 4
        }
        totalWidth -= 4
        cX = rect.x + (rect.width - totalWidth) / 2
        
        for b in middleButtons {
            
            let width : Float = b.label.rect.width + 10

            b.rect.x = cX
            b.rect.y = cY + 2
            b.rect.width = width
            b.rect.height = lineHeight
            
            b.label.rect.x = cX + (lineHeight - tempRect.width)/2
            b.label.rect.y = cY + 2
            b.label.draw()
            
            if hoverButton === b || selectedButton === b {
                let alpha : Float = selectedButton === b ? 0.7 : 0.5
                mmView.drawBox.draw( x: b.rect.x, y: b.rect.y - 1, width: b.rect.width, height: b.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
            }
            cX += width + 4
        }
    }
    
    /// Execute the selected button for the given state
    func perform(_ button: AccessButton)
    {
        if accessState == .Arithmetic {

            if let frag = codeEditor.codeContext.selectedFragment {
                
                if button.name == "Negate" {
                    let undo = codeEditor.undoStart("Negate")

                    frag.setNegated(!frag.isNegated())
                    codeEditor.editor.codeProperties.needsUpdate = true
                    codeEditor.updateCode(compile: true)
                    codeEditor.undoEnd(undo)
                    return
                } else
                if button.name == "Shorten" {
                    let undo = codeEditor.undoStart("Shorten Constant")

                    frag.isSimplified = true
                    codeEditor.editor.codeProperties.needsUpdate = true
                    codeEditor.updateCode(compile: true)
                    codeEditor.undoEnd(undo)
                    return
                } else
                if button.name == "Expand" {
                    let undo = codeEditor.undoStart("Expand Constant")

                    frag.isSimplified = false
                    codeEditor.editor.codeProperties.needsUpdate = true
                    codeEditor.updateCode(compile: true)
                    codeEditor.undoEnd(undo)
                    return
                }
                
                let pStatement = frag.parentStatement!
                if let pIndex = pStatement.fragments.firstIndex(of: frag) {
                                    
                    if button.name == "(" || button.name == ")"
                    {
                        let undo = codeEditor.undoStart("Add Brackets")

                        let typeName = frag.evaluateType()
                        let open = CodeFragment(.OpeningRoundBracket, typeName, "(", [.Selectable])
                        let close = CodeFragment(.ClosingRoundBracket, typeName, ")", [.Selectable])
                        close.uuid = open.uuid
                        pStatement.fragments.insert(open, at: pIndex)
                        pStatement.fragments.insert(close, at: pIndex + 2)

                        codeEditor.editor.codeProperties.needsUpdate = true
                        codeEditor.updateCode(compile: true)
                        codeEditor.undoEnd(undo)
                    } else
                    {
                        let undo = codeEditor.undoStart("Add Arithmetic")
                        
                        let typeName = frag.evaluateType()
                        var constant : CodeFragment = defaultConstantForType(typeName)
                        
                        // By default simplify math operators
                        if frag.evaluateComponents() > 1 {
                            constant.isSimplified = true
                        }
                        
                        // If the reference statement was simplified need to create the math fragment in the same type and simplify it
                        if frag.isSimplified {
                            constant = defaultConstantForType(frag.typeName)
                            constant.isSimplified = true
                        }
                        
                        let arithmetic = CodeFragment(.Arithmetic, typeName, button.name, [.Selectable])
                        
                        if frag.name == "(" || frag.name == ")" {
                            // Add arithmetic outside of the bracket
                            
                            var leftIndex : Int = -1
                            var rightIndex : Int = -1
                            
                            for (index, f) in pStatement.fragments.enumerated() {
                                if f.uuid == frag.uuid {
                                    if leftIndex == -1 {
                                        leftIndex = index
                                    } else {
                                        rightIndex = index
                                    }
                                }
                            }
                            
                            if button.isLeft {
                                pStatement.fragments.insert(constant, at: leftIndex)
                                pStatement.fragments.insert(arithmetic, at: leftIndex+1)
                            } else {
                                pStatement.fragments.insert(arithmetic, at: rightIndex+1)
                                pStatement.fragments.insert(constant, at: rightIndex+2)
                            }
                        } else {
                            if button.isLeft {
                                pStatement.fragments.insert(constant, at: pIndex)
                                pStatement.fragments.insert(arithmetic, at: pIndex+1)
                            } else {
                                pStatement.fragments.insert(arithmetic, at: pIndex+1)
                                pStatement.fragments.insert(constant, at: pIndex+2)
                            }
                        }
                        codeEditor.codeComponent!.selected = constant.uuid
                        codeEditor.codeContext.selectedFragment = constant
                        codeEditor.editor.codeProperties.needsUpdate = true
                        codeEditor.updateCode(compile: true)
                        codeEditor.undoEnd(undo)
                    }
                }
            }
        } else
        if accessState == .ArithmeticOperator {

             if let frag = codeEditor.codeContext.selectedFragment {
                let undo = codeEditor.undoStart("Changed Operator")
                frag.name = button.name
                codeEditor.editor.codeProperties.needsUpdate = true
                codeEditor.updateCode(compile: true)
                codeEditor.undoEnd(undo)
            }
        } else
        if accessState == .AssignmentOperator {

             if let frag = codeEditor.codeContext.selectedFragment {
                let undo = codeEditor.undoStart("Changed Assignment")
                frag.name = button.name
                codeEditor.editor.codeProperties.needsUpdate = true
                codeEditor.updateCode(compile: true)
                codeEditor.undoEnd(undo)
            }
        } else
        if accessState == .ComparisonOperator {

             if let frag = codeEditor.codeContext.selectedFragment {
                let undo = codeEditor.undoStart("Changed Comparison")
                frag.name = button.name
                codeEditor.editor.codeProperties.needsUpdate = true
                codeEditor.updateCode(compile: true)
                codeEditor.undoEnd(undo)
            }
        } else
        if accessState == .FreeFlowFunctionArgument {
            if let frag = codeEditor.codeContext.selectedFragment {
                let pBlock = frag.parentBlock!
                if let pIndex = pBlock.statement.fragments.firstIndex(of: frag) {
                    let undo = codeEditor.undoStart("New Function Argument")

                    var name = "newVar"
                    var counter : Int = 1
                    var hasCounter : Bool = false
                    
                    func replace(_ myString: String, _ index: Int, _ newChar: Character) -> String {
                        var chars = Array(myString)     // gets an array of characters
                        chars[index] = newChar
                        let modifiedString = String(chars)
                        return modifiedString
                    }
                    
                    for a in pBlock.statement.fragments.sorted(by: { $0.name < $1.name }) {
                        if a.name == name {
                            if hasCounter == false {
                                name += String(counter)
                                counter += 1
                                hasCounter = true
                            } else {
                                if counter <= 9 {
                                    name = replace(name, name.count-1, Character(String(counter)))
                                    counter += 1
                                } else {
                                    name += "_"
                                }
                            }
                        }
                    }
                    
                    let newArg = CodeFragment(.VariableDefinition, button.name, name, [.Selectable, .Dragable])
                    if button.isLeft {
                        pBlock.statement.fragments.insert(newArg, at: pIndex)
                    } else {
                        pBlock.statement.fragments.insert(newArg, at: pIndex+1)
                    }
                    
                    codeEditor.updateCode(compile: true)
                    codeEditor.undoEnd(undo)
                }
            }
        }
    }
}
