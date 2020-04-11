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
    
    var codeContext1    : CodeContext
    var codeContext2    : CodeContext
    
    var currentTexture  : MTLTexture? = nil
    var texture1        : MTLTexture? = nil
    var texture2        : MTLTexture? = nil
    
    var currentComponent: CodeComponent? = nil

    var codeAccess      : CodeAccess!
        
    var editor          : DeveloperEditor!

    var needsUpdate     : Bool = false
    var codeChanged     : Bool = false
        
    var mouseIsDown     : Bool = false
    var mouseDownPos    : SIMD2<Float> = SIMD2<Float>()
    var mousePos        : SIMD2<Float> = SIMD2<Float>()

    var pinchBuffer     : Float = 0
    
    var dndFunction     : CodeFunction? = nil
    
    var orientationDrag : Bool = false
    var orientationHeight: Float = 0
    
    var orientationRatio: Float = 0
    var orientationRect : MMRect = MMRect()
    
    var codeClipboard   : CodeClipboard!
    
    var liveEditing     : Bool = true
    var codeHasRendered : Bool = false
    var codeIsUpdating  : Bool = false

    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .HorizontalAndVertical)

        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        textureWidget = MMTextureWidget( view, texture: fragment.texture )
        
        codeContext1 = CodeContext(view, fragment, view.openSans, 0.5)
        codeContext2 = CodeContext(view, fragment, view.openSans, 0.5)

        codeContext = codeContext1
        
        currentTexture = fragment.texture
        texture1 = fragment.texture
        texture2 = fragment.allocateTexture(width: 10, height: 10, output: false)
        
        super.init(view)
        
        codeClipboard = CodeClipboard(self)
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
        mousePos.x = event.x
        mousePos.y = event.y
        
        if orientationDrag == true {
            var offset : Float = mouseDownPos.y - event.y
            
            offset /= orientationRatio
            scrollArea.offsetY += offset
            scrollArea.offsetX += (mouseDownPos.x - event.x) / (100 / codeContext.width)
            
            mouseDownPos.x = event.x
            mouseDownPos.y = event.y

            scrollArea.checkOffset(widget: textureWidget, area: rect)
            if let comp = codeComponent {
                comp.scrollOffsetY = scrollArea.offsetY
            }
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
                drag.pWidgetOffset!.x = event.x - selFragment.rect.x - rect.x
                drag.pWidgetOffset!.y = event.y - selFragment.rect.y - rect.y - scrollArea.offsetY
                
                drag.codeFragment = processFragmentForCopy(selFragment)
                 
                var dragName : String
                if selFragment.fragmentType == .ConstantValue {
                    dragName = selFragment.getValueString()
                } else {
                    dragName = selFragment.typeName + " " + selFragment.name
                }
            
                let texture = editor.codeList.listWidget.createGenericThumbnail(dragName, selFragment.rect.width + 2*codeContext.gapX)
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
        
        // During DnD, check if we have to scroll the code
        if codeContext.dropFragment != nil {
            let scrollHeight = rect.height / 5
            
            func scroll()
            {
                if mouseIsDown && codeContext.dropFragment != nil {
                    if mousePos.y > rect.bottom() - scrollHeight {
                        // Scroll Down
                        scrollArea.offsetY -= 2;
                        scrollArea.checkOffset(widget: textureWidget, area: rect)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            scroll()
                        }
                    } else
                    if mousePos.y < rect.y + scrollHeight {
                        // Scroll Up
                        scrollArea.offsetY += 2;
                        scrollArea.checkOffset(widget: textureWidget, area: rect)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            scroll()
                        }
                    }
                }
            }
            
            scroll()
        }
                
        if let comp = codeComponent {
            let oldFunc = codeContext.hoverFunction
            let oldBlock = codeContext.hoverBlock
            let oldFrag = codeContext.hoverFragment
            
            comp.codeAt(event.x - rect.x - scrollArea.offsetX, event.y - rect.y - scrollArea.offsetY, codeContext)
            
            codeContext.dropIsValid = false
            if codeContext.dropFragment != nil && codeContext.hoverFragment != nil {
                codeContext.checkIfDropIsValid(codeContext.hoverFragment!)
            }
            
            if oldFunc !== codeContext.hoverFunction || oldBlock !== codeContext.hoverBlock || oldFrag !== codeContext.hoverFragment {
                mmView.update()
            }
        }
    }
    
    /// Processes the fragment and returns a copy suitable for copying into the code editor
    func processFragmentForCopy(_ selFragment: CodeFragment) -> CodeFragment?
    {
        let copyFragment : CodeFragment? = selFragment.createCopy()
        codeContext.dropOriginalUUID = selFragment.uuid
        
        copyFragment?.parentBlock = selFragment.parentBlock
        if selFragment.fragmentType == .TypeDefinition {
            // --- Dragging the typedef of a function, create a .Primitive out of it
            if let frag = copyFragment {
            
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
            copyFragment?.fragmentType = .VariableReference
            copyFragment?.referseTo = selFragment.uuid
        }
        
        return copyFragment
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
        
        // Click in Orientation Slider
        if event.x > rect.right() - 100 && event.y <= (rect.y + orientationHeight) {
            orientationDrag = true;
            if orientationRect.contains(event.x, event.y) == false {
                var offset : Float = event.y - rect.y
                
                offset /= orientationRatio
                scrollArea.offsetY = -offset
                scrollArea.offsetX = -(event.x - (rect.right() - 100)) / (100 / codeContext.width)
                scrollArea.checkOffset(widget: textureWidget, area: rect)
                
                if let comp = codeComponent {
                    comp.scrollOffsetY = scrollArea.offsetY
                }
                mmView.update()
            }
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
            
            codeClipboard.updateSelection(codeContext.selectedFragment, codeContext.selectedBlock)
                        
            if oldSelected != comp.selected {

                mmView.update()
                DispatchQueue.main.async {
                    self.editor.codeProperties.setSelected(comp, self.codeContext)
                    self.codeAccess.setSelected(comp, self.codeContext)
                }
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
        // If active scroll scene graph
        if globalApp!.project.graphIsActive {
            globalApp!.sceneGraph.mouseScrolled(event)
            return
        }
        
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
            if let codeComponent = self.codeComponent {
                codeComponent.scrollOffsetY = scrollArea.offsetY
            }
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
        codeIsUpdating = true
        DispatchQueue.main.async {
            
            var workingTexture : MTLTexture? = nil
            var workingContext : CodeContext
            
            func copyContext(dest: CodeContext, source: CodeContext)
            {
                dest.hoverFragment = source.hoverFragment
                dest.hoverBlock = source.hoverBlock
                dest.hoverFunction = source.hoverFunction
                dest.selectedFragment = source.selectedFragment
                dest.selectedBlock = source.selectedBlock
                dest.selectedFunction = source.selectedFunction
            }
            
            if self.codeContext === self.codeContext1 {
                workingContext = self.codeContext2
                workingTexture = self.texture2
            } else {
                workingContext = self.codeContext1
                workingTexture = self.texture1
            }
            copyContext(dest: workingContext, source: self.codeContext)

            if self.codeChanged {
                if let comp = self.codeComponent {
                    self.dryRunComponent(comp, context: workingContext)
                }
            }
                        
            let width : Float = max(workingContext.width, 10)
            let height : Float = workingContext.height == 0 ? 500 : workingContext.height
                    
            if workingTexture!.width != Int(width * self.zoom) || workingTexture!.height != Int(height * self.zoom) {
                workingTexture = self.fragment.allocateTexture(width: Float(Int(width * self.zoom)), height: Float(Int(height * self.zoom)), output: false)
            }
            self.fragment.texture = workingTexture
            
            if self.fragment.encoderStart()
            {
                if let comp = self.codeComponent {
                    workingContext.reset(self.rect.width)
                    comp.draw(self.mmView, workingContext)
                }
                self.fragment.encodeEnd()
                self.codeClipboard.updateSelection(workingContext.selectedFragment, workingContext.selectedBlock)

                /*
                print(fragment.texture.mipmapLevelCount, fragment.width, fragment.height)
                if fragment.texture.mipmapLevelCount > 0 {
                    if let blitEncoder = fragment.commandBuffer!.makeBlitCommandEncoder() {
                        blitEncoder.generateMipmaps(for: fragment.texture)
                        blitEncoder.endEncoding()
                    }
                }*/
                
                // Set the current working contexts to be the default
                self.textureWidget.setTexture(self.fragment.texture)
                self.scrollArea.checkOffset(widget: self.textureWidget, area: self.rect)
                self.codeContext = workingContext
                
                if self.codeContext === self.codeContext1 {
                    self.texture2 = workingTexture
                } else {
                    self.texture1 = workingTexture
                }
                
                // Set Code Properties / Code Access
                if let comp = self.codeComponent, self.editor.codeProperties.needsUpdate {
                    self.editor.codeProperties.setSelected(comp, self.codeContext)
                    self.codeAccess.setSelected(comp, self.codeContext)
                }
                
                self.currentComponent = self.codeComponent
                
                // Set Scroll Area
                if let comp = self.codeComponent {
                    self.scrollArea.offsetY = comp.scrollOffsetY
                }

                self.codeHasRendered = true
                self.codeIsUpdating = false
                self.mmView.update()
                
                // Compile
                if self.codeChanged && self.liveEditing {
                    // Mark the current Component invalid
                    if let comp = self.codeComponent {
                        self.markStageItemOfComponentInvalid(comp)
                    }
                    // Compile
                    globalApp!.currentPipeline!.build(scene: globalApp!.project.selected!)
                    globalApp!.currentPipeline!.render(self.rect.width, self.rect.height)
                    self.codeChanged = false
                }
            }
        }
        needsUpdate = false
    }
    
    /// Invalidate the BuilderInstance of the StageItem of the current component
    func markStageItemOfComponentInvalid(_ component: CodeComponent)
    {
        if let stageItem = globalApp!.project.selected!.getStageItem(component) {
            //print("markStageItemOfComponentInvalid", stageItem.stageItemType, component.componentType)
            markStageItemInvalid(stageItem)
        }
    }
    
    /// Invalidate the BuilderInstance of the StageItem
    func markStageItemInvalid(_ stageItem: StageItem)
    {
        stageItem.builderInstance = nil
        
        //print("markStageItemOfComponentInvalid", stageItem.stageItemType, component.componentType)
        if stageItem.stageItemType == .RenderStage {
            globalApp!.project.selected!.invalidateCompilerInfos()
        }
        
        if stageItem.stageItemType == .ShapeStage {
            
            let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
            
            var parent : StageItem? = stageItem
            while parent != nil {
                parent?.builderInstance = nil
                parent = shapeStage.getParentOfStageItem(parent!).1
            }
        }
    }
    
    /// Runs the component to generate code without any drawing
    func dryRunComponent(_ comp: CodeComponent,_ propertyOffset: Int = 0, context: CodeContext)
    {
        context.fragment = nil
        context.reset(rect.width, propertyOffset)
        comp.draw(globalApp!.mmView, context)
        context.fragment = fragment
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        // Texture ?
        if let component = codeComponent {
            if component.componentType == .Image {
                if let texture = component.texture {
                    let rX : Float = rect.width / Float(texture.width)
                    let rY : Float = rect.height / Float(texture.height)
                    let r = min(rX, rY)
                    let xO = rect.x + (rect.width - (Float(texture.width) * r)) / 2
                    let yO = rect.y + (rect.height - (Float(texture.height) * r)) / 2
                    mmView.drawTexture.drawScaled(texture, x: xO, y: yO, width: Float(texture.width) * r, height: Float(texture.height) * r)
                    return
                }
            }
        }
        
        // Need to update the code display ?
        if needsUpdate {
            update()
        }
        
        // Need to update the codeProperties ?
        if let comp = codeComponent, editor.codeProperties.needsUpdate, codeIsUpdating == false {
            editor.codeProperties.setSelected(comp, codeContext)
        }

        // Is playing ?
        if globalApp!.currentPipeline!.codeBuilder.isPlaying {
            globalApp!.currentPipeline!.render(rect.width, rect.height)
        }
        
        // Do the preview
        if let texture = globalApp!.currentPipeline!.finalTexture {
            if rect.width == Float(texture.width) && rect.height == Float(texture.height) {
                mmView.drawTexture.draw(texture, x: rect.x, y: rect.y)
            } else {
                mmView.drawTexture.drawScaled(texture, x: rect.x, y: rect.y, width: rect.width, height: rect.height)
            }
            globalApp!.currentPipeline!.renderIfResolutionChanged(rect.width, rect.height)
            
            mmView.renderer.setClipRect(rect)
            if let comp = currentComponent {
                // Draw semi transparent function backgrounds
                for f in comp.functions {
                    var color = mmView.skin.Code.background
                    color.w = 0.9
                    
                    mmView.drawBox.draw(x: rect.x + codeContext.gapX / 2 + scrollArea.offsetX, y: rect.y + codeContext.gapY / 2 + f.rect.y + scrollArea.offsetY, width: codeContext.border - codeContext.gapX / 2, height: f.rect.height, round: 6, borderSize: 0, fillColor: color)
                    
                    mmView.drawBox.draw(x: rect.x + f.rect.x + scrollArea.offsetX, y: rect.y + f.rect.y + scrollArea.offsetY, width: f.rect.width, height: f.rect.height, round: 6, borderSize: 0, fillColor: color)
                }
            }
            mmView.renderer.setClipRect()
        } else {
            mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.background)
        }
        
        // Draw the code
        if codeHasRendered == true {
            scrollArea.rect.copy(rect)
            scrollArea.build(widget: textureWidget, area: rect, xOffset: xOffset, yOffset: yOffset)
        }
        
        // Hover and Selection Modes
        
        func drawHighlight(_ rect: MMRect, alpha: Float)
        {
            mmView.drawBox.draw( x: self.rect.x + rect.x + scrollArea.offsetX, y: self.rect.y + rect.y + scrollArea.offsetY, width: rect.width, height: rect.height, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1, 1, 1, alpha) )
        }
        func drawLeftFuncHighlight(_ function: CodeFunction, alpha: Float)
        {
            let fY : Float = function.comment.isEmpty ? 0 : codeContext.lineHeight + codeContext.gapY
            mmView.drawBox.draw( x: self.rect.x + codeContext.gapX / 2 + scrollArea.offsetX, y: self.rect.y + function.rect.y - codeContext.gapY / 2 + fY + scrollArea.offsetY, width: codeContext.border - codeContext.gapX / 2, height: codeContext.lineHeight + codeContext.gapY, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha) )
        }
        func drawLeftBlockHighlight(_ block: CodeBlock, alpha: Float)
        {
            mmView.drawBox.draw( x: self.rect.x + codeContext.gapX / 2 + scrollArea.offsetX, y: self.rect.y + block.rect.y - codeContext.gapY / 2 + scrollArea.offsetY, width: codeContext.border - codeContext.gapX / 2, height: codeContext.lineHeight + codeContext.gapY, round: 6, borderSize: 0, fillColor: SIMD4<Float>(1,1,1, alpha))
        }
        
        let hoverAlpha : Float = 0.3
        let selectedAlpha : Float = 0.4

        mmView.renderer.setClipRect(rect)
        
        if currentComponent === codeComponent {
            // Fragments
            var workRect: MMRect = MMRect()
            if codeContext.dropFragment == nil {
                
                // Highlight drawing which also highlights the opening / closing brackets
                func drawFragmentHightlight(_ frag: CodeFragment, alpha: Float)
                {
                    if frag.arguments.count > 0 {
                        workRect.copy(frag.rect)
                        workRect.width += codeContext.bracketWidth
                        drawHighlight(workRect, alpha: alpha)
                        if let last = frag.arguments.last?.fragments.last {
                            workRect.width = codeContext.bracketWidth
                            if last.arguments.count == 0 {
                                workRect.x = last.rect.right()
                            } else {
                                var depth : Int = 0
                                var l : CodeFragment = last
                                func getLast(_ frag: CodeFragment)
                                {
                                    if let last = frag.arguments.last?.fragments.last {
                                        l = last
                                        depth += 1
                                        getLast(last)
                                    }
                                }
                                getLast(last)
                                workRect.x = l.rect.right() + Float(depth) * codeContext.bracketWidth
                            }
                            drawHighlight(workRect, alpha: alpha)
                        }
                    } else
                    if frag.fragmentType == .OpeningRoundBracket || frag.fragmentType == .ClosingRoundBracket
                    {
                        if let pStatement = frag.parentStatement {
                            for p in pStatement.fragments {
                                if p.uuid == frag.uuid {
                                    drawHighlight(p.rect, alpha: alpha)
                                }
                            }
                        }
                    } else {
                        drawHighlight(frag.rect, alpha: alpha)
                    }
                }
                
                // Hover and Selection
                if let hoverFrag = codeContext.hoverFragment {
                    //drawHighlight(hoverFrag.rect, alpha: hoverAlpha)
                    drawFragmentHightlight(hoverFrag, alpha: hoverAlpha)
                }
                if let selectedFrag = codeContext.selectedFragment {
                    //drawHighlight(selectedFrag.rect, alpha: selectedAlpha)
                    drawFragmentHightlight(selectedFrag, alpha: selectedAlpha)
                }
            } else if codeContext.dropIsValid {
                // Drop Highlight
                if let hoverFrag = codeContext.hoverFragment {
                    drawHighlight(hoverFrag.rect, alpha: hoverAlpha)
                }
            }
            
            // Function: Hover and Selection
            if let hoverFunc = codeContext.hoverFunction {
                drawHighlight(hoverFunc.rect, alpha: hoverAlpha)
                // Left side
                drawLeftFuncHighlight(hoverFunc, alpha: hoverAlpha)
            }
            if let selectedFunc = codeContext.selectedFunction {
                drawHighlight(selectedFunc.rect, alpha: selectedAlpha)
                drawLeftFuncHighlight(selectedFunc, alpha: selectedAlpha)
            }
            
            // Block: Hover and Selection
            if let hoverBlock = codeContext.hoverBlock {
                drawHighlight(hoverBlock.rect, alpha: hoverAlpha)
                drawLeftBlockHighlight(hoverBlock, alpha: hoverAlpha)
            }
            if let selectedBlock = codeContext.selectedBlock {
                drawHighlight(selectedBlock.rect, alpha: selectedAlpha)
                drawLeftBlockHighlight(selectedBlock, alpha: selectedAlpha)
            }
        }
                
        // Orientation area

        orientationRatio = 100 / rect.width * 2
        orientationHeight = orientationRatio * codeContext.height
        while orientationHeight > rect.height {
            orientationRatio *= 0.75
            orientationHeight = orientationRatio * codeContext.height
        }
        mmView.drawBox.draw(x: rect.right() - 100, y: rect.y, width: 100 , height: orientationHeight, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.0,0.0,0.0,0.3))
        mmView.drawTexture.drawScaled(textureWidget.texture!, x: rect.right() - 100, y: rect.y, width: 100, height: orientationHeight)
        
        let y : Float = (-scrollArea.offsetY) * orientationRatio
        let height : Float = min(rect.height * orientationRatio, orientationHeight)
        orientationRect.x = rect.right() - 100 + -scrollArea.offsetX * (100 / codeContext.width)
        orientationRect.y = rect.y + y
        orientationRect.width = 100 * rect.width / codeContext.width
        orientationRect.height = height
        mmView.drawBox.draw(x: orientationRect.x, y: orientationRect.y, width: orientationRect.width, height: orientationRect.height, round: 0, borderSize: 0, fillColor: SIMD4<Float>(1,1,1,0.1))
        
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
        
        // Clipboard without a custom rect, needs to get clipped
        if codeClipboard.customRect == false, codeHasRendered {
            codeClipboard.draw()
        }
        
        mmView.renderer.setClipRect()
        
        // Clipboard for custom area, i.e. code frag list, should not be clipped
        if codeClipboard.customRect == true, codeHasRendered {
            codeClipboard.draw()
        }
    }
    
    /// Clears the current selection
    func clearSelection()
    {
        codeContext.selectedBlock = nil
        codeContext.selectedFragment = nil
        codeContext.selectedFunction = nil
    }
    
    /// Update the code syntax and redraws
    func updateCode(compile: Bool = false)
    {
        codeChanged = compile
        needsUpdate = true
        update()
        mmView.update()
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
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
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
                destBlock.fragment.qualifier = sourceFrag.qualifier

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
                destBlock.fragment.qualifier = sourceFrag.qualifier
                
                let constant = defaultConstantForType(sourceFrag.evaluateType())
                destBlock.statement.fragments.append(constant)

                self.updateCode(compile: true)
                self.undoEnd(undo)
            } else
            // Break, only inside loops
            if sourceFrag.typeName == "block" && (sourceFrag.name == "break") {
                var insideLoop = false
                
                func testParent(_ parent: CodeBlock)
                {
                    if parent.blockType == .ForHeader {
                        insideLoop = true
                    } else {
                        if let p = parent.parentBlock {
                            testParent(p)
                        }
                    }
                }
                
                if let p = destBlock.parentBlock {
                    testParent(p)
                }
                
                if insideLoop {
                    destBlock.blockType = .Break
                    destBlock.fragment.fragmentType = .Break
                    destBlock.fragment.typeName = "block"
                    destBlock.fragment.name = "break"
                    destBlock.fragment.properties = []
                }
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
                
                if destFrag.parentBlock!.blockType == .ForHeader && sourceFrag.fragmentType == .VariableReference {
                    // If destination is a for header, need to reset the variable references in the header
                    if let index = destFrag.parentBlock!.fragment.arguments[0].fragments.firstIndex(of: destFrag) {
                        if index == 0 {
                            for stats in destFrag.parentBlock!.fragment.arguments {
                                for frag in stats.fragments {
                                    if frag.fragmentType == .ConstantValue {
                                        frag.typeName = sourceFrag.typeName
                                        frag.values["precision"] = sourceFrag.values["precision"]
                                    } else
                                    if frag.fragmentType == .VariableReference {
                                        frag.referseTo = sourceFrag.referseTo
                                    }
                                }
                            }
                        }
                    }
                }
                
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
                var destComponents = destFrag.evaluateComponents()
                             
                // Check if we can adjust the typeName of the destFrag to that of the source based on the argumentFormat
                if let pStatement = destFrag.parentStatement, sourceComponents != destComponents {
                    let argumentIndex = pStatement.isArgumentIndexOf
                    if let argumentFormat = destFrag.argumentFormat {
                        if argumentIndex < argumentFormat.count {
                            let argument = argumentFormat[argumentIndex]
                            
                            // Sanity check, if we drop an atom (components == 1) on an incompatible type, we cannot correct it later
                            if sourceComponents == 1 && argument.contains("|") == false && argument != sourceFrag.typeName {
                                #if DEBUG
                                print("Drop #4 Exclusion")
                                #endif
                                return
                            }
                            
                            if argument.contains(sourceFrag.typeName) {
                                
                                // Replace all arguments of the parent which have the old typeName with a constant of the new type
                                if let parent = pStatement.parentFragment {
                                    for (index,statement) in parent.arguments.enumerated() {
                                        for arg in statement.fragments {
                                            if arg !== destFrag && arg.typeName == destFrag.typeName && parent.argumentFormat != nil {
                                                let aFormat = parent.argumentFormat![index]
                                                if aFormat.contains(sourceFrag.typeName) {
                                                    defaultConstantForType(sourceFrag.typeName).copyTo(arg)
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                destFrag.typeName = sourceFrag.typeName
                                destComponents = destFrag.evaluateComponents()
                            }
                        }
                    }
                }
                
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
                
                if let argumentFormat = sourceFrag.argumentFormat {
                    for format in argumentFormat {
                        
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
                }
                
                // If the typeNames don't match, check if we can set the typeName of the source to that of the destination
                // This is possible when the evaluatesTo string has an input0 parameter (i.e. output adjusts to the input)
                let typeNameBuffer = sourceFrag.typeName
                if sourceFrag.typeName != destFrag.typeName {
                    if sourceFrag.supportsType(destFrag.typeName) {
                        sourceFrag.typeName = destFrag.typeName
                    }
                }
                
                let sourceComponents = sourceFrag.evaluateComponents()
                let destComponents = destFrag.evaluateComponents()
                
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
                
                // Not allowed to change the source frag, if we change the typeName, need to set it back
                sourceFrag.typeName = typeNameBuffer
                
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
                    constant.argumentFormat = sourceFormats // Copy the argumentFormat
                    
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
