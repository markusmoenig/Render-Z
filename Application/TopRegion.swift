//
//  TopRegion.swift
//  Framework
//
//  Created by Markus Moenig on 04.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class TopRegion: MMRegion
{
    enum RightRegionMode
    {
        case Closed, Open
    }
    
    var rightRegionMode : RightRegionMode = .Closed
    var animating       : Bool = false

    var logoTexture     : MTLTexture? = nil
    var undoButton      : MMButtonWidget!
    var redoButton      : MMButtonWidget!
    var newButton       : MMButtonWidget!
    var openButton      : MMButtonWidget!
    var saveButton      : MMButtonWidget!
    
    var helpButton      : MMButtonWidget!
    var exportButton    : MMButtonWidget!
    
    var graphButton     : MMButtonWidget!
    
    var switchButton    : MMSwitchIconWidget
    var libraryButton   : MMButtonWidget!

    var app             : App

    init( _ view: MMView, app: App )
    {
        self.app = app
        
        switchButton =  MMSwitchIconWidget( view, leftIconName: "gizmo", rightIconName: "dev")
        switchButton.setState(.Left)
        
        super.init( view, type: .Top )
        
        switchButton.clicked = { (event) in
            self.app.currentEditor.deactivate()
            if self.switchButton.state == .Left {
                self.app.currentEditor = self.app.artistEditor
                //if let component = globalApp!.artistEditor.designEditor.designComponent, component.componentType != .Dummy  {
                //    globalApp!.project.selected!.getStageItem(component, selectIt: true)
                //} else
                if let component = globalApp!.developerEditor.codeEditor.codeComponent {
                    self.app.currentEditor.setComponent(component)
                    //globalApp!.project.selected!.getStageItem(component, selectIt: true)
                }
            } else {
                self.app.currentEditor = self.app.developerEditor
                //if let component = globalApp!.developerEditor.codeEditor.codeComponent, component.componentType != .Dummy {
                //    globalApp!.project.selected!.getStageItem(component, selectIt: true)
                //} else
                if let component = globalApp!.artistEditor.designEditor.designComponent {
                    //globalApp!.project.selected!.getStageItem(component, selectIt: true)
                    self.app.currentEditor.setComponent(component)
                }
            }
            self.app.currentEditor.activate()
        }
        
        logoTexture = view.icons["rz_toolbar"]
        
        var borderlessSkin = MMSkinButton()
        borderlessSkin.margin = MMMargin( 8, 4, 8, 4 )
        borderlessSkin.borderSize = 0
        borderlessSkin.height = 30
        borderlessSkin.round = 26

        undoButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Undo" )
        undoButton.isDisabled = true
        undoButton.textYOffset = -2
        undoButton.clicked = { (event) -> Void in
            self.undoButton.removeState(.Checked)
            view.undoManager?.undo()
        }
        
        redoButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Redo" )
        redoButton.isDisabled = true
        redoButton.textYOffset = -2
        redoButton.clicked = { (event) -> Void in
            self.redoButton.removeState(.Checked)
            view.undoManager?.redo()
        }
        
        newButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "New" )
        newButton.isDisabled = false
        newButton.textYOffset = -2
        newButton.clicked = { (event) -> Void in
            self.newButton.removeState(.Checked)
            
            func new() {
                self.mmView.undoManager!.removeAllActions()
                
                let dialog = NewDialog(app.mmView)
                app.mmView.showDialog(dialog)
                
                /*
                if self.app.nodeGraph.maximizedNode != nil {
                    self.app.nodeGraph.maximizedNode!.maxDelegate!.deactivate()
                }
                self.app.nodeGraph.deactivate()
                
                self.app.nodeGraph = NodeGraph()
                self.app.nodeGraph.setup(app: self.app)
                self.app.nodeGraph.activate()
                self.app.nodeGraph.updateNodes()
                
                let dialog = MMTemplateChooser(app.mmView)
                app.mmView.showDialog(dialog)*/
            }
            
            if self.mmView.undoManager!.canUndo {
                askUserToSave(view: self.mmView, cb: { (rc) -> Void in
                    if rc == true {
                        new()
                    }
                })
            } else {
                new()
            }
        }
        
        openButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Open" )
        openButton.isDisabled = false
        openButton.textYOffset = -2
        openButton.clicked = { (event) -> Void in
            
            self.openButton.removeState(.Checked)
//            view.undoManager?.undo()

            func load() {
                #if os(iOS)
                let dialog = MMFileDialog(app.mmView)
                app.mmView.showDialog(dialog)
                #else
                app.mmFile.chooseFile(app: app)
                #endif
                
                app.currentEditor.instantUpdate()
            }

            if self.mmView.undoManager!.canUndo {
                askUserToSave(view: self.mmView, cb: { (rc) -> Void in
                    if rc == true {
                        load()
                    }
                })
            } else {
                load()
            }
        }
        
        saveButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Save" )
        saveButton.isDisabled = false
        saveButton.textYOffset = -2
        saveButton.clicked = { (event) -> Void in
            self.saveButton.removeState(.Checked)
        
            #if os(iOS)
            let dialog = MMFileDialog(app.mmView, .Save)
            app.mmView.showDialog(dialog)
            #else
            let json = app.encodeJSON()
            app.mmFile.saveAs(json, app)
            #endif
        }
        
        libraryButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Library" )
        libraryButton.clicked = { (event) -> Void in
            
            if app.currentEditor === app.developerEditor {
                globalApp!.libraryDialog.show(ids: ["FuncSDF", "FuncAnalytical", "FuncMaterial", "FuncNoise", "FuncHash", "FuncMisc"])
            } else {
                /*
                globalApp!.libraryDialog.showObjects(cb: { (object) in                    
                    let stageItem = decodeStageItemFromJSON(object)
                    
                    stageItem?.values["_posX"] = 0
                    stageItem?.values["_posY"] = 0
                    stageItem?.values["_posZ"] = 0

                    let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                    shapeStage.children3D.append(stageItem!)
                    
                    globalApp!.currentEditor.updateOnNextDraw(compile: true)
                })*/
            }
            
            self.libraryButton.removeState(.Checked)
        }
        libraryButton.isDisabled = true
        
        helpButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Help" )
        helpButton.isDisabled = false
        helpButton.textYOffset = -2
        helpButton.clicked = { (event) -> Void in
            self.helpButton.removeState(.Checked)
            showHelp()
        }
        
        /*
        playButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Play" )
        playButton.isDisabled = false
        playButton.textYOffset = -2
        playButton.clicked = { (event) -> Void in
        
            //globalApp!.pipeline.start(400, 400)
            
            if app.currentPipeline!.codeBuilder.isPlaying == false {
                self.playButton.addState(.Checked)
                app.mmView.lockFramerate(true)
                app.currentPipeline!.codeBuilder.isPlaying = true
                app.currentPipeline!.codeBuilder.currentFrame = 0
            } else {
                self.playButton.removeState(.Checked)
                app.mmView.unlockFramerate(true)
                app.currentPipeline!.codeBuilder.isPlaying = false
                app.currentPipeline!.codeBuilder.currentFrame = 0
            }
        }*/

        exportButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Export" )
        exportButton.isDisabled = false
        exportButton.textYOffset = -2
        exportButton.clicked = { (event) -> Void in
            let exportDialog = ExportDialog(self.mmView)
            exportDialog.show()
            self.exportButton.removeState(.Checked)
        }
        
        graphButton = MMButtonWidget( mmView, iconName: "scenegraph" )
        graphButton.iconZoom = 2
        graphButton.rect.width += 16
        graphButton.rect.height -= 2
        graphButton.clicked = { (event) -> Void in
            globalApp!.sceneGraph.switchState()
        }

        layoutH(startX: 50, startY: 8, spacing: 10, widgets: undoButton, redoButton)
        layoutH(startX: redoButton.rect.right() + 20, startY: 8, spacing: 10, widgets: newButton, openButton, saveButton)
        layoutH(startX: saveButton.rect.right() + 20, startY: 8, spacing: 10, widgets: libraryButton)
        registerWidgets( widgets: undoButton, redoButton, newButton, openButton, saveButton, libraryButton, helpButton, exportButton, switchButton, graphButton )
    }
    
    override func build()
    {
        mmView.drawBox.draw( x: 1, y: 0, width: mmView.renderer.width - 1, height: mmView.skin.ToolBar.height, round: 0, borderSize: mmView.skin.ToolBar.borderSize, fillColor : mmView.skin.ToolBar.color, borderColor: mmView.skin.ToolBar.borderColor )
        //mmView.drawBoxGradient.draw( x: 1, y: 0, width: mmView.renderer.width - 1, height: 44, round: 0, borderSize: 1, uv1: float2( 0, 0 ), uv2: float2( 0, 1 ), gradientColor1 : float4(0.275, 0.275, 0.275, 1.000), gradientColor2 : float4(0.153, 0.153, 0.153, 1.000), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        
        mmView.drawBox.draw( x: 149 + 55, y: 8, width: 1, height: 30, round: 0, borderSize: 0, fillColor : SIMD4<Float>(0.125, 0.125, 0.125, 1.000) )
        mmView.drawBox.draw( x: 150 + 55, y: 8, width: 1, height: 30, round: 0, borderSize: 0, fillColor : SIMD4<Float>(0.247, 0.243, 0.247, 1.000) )

        let saveRight = saveButton.rect.right() + 9
        mmView.drawBox.draw( x: saveRight, y: 8, width: 1, height: 30, round: 0, borderSize: 0, fillColor : SIMD4<Float>(0.125, 0.125, 0.125, 1.000) )
        mmView.drawBox.draw( x: saveRight + 1, y: 8, width: 1, height: 30, round: 0, borderSize: 0, fillColor : SIMD4<Float>(0.247, 0.243, 0.247, 1.000) )

        mmView.drawBox.draw( x: 1, y: mmView.skin.ToolBar.height, width: mmView.renderer.width - 1, height: mmView.skin.ToolBar.height + 3, round: 0, borderSize: mmView.skin.ToolBar.borderSize, fillColor : mmView.skin.ToolBar.color, borderColor: mmView.skin.ToolBar.borderColor )
        //mmView.drawBoxGradient.draw( x: 1, y: 44, width: mmView.renderer.width-1, height: 48, round: 0, borderSize: 1, uv1: float2( 0, 0 ), uv2: float2( 0, 1 ), gradientColor1 : float4( 0.082, 0.082, 0.082, 1), gradientColor2 : float4( 0.169, 0.173, 0.169, 1), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        rect.height = mmView.skin.ToolBar.height + 4 + mmView.skin.ToolBar.height
     
        mmView.drawTexture.draw(logoTexture!, x: 10, y: 7, zoom: 1.5)

        undoButton.isDisabled = !mmView.window!.undoManager!.canUndo
        undoButton.draw()
        
        redoButton.isDisabled = !mmView.window!.undoManager!.canRedo
        redoButton.draw()

        //newButton.isDisabled = !mmView.window!.undoManager!.canUndo
        newButton.draw()
        
        openButton.draw()
        saveButton.draw()

        libraryButton.draw()

        layoutHFromRight(startX: rect.x + rect.width - 10, startY: 8, spacing: 10, widgets: helpButton, exportButton)
        
        helpButton.draw()
        exportButton.draw()
        
        layoutH( startX: 3, startY: 4 + 44, spacing: 50, widgets: switchButton)
        switchButton.draw()

        #if os(OSX)
        mmView.window!.isDocumentEdited = !undoButton.isDisabled
        #endif
        
        app.currentEditor.drawRegion(self)
    }
}
