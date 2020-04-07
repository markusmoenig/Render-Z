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

    var bottomHeight        : Float = 0
    
    var dispatched          : Bool = false
    
    var outputButton        : MMScrollButton
    
    var cameraButton        : MMButtonWidget
    var renderButton        : MMButtonWidget

    required init(_ view: MMView)
    {
        mmView = view

        designEditor = DesignEditor(view)
        designProperties = DesignProperties(view)

        timelineButton = MMButtonWidget( view, iconName: "timeline" )
        timelineButton.iconZoom = 2
        timelineButton.rect.height -= 11
        timeline = MMTimeline(view)

        outputButton = MMScrollButton(view, items:["Final Image", "Depth Map", "Occlusion", "Shadows", "Fog Density"], index: 0)
        outputButton.changed = { (index)->() in
            globalApp!.currentPipeline!.outputType = Pipeline.OutputType(rawValue: index)!
            globalApp!.currentEditor.updateOnNextDraw(compile: false)
        }
        
        cameraButton = MMButtonWidget( mmView, iconName: "camera" )
        cameraButton.iconZoom = 2
        cameraButton.rect.width += 16
        cameraButton.rect.height -= 9
        
        renderButton = MMButtonWidget( mmView, iconName: "render" )
        renderButton.iconZoom = 2
        renderButton.rect.width += 16
        renderButton.rect.height -= 14
        
        super.init()
        
        cameraButton.clicked = { (event) -> Void in
            let preStage = globalApp!.project.selected!.getStage(.PreStage)
            let preStageChildren = preStage.getChildren()
            for stageItem in preStageChildren {
                if let c = stageItem.components[stageItem.defaultName] {
                    if c.componentType == .Camera2D || c.componentType == .Camera3D {
                        globalApp!.sceneGraph.setCurrent(stage: preStage, stageItem: stageItem, component: c)
                        break
                    }
                }
            }
            self.cameraButton.removeState(.Checked)
        }
        
        renderButton.clicked = { (event) -> Void in

            if let component = getComponent(name: "Renderer") {
                globalApp!.project.selected!.getStageItem(component, selectIt: true)
            }
            self.renderButton.removeState(.Checked)
        }
        
        timelineButton.clicked = { (event) -> Void in
            self.switchTimelineMode()
        }
        
        timeline.changedCB = { (frame) in
            self.updateOnNextDraw(compile: false)
        }
        
        designEditor.editor = self
        designProperties.editor = self
    }
    
    override func activate()
    {
        mmView.registerWidgets(widgets: designEditor, timelineButton, cameraButton, renderButton, outputButton)
        if bottomRegionMode == .Open {
            timeline.activate()
            mmView.registerWidget(timeline)
        }
    }
    
    override func deactivate()
    {
        mmView.deregisterWidgets(widgets: designEditor, timelineButton, cameraButton, renderButton, outputButton)
        if bottomRegionMode == .Open {
            mmView.deregisterWidget(timeline)
            timeline.deactivate()
        }
    }
    
    override func setComponent(_ component: CodeComponent)
    {
        dryRunComponent(component)

        designEditor.designComponent = component
        designProperties.setSelected(component)
        designEditor.updateGizmo()
        updateOnNextDraw(compile: false)
        mmView.update()
    }
    
    override func updateOnNextDraw(compile: Bool = true)
    {
        designEditor.needsUpdate = true
        if designEditor.designChanged == false {
            designEditor.designChanged = compile
        }
        
        if designEditor.rect.width > 0 {
            designEditor.update()
        }
        
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.mmView.update()
                self.dispatched = false
            }
            dispatched = true
        }
    }
    
    override func drawRegion(_ region: MMRegion)
    {
        if region.type == .Top {
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 43, spacing: 10, widgets: timelineButton, globalApp!.topRegion!.graphButton)
            timelineButton.draw()
            globalApp!.topRegion!.graphButton.draw()

            cameraButton.rect.x = (globalApp!.topRegion!.rect.width - (cameraButton.rect.width + renderButton.rect.width + 6)) / 2
            cameraButton.rect.y = 4 + 44
            cameraButton.draw()
            
            renderButton.rect.x = cameraButton.rect.right() + 6
            renderButton.rect.y = 4 + 44
            renderButton.draw()
            
            outputButton.rect.x = cameraButton.rect.x / 2 - outputButton.rect.width / 4
            outputButton.rect.y = cameraButton.rect.y
            outputButton.draw()

        } else
        if region.type == .Left {
            region.rect.width = 0
        } else
        if region.type == .Right {
            if globalApp!.sceneGraph.currentWidth > 0 {
                region.rect.x = globalApp!.mmView.renderer.cWidth - region.rect.width
                globalApp!.sceneGraph.rect.copy(region.rect)
                globalApp!.sceneGraph.draw()
            }
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
                //timeline.rect.width -= globalApp!.rightRegion!.rect.width
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
    
    override func undoComponentStart(_ name: String) -> CodeUndoComponent
    {
        return designEditor.undoStart(name)
    }
    
    override func undoComponentEnd(_ undoComponent: CodeUndoComponent)
    {
        designEditor.undoEnd(undoComponent)
    }
}
