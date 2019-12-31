//
//  Editor.swift
//  Render-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class Editor
{
    let sourceList      : SourceList!
    let mmView          : MMView!
    
    let codeEditor      : CodeEditor
    var codeProperties  : CodeProperties
    
    // Toolbar
    var tabButton       : MMTabButtonWidget

    required init(_ view: MMView)
    {
        mmView = view
        sourceList = SourceList(view)
        codeEditor = CodeEditor(view)
        codeProperties = CodeProperties(view)

        tabButton = MMTabButtonWidget(mmView)
        tabButton.addTab("Artist")
        tabButton.addTab("Developer")
        tabButton.currentTab = tabButton.items[1]
        
        codeEditor.editor = self
        codeProperties.editor = self
    }
    
    func activate()
    {
        mmView.registerWidgets(widgets: sourceList, codeEditor, codeProperties, tabButton)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: sourceList, codeEditor, codeProperties, tabButton)
    }
    
    func drawRegion(_ region: MMRegion)
    {
        if region.type == .Top {
            region.layoutH( startX: 3, startY: 4 + 44, spacing: 10, widgets: tabButton)
            tabButton.draw()
        } else
        if region.type == .Left {
            sourceList.rect.copy(region.rect)
            sourceList.draw()
        } else
        if region.type == .Editor {
            codeEditor.rect.copy(region.rect)
            codeEditor.draw()
        } else
        if region.type == .Bottom {
            region.rect.y = globalApp!.mmView.renderer.cHeight - region.rect.height - 1
            codeProperties.rect.copy(region.rect)
            codeProperties.draw()
        }
    }
}
