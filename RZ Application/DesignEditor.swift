//
//  CodeEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class DesignEditor          : MMWidget
{
    enum GizmoState {
        case None, Combo2D, Combo3D, Camera2D, Camera3D
    }
    
    var fragment            : MMFragment
            
    var designComponent     : CodeComponent? = nil
    var gizmoState          : GizmoState = .None
    
    var editor              : ArtistEditor!
    
    var groundEditor        : GroundEditor

    var needsUpdate         : Bool = false
    var designChanged       : Bool = false
        
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    var mouseDownItemPos    : SIMD2<Float> = SIMD2<Float>(0,0)

    var gizmoCombo2D        : GizmoCombo2D
    var gizmoCombo3D        : GizmoCombo3D
    var gizmoCamera2D       : GizmoCamera2D
    var gizmoCamera3D       : GizmoCamera3D
    var currentGizmo        : GizmoBase? = nil
    
    var dispatched          : Bool = false
    var zoomBuffer          : Float = 0
    
    var blockRendering      : Bool = false
    
    var isDraggingKnob      : Bool = false
    var knobRect            : MMRect = MMRect()

    override init(_ view: MMView)
    {
        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        gizmoCombo2D = GizmoCombo2D(view)
        gizmoCombo3D = GizmoCombo3D(view)
        gizmoCamera2D = GizmoCamera2D(view)
        gizmoCamera3D = GizmoCamera3D(view)
        
        groundEditor = GroundEditor(view)

        super.init(view)

        zoom = mmView.scaleFactor
                
        needsUpdate = true
        designChanged = true
    }
    
    /// Update the gizmo state
    func updateGizmo()
    {
        currentGizmo = nil
        gizmoState = .None
        
        if let comp = designComponent {
            if comp.componentType == .SDF2D || comp.componentType == .Transform2D {
                gizmoState = .Combo2D
                currentGizmo = gizmoCombo2D
            } else
            if comp.componentType == .SDF3D || comp.componentType == .Transform3D || comp.componentType == .PointLight3D {
                gizmoState = .Combo3D
                currentGizmo = gizmoCombo3D
            } else
            if comp.componentType == .Camera2D  {
                gizmoState = .Camera2D
                currentGizmo = gizmoCamera2D
            } else
            if comp.componentType == .Camera3D  {
                gizmoState = .Camera3D
                currentGizmo = gizmoCamera3D
            }
            
            if let gizmo = currentGizmo {
                gizmo.rect.copy(rect)
                gizmo.setComponent(comp)
            }
        } else {
            gizmoState = .None
        }
    }
    
    /// Drag and Drop Target
    override func dragEnded(event: MMMouseEvent, dragSource: MMDragSource)
    {
        /*
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
        }*/
    }
    
    // For internal drags from the editor, i.e. variable references etc
    override func dragTerminated() {
        mmView.unlockFramerate()
        mouseIsDown = false
    }
    
    /// Disable hover when mouse leaves the editor
    override func mouseLeave(_ event: MMMouseEvent) {
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if let component = designComponent {
            if component.componentType == .Ground3D {
                groundEditor.mouseMoved(event)
                return
            }
        }
        
        if let gizmo = currentGizmo, editor.designProperties.hoverMode != .NodeUIMouseLocked, editor.designProperties.hoverUITitle == nil {
            gizmo.rect.copy(rect)
            gizmo.mouseMoved(event)
        }
        
        if isDraggingKnob {
            let sceneGraph = globalApp!.sceneGraph
            sceneGraph.currentWidth = min(max(mouseDownItemPos.x + (mouseDownPos.x - event.x), 300), 900)
            sceneGraph.openWidth = sceneGraph.currentWidth
            mmView.update()
        } else
        if currentGizmo == nil || currentGizmo!.hoverState == .Inactive {
            editor.designProperties.mouseMoved(event)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif
        
        if let component = designComponent {
            if component.componentType == .Ground3D {
                groundEditor.mouseDown(event)
                return
            }
        }
        
        if let gizmo = currentGizmo {
            gizmo.rect.copy(rect)
            gizmo.mouseDown(event)
        }
        
        // Handle properties click
        if currentGizmo == nil || (currentGizmo!.hoverState == .Inactive && currentGizmo!.clickWasConsumed == false) {
            editor.designProperties.mouseDown(event)
        }
        
        // Clicked on the knob
        if globalApp!.sceneGraph.currentWidth > 0 && knobRect.contains(event.x, event.y) {
            isDraggingKnob = true
            mouseDownPos.x = event.x
            mouseDownPos.y = event.y
            mouseDownItemPos.x = globalApp!.sceneGraph.currentWidth
            mmView.mouseTrackWidget = self
            globalApp!.currentPipeline!.setMinimalPreview(true)
            return
        }
        
        //  Handle selection click
        if editor.designProperties.hoverMode == .None && editor.designProperties.hoverUITitle == nil && (currentGizmo == nil || (currentGizmo!.hoverState == .Inactive && currentGizmo!.clickWasConsumed == false)) {
            
            let x : Float = event.x - rect.x
            let y : Float = event.y - rect.y
            
            // Selection
            if let texture = globalApp!.currentPipeline!.getTextureOfId("id") {
                
                if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .rgba32Float) {
                
                    globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
                    
                    let region = MTLRegionMake2D(min(Int(x), convertTo.width-1), min(Int(y), convertTo.height-1), 1, 1)

                    var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(repeating: 0), count: 1)
                    //convertTo.getBytes(UnsafeMutableRawPointer(mutating: texArray), bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * convertTo.width), from: region, mipmapLevel: 0)
                    texArray.withUnsafeMutableBytes { texArrayPtr in
                        convertTo.getBytes(texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * convertTo.width), from: region, mipmapLevel: 0)
                    }
                    let value = texArray[0]
                    
                    var valid : Bool = true
                    if globalApp!.currentSceneMode == .TwoD && value.x > 0 {
                        valid = false
                    }
                               
                    if let id = globalApp!.currentPipeline!.codeBuilder.sdfStream.ids[Int(value.w)], valid {
                        blockRendering = true
                        globalApp!.sceneGraph.setCurrent(stage: globalApp!.project.selected!.getStage(.ShapeStage), stageItem: id.0.last, component: id.1)
                        blockRendering = false
                    } else {
                        // Select Base Object
                        //globalApp!.sceneGraph.setCurrent(stage: globalApp!.sceneGraph.currentStage!, stageItem: globalApp!.sceneGraph.currentStageItem)
                        // Select World
                        //globalApp!.sceneGraph.setCurrent(stage: globalApp!.project.selected!.getStage(.PreStage))
                    }
                }
            }            
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if let component = designComponent {
            if component.componentType == .Ground3D {
                groundEditor.mouseUp(event)
                return
            }
        }

        if let gizmo = currentGizmo {
            gizmo.mouseUp(event)
        }
        if currentGizmo == nil || currentGizmo!.hoverState == .Inactive {
            editor.designProperties.mouseUp(event)
        }
        
        if isDraggingKnob {
            isDraggingKnob = false
            mmView.mouseTrackWidget = nil
            globalApp!.currentPipeline!.setMinimalPreview(false)
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent) {
        if let component = designComponent {
            if component.componentType == .Ground3D {
                groundEditor.mouseScrolled(event)
                return
            }
        }
    }
    
    /*
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS)
        // On iOS only scroll when nothing else is going on
        if let gizmo = currentGizmo {
            if gizmo.hoverState != .Inactive {
                return
            }
        }
        if editor.designProperties.hoverMode != .None {
            return
        }
        #endif
        
        if globalApp!.currentSceneMode == .TwoD {
            gizmoCombo2D.mouseScrolled(event)
        } else {
            gizmoCombo3D.mouseScrolled(event)
            if let comp = designComponent {
                if comp.componentType == .Camera3D {
                    editor.designProperties.setSelected(comp)
                }
            }
        }
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        if globalApp!.currentSceneMode == .TwoD {
            gizmoCombo2D.pinchGesture(scale, firstTouch)
        } else {
            gizmoCombo3D.pinchGesture(scale, firstTouch)
            if let comp = designComponent {
                if comp.componentType == .Camera3D {
                    editor.designProperties.setSelected(comp)
                }
            }
        }
    }*/
    
    override func update()
    {
        if fragment.width != rect.width * zoom || fragment.height != rect.height * zoom {
            fragment.allocateTexture(width: rect.width * zoom, height: rect.height * zoom)
        }
                
        if fragment.encoderStart()
        {
            fragment.encodeEnd()
            
            if designChanged {
                globalApp!.currentPipeline!.build(scene: globalApp!.project.selected!)
                designChanged = false
            }
            if blockRendering == false {
                globalApp!.currentPipeline!.render(rect.width, rect.height)
            }
        }
        needsUpdate = false
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        // Texture ?
        if let component = designComponent {
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
        
        if let component = designComponent {
            if component.componentType == .Ground3D {
                groundEditor.rect.copy(rect)
                groundEditor.draw()
                
                if let texture = globalApp!.currentPipeline!.finalTexture {
                    let width : Float = Float(texture.width) / 4
                    let height : Float = Float(texture.height) / 4
                    
                    let x : Float = rect.right() - width
                    let y : Float = rect.y

                    mmView.drawTexture.drawScaled(texture, x: x, y: y, width: width, height: height)
                }
                return
            }
        }
        
        // Need to update the code display ?
        if /*needsUpdate ||*/ fragment.width != rect.width * zoom {
            update()
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
        } else {
            mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.background)
        }
        
        mmView.drawTexture.draw(fragment.texture, x: rect.x, y: rect.y, zoom: zoom)
        
        // Knob
        if globalApp!.sceneGraph.currentWidth > 0 {
            let halfKnobWidth : Float = 6
            knobRect.x = rect.right() - halfKnobWidth - 8
            knobRect.y = rect.y + rect.height / 2 - halfKnobWidth * 2
            knobRect.width = halfKnobWidth * 2.2
            knobRect.height = halfKnobWidth * 9

            if isDraggingKnob == false {
                mmView.drawBox.draw( x: knobRect.x, y: knobRect.y, width: knobRect.width - halfKnobWidth, height: knobRect.height, round: 6, fillColor : SIMD4<Float>( 0, 0, 0, 1))
            } else {
                mmView.drawBox.draw( x: knobRect.x, y: knobRect.y, width: knobRect.width - halfKnobWidth, height: knobRect.height, round: 6, fillColor : SIMD4<Float>( 0.5, 0.5, 0.5, 1))
            }
        }
        
        if let gizmo = currentGizmo, designComponent != nil {
            gizmo.rect.copy(rect)
            gizmo.draw()
        }
    }
    
    func undoStart(_ name: String) -> CodeUndoComponent
    {
        let codeUndo = CodeUndoComponent(name)

        if let component = designComponent {
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
        if let component = designComponent {
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
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                componentChanged(newState, oldState)
            }
            self.mmView.undoManager!.setActionName(undoComponent.name)
        }
        
        componentChanged(undoComponent.originalData, undoComponent.processedData)
    }
}
