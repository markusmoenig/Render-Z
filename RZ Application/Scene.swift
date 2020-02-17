//
//  Scene.swift
//  Render-Z
//
//  Created by Markus Moenig on 8/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

class StageItem             : Codable, Equatable
{
    var stageItemType       : Stage.StageType = .PreStage
    var name                : String = ""
    var uuid                : UUID = UUID()
 
    var folderIsOpen        : Bool = false

    var components          : [String:CodeComponent] = [:]
    var componentLists      : [String:[CodeComponent]] = [:]

    var children            : [StageItem] = []
    
    var defaultName         : String = "main"
    
    var values              : [String:Float] = [:]
    
    var label               : MMTextLabel? = nil

    private enum CodingKeys: String, CodingKey {
        case stageItemType
        case name
        case uuid
        case folderIsOpen
        case components
        case componentLists
        case children
        case defaultName
        case values
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stageItemType = try container.decode(Stage.StageType.self, forKey: .stageItemType)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        folderIsOpen = try container.decode(Bool.self, forKey: .folderIsOpen)
        components = try container.decode([String:CodeComponent].self, forKey: .components)
        componentLists = try container.decode([String:[CodeComponent]].self, forKey: .componentLists)
        children = try container.decode([StageItem].self, forKey: .children)
        defaultName = try container.decode(String.self, forKey: .defaultName)
        values = try container.decode([String:Float].self, forKey: .values)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stageItemType, forKey: .stageItemType)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(folderIsOpen, forKey: .folderIsOpen)
        try container.encode(components, forKey: .components)
        try container.encode(componentLists, forKey: .componentLists)
        try container.encode(children, forKey: .children)
        try container.encode(defaultName, forKey: .defaultName)
        try container.encode(values, forKey: .values)
    }
    
    static func ==(lhs:StageItem, rhs:StageItem) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    init(_ stageItemType: Stage.StageType,_ name: String = "")
    {
        self.stageItemType = stageItemType
        self.name = name
        
        values["_graphX"] = 0
        values["_graphY"] = 0
        
        values["_graphShapesX"] = 120
        values["_graphShapesY"] = 40
    }

    /// Recursively update the component
    func updateComponent(_ comp: CodeComponent)
    {
        for (id, c) in components {
            if c.uuid == comp.uuid {
                components[id] = comp
                return
            }
        }
        for (id, list) in componentLists {
            if let index = list.firstIndex(of: comp) {
                componentLists[id]![index] = comp
                return
            }
        }
        for child in children {
            child.updateComponent(comp)
        }
    }
    
    /// Recursively update the item
    func updateStageItem(_ item: StageItem)
    {
        if let index = children.firstIndex(of: item) {
            children[index] = item
            return
        }
        
        for item in children {
            item.updateStageItem(item)
        }
    }
    
    /// Return the component list of the given base name
    func getComponentList(_ name: String ) -> [CodeComponent]?
    {
        let id = name + (globalApp!.currentSceneMode == .TwoD ? "2D" : "3D")
        return componentLists[id]
    }
}

class Stage                 : Codable, Equatable
{
    enum StageType          : Int, Codable {
        case PreStage, ShapeStage, LightStage, RenderStage, PostStage
    }
    
    var stageType           : StageType = .PreStage

    var name                : String = ""
    var uuid                : UUID = UUID()
 
    var folderIsOpen        : Bool = false
    
    var children2D          : [StageItem] = []
    var children3D          : [StageItem] = []

    var values              : [String:Float] = [:]
    
    var label               : MMTextLabel? = nil
    
