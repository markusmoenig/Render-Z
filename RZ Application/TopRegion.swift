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
    var logoTexture     : MTLTexture? = nil
    var undoButton      : MMButtonWidget!
    var redoButton      : MMButtonWidget!
    var newButton       : MMButtonWidget!
    var openButton      : MMButtonWidget!
    var saveButton      : MMButtonWidget!
    
    var helpButton      : MMButtonWidget!
    var playButton      : MMButtonWidget!
    
    var tabButton       : MMTabButtonWidget
    
    var app             : App

    init( _ view: MMView, app: App )
    {
        self.app = app
        
        tabButton = MMTabButtonWidget(view)
        tabButton.addTab("Artist")
        tabButton.addTab("Developer")
        tabButton.currentTab = tabButton.items[1]
        
        super.init( view, type: .Top )
        
        tabButton.clicked = { (event) in
            self.app.currentEditor.deactivate()
            let component : CodeComponent
            if self.tabButton.index == 0 {
                component = self.app.developerEditor.codeEditor.codeComponent!
                self.app.currentEditor = self.app.artistEditor
            } else {
                component = self.app.artistEditor.designEditor.designComponent!
                self.app.currentEditor = self.app.developerEditor
            }
            self.app.currentEditor.activate()
            self.app.currentEditor.setComponent(component)
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
        
        helpButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Help" )
        helpButton.isDisabled = false
        helpButton.textYOffset = -2
        helpButton.clicked = { (event) -> Void in
            self.helpButton.removeState(.Checked)
            showHelp()
        }
        
        playButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Play" )
        playButton.isDisabled = false
        playButton.textYOffset = -2
        playButton.clicked = { (event) -> Void in
        
            //globalApp!.pipeline.start(400, 400)
            
            if app.codeBuilder.isPlaying == false {
                self.playButton.addState(.Checked)
                app.mmView.lockFramerate(true)
                app.codeBuilder.isPlaying = true
                app.codeBuilder.currentFrame = 0
                if app.developerEditor.codeProperties.monitorInstance != nil {
                    app.developerEditor.codeProperties.resetMonitorData()
                }
            } else {
                self.playButton.removeState(.Checked)
                app.mmView.unlockFramerate(true)
                app.codeBuilder.isPlaying = false
                app.codeBuilder.currentFrame = 0
            }
        }

        layoutH( startX: 50, startY: 8, spacing: 10, widgets: undoButton, redoButton)
        layoutH( startX: redoButton.rect.right() + 20, startY: 8, spacing: 10, widgets: newButton, openButton, saveButton )
        registerWidgets( widgets: undoButton, redoButton, newButton, openButton, saveButton, helpButton, playButton, tabButton )
    }
    
    override func build()
    {
        mmView.drawBox.draw( x: 1, y: 0, width: mmView.renderer.width - 1, height: mmView.skin.ToolBar.height, round: 0, borderSize: mmView.skin.ToolBar.borderSize, fillColor : mmView.skin.ToolBar.color, borderColor: mmView.skin.ToolBar.borderColor )
        //mmView.drawBoxGradient.draw( x: 1, y: 0, width: mmView.renderer.width - 1, height: 44, round: 0, borderSize: 1, uv1: float2( 0, 0 ), uv2: float2( 0, 1 ), gradientColor1 : float4(0.275, 0.275, 0.275, 1.000), gradientColor2 : float4(0.153, 0.153, 0.153, 1.000), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        
        mmView.drawBox.draw( x: 149 + 55, y: 8, width: 1, height: 30, round: 0, borderSize: 0, fillColor : SIMD4<Float>(0.125, 0.125, 0.125, 1.000) )
        mmView.drawBox.draw( x: 150 + 55, y: 8, width: 1, height: 30, round: 0, borderSize: 0, fillColor : SIMD4<Float>(0.247, 0.243, 0.247, 1.000) )

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
        
        layoutHFromRight(startX: rect.x + rect.width - 10, startY: 8, spacing: 10, widgets: helpButton, playButton)
        
        helpButton.draw()
        playButton.draw()
        
        layoutH( startX: 3, startY: 4 + 44, spacing: 10, widgets: tabButton)
        tabButton.draw()

        #if os(OSX)
        mmView.window!.isDocumentEdited = !undoButton.isDisabled
        #endif
        
        app.currentEditor.drawRegion(self)
    }
}
