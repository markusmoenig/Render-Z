//
//  CodeEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 27/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class CodeUndoComponent
{
    var name            : String
    
    var originalData    : String = ""
    var processedData   : String = ""

    init(_ name: String)
    {
        self.name = name
    }
}

class CodeEditor        : MMWidget
{
    var fragment        : MMFragment
    var textureWidget   : MMTextureWidget
    var scrollArea      : MMScrollArea
    
    var codeComponent   : CodeComponent? = nil
    var codeContext     : CodeContext
    
    var codeAccess      : CodeAccess!
    
    var previewTexture  : MTLTexture? = nil
    
    var editor          : DeveloperEditor!

    var needsUpdate     : Bool = false
    var codeChanged     : Bool = false
    var previewInstance : CodeBuilderInstance? = nil
        
    var mouseIsDown     : Bool = false
    var mouseDownPos    : SIMD2<Float> = SIMD2<Float>()

    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .Vertical)

        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        textureWidget = MMTextureWidget( view, texture: fragment.texture )
        
        codeContext = CodeContext(view, fragment, view.openSans, 0.5)

        super.init(view)

        codeAccess = CodeAccess(view, self)

        zoom = mmView.scaleFactor
        textureWidget.zoom = zoom
        
        dropTargets.append( "SourceFragmentItem" )
        
        needsUpdate = true
        codeChanged = true
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
            codeContext.dropOriginalUUID = UUID()
            
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
        if codeAccess.accessState != .Closed && codeAccess.rect.contains(event.x, event.y) {
            codeAccess.mouseMoved(event)
            return
        }
        
        if let selFragment = codeContext.selectedFragment, selFragment.supports(.Dragable), mmView.dragSource == nil, mouseIsDown == true {
            let dist = distance(mouseDownPos, SIMD2<Float>(event.x, event.y))
            if dist > 5 {
                var drag = SourceListDrag()
                
                drag.id = "SourceFragmentItem"
                drag.name = selFragment.name
                drag.pWidgetOffset!.x = (event.x - (selFragment.rect.x)) - rect.x
                drag.pWidgetOffset!.y = ((event.y - selFragment.rect.y) - rect.y).truncatingRemainder(dividingBy: editor.codeList.fragList.listWidget.unitSize)
                
                drag.codeFragment = selFragment.createCopy()
                codeContext.dropOriginalUUID = selFragment.uuid

                if selFragment.fragmentType == .VariableDefinition {
                    drag.codeFragment?.fragmentType = .VariableReference
                    drag.codeFragment?.referseTo = selFragment.uuid
                }
                
                var dragName : String
                if selFragment.fragmentType == .ConstantValue {
                    dragName = selFragment.getValueString()
                } else {
                    dragName = selFragment.typeName + " " + selFragment.name
                }
            
                let texture = editor.codeList.fragList.listWidget.createGenericThumbnail(dragName, selFragment.rect.width + 2*codeContext.gapX)
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
            
            comp.codeAt(event.x - rect.x, event.y - rect.y, codeContext)
                        
            if oldFunc !== codeContext.hoverFunction || oldBlock !== codeContext.hoverBlock || oldFrag !== codeContext.hoverFragment {
                needsUpdate = true
                mmView.update()
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if codeAccess.accessState != .Closed && codeAccess.rect.contains(event.x, event.y) {
            codeAccess.mouseDown(event)
            return
        }
        
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
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
                codeAccess.setSelected(comp, codeContext)
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if codeAccess.accessState != .Closed && codeAccess.rect.contains(event.x, event.y) {
            codeAccess.mouseUp(event)
            return
        }
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
            
            if codeChanged {
                buildPreview()
                codeChanged = false
            }
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
        if needsUpdate || fragment.width != rect.width * zoom {
            update()
            if let comp = codeComponent, editor.codeProperties.needsUpdate {
                editor.codeProperties.setSelected(comp, codeContext)
            }
        }

        // Is playing ?
        if globalApp!.codeBuilder.isPlaying && previewInstance != nil {
            globalApp?.codeBuilder.render(previewInstance!)
            editor.codeProperties.updateMonitor()
        }
        
        // Do the preview
        if let texture = previewTexture {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y, zoom: zoom)
            
            if let pipe = globalApp!.pipeline.texture {
                mmView.drawTexture.draw(pipe, x: rect.x, y: rect.y)
            }
            
            if Float(previewTexture!.width) != rect.width * zoom || Float(previewTexture!.height) != rect.height * zoom {
                previewTexture = globalApp!.codeBuilder.fragment.allocateTexture(width: rect.width * zoom, height: rect.height * zoom)
                globalApp!.codeBuilder.render(previewInstance!, previewTexture)
            }
            
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
        
        // Access Area
        
        codeAccess.rect.x = rect.x
        codeAccess.rect.y = rect.bottom() - codeAccess.rect.height + 1
        codeAccess.rect.width = rect.width
        if codeAccess.accessState != .Closed {
            codeAccess.draw()
        }
    }
    
    /// Update the code syntax and redraws
    func updateCode(compile: Bool = false)
    {
        codeChanged = compile
        needsUpdate = true
        update()
        mmView.update()
        if let comp = codeComponent, editor.codeProperties.needsUpdate {
            editor.codeProperties.setSelected(comp, codeContext)
        }
    }
    
    func undoStart(_ name: String) -> CodeUndoComponent
    {
        let codeUndo = CodeUndoComponent(name)

        if let component = codeComponent {
            let encodedData = try? JSONEncoder().encode(component)
            if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
            {
                codeUndo.originalData = encodedObjectJsonString
            }
        }
        
        return codeUndo
    }
    
    func undoEnd(_ undoComponent: CodeUndoComponent)
    {
        if let component = codeComponent {
            let encodedData = try? JSONEncoder().encode(component)
            if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
            {
                undoComponent.processedData = encodedObjectJsonString
            }
        }

        func componentChanged(_ oldState: String, _ newState: String)
        {
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                globalApp!.loadComponentFrom(oldState)
                componentChanged(newState, oldState)
            }
            self.mmView.undoManager!.setActionName(undoComponent.name)
        }
        
        componentChanged(undoComponent.originalData, undoComponent.processedData)
    }
    
    /// Insert a Code Fragment
    func insertCodeFragment(_ sourceFrag: CodeFragment,_ ctx: CodeContext )
    {
        let destFrag : CodeFragment = ctx.hoverFragment!
        let destBlock : CodeBlock = destFrag.parentBlock!

        #if DEBUG
        print( "insertCodeFragment, destBlock =", destBlock.blockType, "sourceFrag =", sourceFrag.fragmentType, "destFrag =", destFrag.fragmentType)
        #endif

        if destBlock.blockType == .Empty {

            // Insert a new Variable into an empty line
            if sourceFrag.fragmentType == .VariableDefinition {
                
                getStringDialog(view: mmView, title: "Float Variable", message: "Enter variable name", defaultValue: "newVar", cb: { (value) -> Void in
                
                    let undo = self.undoStart("Insert Variable: \(value)")
                    destBlock.blockType = .VariableDefinition
                    destBlock.fragment.fragmentType = .VariableDefinition
                    destBlock.fragment.properties = sourceFrag.properties
                    destBlock.fragment.typeName = sourceFrag.typeName
                    destBlock.fragment.name = value
                    
                    let constant = self.defaultConstantForType(sourceFrag.evaluateType())
                    destBlock.statement.fragments.append(constant)
                    
                    self.updateCode(compile: true)
                    self.undoEnd(undo)
                } )
            } else
            // Insert a variable reference into a new line
            if sourceFrag.fragmentType == .VariableReference
            {
                let undo = self.undoStart("Variable Reference: \(sourceFrag.name)")
                destBlock.blockType = .VariableReference
                destBlock.fragment.fragmentType = .VariableReference
                destBlock.fragment.properties = sourceFrag.properties
                destBlock.fragment.typeName = sourceFrag.typeName
                destBlock.fragment.name = sourceFrag.name
                destBlock.fragment.referseTo = sourceFrag.referseTo
                
                let constant = defaultConstantForType(sourceFrag.evaluateType())
                destBlock.statement.fragments.append(constant)

                self.updateCode(compile: true)
                self.undoEnd(undo)
            }
        } else
        {
            let undo = self.undoStart("Drag and Drop")
            
            // Drag on a constant value or when the target has only one component, i.e. single float values
            if (destFrag.fragmentType == .ConstantValue || destFrag.evaluateComponents() == 1) {
                print(destFrag.evaluateComponents(), destFrag.evaluateType(), destFrag.typeName)
                let sourceComponents = sourceFrag.evaluateComponents()
                //let destComponents = destFrag.evaluateComponents() // Currently only float anyway
                //print( sourceComponents, 1)
                var compName : String = sourceFrag.qualifier
                if sourceComponents > 1 {
                    let compArray : [String] = ["x", "y", "z", "w"]
                    if let parentStatement = destFrag.parentStatement {
                        let argumentIndex = parentStatement.isArgumentIndexOf
                        if argumentIndex < sourceComponents {
                            compName = compArray[argumentIndex]
                        }
                    }
                }
                sourceFrag.copyTo(destFrag)
                createFragmentArguments(destFrag, sourceFrag)
                destFrag.addProperty(.Targetable)
                destFrag.qualifier = compName
                #if DEBUG
                print("Drop #1")
                #endif
            } else
            // Copy constant to constant where the constants have more components than 1, i.e. 1 to 1 copy
            if (destFrag.fragmentType == .ConstantDefinition && sourceFrag.fragmentType == .ConstantDefinition) {
                sourceFrag.copyTo(destFrag)
                #if DEBUG
                print("Drop #2")
                #endif
            } else
            // Copy constant to a .Primitive
            if (destFrag.fragmentType == .Primitive && sourceFrag.fragmentType == .ConstantDefinition) {
                sourceFrag.copyTo(destFrag)
                #if DEBUG
                print("Drop #3")
                #endif
            } else
            // Copy a variable
            if sourceFrag.fragmentType == .VariableReference {
                sourceFrag.copyTo(destFrag)
                destFrag.addProperty(.Targetable)
                #if DEBUG
                print("Drop #4")
                #endif
            } else
            // Copy constant to constant where the constants have more components than 1, i.e. 1 to 1 copy
            if (destFrag.fragmentType == .VariableReference && sourceFrag.fragmentType == .ConstantDefinition) {
                sourceFrag.copyTo(destFrag)
                #if DEBUG
                print("Drop #5")
                #endif
            } else
            //
            if sourceFrag.fragmentType == .Primitive {
                //print( sourceFrag.name )
                let typeName = destFrag.evaluateType()
                sourceFrag.copyTo(destFrag)
                destFrag.typeName = typeName
                destFrag.arguments = []
             
                // TODO make sure all arguments comform to their formats
                
                for _ in sourceFrag.argumentFormat! {
                    let constant = defaultConstantForType(typeName)
                    
                    let statement = CodeStatement(.List)
                    statement.fragments.append(constant)
                    
                    destFrag.arguments.append(statement)
                }
                #if DEBUG
                print("Drop #5")
                #endif
            }
                        
            self.updateCode(compile: true)
            self.undoEnd(undo)
        }
    }
    
    /// Creates a constant for the given type
    func defaultConstantForType(_ typeName: String) -> CodeFragment
    {
        //print("defaultConstantForType", typeName)
        
        let constant    : CodeFragment
        var components  : Int = 0
        var compName    : String = typeName
        
        if typeName.hasSuffix("2") {
            components = 2
            compName.remove(at: compName.index(before: compName.endIndex))
        } else
        if typeName.hasSuffix("3") {
            components = 3
            compName.remove(at: compName.index(before: compName.endIndex))
        } else
        if typeName.hasSuffix("4") {
            components = 4
            compName.remove(at: compName.index(before: compName.endIndex))
        }
        
        if components == 0 {
            constant = CodeFragment(.ConstantValue, typeName, typeName, [.Selectable, .Dragable, .Targetable], [typeName], typeName)
        } else {
            constant = CodeFragment(.ConstantDefinition, typeName, typeName, [.Selectable, .Dragable, .Targetable], [typeName], typeName)
            
            for _ in 0..<components {
                let argStatement = CodeStatement(.Arithmetic)
                
                let constValue = CodeFragment(.ConstantValue, compName, "", [.Selectable, .Dragable, .Targetable], [compName], compName)
                argStatement.fragments.append(constValue)
                constant.arguments.append(argStatement)
            }
        }
        
        return constant
    }
    
    /// Creates the arguments for the fragment
    func createFragmentArguments(_ destFrag: CodeFragment, _ sourceFrag: CodeFragment)
    {
        if let sourceFormats = sourceFrag.argumentFormat, sourceFrag.fragmentType == .Primitive || sourceFrag.fragmentType == .ConstantDefinition {
            // Case1, source is directly from the source list and we need to create the arguments based on the argumentFormat
            if sourceFormats.count > sourceFrag.arguments.count {

                for _ in sourceFormats
                {
                    let argStatement = CodeStatement(.Arithmetic)

                    let constValue = CodeFragment(.ConstantValue, "float", "float", [.Selectable, .Dragable, .Targetable], ["float"], "float")
                    argStatement.fragments.append(constValue)
                    destFrag.arguments.append(argStatement)
                }
            }
        } else {
            destFrag.argumentFormat = nil
            destFrag.arguments = []
        }
    }
}
