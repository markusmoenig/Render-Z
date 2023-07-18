//
//  DeveloperEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class DeveloperEditor   : Editor
{
    let codeList        : CodeFragList
    let mmView          : MMView!
    
    let codeEditor      : CodeEditor
    var codeProperties  : CodeProperties
    
    var navButton       : MMButtonWidget!
    var showButton      : MMButtonWidget!
    var liveButton      : MMButtonWidget!

    required init(_ view: MMView)
    {
        mmView = view
        codeList = CodeFragList(view)
        codeEditor = CodeEditor(view)
        codeProperties = CodeProperties(view)
        
        var liveSkin = MMSkinButton()
        liveSkin.borderColor = SIMD4<Float>(0.824, 0.396, 0.204, 1.000)
        liveSkin.hoverColor = SIMD4<Float>(0.824, 0.396, 0.204, 1.000)
        liveSkin.activeColor = SIMD4<Float>(0.824, 0.396, 0.204, 1.000)

        navButton = MMButtonWidget( mmView, skinToUse: liveSkin, text: "NAV" )
        showButton = MMButtonWidget( mmView, skinToUse: liveSkin, text: "SHOW" )
        liveButton = MMButtonWidget( mmView, skinToUse: liveSkin, text: "LIVE" )
        
        liveButton.rect.width += 16
        showButton.rect.width += 4

        super.init()
        
        navButton.clicked = { (event) -> Void in
            let editor = globalApp!.developerEditor.codeEditor
            if editor.hasNav == true {
                self.navButton.removeState(.Checked)
                editor.hasNav = false
            } else {
                editor.hasNav = true
            }
            self.mmView.update()
        }
        navButton.addState(.Checked)
        
        showButton.clicked = { (event) -> Void in
            let editor = globalApp!.developerEditor.codeEditor
            if editor.showCode == true {
                self.showButton.removeState(.Checked)
                editor.showCode = false
            } else {
                editor.showCode = true
            }
            self.mmView.update()
        }
        showButton.addState(.Checked)
        
        liveButton.clicked = { (event) -> Void in
            let editor = globalApp!.developerEditor.codeEditor
            if editor.liveEditing == true {
                self.liveButton.removeState(.Checked)
                editor.liveEditing = false
            } else {
                editor.liveEditing = true
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
            }
        }
        liveButton.addState(.Checked)
        
        codeEditor.editor = self
        codeProperties.editor = self
    }
    
    override func activate()
    {
        mmView.registerWidgets(widgets: codeList, codeEditor, codeProperties, showButton, liveButton, navButton)
    }
    
    override func deactivate()
    {
        codeProperties.clear()
        mmView.deregisterWidgets(widgets: codeList, codeEditor, codeProperties, showButton, liveButton, navButton)
    }
    
    override func render()
    {
        let rect = codeEditor.getPreviewRect()
        globalApp!.currentPipeline!.render(rect.width, rect.height)
    }
    
    override func setComponent(_ component: CodeComponent)
    {
        // Store scroll offset of the previous component
        if let component = codeEditor.codeComponent {
            component.scrollOffsetY = codeEditor.scrollArea.offsetY
        }
        codeEditor.codeComponent = component
        //codeEditor.codeHasRendered = false
        codeEditor.clearSelection()
        if let uuid = component.selected {
            component.selectUUID(uuid, codeEditor.codeContext)
            codeProperties.needsUpdate = true
        }
        updateOnNextDraw(compile: false)
        
        mmView.deregisterPopups()
    }
    
    override func instantUpdate()
    {
        codeEditor.updateCode(compile: true)
    }
    
    override func updateOnNextDraw(compile: Bool = true)
    {
        codeEditor.needsUpdate = true
        if codeEditor.codeChanged == false {
            codeEditor.codeChanged = compile
        }
        
        if self.codeEditor.rect.width > 0 {//&& codeEditor.codeChanged == false {
            self.codeEditor.update()
        }
    }

    override func drawRegion(_ region: MMRegion)
    {
        if region.type == .Top {
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 43, spacing: 10, widgets: globalApp!.topRegion!.graphButton)
            globalApp!.topRegion!.graphButton.draw()
            
            navButton.rect.x = (globalApp!.topRegion!.rect.width - navButton.rect.width - showButton.rect.width - liveButton.rect.width - 24) / 2
            navButton.rect.y = 4 + 44
            navButton.draw()
            
            showButton.rect.x = navButton.rect.right() + 12
            showButton.rect.y = 4 + 44
            showButton.draw()
            
            liveButton.rect.x = showButton.rect.right() + 12
            liveButton.rect.y = 4 + 44
            liveButton.draw()
        } else
        if region.type == .Left {
            region.rect.width = CodeFragList.openWidth
            codeList.rect.copy(region.rect)
            codeList.draw()
        } else
        if region.type == .Editor {
            codeEditor.rect.copy(region.rect)
            codeEditor.draw()
        } else
        if region.type == .Right {
            if globalApp!.sceneGraph.currentWidth > 0 {
                region.rect.x = globalApp!.mmView.renderer.cWidth - region.rect.width
                globalApp!.sceneGraph.rect.copy(region.rect)
                globalApp!.sceneGraph.draw()
            }
        } else
        if region.type == .Bottom {
            region.rect.y = globalApp!.mmView.renderer.cHeight - region.rect.height - 1
            codeProperties.rect.copy(region.rect)
            codeProperties.draw()
        }
    }
    
    override func getBottomHeight() -> Float
    {
        return 160
    }
    
    override func undoComponentStart(_ name: String) -> CodeUndoComponent
    {
        return codeEditor.undoStart(name)
    }
    
    override func undoComponentEnd(_ undoComponent: CodeUndoComponent)
    {
        codeEditor.undoEnd(undoComponent)
    }
}
