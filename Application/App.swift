//
//  App.swift
//  Render-Z
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

import MetalKit
import CloudKit

enum Constants {
    static let LinesToRenderFloat: Float = 50
    static let LinesToRenderInt: Int = 50
}

// Necessary for undo / redo situations
var globalApp : App? = nil

class App
{
    var mmView          : MMView
    var leftRegion      : LeftRegion?
    var topRegion       : TopRegion?
    var rightRegion     : RightRegion?
    var bottomRegion    : BottomRegion?
    var editorRegion    : EditorRegion?
    
    //var codeBuilder     : CodeBuilder
    var pipelineFX      : PipelineFX
    var currentPipeline : Pipeline?
    var thumbnail       : Thumbnail

    var artistEditor    : ArtistEditor
    var developerEditor : DeveloperEditor
    var sceneGraph      : SceneTimeline

    var currentEditor   : Editor
    
    var changed         : Bool = false
    
    let mmFile          : MMFile!
    
    let privateDatabase : CKDatabase
    let publicDatabase  : CKDatabase

    let libraryDialog   : LibraryDialog

    var project         : Project
    
    var images          : [(String,MTLTexture)] = []
        
    var executionTime   : Double = 0
        
    #if os(iOS)
    var viewController  : ViewController?
    #endif

    var hasValidScene   = false
    
    var firstStart      = true
    
    var globalCamera    : CodeComponent? = nil
    
    init(_ view : MMView )
    {
        mmView = view
        mmFile = MMFile( view, "shape-z" )
                
        mmView.registerIcon("rz_toolbar")
        mmView.registerIcon("scenegraph")
        mmView.registerIcon("timeline")
        mmView.registerIcon("camera")
        mmView.registerIcon("gizmo_on")
        mmView.registerIcon("gizmo_off")
        mmView.registerIcon("dev_on")
        mmView.registerIcon("dev_off")
        mmView.registerIcon("X_blue")
        mmView.registerIcon("Y_red")
        mmView.registerIcon("Z_green")
        mmView.registerIcon("X_blue_ring")
        mmView.registerIcon("Y_red_ring")
        mmView.registerIcon("Z_green_ring")
        mmView.registerIcon("move")
        mmView.registerIcon("rotate")
        mmView.registerIcon("scale")
        //mmView.registerIcon("render")
        mmView.registerIcon("material")
        mmView.registerIcon("ground")
        mmView.registerIcon("fileicon")
        mmView.registerIcon("maximize")
        mmView.registerIcon("minimize")
        mmView.registerIcon("render-z")
        sceneGraph = SceneTimeline(mmView)

        // Initialize images
        let imageNames = ["StoneWall", "GreyStone", "Soil"]
        for name in imageNames {
            if let texture = mmView.loadTexture(name, mipmaps: false, sRGB: true) {
                images.append(("Images." + name, texture))
            }
        }

        artistEditor = ArtistEditor(mmView)
        developerEditor = DeveloperEditor(mmView)
        //codeBuilder = CodeBuilder(mmView)
        pipelineFX = PipelineFX(mmView)
        thumbnail = Thumbnail(mmView)

        currentPipeline = pipelineFX

        currentEditor = artistEditor
        project = Project()
        
        privateDatabase = CKContainer.init(identifier: "iCloud.com.moenig.renderz").privateCloudDatabase
        publicDatabase = CKContainer.init(identifier: "iCloud.com.moenig.renderz").publicCloudDatabase
        
        libraryDialog = LibraryDialog(mmView)

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
                
        globalApp = self
        
        /*
        let preStage = project.selected!.getStage(.PreStage)
        let selected = preStage.getChildren()[0]
        project.selected!.addDefaultImages()
        sceneGraph.setCurrent(stage: preStage, stageItem: selected)
        */
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let dialog = NewDialog(self.mmView)
            self.mmView.showDialog(dialog)
        }

