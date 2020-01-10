//
//  ArtistEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 05/01/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class ArtistEditor          : Editor
{
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var bottomRegionMode    : BottomRegionMode = .Closed
    var animating           : Bool = false

    let mmView              : MMView!
    
    let designEditor        : DesignEditor
    var designProperties    : DesignProperties
    
    var timelineButton      : MMButtonWidget
    var timeline            : MMTimeline

    var sceneList           : SceneList
    
    var bottomHeight        : Float = 0

    required init(_ view: MMView,_ sceneList: SceneList)
    {
        mmView = view
        self.sceneList = sceneList

        designEditor = DesignEditor(view)
        designProperties = DesignProperties(view)
        
        timelineButton = MMButtonWidget( view, text: "Timeline" )
        timeline = MMTimeline(view)

        super.init()
        
        timelineButton.clicked = { (event) -> Void in
            self.switchTimelineMode()
        }
        
        timeline.changedCB = { (frame) in
            self.mmView.update()
        }
        
        designEditor.editor = self
        designProperties.editor = self
    }
    
    override func activate()
    {
        mmView.registerWidgets(widgets: sceneList, designProperties, timelineButton)
        if bottomRegionMode == .Open {
            timeline.activate()
            mmView.registerWidget(timeline)
        }
    }
    
    override func deactivate()
    {
        mmView.deregisterWidgets(widgets: sceneList, designProperties, timelineButton)
        if bottomRegionMode == .Open {
            mmView.deregisterWidget(timeline)
            timeline.deactivate()
        }
    }
    
    override func setComponent(_ component: CodeComponent)
    {
        designEditor.designComponent = component
        designProperties.setSelected(component)
        updateOnNextDraw()
        mmView.update()
    }
    
    override func updateOnNextDraw(compile: Bool = true)
    {
        designEditor.needsUpdate = true
        designEditor.designChanged = compile
        mmView.update()
    }
    
    override func drawRegion(_ region: MMRegion)
    {
        if region.type == .Top {
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: timelineButton)
            timelineButton.draw()
        } else
        if region.type == .Left {
            sceneList.rect.copy(region.rect)
            sceneList.draw()
        } else
        if region.type == .Editor {
            designEditor.rect.copy(region.rect)
            designEditor.draw()
            designProperties.rect.copy(region.rect)
            designProperties.draw()
        } else
        if region.type == .Bottom {
            if bottomHeight > 0 {
                region.rect.y = globalApp!.mmView.renderer.cHeight - bottomHeight - 1
                timeline.rect.copy( region.rect )
                timeline.rect.width -= globalApp!.rightRegion!.rect.width
                timeline.draw(designEditor.designComponent!.sequence, uuid: designEditor.designComponent!.uuid)
            }
        }
    }
    
    /// Switches the mode of the timeline (Open / Closed)
    func switchTimelineMode()
    {
        if animating { return }
        let bottomRegion = globalApp!.bottomRegion!
        
        if bottomRegionMode == .Open {
            globalApp!.mmView.startAnimate( startValue: bottomRegion.rect.height, endValue: 0, duration: 500, cb: { (value,finished) in
                self.bottomHeight = value
                if finished {
                    self.animating = false
                    self.bottomRegionMode = .Closed
                    self.timelineButton.removeState( .Checked )
                    
                    self.mmView.deregisterWidget(self.timeline)
                    self.timeline.deactivate()
                }
                self.updateOnNextDraw(compile: false)
            } )
            animating = true
        } else if bottomRegion.rect.height != 130 {
            
            globalApp!.mmView.startAnimate( startValue: bottomRegion.rect.height, endValue: 130, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.bottomRegionMode = .Open
                    self.timeline.activate()
                    self.mmView.registerWidget(self.timeline)
                }
                self.bottomHeight = value
                self.updateOnNextDraw(compile: false)
            } )
            animating = true
        }
    }
    
    override func getBottomHeight() -> Float
    {
        return bottomHeight
    }
}
