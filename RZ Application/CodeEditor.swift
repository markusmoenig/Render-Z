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
        
    var editor          : DeveloperEditor!

    var needsUpdate     : Bool = false
    var codeChanged     : Bool = false
        
    var mouseIsDown     : Bool = false
    var mouseDownPos    : SIMD2<Float> = SIMD2<Float>()
    
    var pinchBuffer     : Float = 0
    
    var dndFunction     : CodeFunction? = nil
    
    var orientationDrag : Bool = false
    
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
                } else
                // Function ?
                if let frag = drag.codeFragment, dndFunction != nil {
                    if frag.name == "function" {
                        // Insert new function
                        if let comp = codeComponent {
                            if let index = comp.functions.firstIndex(of: dndFunction!) {
                                
                                getStringDialog(view: mmView, title: "New Function", message: "Function name", defaultValue: "newFunction", cb: { (value) -> Void in

                                    let undo = self.undoStart("Insert New Function")
                                    let f = CodeFunction(.FreeFlow, value)
                                    
                                    let arg = CodeFragment(.VariableDefinition, "float", "argument", [.Selectable, .Dragable])
                                    f.header.statement.fragments.append(arg)
                                    
                                    let b = CodeBlock(.Empty)
                                    b.fragment.addProperty(.Selectable)
                                    f.body.append(b)
                                    f.body.append(f.createOutVariableBlock("float4", "out"))

                                    
                                    comp.functions.insert(f, at: index)
                                    self.undoEnd(undo)
                                    self.editor.updateOnNextDraw()
                                })
                            }
                        }
                    }
                }
            }
            
            codeContext.hoverFragment = nil
            codeContext.dropFragment = nil
            codeContext.dropOriginalUUID = UUID()
            
            dndFunction = nil

            editor.updateOnNextDraw(compile: true)
            mmView.update()
        }
    }
    
    // For internal drags from the editor, i.e. variable references etc
    override func dragTerminated() {
        mmView.unlockFramerate()
        mouseIsDown = false
        dndFunction = nil
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
        if orientationDrag == true {
            var offset : Float = mouseDownPos.y - event.y
            
            offset /= (100 / rect.width) * 1.8
            scrollArea.offsetY += offset
            
            mouseDownPos.x = event.x
            mouseDownPos.y = event.y

            scrollArea.checkOffset(widget: textureWidget, area: rect)
            mmView.update()
            return
        }
        
        if codeAccess.accessState != .Closed && codeAccess.rect.contains(event.x, event.y) {
            codeAccess.mouseMoved(event)
            return
        }
        
        // Drag and drop inside the editor
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
                
                drag.codeFragment?.parentBlock = selFragment.parentBlock
                if selFragment.fragmentType == .TypeDefinition {
                    // --- Dragging the typedef of a function, create a .Primitive out of it
                    if let frag = drag.codeFragment {
                    
                        frag.fragmentType = .Primitive
                        var argFormat : [String] = []
                        
                        let args = selFragment.parentBlock!.statement.fragments
                        for arg in args {
                            argFormat.append(arg.typeName)
                        }
                        frag.argumentFormat = argFormat
                        frag.referseTo = selFragment.parentBlock!.parentFunction!.uuid
                    }
                }

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
        
        // Drag and drop from the fraglist
        if let dragSource = mmView.dragSource as? SourceListDrag {
            codeContext.dropFragment = dragSource.codeFragment
            
            let oldDndFunction = dndFunction
            
            dndFunction = nil
            if let frag = dragSource.codeFragment {
                if frag.name == "function" {
                    codeContext.dropFragment = nil
                    if let comp = codeComponent {
                        let y = event.y - rect.y
                        for f in comp.functions {
                            if y >= f.rect.y - CodeContext.fSpace + scrollArea.offsetY && y < f.rect.y + scrollArea.offsetY {
                                dndFunction = f
                                break
                            }
                        }
                    }
                }
            }
            if oldDndFunction !== dndFunction {
                mmView.update()
            }
        }
                
        if let comp = codeComponent {
            let oldFunc = codeContext.hoverFunction
            let oldBlock = codeContext.hoverBlock
            let oldFrag = codeContext.hoverFragment
            
            comp.codeAt(event.x - rect.x, event.y - rect.y - scrollArea.offsetY, codeContext)
                        
            if oldFunc !== codeContext.hoverFunction || oldBlock !== codeContext.hoverBlock || oldFrag !== codeContext.hoverFragment {
                needsUpdate = true
                mmView.update()
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        orientationDrag = false
        if codeAccess.accessState != .Closed && codeAccess.rect.contains(event.x, event.y) {
            codeAccess.mouseDown(event)
            return
        }
        
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        if event.x > rect.right() - 100 {
            orientationDrag = true;
            
            var offset : Float = event.y - rect.y
            
            offset /= (100 / rect.width) * 1.8
            scrollArea.offsetY = -offset

            scrollArea.checkOffset(widget: textureWidget, area: rect)
            mmView.update()
            
            return
        }
        
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
        dndFunction = nil
        orientationDrag = false
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        var prevScale = codeContext.fontScale
        
        #if os(OSX)
        if mmView.commandIsDown && event.deltaY! != 0 {
            prevScale += event.deltaY! * 0.01
            prevScale = max(0.2, prevScale)
            prevScale = min(2, prevScale)
            
            codeContext.fontScale = prevScale
            editor.updateOnNextDraw(compile: false)
        } else {
            scrollArea.mouseScrolled(event)
            scrollArea.checkOffset(widget: textureWidget, area: rect)
        }
        #endif
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        if firstTouch == true {
            let realScale : Float = codeContext.fontScale
            pinchBuffer = realScale
        }
        
        codeContext.fontScale = max(0.2, pinchBuffer * scale)
        codeContext.fontScale = min(2, codeContext.fontScale)
        
        editor.updateOnNextDraw(compile: false)
    }
    
    override func update()
    {
        if codeChanged {
            if let comp = codeComponent {
                dryRunComponent(comp)
            }
        }
        
        let height : Float = codeContext.cY == 0 ? 500 : codeContext.cY
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
                globalApp!.pipeline.build(scene: globalApp!.project.selected!)
                codeChanged = false
            }
            globalApp!.pipeline.render(rect.width, rect.height)
        }
        needsUpdate = false
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
        if globalApp!.pipeline.codeBuilder.isPlaying {
            globalApp!.pipeline.render(rect.width, rect.height)
        }
        
        // Do the preview
        if let texture = globalApp!.pipeline.resultTexture {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y)
            globalApp!.pipeline.renderIfResolutionChanged(rect.width, rect.height)
            
            mmView.renderer.setClipRect(rect)
            if let comp = codeComponent {
                for f in comp.functions {
                    var color = mmView.skin.Code.background
                    color.w = 0.9
                    
                    mmView.drawBox.draw(x: rect.x + codeContext.gapX / 2, y: rect.y + codeContext.gapY / 2 + f.rect.y + scrollArea.offsetY, width: codeContext.border - codeContext.gapX, height: f.rect.height, round: 6, borderSize: 0, fillColor: color)
                    
                    mmView.drawBox.draw(x: rect.x + f.rect.x, y: rect.y + f.rect.y + scrollArea.offsetY, width: f.rect.width, height: f.rect.height, round: 6, borderSize: 0, fillColor: color)
                }
            }
            mmView.renderer.setClipRect()
        } else {
            mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.background)
        }
        
        scrollArea.rect.copy(rect)
        scrollArea.build(widget: textureWidget, area: rect, xOffset: xOffset)
        
        // Orientation area
        mmView.renderer.setClipRect(rect)

        let factor : Float = 1.8
        var ratio : Float = 100 / Float(fragment.width)
        ratio = ratio * Float(fragment.height)
        mmView.drawTexture.drawScaled(textureWidget.texture!, x: rect.right() - 100, y: rect.y, width: 100 * factor, height: ratio * factor)
        
        ratio = 100 / rect.width
        ratio = ratio * rect.height

        let height : Float = ratio * factor
        let y : Float = (100 / rect.width) * -scrollArea.offsetY * 1.8
        mmView.drawBox.draw(x: rect.right() - 100, y: rect.y + y, width: 100, height: height, round: 0, borderSize: 0, fillColor: SIMD4<Float>(1,1,1,0.1))
        mmView.renderer.setClipRect()
        //
        
        // Function DND
        if let f = dndFunction {
            mmView.drawBox.draw(x: rect.x, y: rect.y + f.rect.y - CodeContext.fSpace + scrollArea.offsetY, width: rect.width, height: CodeContext.fSpace, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, 0.2))
        }
        
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
            codeAccess.setSelected(comp, codeContext)
            editor.codeProperties.setSelected(comp, codeContext)
        }
    }
    
    /// Runs the component to generate code without any drawing
    func dryRunComponent(_ comp: CodeComponent,_ propertyOffset: Int = 0)
    {
        codeContext.fragment = nil
        codeContext.reset(rect.width, propertyOffset)
        comp.draw(globalApp!.mmView, codeContext)
        codeContext.fragment = fragment
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
                    
                    let constant = defaultConstantForType(sourceFrag.evaluateType())
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
            } else
            if sourceFrag.fragmentType == .OutVariable
            {
                let undo = self.undoStart("Variable Reference: \(sourceFrag.name)")
                destBlock.blockType = .OutVariable
                destBlock.fragment.fragmentType = .OutVariable
                destBlock.fragment.properties = sourceFrag.properties
                destBlock.fragment.typeName = sourceFrag.typeName
                destBlock.fragment.name = sourceFrag.name
                destBlock.fragment.referseTo = sourceFrag.referseTo
                
                let constant = defaultConstantForType(sourceFrag.evaluateType())
                destBlock.statement.fragments.append(constant)

                self.updateCode(compile: true)
                self.undoEnd(undo)
            } else
            // If switch
            if sourceFrag.typeName == "block" && (sourceFrag.name == "if" || sourceFrag.name == "if else"){
                destBlock.blockType = .IfHeader
                destBlock.fragment.fragmentType = .If
                destBlock.fragment.typeName = "bool"
                destBlock.fragment.name = "if"
                destBlock.fragment.properties = [.Selectable]
                
                let statement = CodeStatement(.Boolean)
                var frag = CodeFragment(.ConstantValue, "float", "", [.Selectable, .Dragable, .Targetable])
                statement.fragments.append(frag)
                
                frag = CodeFragment(.Comparison, "bool", "==", [.Selectable])
                statement.fragments.append(frag)

                frag = CodeFragment(.ConstantValue, "float", "", [.Selectable, .Dragable, .Targetable])
                statement.fragments.append(frag)
                
                destBlock.fragment.arguments.append(statement)
                
                destBlock.children.append(CodeBlock(.Empty))
                destBlock.children.append(CodeBlock(.Empty))
                destBlock.children.append(CodeBlock(.End))

                destBlock.children[0].fragment.addProperty(.Selectable)
                destBlock.children[1].fragment.addProperty(.Selectable)
                
                if sourceFrag.name == "if else" {
                    var newBlock : CodeBlock? = nil
                    if let pF = destBlock.parentFunction {
                        if let index = pF.body.firstIndex(of: destBlock) {
                            newBlock = CodeBlock(.ElseHeader)
                            pF.body.insert(newBlock!, at: index+1)
                        }
                    } else
                    if let pB = destBlock.parentBlock {
                        if let index = pB.children.firstIndex(of: destBlock) {
                            newBlock = CodeBlock(.ElseHeader)
                            pB.children.insert(newBlock!, at: index+1)
                        }
                    }
                    if let block = newBlock {
                        block.fragment.fragmentType = .Else
                        block.fragment.typeName = "bool"
                        block.fragment.name = "else"
                        block.fragment.properties = [.Selectable]
                        
                        block.children.append(CodeBlock(.Empty))
                        block.children.append(CodeBlock(.Empty))
                        block.children.append(CodeBlock(.End))

                        block.children[0].fragment.addProperty(.Selectable)
                        block.children[1].fragment.addProperty(.Selectable)
                    }
                }
            } else
            // For switch
            if sourceFrag.typeName == "block" && sourceFrag.name == "for" {
                destBlock.blockType = .ForHeader
                destBlock.fragment.fragmentType = .For
                destBlock.fragment.typeName = ""
                destBlock.fragment.name = "for"
                destBlock.fragment.properties = [.Selectable]
                            
                // Left part
                var statement = CodeStatement(.List)
                var frag = CodeFragment(.VariableDefinition, "int", "i", [.Selectable, .Dragable, .Targetable])
                let varUUID = frag.uuid
                statement.fragments.append(frag)
                
                frag = CodeFragment(.Assignment, "", "=", [.Selectable])
                statement.fragments.append(frag)

                frag = CodeFragment(.ConstantValue, "int", "", [.Selectable, .Dragable, .Targetable])
                frag.values["value"] = 0
                frag.values["max"] = 10
                statement.fragments.append(frag)
        
                destBlock.fragment.arguments.append(statement)

                // Middle part
                statement = CodeStatement(.Boolean)
                frag = CodeFragment(.VariableReference, "int", "i", [.Selectable, .Dragable, .Targetable])
                frag.referseTo = varUUID
                statement.fragments.append(frag)
                
                frag = CodeFragment(.Comparison, "", "<", [.Selectable])
                statement.fragments.append(frag)

                frag = CodeFragment(.ConstantValue, "int", "", [.Selectable, .Dragable, .Targetable])
                frag.values["value"] = 10
                frag.values["max"] = 100
                statement.fragments.append(frag)
                
                destBlock.fragment.arguments.append(statement)

                // Right part
                statement = CodeStatement(.Arithmetic)
                frag = CodeFragment(.VariableReference, "int", "i", [.Selectable, .Dragable, .Targetable])
                frag.referseTo = varUUID
                statement.fragments.append(frag)
                
                frag = CodeFragment(.Assignment, "", "+=", [.Selectable])
                statement.fragments.append(frag)

                frag = CodeFragment(.ConstantValue, "int", "", [.Selectable, .Dragable, .Targetable])
                frag.values["value"] = 1
                frag.values["max"] = 100
                statement.fragments.append(frag)
                
                destBlock.fragment.arguments.append(statement)
                //
                
                destBlock.children.append(CodeBlock(.Empty))
                destBlock.children.append(CodeBlock(.Empty))
                destBlock.children.append(CodeBlock(.End))

                destBlock.children[0].fragment.addProperty(.Selectable)
                destBlock.children[1].fragment.addProperty(.Selectable)
            }
        } else
        {
            let undo = self.undoStart("Drag and Drop")
            
            // Drag on a constant value or when the target has only one component, i.e. single float values
            if (destFrag.fragmentType == .ConstantValue || destFrag.evaluateComponents() == 1) {
                let sourceComponents = sourceFrag.evaluateComponents()
                var compName : String = sourceFrag.qualifier
                if sourceComponents > 1 {
                    let compArray : [String] = ["x", "y", "z", "w"]
                    if let parentStatement = destFrag.parentStatement {
                        let argumentIndex = parentStatement.isArgumentIndexOf
                        if argumentIndex < sourceComponents {
                            compName = compArray[argumentIndex]
                        } else {
                            compName = compArray[0]
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
            if sourceFrag.fragmentType == .VariableReference || sourceFrag.fragmentType == .OutVariable {
                let sourceComponents = sourceFrag.evaluateComponents()
                let destComponents = destFrag.evaluateComponents()
                
                sourceFrag.copyTo(destFrag)
                destFrag.addProperty(.Targetable)

                if sourceComponents != destComponents && sourceComponents > 1 {
                    // --- Need to add a qualification to match
                    
                    let compArray = ["x", "y", "z", "w"]
                    let validRange = sourceComponents - 1
                    
                    var counter = 0
                    for _ in 0..<destComponents {
                        if counter > validRange {
                            counter = 0
                        }
                        
                        destFrag.qualifier += compArray[counter]
                        counter += 1
                    }
                }
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
                
                for format in sourceFrag.argumentFormat! {
                    
                    var argFormatToUse = typeName
                    let supportedFormats = format.components(separatedBy: "|")
                    
                    if supportedFormats.contains(typeName) == false {
                        argFormatToUse = supportedFormats[0]
                    }
                    
                    let constant = defaultConstantForType(argFormatToUse)
                    
                    let statement = CodeStatement(.List)
                    statement.fragments.append(constant)
                    
                    destFrag.arguments.append(statement)
                }
                #if DEBUG
                print("Drop #6")
                #endif
            }
                        
            self.updateCode(compile: true)
            self.undoEnd(undo)
        }
    }
    
    /// Creates the arguments for the fragment
    func createFragmentArguments(_ destFrag: CodeFragment, _ sourceFrag: CodeFragment)
    {
        if let sourceFormats = sourceFrag.argumentFormat, sourceFrag.fragmentType == .Primitive || sourceFrag.fragmentType == .ConstantDefinition {
            // Case1, source is directly from the source list and we need to create the arguments based on the argumentFormat
            if sourceFormats.count > sourceFrag.arguments.count {

                for format in sourceFormats
                {
                    let types = format.components(separatedBy: "|")
                    let typeName = types[0]
                    
                    let constant = defaultConstantForType(typeName)
                    
                    let statement = CodeStatement(.List)
                    statement.fragments.append(constant)
                    
                    destFrag.arguments.append(statement)
                }
            }
        } else {
            destFrag.argumentFormat = nil
            destFrag.arguments = []
        }
    }
}