    private enum CodingKeys: String, CodingKey {
        case stageType
        case name
        case uuid
        case folderIsOpen
        case children2D
        case children3D
        case values
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stageType = try container.decode(StageType.self, forKey: .stageType)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        folderIsOpen = try container.decode(Bool.self, forKey: .folderIsOpen)
        children2D = try container.decode([StageItem].self, forKey: .children2D)
        children3D = try container.decode([StageItem].self, forKey: .children3D)
        values = try container.decode([String:Float].self, forKey: .values)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stageType, forKey: .stageType)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(folderIsOpen, forKey: .folderIsOpen)
        try container.encode(children2D, forKey: .children2D)
        try container.encode(children3D, forKey: .children3D)
        try container.encode(values, forKey: .values)
    }
    
    static func ==(lhs:Stage, rhs:Stage) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    init(_ stageType: StageType,_ name: String = "")
    {
        self.stageType = stageType
        self.name = name
        
        values["_graphX"] = 0
        values["_graphY"] = 0
        
        if stageType == .PreStage {
            var item = StageItem(.PreStage, "Background")
            var codeComponent = CodeComponent(.Colorize)
            codeComponent.createDefaultFunction(.Colorize)
            item.components[item.defaultName] = codeComponent
            children2D.append(item)
            
            item.values["_graphX"] = 100
            item.values["_graphY"] = -50
            
            item = StageItem(.PreStage, "Camera")
            //codeComponent = CodeComponent(.Camera2D)
            //codeComponent.createDefaultFunction(.Camera2D)
            codeComponent = decodeComponentFromJSON(defaultCamera2D)!
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children2D.append(item)
            
            item.values["_graphX"] = 130
            item.values["_graphY"] = 70
            
            item = StageItem(.PreStage, "Sky Dome")
            codeComponent = CodeComponent(.SkyDome)
            codeComponent.createDefaultFunction(.SkyDome)
            item.components[item.defaultName] = codeComponent
            children3D.append(item)
            
            item.values["_graphX"] = 100
            item.values["_graphY"] = -50
            
            item = StageItem(.PreStage, "Camera")
            //codeComponent = CodeComponent(.Camera3D)
            //codeComponent.createDefaultFunction(.Camera3D)
            codeComponent = decodeComponentFromJSON(defaultCamera3D)!
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children3D.append(item)
            
            item.values["_graphX"] = 130
            item.values["_graphY"] = 70
            
            folderIsOpen = true
        }
        
        if stageType == .RenderStage {
            
            values["_graphX"] = 200
            values["_graphY"] = 0
            
            var item = StageItem(.RenderStage, "Color")
            var codeComponent = decodeComponentFromJSON(defaultRender2D)!
            //let codeComponent = CodeComponent(.Render2D, "Black")
            //codeComponent.createDefaultFunction(.Render2D)
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children2D.append(item)
            
            item.values["_graphX"] = 130
            item.values["_graphY"] = 70
            
            item = StageItem(.RenderStage, "Color")
            //codeComponent = decodeComponentFromJSON(defaultRender2D)!
            codeComponent = CodeComponent(.Render3D, "Black")
            codeComponent.createDefaultFunction(.Render3D)
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children3D.append(item)
            
            item.values["_graphX"] = 130
            item.values["_graphY"] = 70
        }
    }
    
    /// Returns the 2D or 3D children depending on the current scene mode
    func getChildren() -> [StageItem]
    {
        return globalApp!.currentSceneMode == .TwoD ? children2D : children3D
    }
    
    /// Sets the 2D or 3D children depending on the current scene mode
    func setChildren(_ children: [StageItem])
    {
        if globalApp!.currentSceneMode == .TwoD {
            children2D = children
        } else {
            children3D = children
        }
    }
    
    /// Adds a new stage item to the children list and returns it
    @discardableResult func createChild(_ name: String = "") -> StageItem
    {
        let stageItem = StageItem(stageType, name)
        
        if stageItem.stageItemType == .ShapeStage {
            
            let transformComponent = CodeComponent( globalApp!.currentSceneMode == .TwoD ? .Transform2D : .Transform3D, "Transform")
            transformComponent.createDefaultFunction(globalApp!.currentSceneMode == .TwoD ? .Transform2D : .Transform3D)
            stageItem.components[stageItem.defaultName] = transformComponent
            setDefaultComponentValues(transformComponent)
            
            //let defComponent = CodeComponent(.SDF2D, "Empty")
            //defComponent.createDefaultFunction(.SDF2D)
            
            //let defComponent3D = CodeComponent(.SDF3D, "Empty")
            //defComponent3D.createDefaultFunction(.SDF3D)

            stageItem.componentLists["shapes2D"] = []//[defComponent]
            stageItem.componentLists["shapes3D"] = []//defComponent3D]

            stageItem.componentLists["materials2D"] = []
            stageItem.componentLists["materials3D"] = []
            
            stageItem.componentLists["domain2D"] = []
            stageItem.componentLists["domain3D"] = []
        }
        
        if globalApp!.currentSceneMode == .TwoD
        {
            children2D.append(stageItem)
        } else {
            children3D.append(stageItem)
        }
        folderIsOpen = true
        return stageItem
    }
    
    /// Recursively update the component
    func updateComponent(_ comp: CodeComponent)
    {
        for item in children2D {
            item.updateComponent(comp)
        }
        for item in children3D {
            item.updateComponent(comp)
        }
    }
    
    /// Recursively update the item
    func updateStageItem(_ item: StageItem)
    {
        if let index = children2D.firstIndex(of: item) {
            children2D[index] = item
            return
        }
        if let index = children3D.firstIndex(of: item) {
            children3D[index] = item
            return
        }
        
        for item in children2D {
            item.updateStageItem(item)
        }
        for item in children3D {
            item.updateStageItem(item)
        }
    }
}

class Scene                 : Codable, Equatable
{
    enum SceneMode          : Int, Codable {
        case TwoD, ThreeD
    }
    
    var sceneMode           : SceneMode = .TwoD

    var name                : String = ""
    var uuid                : UUID = UUID()

    var selectedUUID2D      : UUID? = nil
    var selectedUUID3D      : UUID? = nil

    var stages              : [Stage] = []
       
    private enum CodingKeys: String, CodingKey {
        case name
        case uuid
        case selectedUUID2D
        case selectedUUID3D
        case stages
        case sceneMode
    }
   
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        selectedUUID2D = try container.decode(UUID?.self, forKey: .selectedUUID2D)
        selectedUUID3D = try container.decode(UUID?.self, forKey: .selectedUUID3D)
        stages = try container.decode([Stage].self, forKey: .stages)
        sceneMode = try container.decode(SceneMode.self, forKey: .sceneMode)

