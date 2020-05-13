//
//  ArtistEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 05/01/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ArtistEditor          : Editor
{
    enum BottomRegionMode
    {
        case Closed, Open
    }
    
    var drawComponentId     : MTLRenderPipelineState?

    var bottomRegionMode    : BottomRegionMode = .Closed
    var animating           : Bool = false

    let mmView              : MMView!
    
    let designEditor        : DesignEditor
    var designProperties    : DesignProperties
    
    var timelineButton      : MMButtonWidget
    var timeline            : MMTimeline

    var bottomHeight        : Float = 0
    
    var dispatched          : Bool = false
        
    var groundButton        : MMButtonWidget

    var materialButton      : MMButtonWidget
    var cameraButton        : MMButtonWidget
    var renderButton        : MMButtonWidget
    
    var currentSamples      : Int = 0
    var samplesLabel        : MMShadowTextLabel
    
    var componentId         : Int? = nil
    
    var terrainEditor       : TerrainEditor
    var terrainIsActive     : Bool = false
    
    required init(_ view: MMView)
    {
        mmView = view

        let function = view.renderer.defaultLibrary.makeFunction( name: "highlightComponent" )
        drawComponentId = view.renderer.createNewPipelineState( function! )
        
        designEditor = DesignEditor(view)
        designProperties = DesignProperties(view)
        
        timelineButton = MMButtonWidget( view, iconName: "timeline" )
        timelineButton.iconZoom = 2
        timelineButton.rect.height -= 11
        timeline = MMTimeline(view)
        
        groundButton = MMButtonWidget( mmView, iconName: "ground" )
        groundButton.iconZoom = 2
        groundButton.rect.width += 2
        groundButton.rect.height -= 7
        
        materialButton = MMButtonWidget( mmView, iconName: "material" )
        materialButton.iconZoom = 2
        materialButton.rect.width += 14
        materialButton.rect.height -= 17
        
        cameraButton = MMButtonWidget( mmView, iconName: "camera" )
        cameraButton.iconZoom = 2
        cameraButton.rect.width += 16
        cameraButton.rect.height -= 9
        
        renderButton = MMButtonWidget( mmView, iconName: "render" )
        renderButton.iconZoom = 2
        renderButton.rect.width += 16
        renderButton.rect.height -= 14
        
        samplesLabel = MMShadowTextLabel(view, font: view.openSans, text: "0", scale: 0.3)
        
        terrainEditor = TerrainEditor(view)
        
        super.init()
        
        materialButton.clicked = { (event) -> Void in
            if let component = self.designEditor.designComponent {
                if component.componentType != .Material3D {
                    if let stageItem = globalApp!.project.selected!.getStageItem(component) {
                        for child in stageItem.children {
                            if child.components[child.defaultName]!.componentType == .Material3D {
                                globalApp!.project.selected!.getStageItem(child.components[child.defaultName]!, selectIt: true)
                                return
                            }
                        }
                    }
                }
            }
        }
        
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
        }
        
        groundButton.clicked = { (event) -> Void in
            if self.getTerrain() != nil {
                if let component = getComponent(name: "Ground") {
                    globalApp!.project.selected!.getStageItem(component, selectIt: true)
                }
            } else {
                askUserDialog(view: view, title: "Create Terrain ?", info: "Creating a terrain will replace your analytical ground object. You can remove the terrain again in the context menu of the terrain object in the scene graph.", cancelText: "Cancel", continueText: "Create Terrain", cb: { (result) in
                    
                    if result == true {
                        if let component = getComponent(name: "Ground") {
                            if let stageItem = globalApp!.project.selected!.getStageItem(component, selectIt: true) {
                                let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                                shapeStage.terrain = Terrain()
                                stageItem.name = "Terrain"
                                stageItem.label = nil
                                
                                globalApp!.developerEditor.codeEditor.markStageItemInvalid(stageItem)
                                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        
                                if let component = getComponent(name: "Ground") {
                                    globalApp!.project.selected!.getStageItem(component, selectIt: true)
                                }
                            }
                        }
                    } else {
                        self.groundButton.removeState(.Checked)
                        
                    }
                })
            }
        }
        
        renderButton.clicked = { (event) -> Void in
            if let component = getComponent(name: "Renderer") {
                globalApp!.project.selected!.getStageItem(component, selectIt: true)
            }
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
        mmView.registerWidgets(widgets: designEditor, timelineButton, groundButton, cameraButton, renderButton, materialButton)
        if bottomRegionMode == .Open {
            timeline.activate()
            mmView.registerWidget(timeline)
        }
        terrainIsActive = false
        terrainEditor.deactivate()
    }
    
    override func deactivate()
    {
        mmView.deregisterWidgets(widgets: designEditor, timelineButton, groundButton, cameraButton, renderButton, materialButton)
        if bottomRegionMode == .Open {
            mmView.deregisterWidget(timeline)
            timeline.deactivate()
        }
        terrainIsActive = false
        terrainEditor.deactivate()
    }
    
    func getTerrain() -> Terrain?
    {
        let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
        return shapeStage.terrain
    }
    
    func activateTerrain()
    {
        if let terrain = self.getTerrain() {
            self.terrainEditor.activate()
            self.terrainEditor.setTerrain(terrain)
            self.terrainIsActive = true
            self.groundButton.addState(.Checked)
        } else {
            self.terrainIsActive = false
            self.terrainEditor.deactivate()
            self.groundButton.removeState(.Checked)
        }
    }
    
    override func setComponent(_ component: CodeComponent)
    {
        dryRunComponent(component)
        
        if component.componentType == .Transform3D || component.componentType == .SDF3D || component.componentType == .Ground3D || component.componentType == .Material3D {
            materialButton.isDisabled = false
            
            if component.componentType == .Material3D {
                materialButton.addState(.Checked)
            } else {
                materialButton.removeState(.Checked)
            }
        } else {
            materialButton.isDisabled = true
        }
        
        if component.componentType == .Camera3D {
            cameraButton.addState(.Checked)
        } else {
            cameraButton.removeState(.Checked)
        }
        
        if component.componentType == .Render3D {
            renderButton.addState(.Checked)
        } else {
            renderButton.removeState(.Checked)
        }
        
        if component.componentType == .Ground3D && getTerrain() != nil {
            groundButton.addState(.Checked)
            activateTerrain()
        } else {
            terrainIsActive = false
            groundButton.removeState(.Checked)
            terrainEditor.deactivate()
        }

        designEditor.designComponent = component
        designProperties.setSelected(component)
        designEditor.updateGizmo()
        updateOnNextDraw(compile: false)
        mmView.update()
        
        mmView.deregisterPopups()
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
            
            materialButton.rect.x = (globalApp!.topRegion!.rect.width - (materialButton.rect.width + cameraButton.rect.width + renderButton.rect.width + 2 * 6)) / 2
            materialButton.rect.y = 4 + 44
            materialButton.draw()
            
            cameraButton.rect.x = materialButton.rect.right() + 6
            cameraButton.rect.y = 4 + 44
            cameraButton.draw()
            
            renderButton.rect.x = cameraButton.rect.right() + 6
            renderButton.rect.y = 4 + 44
            renderButton.draw()
            
            groundButton.rect.x = materialButton.rect.x - groundButton.rect.width - 20
            groundButton.rect.y = 4 + 44
            groundButton.draw()
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
            
            if terrainIsActive {
                terrainEditor.rect.copy(region.rect)
                terrainEditor.draw()
                return
            }
            
            designEditor.rect.copy(region.rect)
            designEditor.draw()
            
            if globalApp!.currentEditor.textureAlpha >= 1 {
                
                // Draw selected component
                if let component = designEditor.designComponent, component.componentType == .SDF2D || component.componentType == .SDF3D
                {
                    // Get the component id for highlighting
                    componentId = nil
                    if component.componentType == .SDF3D || component.componentType == .SDF2D {
                        for (id, value) in globalApp!.currentPipeline!.codeBuilder.sdfStream.ids {
                            if value.1 === component {
                                componentId = id
                            }
                        }
                    }
                    
                    if let id = componentId {
                        let settings: [Float] = [Float(id)];
                        
                        let renderEncoder = mmView.renderer.renderEncoder!
                        
                        let vertexBuffer = mmView.renderer.createVertexBuffer( MMRect( designEditor.rect.x, designEditor.rect.y, designEditor.rect.width, designEditor.rect.height, scale: mmView.scaleFactor ) )
                        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                        
                        let buffer = mmView.renderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
                        
                        renderEncoder.setFragmentTexture(globalApp!.currentPipeline?.getTextureOfId("id"), index: 0)
                        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 1)
                        
                        renderEncoder.setRenderPipelineState( drawComponentId! )
                        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                    }
                }
                
                
                if let gizmo = designEditor.currentGizmo, designEditor.designComponent != nil {
                    gizmo.rect.copy(designEditor.rect)
                    gizmo.draw()
                }
                
                designProperties.rect.copy(region.rect)
                designProperties.draw()
            
                var drawSamples : Bool = true
                if designEditor.designComponent != nil && designEditor.designComponent!.componentType == .Ground3D && designEditor.designComponent!.libraryName == "Plane" {
                    drawSamples = false
                }
                
                if drawSamples {
                    if currentSamples != globalApp!.currentPipeline!.samples {
                        let samplesString = String(globalApp!.currentPipeline!.samples)
                        samplesLabel.setText(samplesString)
                        currentSamples = globalApp!.currentPipeline!.samples
                    }
                    
                    if currentSamples > 0 {
                        samplesLabel.rect.x = region.rect.x + 8
                        samplesLabel.rect.y = region.rect.bottom() - 17
                        samplesLabel.draw()
                    }
                }
            }
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
            globalApp!.viewsAreAnimating = true
            globalApp!.currentPipeline!.cancel()
            globalApp!.mmView.startAnimate( startValue: bottomRegion.rect.height, endValue: 0, duration: 500, cb: { (value,finished) in
                self.bottomHeight = value
                if finished {
                    self.animating = false
                    self.bottomRegionMode = .Closed
                    self.timelineButton.removeState( .Checked )
                    
                    self.mmView.deregisterWidget(self.timeline)
                    self.timeline.deactivate()
                    globalApp!.viewsAreAnimating = false
                }
                self.updateOnNextDraw(compile: false)
            } )
            animating = true
        } else if bottomRegion.rect.height != 130 {
            globalApp!.viewsAreAnimating = true
            globalApp!.currentPipeline!.cancel()
            globalApp!.mmView.startAnimate( startValue: bottomRegion.rect.height, endValue: 130, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.bottomRegionMode = .Open
                    self.timeline.activate()
                    self.mmView.registerWidget(self.timeline)
                    globalApp!.viewsAreAnimating = false
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
