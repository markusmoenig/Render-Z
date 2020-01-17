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
    let codeList        : CodeList
    let mmView          : MMView!
    
    let codeEditor      : CodeEditor
    var codeProperties  : CodeProperties

    required init(_ view: MMView,_ sceneList: SceneList)
    {
        mmView = view
        codeList = CodeList(view, sceneList)
        codeEditor = CodeEditor(view)
        codeProperties = CodeProperties(view)
        
        super.init()
        
        codeEditor.editor = self
        codeProperties.editor = self
    }
    
    override func activate()
    {
        mmView.registerWidgets(widgets: codeList.sceneList, codeList.fragList, codeEditor, codeProperties)
    }
    
    override func deactivate()
    {
        codeProperties.clear()
        mmView.deregisterWidgets(widgets: codeList.sceneList, codeList.fragList, codeEditor, codeProperties)
    }
    
    override func setComponent(_ component: CodeComponent)
    {
        codeEditor.codeComponent = component
        updateOnNextDraw()
        if let uuid = component.selected {
            component.selectUUID(uuid, codeEditor.codeContext)
            codeProperties.needsUpdate = true
        }
        mmView.update()
    }
    
    override func instantUpdate()
    {
        codeEditor.updateCode(compile: true)
    }
    
    override func updateOnNextDraw(compile: Bool = true)
    {
        codeEditor.needsUpdate = true
        codeEditor.codeChanged = compile
        mmView.update()
    }
    
    override func drawRegion(_ region: MMRegion)
    {
        if region.type == .Top {
            //region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: globalApp!.topRegion!.libraryButton)
            //globalApp!.topRegion!.libraryButton.draw()
        } else
        if region.type == .Left {
            codeList.sceneList.rect.copy(region.rect)
            codeList.sceneList.rect.height /= 2
            codeList.sceneList.rect.height += SceneList.InfoHeight
            codeList.draw()
            codeList.fragList.rect.copy(region.rect)
            codeList.fragList.rect.y += codeList.sceneList.rect.height + 1
            codeList.fragList.rect.height /= 2
            codeList.fragList.rect.height -= SceneList.InfoHeight
            codeList.fragList.rect.height -= 1
            codeList.draw()
        } else
        if region.type == .Editor {
            codeEditor.rect.copy(region.rect)
            codeEditor.draw()
        } else
        if region.type == .Right {
            if globalApp!.context.currentWidth > 0 {
                region.rect.x = globalApp!.mmView.renderer.cWidth - region.rect.width
                globalApp!.context.rect.copy(region.rect)
                globalApp!.context.draw()
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
}