        if sceneMode != globalApp!.currentSceneMode {
            globalApp!.currentSceneMode = sceneMode
        }
        
        if sceneMode == .TwoD && uuid == selectedUUID2D {
            if let item = itemOfUUID(uuid) {
                setSelected(item)
            }
        } else
        if sceneMode == .ThreeD && uuid == selectedUUID3D {
            if let item = itemOfUUID(uuid) {
                setSelected(item)
            }
        }
    }
   
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(selectedUUID2D, forKey: .selectedUUID2D)
        try container.encode(selectedUUID3D, forKey: .selectedUUID3D)
        try container.encode(stages, forKey: .stages)
        try container.encode(sceneMode, forKey: .sceneMode)
    }
   
    static func ==(lhs:Scene, rhs:Scene) -> Bool {
       return lhs.uuid == rhs.uuid
    }

    init(_ sceneMode: SceneMode,_ name: String = "")
    {
        self.name = name
    
        self.sceneMode = sceneMode

        stages.append(Stage(.PreStage, "World"))
        stages.append(Stage(.ShapeStage, "Objects"))
        stages.append(Stage(.LightStage, "Lights"))
        stages.append(Stage(.RenderStage, "Render"))
        stages.append(Stage(.PostStage, "Post FX"))
        
        selectedUUID2D = stages[0].children2D[0].uuid
        selectedUUID3D = stages[0].children3D[0].uuid
    }
    
    /// Return the stage of the given type
    func getStage(_ stageType: Stage.StageType) -> Stage
    {
        if stageType == .PreStage {
            return stages[0]
        } else
        if stageType == .ShapeStage {
            return stages[1]
        } else
        if stageType == .LightStage {
            return stages[2]
        }
        if stageType == .RenderStage {
            return stages[3]
        }
        if stageType == .PostStage {
            return stages[4]
        }
        return stages[0]
    }
    
    /// Returns the selected UUID
    func getSelectedUUID() -> UUID?
    {
        if sceneMode == .TwoD {
            return selectedUUID2D
        } else {
            return selectedUUID3D
        }
    }
    
    /// Sets the selected UUID
    func setSelectedUUID(_ uuid: UUID)
    {
        if sceneMode == .TwoD {
            selectedUUID2D = uuid
        } else {
            selectedUUID3D = uuid
        }
    }
    
    /// Recursively update the component
    func updateComponent(_ comp: CodeComponent)
    {
        for stage in stages {
            stage.updateComponent(comp)
        }
    }
    
    /// Recursively update the item
    func updateStageItem(_ item: StageItem)
    {
        for stage in stages {
            stage.updateStageItem(item)
        }
    }
    
    /// Find the item of the given uuid
    func itemOfUUID(_ uuid: UUID) -> StageItem?
    {
        for stage in stages {
            for item in stage.getChildren() {
                if item.uuid == uuid {
                    return item
                }
            }
        }
        return nil
    }
    
    /// Returns the currently selected item
    func getSelected() -> StageItem?
    {
        if let uuid = getSelectedUUID() {
            return itemOfUUID(uuid)
        }
        return nil
    }
    
    /// Sets the selected item for the scene and updates the current editor
    func setSelected(_ item: StageItem)
    {
        setSelectedUUID(item.uuid)
        /*
        if let defaultComponent = item.components[item.defaultName] {
            globalApp!.currentEditor.setComponent(defaultComponent)
        }
        globalApp!.context.setSelected(item)
        if let app = globalApp { app.sceneGraph.needsUpdate = true }
        */
    }
}

class Project               : Codable, Equatable
{
    var name                : String = ""
    var uuid                : UUID = UUID()

    var scenes              : [Scene] = []
    
    var selectedUUID        : UUID? = nil
    var selected            : Scene? = nil
    
    var graphIsActive       : Bool = false
   
    private enum CodingKeys: String, CodingKey {
        case name
        case uuid
        case selectedUUID
        case scenes
        case graphIsActive
    }
   
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        selectedUUID = try container.decode(UUID?.self, forKey: .selectedUUID)
        scenes = try container.decode([Scene].self, forKey: .scenes)
        graphIsActive = try container.decode(Bool.self, forKey: .graphIsActive)

        if let uuid = selectedUUID {
            if let scene = sceneOfUUID(uuid) {
                setSelected(scene: scene)
            }
        }
    }
   
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(selectedUUID, forKey: .selectedUUID)
        try container.encode(scenes, forKey: .scenes)
        try container.encode(graphIsActive, forKey: .graphIsActive)
    }
   
    static func ==(lhs:Project, rhs:Project) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    init(_ sceneMode: Scene.SceneMode,_ name: String = "")
    {
        self.name = name
        
        let scene = Scene(sceneMode, "Untitled")
        scenes.append(scene)
        setSelected(scene: scene)
    }
    
    func sceneOfUUID(_ uuid: UUID) -> Scene?
    {
        for s in scenes {
            if s.uuid == uuid {
                return s
            }
        }
        return nil
    }
    
    func setSelected(scene: Scene)
    {
        selected = scene
        selectedUUID = scene.uuid
    }
}
