//
//  App.swift
//  Framework
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class App
{
    var mmView          : MMView
    var leftRegion      : LeftRegion?
    var topRegion       : TopRegion?
    var rightRegion     : RightRegion?
    var bottomRegion    : BottomRegion?
    var editorRegion    : EditorRegion?
    
    var layerManager    : LayerManager
    
    var changed         : Bool = false
    
    let gizmo           : Gizmo

    init(_ view : MMView )
    {
        mmView = view
    
        layerManager = LayerManager()
        gizmo = Gizmo(view, layerManager: layerManager)
        layerManager.app = self
        
        topRegion = TopRegion( mmView, app: self )
        leftRegion = LeftRegion( mmView, app: self )
        rightRegion = RightRegion( mmView, app: self )
        bottomRegion = BottomRegion( mmView, app: self )
        editorRegion = EditorRegion( mmView, app: self )
        
        mmView.leftRegion = leftRegion
        mmView.topRegion = topRegion
        mmView.rightRegion = rightRegion
        mmView.bottomRegion = bottomRegion
        mmView.editorRegion = editorRegion
        
        setChanged()
    }

    func setChanged()
    {
        changed = true
        rightRegion!.changed = true
    }
}

class AppUndo : UndoManager
{
    
}


