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
    let sourceList  : SourceList!
    let mmView      : MMView!
    
    let codeEditor  : CodeEditor
    
    required init(_ view: MMView)
    {
        mmView = view
        sourceList = SourceList(view)
        codeEditor = CodeEditor(view)
        
        mmView.registerWidgets(widgets: sourceList, codeEditor)

    }
    
    func activate()
    {
        mmView.registerWidgets(widgets: sourceList, codeEditor)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: sourceList)
    }
    
    func drawRegion(_ region: MMRegion)
    {
        if region.type == .Left {
            sourceList.rect.copy(region.rect)
            sourceList.draw()
        } else
        if region.type == .Editor {
            codeEditor.rect.copy(region.rect)
            codeEditor.draw()
        }
    }
}
