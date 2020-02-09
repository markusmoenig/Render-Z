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
    var pipeline        : Pipeline
    var thumbnail       : Thumbnail

    var sceneList       : SceneList

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
    var currentSceneMode: Scene.SceneMode = .TwoD
        
    #if os(iOS)
    var viewController  : ViewController?
    #endif

    init(_ view : MMView )
    {
        mmView = view
        mmFile = MMFile( view, "render-z" )
        
        mmView.registerIcon("rz_toolbar")
        sceneGraph = SceneGraph(mmView)

        sceneList = SceneList(mmView)
        artistEditor = ArtistEditor(mmView, sceneList)
        developerEditor = DeveloperEditor(mmView, sceneList)
        codeBuilder = CodeBuilder(mmView)
        pipeline = Pipeline(mmView)
        thumbnail = Thumbnail(mmView)

        currentEditor = developerEditor
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
        
        let backStage = project.selected!.getStage(.PreStage)
        //let shapeStage = project.selected!.stages[1]
        let selected = backStage.getChildren()[0]
        //_ = shapeStage.createChild("2D Object")
        //project.scenes[0].setSelected(selected)
        sceneGraph.setCurrent(stageItem: selected)
        //sceneGraph.activate()

        sceneList.setScene(project.selected!)

        currentEditor.activate()
    }
    
    func loadFrom(_ json: String)
    {
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
                //currentEditor.setComponent(component)
                self.project = project
                self.sceneList.setScene(self.project.selected!)
                self.mmView.update()
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
                self.sceneList.setScene(self.project.selected!)
                currentEditor.setComponent(component)
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
                sceneList.setScene(self.project.selected!)
                if let selected = project.selected!.getSelected() {
                    //project.selected!.setSelected(selected)
                    sceneGraph.setCurrent(stageItem: selected)
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
    func activate()
    {
    }
    
    func deactivate()
    {
    }
    
    func setComponent(_ component: CodeComponent)
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
    
    func undoStageItemStart(_ name: String) -> StageItemUndo
    {
        let undo = StageItemUndo(name)
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
    
    func undoStageItemEnd(_ undoComponent: StageItemUndo)
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
}

class StageItemUndo
{
    var name            : String
    
    var originalData    : String = ""
    var processedData   : String = ""

    init(_ name: String)
    {
        self.name = name
    }
}
