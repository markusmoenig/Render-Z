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
    
    var previewTexture  : MTLTexture? = nil
    
    var editor          : Editor!

    var needsUpdate     : Bool = false
    var previewInstance : CodeBuilderInstance? = nil
    
    var mouseIsDown     : Bool = false

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
        
        dropTargets.append( "SourceFragmentItem" )
        
        codeComponent = CodeComponent()
        codeComponent?.createDefaultFunction(.ScreenObjectColorize)
        needsUpdate = true
    }
    
    /// Drag and Drop Target
    override func dragEnded(event: MMMouseEvent, dragSource: MMDragSource)
    {
        if dragSource.id == "SourceFragmentItem"
        {
            // Source Item
            if let drag = dragSource as? SourceListDrag {
                /// Insert the fragment
                if let frag = drag.codeFragment, codeContext.hoverFragment != nil, codeContext.dropIsValid == true {
                    insertCodeFragment(frag, codeContext)
                }
            }
            
            codeContext.hoverFragment = nil
            
            codeContext.dropFragment = nil
            needsUpdate = true
            mmView.update()
        }
    }
    
    // For internal drags from the editor, i.e. variable references etc
    override func dragTerminated() {
        mmView.unlockFramerate()
        mouseIsDown = false
    }
    
    /// Disable hover when mouse leaves the editor
    override func mouseLeave(_ event: MMMouseEvent) {
        let oldFunc = codeContext.hoverFunction
        let oldBlock = codeContext.hoverBlock

        codeContext.hoverFunction = nil
        codeContext.hoverBlock = nil

        if oldFunc !== codeContext.hoverFunction || oldBlock !== codeContext.hoverBlock {
            needsUpdate = true
            mmView.update()
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if let selFragment = codeContext.selectedFragment, mouseIsDown == true {
            
            if selFragment.fragmentType == .VariableDefinition && mmView.dragSource == nil {
                var drag = SourceListDrag()
                
                drag.id = "SourceFragmentItem"
                drag.name = selFragment.name
                drag.pWidgetOffset!.x = (event.x - (selFragment.rect.x)) - rect.x
                drag.pWidgetOffset!.y = ((event.y - selFragment.rect.y) - rect.y).truncatingRemainder(dividingBy: editor.codeList.fragList.listWidget.unitSize)
                
                drag.codeFragment = CodeFragment(.VariableReference)
                                                
                drag.codeFragment?.typeName = selFragment.typeName
                drag.codeFragment?.name = selFragment.name
                drag.codeFragment?.referseTo = selFragment.uuid
                
                let texture = editor.codeList.fragList.listWidget.createGenericThumbnail(selFragment.typeName + " " + selFragment.name, selFragment.rect.width + 2*codeContext.gapX)
                drag.previewWidget = MMTextureWidget(mmView, texture: texture)
                drag.previewWidget!.zoom = mmView.scaleFactor
                            
                drag.sourceWidget = self
                mmView.dragStarted(source: drag)
                
                return
            }
        }
        
        if let dragSource = mmView.dragSource as? SourceListDrag {
            codeContext.dropFragment = dragSource.codeFragment
        }
                
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
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        #if os(iOS)
        mouseMoved(event)
        #endif
        
        if let comp = codeComponent {
            codeContext.selectedFunction = codeContext.hoverFunction
            codeContext.selectedBlock = codeContext.hoverBlock
            codeContext.selectedFragment = codeContext.hoverFragment
            
            let oldSelected = comp.selected
            comp.selected = nil

            if let c = codeContext.selectedFragment {
                comp.selected = c.uuid
            } else
            if let c = codeContext.selectedBlock {
                comp.selected = c.uuid
            } else
            if let c = codeContext.selectedFunction {
                comp.selected = c.uuid
            }
            
            if oldSelected != comp.selected {

                needsUpdate = true
                mmView.update()
                
                editor.codeProperties.setSelected(comp, codeContext)
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
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
            
            buildPreview()
        }
        needsUpdate = false
    }
    
    /// Builds the preview
    func buildPreview()
    {
        if let comp = codeComponent {

            previewInstance = globalApp!.codeBuilder.build(comp)
            if previewTexture == nil || (Float(previewTexture!.width) != rect.width * zoom || Float(previewTexture!.height) != rect.height * zoom) {
                previewTexture = globalApp!.codeBuilder.fragment.allocateTexture(width: rect.width * zoom, height: rect.height * zoom)
            }
            
            globalApp!.codeBuilder.render(previewInstance!, previewTexture)
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        // Need to update the code display ?
        if needsUpdate {
            update()
        }
        
        // Is playing ?
        if globalApp!.codeBuilder.isPlaying && previewInstance != nil {
            globalApp?.codeBuilder.render(previewInstance!)
        }
        
        if let texture = previewTexture {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y, zoom: zoom)
            
            if let comp = codeComponent {
                for f in comp.functions {
                    var color = mmView.skin.Code.background
                    color.w = 0.9
                    
                    mmView.drawBox.draw(x: rect.x + codeContext.gapX / 2, y: rect.y + codeContext.gapY / 2 + f.rect.y, width: codeContext.border - codeContext.gapX, height: f.rect.height, round: 6, borderSize: 0, fillColor: color)
                    
                    mmView.drawBox.draw(x: rect.x + f.rect.x, y: rect.y + f.rect.y, width: f.rect.width, height: f.rect.height, round: 6, borderSize: 0, fillColor: color)
                }
            }
            
        } else {
            mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.background)
        }
        
        scrollArea.rect.copy(rect)
        scrollArea.build(widget: textureWidget, area: rect, xOffset: xOffset)
        
        //mmView.drawTexture.draw(fragment.texture, x: rect.x, y: rect.y, zoom: zoom)
    }
    
    /// Update the code syntax and redraws
    func updateCode()
    {
        needsUpdate = true
        update()
        mmView.update()
    }
    
    /// Insert a Code Fragment
    func insertCodeFragment(_ sourceFrag: CodeFragment,_ ctx: CodeContext )
    {
        let destFrag : CodeFragment = ctx.hoverFragment!
        
        print( destFrag.fragmentType, destFrag.typeName, destFrag.name )
        let destBlock : CodeBlock = destFrag.parentBlock!

        if sourceFrag.fragmentType == .VariableDefinition {
            
            if destBlock.blockType == .Empty {
                
                getStringDialog(view: mmView, title: "Float Variable", message: "Enter variable name", defaultValue: "var", cb: { (value) -> Void in
                
                    destBlock.blockType = .VariableDefinition
                    destBlock.fragment.fragmentType = .VariableDefinition
                    destBlock.fragment.typeName = sourceFrag.typeName
                    destBlock.fragment.name = value
                    
                    if destFrag.typeName == "float" {
                        let constant = CodeFragment(.ConstantValue, sourceFrag.typeName, sourceFrag.typeName)
                        destBlock.statement.fragments.append(constant)
                    } else {
                        let constant = CodeFragment(.ConstantDefinition, sourceFrag.typeName, sourceFrag.typeName)
                        destBlock.statement.fragments.append(constant)
                        
                        for _ in 0...0 {
                            let argStatement = CodeStatement(.Arithmetic)
                            
                            let constValue = CodeFragment(.ConstantValue, "float")
                            argStatement.fragments.append(constValue)
                            constant.arguments.append(argStatement)
                        }
                    }
                    self.updateCode()
                } )
            }
        }
        
        if sourceFrag.fragmentType == .Primitive {
            
            copyFragmentArguments(destFrag, sourceFrag)
            
            destFrag.fragmentType = .Primitive
            destFrag.name = sourceFrag.name
            
            self.updateCode()

            /*
            if destFrag.fragmentType == .ConstantValue {
                
                getStringDialog(view: mmView, title: "Float Variable", message: "Enter variable name", defaultValue: "var", cb: { (value) -> Void in
                
                    destBlock.blockType = .VariableDefinition
                    destBlock.fragment.fragmentType = .VariableDefinition
                    destBlock.fragment.typeName = frag.typeName
                    destBlock.fragment.name = value
                    
                    if frag.fragmentType == .VariableDefinition && destFrag.typeName == "float" {
                        let constant = CodeFragment(.ConstantValue, frag.typeName, frag.typeName)
                        destBlock.statement.fragments.append(constant)
                    } else {
                        let constant = CodeFragment(.ConstantDefinition, frag.typeName, frag.typeName)
                        destBlock.statement.fragments.append(constant)
                        
                        for _ in 0...0 {
                            let argStatement = CodeStatement(.Arithmetic)
                            
                            let constValue = CodeFragment(.ConstantValue, "float")
                            argStatement.fragments.append(constValue)
                            constant.arguments.append(argStatement)
                        }
                    }
                    self.updateCode()
                } )
            }*/
        }
        
        
        if sourceFrag.fragmentType == .VariableReference {
            
            //copyFragmentArguments(destFrag, sourceFrag)
            
            print("jere")
            
            destFrag.fragmentType = .VariableReference
            destFrag.typeName = sourceFrag.typeName
            destFrag.name = sourceFrag.name
            destFrag.referseTo = sourceFrag.referseTo

            self.updateCode()
        }
        
    }
    
    /// Copy the
    func copyFragmentArguments(_ destFrag: CodeFragment, _ sourceFrag: CodeFragment)
    {
        if let sourceFormats = sourceFrag.argumentFormat {
            for arg in sourceFormats
            {
                let argStatement = CodeStatement(.Arithmetic)

                let constValue = CodeFragment(.ConstantValue, "float", "float")
                argStatement.fragments.append(constValue)
                destFrag.arguments.append(argStatement)
            }
        } else {
            destFrag.argumentFormat = nil
            destFrag.arguments = []
        }
    }
}
