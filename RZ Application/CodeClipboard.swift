//
//  CodeClipboard.swift
//  Shape-Z
//
//  Created by Markus Moenig on 1/4/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

class CodeClipboard
{
    enum DataMode {
        case Empty, Fragment, Block
    }
    
    var dataMode            : DataMode = .Empty
    
    let mmView              : MMView
    let codeEditor          : CodeEditor
    
    var selectionRect       : MMRect? = nil
    
    var copyButton          : MMButtonWidget
    var pasteButton         : MMButtonWidget

    var selectedFragment    : CodeFragment? = nil
    var selectedBlock       : CodeBlock? = nil
    var selectedCompUUID    : UUID? = nil
    
    var encodedData         : String = ""
    var dataCompUUID        : UUID? = nil
    
    var canCopy             : Bool = false
    var canPaste            : Bool = false
    
    var customRect          : Bool = false

    init(_ editor: CodeEditor)
    {
        codeEditor = editor
        mmView = codeEditor.mmView
        
        var buttonSkin = MMSkinButton()
        buttonSkin.margin = MMMargin( 8, 4, 8, 4 )
        buttonSkin.borderSize = 1
        buttonSkin.height = mmView.skin.Button.height - 5
        buttonSkin.fontScale = 0.40
        buttonSkin.round = 20
        buttonSkin.color = SIMD4<Float>(1,1,1,0.3)
        
        copyButton = MMButtonWidget(editor.mmView, skinToUse: buttonSkin, text: "Copy")
        pasteButton = MMButtonWidget(editor.mmView, skinToUse: buttonSkin, text: "Paste")

        copyButton.clicked = { (event) in
            
            if let selectedFragment = self.selectedFragment {
                if let selFrag = self.codeEditor.processFragmentForCopy(selectedFragment) {
                    let encodedData = try? JSONEncoder().encode(selFrag)
                    if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
                        self.encodedData = encodedObjectJsonString
                        self.dataMode = .Fragment
                        self.canCopy = false
                        self.dataCompUUID = globalApp!.developerEditor.codeEditor.codeComponent!.uuid
                    }
                }
            } else
            if let selectedBlock = self.selectedBlock {
                let encodedData = try? JSONEncoder().encode(selectedBlock)
                if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
                    self.encodedData = encodedObjectJsonString
                    self.dataMode = .Block
                    self.canCopy = false
                    self.dataCompUUID = globalApp!.developerEditor.codeEditor.codeComponent!.uuid
                }
            }
                
