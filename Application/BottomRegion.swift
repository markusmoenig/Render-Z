//
//  BottomRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class BottomRegion: MMRegion
{
    var app             : App
    var animating       : Bool = false
    
    let timeline        : MMTimeline
    let sequenceWidget  : SequenceWidget
    
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var mode            : BottomRegionMode
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        mode = .Open
        
        timeline = MMTimeline(view)
        timeline.changedCB = { (frame) in
            app.editorRegion?.result = nil
        }
        
        sequenceWidget = SequenceWidget(view, app: app)
        
        super.init( view, type: .Bottom )
        
        rect.height = 100
        self.app.topRegion!.timelineButton.addState( .Checked )
        
        mmView.registerWidget(timeline)
        mmView.registerWidget(sequenceWidget)
    }
    
    override func build()
    {
        rect.y = mmView.renderer.cHeight - rect.height

        if rect.height > 0 {
            
            // Timeline area
            timeline.rect.copy( rect )
            timeline.rect.width -= app.rightRegion!.rect.width
            timeline.draw(app.layerManager.getCurrentLayer().sequence, uuid:app.layerManager.getCurrentUUID())
            
            // Sequence area
            
            sequenceWidget.rect.copy( rect )
            sequenceWidget.rect.x = rect.right() - app.rightRegion!.rect.width
            sequenceWidget.rect.width = app.rightRegion!.rect.width
            sequenceWidget.draw()
        }
    }
    
    func switchMode()
    {
        if animating { return }
        
        if mode == .Open {
            mmView.startAnimate( startValue: rect.height, endValue: 0, duration: 500, cb: { (value,finished) in
                self.rect.height = value
                if finished {
                    self.animating = false
                    self.mode = .Closed
                    self.app.topRegion!.timelineButton.removeState( .Checked )
                }
            } )
            animating = true
        } else if rect.height != 100 {
            
            mmView.startAnimate( startValue: rect.height, endValue: 100, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.mode = .Open
                }
                self.rect.height = value
            } )
            animating = true
        }
    }
}

class SequenceWidget : MMWidget
{
    var app                 : App
    var label               : MMTextLabel
//    var menuWidget          : MMMenuWidget
//    var objectEditorWidget  : ObjectEditorWidget
    
    init(_ view: MMView, app: App)
    {
        self.app = app
        
        label = MMTextLabel(view, font: view.openSans, text:"", scale: 0.44 )//color: float4(0.506, 0.506, 0.506, 1.000))
//        objectEditorWidget = ObjectEditorWidget(view, app: app)

        /*
        // --- Object Menu
        let objectMenuItems = [
            MMMenuItem( text: "Add Child Object", cb: {print("add child") } ),
            MMMenuItem( text: "Rename Object", cb: {
                let object = app.layerManager.getCurrentObject()!
                getStringDialog(view: view, title: "Rename Object", message: "Enter new name", defaultValue: object.name, cb: { (name) -> Void in
                    object.name = name
                } )
            } ),
            MMMenuItem( text: "Delete Object", cb: {print("add child") } )
        ]
        menuWidget = MMMenuWidget( view, items: objectMenuItems )
        */

        super.init(view)
    }
    
    override func draw()
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, borderSize: 1,  fillColor : float4(0.275, 0.275, 0.275, 1), borderColor: float4( 0, 0, 0, 1 ) )
    
        label.setText("Current Sequence")
        label.drawYCentered( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
        
        /*
        if let object = app.layerManager.getCurrentObject() {
            label.setText("Current Sequence")
            label.drawYCentered( x: rect.x + 10, y: rect.y, width: rect.width, height: 30 )
            
            objectEditorWidget.rect.x = rect.x
            objectEditorWidget.rect.y = rect.y + 30
            objectEditorWidget.rect.width = rect.width
            objectEditorWidget.rect.height = rect.height - 30
            
            objectEditorWidget.draw(layer: app.layerManager.getCurrentLayer(), object: object)
        }*/
    
        /*
        menuWidget.rect.x = rect.x + rect.width - 30 - 1
        menuWidget.rect.y = rect.y + 1
        menuWidget.rect.width = 30
        menuWidget.rect.height = 28
        
        if menuWidget.states.contains(.Opened) {
            mmView.delayedDraws.append( menuWidget )
        } else {
            menuWidget.draw()
            // --- Make focus area the size of the toolbar
            menuWidget.rect.x = rect.x
            menuWidget.rect.y = rect.y
            menuWidget.rect.width = rect.width
            menuWidget.rect.height = 30
        }*/
    }
}
