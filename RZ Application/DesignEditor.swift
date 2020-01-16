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
    var fragment            : MMFragment
            
    var designComponent     : CodeComponent? = nil
    
    var editor              : ArtistEditor!

    var needsUpdate         : Bool = false
    var designChanged       : Bool = false
        
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()

    override init(_ view: MMView)
    {
        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        
        super.init(view)

        zoom = mmView.scaleFactor
        
        //dropTargets.append( "SourceFragmentItem" )
        
        needsUpdate = true
        designChanged = true
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
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    override func update()
    {
        if fragment.width != rect.width * zoom || fragment.height != rect.height * zoom {
            fragment.allocateTexture(width: rect.width * zoom, height: rect.height * zoom)
        }
                
        if fragment.encoderStart()
        {
            
            fragment.encodeEnd()
            
            if designChanged {
                globalApp!.pipeline.build(scene: globalApp!.project.selected!)
                designChanged = false
            }
            globalApp!.pipeline.render(rect.width * zoom, rect.height * zoom)
        }
        needsUpdate = false
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        // Need to update the code display ?
        if needsUpdate || fragment.width != rect.width * zoom {
            update()
        }

        // Is playing ?
        if globalApp!.codeBuilder.isPlaying {
            globalApp!.pipeline.render(rect.width * zoom, rect.height * zoom)
        }
        
        // Do the preview
        if let texture = globalApp!.pipeline.resultTexture {
            mmView.drawTexture.draw(texture, x: rect.x, y: rect.y, zoom: zoom)
            globalApp!.pipeline.renderIfResolutionChanged(rect.width * zoom, rect.height * zoom)
        } else {
            mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor: mmView.skin.Code.background)
        }
        
        mmView.drawTexture.draw(fragment.texture, x: rect.x, y: rect.y, zoom: zoom)
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
                componentChanged(newState, oldState)
            }
            self.mmView.undoManager!.setActionName(undoComponent.name)
        }
        
        componentChanged(undoComponent.originalData, undoComponent.processedData)
    }
}