            self.copyButton.removeState(.Checked)
        }
        
        pasteButton.clicked = { (event) in

            if let selectedFragment = self.selectedFragment {
                if self.dataMode == .Fragment {
                    if let dataFragment = self.getDecodedFragment() {
                        let undo = self.codeEditor.undoStart("Paste")
                        
                        let oldHoverFragment = self.codeEditor.codeContext.hoverFragment

                        self.codeEditor.codeContext.hoverFragment = selectedFragment
                        self.codeEditor.insertCodeFragment(dataFragment, self.codeEditor.codeContext)
                        
                        self.codeEditor.codeContext.hoverFragment = oldHoverFragment
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        self.codeEditor.undoEnd(undo)
                    }
                } else
                if self.dataMode == .Block {
                    if let selectedFragment = self.selectedFragment {
                        if let dataBlock = self.getDecodedBlock() {
                            let undo = self.codeEditor.undoStart("Paste")
                            dataBlock.copyTo(selectedFragment.parentBlock!)
                            globalApp!.currentEditor.updateOnNextDraw(compile: true)
                            self.codeEditor.undoEnd(undo)
                        }
                    }
                }
            } else
            if let selectedBlock = self.selectedBlock {
                if let dataBlock = self.getDecodedBlock() {
                    let undo = self.codeEditor.undoStart("Paste")
                    dataBlock.copyTo(selectedBlock)
                    globalApp!.currentEditor.updateOnNextDraw(compile: true)
                    self.codeEditor.undoEnd(undo)
                }
            }
            
            self.pasteButton.removeState(.Checked)
        }
    }
    
    func deregisterButtons()
    {
        mmView.deregisterWidgets(widgets: copyButton)
        mmView.deregisterWidgets(widgets: pasteButton)
    }
    
    func updateSelection(_ fragment: CodeFragment?,_ block: CodeBlock?,_ customRect: MMRect? = nil)
    {
        if globalApp!.developerEditor.codeEditor.codeComponent == nil {
            return
        }
        
        //print("updateSelection", fragment, block)
        selectedFragment = fragment
        selectedBlock = block
        
        selectedCompUUID = globalApp!.developerEditor.codeEditor.codeComponent!.uuid
        
        deregisterButtons()
        
        canCopy = false
        canPaste = false
        selectionRect = nil
        self.customRect = false
        
        // Fragment selected ?
        if let fragment = fragment {
            if let custom = customRect {
                selectionRect = MMRect(custom)
                self.customRect = true
            } else {
                selectionRect = MMRect(fragment.rect)
            }

            // Can Copy ?
            if fragment.properties.contains(.Dragable) {
                mmView.widgets.insert(copyButton, at: 0)
                canCopy = true
            }

            if self.customRect == false {
                // Can Paste Fragment?
                if dataMode == .Fragment && fragment.properties.contains(.Selectable) {
                    let oldHoverFragment = codeEditor.codeContext.hoverFragment
                                    
                    let dataFragment = getDecodedFragment()
                    codeEditor.codeContext.hoverFragment = selectedFragment
                    codeEditor.codeContext.dropFragment = dataFragment
                    
                    codeEditor.codeContext.checkIfDropIsValid(fragment)
                    if codeEditor.codeContext.dropIsValid {
                        
                        if checkFragmentDependencies(dataFragment!) {
                            canPaste = true
                            mmView.widgets.insert(pasteButton, at: 0)
                        }
                    }
                    
                    codeEditor.codeContext.hoverFragment = oldHoverFragment
                    codeEditor.codeContext.dropIsValid = false
                    codeEditor.codeContext.dropFragment = nil
                }
                
                // Can Paste Block ?
                if dataMode == .Block && fragment.parentBlock!.blockType == .Empty {
                    if let dataBlock = getDecodedBlock() {
                        if checkBlockDependencies(dataBlock) {
                            canPaste = true
                            mmView.widgets.insert(pasteButton, at: 0)
                        }
                    }
                }
            }
        } else
        // Block selected
        if let block = block {
            
            selectionRect = MMRect(block.rect)
            mmView.widgets.insert(copyButton, at: 0)

            // Can always copy a block if it is not empty
            if block.blockType != .Empty {
                canCopy = true
            }
            
            // Can Paste Block ?
            if dataMode == .Block && block.blockType == .Empty {
                if let dataBlock = getDecodedBlock() {
                    if checkBlockDependencies(dataBlock) {
                        canPaste = true
                        mmView.widgets.insert(pasteButton, at: 0)
                    }
                }
            }
        }
    }
    
    func getDecodedFragment() -> CodeFragment?
    {
        if let jsonData = encodedData.data(using: .utf8) {
            if let fragment = try? JSONDecoder().decode(CodeFragment.self, from: jsonData) {
                return fragment
            }
        }
        return nil
    }
    
    func getDecodedBlock() -> CodeBlock?
    {
        if let jsonData = encodedData.data(using: .utf8) {
            if let block = try? JSONDecoder().decode(CodeBlock.self, from: jsonData) {
                
                if block.fragment.fragmentType == .VariableDefinition {
                    block.fragment.uuid = UUID()
                }
                return block
            }
        }
        return nil
    }
    
    /// Check if there are function dependencies in the clipboard fragment, if yes, dont allow copy (future: try to resolve them, like sceneMap etc)
    func checkFragmentDependencies(_ dataFragment: CodeFragment) -> Bool
    {
        var dependencies : [CodeFragment] = []
        
        if dataCompUUID == selectedCompUUID {
            // Always allow dependencies in the same CodeComponent
            return true
        }
        
        func checkFragment(_ fragment: CodeFragment)
        {
            if fragment.referseTo != nil {
                if fragment.fragmentType == .Primitive {
                    dependencies.append(fragment)
                }
            }
            
            for s in fragment.arguments {
                for f in s.fragments {
                    checkFragment(f)
                }
            }            
        }
        
        checkFragment(dataFragment)
        
        if dependencies.count == 0 {
            return true
        } else {
            return false
        }
    }
    
    /// Check for dependences of the given block
    func checkBlockDependencies(_ dataBlock: CodeBlock) -> Bool
    {
        if dataCompUUID == selectedCompUUID {
            // Always allow dependencies in the same CodeComponent
            return true
        }
        
        func checkBlock(_ block: CodeBlock) -> Bool {
            for f in dataBlock.statement.fragments {
                if checkFragmentDependencies(f) == false {
                    return false
                }
            }
            return true
        }
        
        if checkBlock(dataBlock) == false {
            return false
        }
        
        for b in dataBlock.children {
            if checkBlock(b) == false {
                return false
            }
        }
        return true
    }
    
    func draw()
    {
        if let rect = selectionRect {
            
            var startX : Float = (customRect == false ? codeEditor.rect.x : 0) + rect.x + (customRect == false ? codeEditor.scrollArea.offsetX : 0) - 20
            let startY : Float = (customRect == false ? codeEditor.rect.y : 0) + rect.y + (customRect == false ? codeEditor.scrollArea.offsetY : 0) - 30

            if canCopy {
                copyButton.rect.x = startX
                copyButton.rect.y = startY
                startX += copyButton.rect.width + 5
                copyButton.draw()
            }
            
            if canPaste {
                pasteButton.rect.x = startX
                pasteButton.rect.y = startY
                pasteButton.draw()
            }
        }
    }
}
