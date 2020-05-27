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
    
    var codeBuilder     : CodeBuilder
    var pipeline2D      : Pipeline2D
    var pipeline3D      : Pipeline3D
    var currentPipeline : Pipeline?
    var thumbnail       : Thumbnail

    var artistEditor    : ArtistEditor
    var developerEditor : DeveloperEditor
    var sceneGraph      : SceneGraph
    
    var currentEditor   : Editor
    
    var changed         : Bool = false
    
    let mmFile          : MMFile!
    
    let privateDatabase : CKDatabase
    let publicDatabase  : CKDatabase

    let libraryDialog   : LibraryDialog

    var project         : Project
    var currentSceneMode: Scene.SceneMode = .ThreeD
    
    var images          : [(String,MTLTexture)] = []
    
    var viewsAreAnimating = false
        
    #if os(iOS)
    var viewController  : ViewController?
    #endif

    var hasValidScene   = false
    
    var firstStart      = true
    
    var globalCamera    : CodeComponent? = nil
    
    init(_ view : MMView )
    {
        mmView = view
        mmFile = MMFile( view, "render-z" )
        
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
        mmView.registerIcon("render")
        mmView.registerIcon("material")
        mmView.registerIcon("ground")
        mmView.registerIcon("fileicon")
        mmView.registerIcon("maximize")
        mmView.registerIcon("minimize")
        mmView.registerIcon("render-z")
        sceneGraph = SceneGraph(mmView)
        
        // Initialize images
        let imageNames = ["Pebbles", "GreyStone"]
        for name in imageNames {
            if let texture = mmView.loadTexture(name, mipmaps: false, sRGB: true) {
                images.append(("Images." + name, texture))
            }
        }

        artistEditor = ArtistEditor(mmView)
        developerEditor = DeveloperEditor(mmView)
        codeBuilder = CodeBuilder(mmView)
        pipeline2D = Pipeline2D(mmView)
        pipeline3D = Pipeline3D(mmView)
        thumbnail = Thumbnail(mmView)

        currentPipeline = pipeline3D

        currentEditor = artistEditor
        project = Project(currentSceneMode)
        
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
                    
                    globalApp!.currentEditor.textureAlpha = 0
                    globalApp!.currentPipeline?.finalTexture = globalApp!.currentPipeline?.checkTextureSize(10, 10, globalApp!.currentPipeline?.finalTexture)
                    
                    //project.selected!.stages[5] = Stage(.VariablePool, "Variables")
                    
                    // Insert fog / cloud if they dont exist
                    let preStage = project.selected!.getStage(.PreStage)
                    var hasFog = false
                    for c in preStage.children3D {
                        if c.componentLists["fog"] != nil {
                            hasFog = true
                        }
                        
                        /*
                        if c.componentLists["clouds"] != nil {
                            
                            let codeComponent = CodeComponent(.Clouds3D, "Dummy")
                            codeComponent.createDefaultFunction(.Clouds3D)
                            
                            c.componentLists["clouds"]!.append(codeComponent)
                        }*/
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
                    }
                    
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
                    }
                        
                    if project.selected!.stages[4].children2D.count == 0 {
                        project.selected!.stages[4] = Stage(.PostStage, "Post FX")
                    }

                    globalApp!.sceneGraph.clearSelection()
                    project.selected!.addDefaultImages()
                    
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
                    print( "yes" )
                }
            }
            catch {
                print("Error is : \(error)")
            }*/
            
            if let component =  try? JSONDecoder().decode(CodeComponent.self, from: jsonData) {
                project.selected!.updateComponent(component)
                
                project.selected!.getStageItem(component, selectIt: true)
                globalApp!.developerEditor.codeEditor.markStageItemOfComponentInvalid(component)
            }
        }
    }
    
    func loadStageFrom(_ json: String)
    {
        if let jsonData = json.data(using: .utf8)
        {
            /*
            do {
                if (try JSONDecoder().decode(CodeComponent.self, from: jsonData)) != nil {
                    print( "yes" )
                }
            }
            catch {
                print("Error is : \(error)")
            }*/
            
            if let stage =  try? JSONDecoder().decode(Stage.self, from: jsonData) {
                project.selected!.updateStage(stage)
                
                project.selected!.invalidateCompilerInfos()
                currentEditor.updateOnNextDraw()
            }
        }
    }
    
    func loadStageItemFrom(_ json: String)
    {
        if let jsonData = json.data(using: .utf8)
        {
            /*
            do {
                if (try JSONDecoder().decode(CodeComponent.self, from: jsonData)) != nil {
                    print( "yes" )
                }
            }
            catch {
                print("Error is : \(error)")
            }*/
            
            if let stageItem =  try? JSONDecoder().decode(StageItem.self, from: jsonData) {
                project.selected!.updateStageItem(stageItem)
                
                globalApp!.developerEditor.codeEditor.markStageItemInvalid(stageItem)
                currentEditor.updateOnNextDraw()
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
    var textureAlpha    : Float = 0

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
    
    // Undo / Redo for the current StageItem
    func undoStageItemStart(_ name: String) -> SceneGraphItemUndo
    {
        let undo = SceneGraphItemUndo(name)
        if let current = globalApp!.sceneGraph.currentStageItem {
            let encodedData = try? JSONEncoder().encode(current)
            if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
                undo.originalData = encodedObjectJsonString
            }
        } else {
            print("undoStageItemStart: Stage Item is 0")
        }
        
        return undo
    }
    
    // Undo / Redo for a StageItem
    func undoStageItemStart(_ stageItem: StageItem, _ name: String) -> SceneGraphItemUndo
    {
        let undo = SceneGraphItemUndo(name)
        let encodedData = try? JSONEncoder().encode(stageItem)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
            undo.originalData = encodedObjectJsonString
        }
        return undo
    }
    
    func undoStageItemEnd(_ undoComponent: SceneGraphItemUndo)
    {
        if let current = globalApp!.sceneGraph.currentStageItem {
            let encodedData = try? JSONEncoder().encode(current)
            if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
                undoComponent.processedData = encodedObjectJsonString
            }
        }

        func stageItemChanged(_ oldState: String, _ newState: String)
        {
            globalApp!.mmView.undoManager!.registerUndo(withTarget: self) { target in
                globalApp!.loadStageItemFrom(oldState)
                stageItemChanged(newState, oldState)
            }
            globalApp!.mmView.undoManager!.setActionName(undoComponent.name)
        }
        
        stageItemChanged(undoComponent.originalData, undoComponent.processedData)
    }
    
    func undoStageItemEnd(_ stageItem: StageItem, _ undoComponent: SceneGraphItemUndo)
    {
        let encodedData = try? JSONEncoder().encode(stageItem)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
            undoComponent.processedData = encodedObjectJsonString
        }

        func stageItemChanged(_ oldState: String, _ newState: String)
        {
            globalApp!.mmView.undoManager!.registerUndo(withTarget: self) { target in
                globalApp!.loadStageItemFrom(oldState)
                stageItemChanged(newState, oldState)
            }
            globalApp!.mmView.undoManager!.setActionName(undoComponent.name)
        }
        
        stageItemChanged(undoComponent.originalData, undoComponent.processedData)
    }
    
    // Undo / Redo for a Stage
    func undoStageStart(_ stage: Stage,_ name: String) -> SceneGraphItemUndo
    {
        let undo = SceneGraphItemUndo(name)
        let encodedData = try? JSONEncoder().encode(stage)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
            undo.originalData = encodedObjectJsonString
        }
        return undo
    }
    
    func undoStageEnd(_ stage: Stage,_ undoComponent: SceneGraphItemUndo)
    {
        let encodedData = try? JSONEncoder().encode(stage)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
            undoComponent.processedData = encodedObjectJsonString
        }

        func stageChanged(_ oldState: String, _ newState: String)
        {
            globalApp!.mmView.undoManager!.registerUndo(withTarget: self) { target in
                globalApp!.loadStageFrom(oldState)
                stageChanged(newState, oldState)
            }
            globalApp!.mmView.undoManager!.setActionName(undoComponent.name)
        }
        
        stageChanged(undoComponent.originalData, undoComponent.processedData)
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