        currentEditor.activate()
    }
    
    func loadFrom(_ json: String)
    {
        hasValidScene = false
        mmView.update()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {

            if let jsonData = json.data(using: .utf8)
            {
                /*
                do {
                    if (try JSONDecoder().decode(Project.self, from: jsonData)) != nil {
                        print( "yes" )
                    }
                }
                catch {
                    print("Error is : \(error)")
                }*/
                
                if let project =  try? JSONDecoder().decode(Project.self, from: jsonData) {
                    self.project = project
                    
                    globalApp!.currentPipeline?.finalTexture = globalApp!.currentPipeline?.checkTextureSize(10, 10, globalApp!.currentPipeline?.finalTexture)
                    
                    //project.selected!.stages[5] = Stage(.VariablePool, "Variables")
                    
                    /*
                    // Insert fog / cloud if they dont exist
                    let preStage = project.selected!.getStage(.PreStage)
                    var hasFog = false
                    for c in preStage.children3D {
                        if c.componentLists["fog"] != nil {
                            hasFog = true
                        }
                        
                        if c.componentLists["clouds"] != nil {
                            
                            let codeComponent = CodeComponent(.Clouds3D, "Default Clouds")
                            codeComponent.createDefaultFunction(.Clouds3D)
                            
                            c.componentLists["clouds"]!.append(codeComponent)
                        }
                    }
                    
                    if hasFog == false {
                        var item = StageItem(.PreStage, "Fog")
                        
                        let codeComponent = CodeComponent(.Fog3D, "Dummy")
                        codeComponent.createDefaultFunction(.Fog3D)
                        
                        item.componentLists["fog"] = [codeComponent]
                        preStage.children3D.append(item)
                        placeChild(modeId: "3D", parent: preStage, child: item, stepSize: 80, radius: 130)
                        
                        item = StageItem(.PreStage, "Clouds")
                        item.componentLists["clouds"] = []
                        preStage.children3D.append(item)
                        placeChild(modeId: "3D", parent: preStage, child: item, stepSize: 50, radius: 120)
                    }*/
                    
                    /*
                    // Insert Max Fog Distance Variable if it does not exist
                    let variableStage = project.selected!.getStage(.VariablePool)
                    for c in variableStage.children3D {
                        if c.name == "World" {
                            if let list = c.componentLists["variables"] {
                                var hasMaxDist = false
                                for v in list {
                                    if v.libraryName == "Fog Distance" {
                                        hasMaxDist = true
                                    }
                                }
                                if hasMaxDist == false {
                                    let worldFogMaxDistanceComponent = CodeComponent(.Variable, "Fog Distance")
                                    worldFogMaxDistanceComponent.values["locked"] = 1
                                    worldFogMaxDistanceComponent.createVariableFunction("worldMaxFogDistance", "float", "Maximum Fog Distance", defaultValue: Float(50), gizmo: 2)
                                    c.componentLists["variables"]!.append(worldFogMaxDistanceComponent)
                                }
                            }
                        }
                    }*/
                    
                    /*
                    let variableStage = project.selected!.getStage(.VariablePool)
                    for c in variableStage.children3D {
                        if c.name == "World" {
                            
                            var newList : [CodeComponent] = []
                            
                            if let list = c.componentLists["variables"] {
                                for v in list {
                                    if v.libraryName.starts(with: "Fog") == false {
                                        newList.append(v)
                                    }
                                }
                            }
                            
                            c.componentLists["variables"] = newList
                        }
                    }*/

                    globalApp!.sceneGraph.clearSelection()
                    project.selected!.addDefaultImages()

                    // --- Set the current shader
                    
                    var index = 0;
                    if let uuid = project.selected!.getSelectedUUID() {
                        if let i = project.selected!.indexOfUUID(uuid) {
                            index = i
                        }
                    }
                    
                    if globalApp!.project.selected!.items.isEmpty == false {
                        globalApp!.sceneGraph.setCurrent(component: globalApp!.project.selected!.items[index])
                    }
                    
                    // ---
                    
                    globalApp!.currentPipeline?.resetIds()
                    
                    self.hasValidScene = true
                    self.currentEditor.updateOnNextDraw(compile: true)
                    self.mmView.update()
                }
            }
        }
    }
    
    func loadComponentFrom(_ json: String)
    {
        if let jsonData = json.data(using: .utf8)
        {
            /*
            do {
                if (try JSONDecoder().decode(CodeComponent.self, from: jsonData)) != nil {
                }
            }
            catch {
                print("Error is : \(error)")
            }*/
            
            if let component =  try? JSONDecoder().decode(CodeComponent.self, from: jsonData) {
                globalApp!.currentEditor.setComponent(component)
                globalApp!.developerEditor.codeEditor.markComponentInvalid(component)
                if let index = globalApp!.project.selected!.indexOfUUID(component.uuid) {
                    globalApp!.project.selected!.items[index] = component
                }
            }
        }
    }
    
    func encodeJSON() -> String
    {
        let encodedData = try? JSONEncoder().encode(project)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            return encodedObjectJsonString
        }
        return ""
    }
    
    /*
    func encodeComponentJSON() -> String
    {
        let encodedData = try? JSONEncoder().encode(developerEditor.codeEditor.codeComponent!)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            return encodedObjectJsonString
        }
        return ""
    }*/
}

class Editor
{
    var textureAlpha    : Float = 1

    func activate()
    {
    }
    
    func deactivate()
    {
    }
    
    func setComponent(_ component: CodeComponent)
    {
    }
    
    func render()
    {
    }
    
    func instantUpdate()
    {
    }
    
    func updateOnNextDraw(compile: Bool = true)
    {
    }
    
    func getBottomHeight() -> Float
    {
        return 0 
    }
    
    func drawRegion(_ region: MMRegion)
    {
    }
    
    func undoComponentStart(_ name: String) -> CodeUndoComponent
    {
        return CodeUndoComponent(name)
    }
    
    func undoComponentEnd(_ undoComponent: CodeUndoComponent)
    {
    }
    
    func undoComponentStart(_ component: CodeComponent,_ name: String) -> CodeUndoComponent
    {
        let codeUndo = CodeUndoComponent(name)
        codeUndo.undoComponent = component

        let encodedData = try? JSONEncoder().encode(component)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            codeUndo.originalData = encodedObjectJsonString
        }
        
        return codeUndo
    }
    
    func undoComponentEnd(_ component: CodeComponent, _ undoComponent: CodeUndoComponent)
    {
        let encodedData = try? JSONEncoder().encode(component)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            undoComponent.processedData = encodedObjectJsonString
        }


        func componentChanged(_ oldState: String, _ newState: String)
        {
            globalApp!.mmView.undoManager!.registerUndo(withTarget: self) { target in
                globalApp!.loadComponentFrom(oldState)
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                componentChanged(newState, oldState)
            }
            globalApp!.mmView.undoManager!.setActionName(undoComponent.name)
        }
        
        componentChanged(undoComponent.originalData, undoComponent.processedData)
    }
}

class SceneGraphItemUndo
{
    var name            : String
    
    var originalData    : String = ""
    var processedData   : String = ""

    init(_ name: String)
    {
        self.name = name
    }
}
