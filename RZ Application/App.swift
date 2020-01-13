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

    var sceneList       : SceneList

    var artistEditor    : ArtistEditor
    var developerEditor : DeveloperEditor
    
    var currentEditor   : Editor
    
    var changed         : Bool = false
    
    let mmFile          : MMFile!
    
    var project         : Project
    
    #if os(iOS)
    var viewController  : ViewController?
    #endif

    init(_ view : MMView )
    {
        mmView = view
        mmFile = MMFile( view, "render-z" )
        
        mmView.registerIcon("rz_toolbar")

        sceneList = SceneList(mmView)
        artistEditor = ArtistEditor(mmView, sceneList)
        developerEditor = DeveloperEditor(mmView, sceneList)
        codeBuilder = CodeBuilder(mmView)
        pipeline = Pipeline(mmView)

        currentEditor = developerEditor
        project = Project()

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
        
        let backStage = project.selected!.stages[0]
        let shapeStage = project.selected!.stages[1]
        let selected = backStage.createChild("Sky")
        _ = shapeStage.createChild("2D Object")
        project.scenes[0].setSelected(selected)

        sceneList.setScene(project.selected!)

        currentEditor.activate()
        
        /*
        let query = CKQuery(recordType: "SampleProjects", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.shapez.documents").publicCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            records?.forEach({ (record) in
                
                print(record)
                
                // System Field from property
                //let recordName_fromProperty = record.recordID.recordName
                //print("System Field, recordName: \(recordName_fromProperty)")
                //let deeplink = record.value(forKey: "deeplink")
                //print("Custom Field, deeplink: \(deeplink ?? "")")
            })
        }*/
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
}
