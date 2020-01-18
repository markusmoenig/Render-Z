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
    
    init(_ name: String)
    {
        self.name = name
    }
}

class CodeAccess            : MMWidget
{
    enum AccessState {
        case Closed, Arithmetic, ArithmeticOperator, AssignmentOperator
    }
    
    var accessState             : AccessState = .Closed

    var codeEditor              : CodeEditor
    
    var leftButtons             : [AccessButton] = []
    var rightButtons            : [AccessButton] = []
    
    var font                    : MMFont
    var fontScale               : Float = 0.5
    
    var hoverButton             : AccessButton? = nil
    var selectedButton          : AccessButton? = nil
    
    let arithmetics             : [String] = ["+", "-", "*", "/"]
    let assignments             : [String] = ["=", "+=", "-=", "*=", "/="]

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
    }
    
    func setSelected(_ comp: CodeComponent,_ ctx: CodeContext)
    {
        accessState = .Closed
        clear()
        
        func addButtonBothSides(_ name: String) {
            leftButtons.append(AccessButton(name))
            rightButtons.append(AccessButton(name))
        }
        
        func addLeftButton(_ name: String) {
            leftButtons.append(AccessButton(name))
        }
        
        func addRightButton(_ name: String) {
            rightButtons.append(AccessButton(name))
        }
        
        if let fragment = ctx.selectedFragment {
            
            if fragment.fragmentType == .ConstantDefinition || fragment.fragmentType == .ConstantValue || fragment.fragmentType == .Primitive || fragment.fragmentType == .VariableReference || fragment.fragmentType == .OpeningRoundBracket || fragment.fragmentType == .ClosingRoundBracket  {
                accessState = .Arithmetic
                
                for a in arithmetics {
                    addButtonBothSides(a)
                }
                if fragment.fragmentType != .OpeningRoundBracket && fragment.fragmentType != .ClosingRoundBracket {
                    addLeftButton("(")
                    addRightButton(")")
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
        
        for b in leftButtons {
            font.getTextRect(text: b.name, scale: fontScale, rectToUse: tempRect)
            
            b.rect.x = cX
            b.rect.y = cY
            b.rect.width = lineHeight
            b.rect.height = lineHeight
            
            mmView.drawText.drawText(font, text: b.name, x: cX + (lineHeight - tempRect.width)/2, y: cY, scale: fontScale, color: mmView.skin.Widget.textColor)
            
            if hoverButton === b || selectedButton === b {
                let alpha : Float = selectedButton === b ? 0.7 : 0.5
                mmView.drawBox.draw( x: b.rect.x, y: b.rect.y, width: b.rect.width, height: b.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
            }
            
            cX += lineHeight + 4
        }
        
        cX = rect.x + rect.width - 4 - lineHeight
        for b in rightButtons {
            font.getTextRect(text: b.name, scale: fontScale, rectToUse: tempRect)
            
            b.rect.x = cX
            b.rect.y = cY
            b.rect.width = lineHeight
            b.rect.height = lineHeight
            
            mmView.drawText.drawText(font, text: b.name, x: cX + (lineHeight - tempRect.width)/2, y: cY, scale: fontScale, color: mmView.skin.Widget.textColor)
            
            if hoverButton === b || selectedButton === b {
                let alpha : Float = selectedButton === b ? 0.7 : 0.5
                mmView.drawBox.draw( x: b.rect.x, y: b.rect.y, width: b.rect.width, height: b.rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
            }
            
            cX -= lineHeight + 4
        }
    }
    
    /// Execute the selected button for the given state
    func perform(_ button: AccessButton)
    {
        if accessState == .Arithmetic {

            if let frag = codeEditor.codeContext.selectedFragment {
                
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
                        let constant = codeEditor.defaultConstantForType(typeName)
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
        }
    }
}
