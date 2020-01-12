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
    var children            : [StageItem] = []

    private enum CodingKeys: String, CodingKey {
        case stageItemType
        case name
        case uuid
        case folderIsOpen
        case components
        case children
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stageItemType = try container.decode(Stage.StageType.self, forKey: .stageItemType)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        folderIsOpen = try container.decode(Bool.self, forKey: .folderIsOpen)
        components = try container.decode([String:CodeComponent].self, forKey: .components)
        children = try container.decode([StageItem].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stageItemType, forKey: .stageItemType)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(folderIsOpen, forKey: .folderIsOpen)
        try container.encode(components, forKey: .components)
        try container.encode(children, forKey: .children)
    }
    
    static func ==(lhs:StageItem, rhs:StageItem) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    init(_ stageItemType: Stage.StageType,_ name: String = "")
    {
        self.stageItemType = stageItemType
        self.name = name
        
        if stageItemType == .PreStage {
            let codeComponent = CodeComponent()
            codeComponent.createDefaultFunction(.Colorize)
            components["main"] = codeComponent
        } else
        if stageItemType == .ShapeStage {
            let codeComponent = CodeComponent(.SDF2D)
            codeComponent.createDefaultFunction(.SDF2D)
            components["main"] = codeComponent
        }
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
        for child in children {
            child.updateComponent(comp)
        }
    }
}

class Stage                 : Codable, Equatable
{
    enum StageType          : Int, Codable{
        case PreStage, ShapeStage, RenderStage, PostStage
    }
    
    var stageType           : StageType = .PreStage

    var name                : String = ""
    var uuid                : UUID = UUID()
 
    var folderIsOpen        : Bool = false
    
    var children            : [StageItem] = []
    
    private enum CodingKeys: String, CodingKey {
        case stageType
        case name
        case uuid
        case folderIsOpen
        case children
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stageType = try container.decode(StageType.self, forKey: .stageType)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        folderIsOpen = try container.decode(Bool.self, forKey: .folderIsOpen)
        children = try container.decode([StageItem].self, forKey: .children)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stageType, forKey: .stageType)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(folderIsOpen, forKey: .folderIsOpen)
        try container.encode(children, forKey: .children)
    }
    
    static func ==(lhs:Stage, rhs:Stage) -> Bool {
        return lhs.uuid == rhs.uuid
    }
    
    init(_ stageType: StageType,_ name: String = "")
    {
        self.stageType = stageType
        self.name = name
    }
    
    /// Adds a new stage item to the children list and returns it
    func createChild(_ name: String = "") -> StageItem
    {
        let stageItem = StageItem(stageType, name)
        children.append(stageItem)
        folderIsOpen = true
        return stageItem
    }
    
    /// Recursively update the component
    func updateComponent(_ comp: CodeComponent)
    {
        for child in children {
            child.updateComponent(comp)
        }
    }
}

class Scene                 : Codable, Equatable
{
    var name                : String = ""
    var uuid                : UUID = UUID()

    var selectedUUID        : UUID? = nil
    var selected            : StageItem? = nil

    var stages             : [Stage] = []
   
    private enum CodingKeys: String, CodingKey {
        case name
        case uuid
        case selectedUUID
        case stages
    }
   
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        selectedUUID = try container.decode(UUID?.self, forKey: .selectedUUID)
        stages = try container.decode([Stage].self, forKey: .stages)
        
        if let uuid = selectedUUID {
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
        try container.encode(selectedUUID, forKey: .selectedUUID)
        try container.encode(stages, forKey: .stages)
    }
   
    static func ==(lhs:Scene, rhs:Scene) -> Bool {
       return lhs.uuid == rhs.uuid
    }

    init(_ name: String = "")
    {
        self.name = name
        
        self.stages.append(Stage(.PreStage, "World"))
        self.stages.append(Stage(.ShapeStage, "Shape"))
        self.stages.append(Stage(.RenderStage, "Render"))
        self.stages.append(Stage(.PostStage, "Post FX"))
    }
    
    /// Recursively update the component
    func updateComponent(_ comp: CodeComponent)
    {
        for stage in stages {
            for item in stage.children {
                item.updateComponent(comp)
            }
        }
    }
    
    /// Find the item of the given uuid
    func itemOfUUID(_ uuid: UUID) -> StageItem?
    {
        for stage in stages {
            for item in stage.children {
                if item.uuid == uuid {
                    return item
                }
            }
        }
        return nil
    }
    
    /// Sets the selected item for the scene and updates the current editor
    func setSelected(_ item: StageItem)
    {
        selected = item
        selectedUUID = item.uuid
        
        globalApp!.currentEditor.setComponent(item.components["main"]!)
    }
}

class Project               : Codable, Equatable
{
    var name                : String = ""
    var uuid                : UUID = UUID()

    var scenes              : [Scene] = []
    
    var selectedUUID        : UUID? = nil
    var selected            : Scene? = nil
   
    private enum CodingKeys: String, CodingKey {
        case name
        case uuid
        case selectedUUID
        case scenes
    }
   
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        selectedUUID = try container.decode(UUID?.self, forKey: .selectedUUID)
        scenes = try container.decode([Scene].self, forKey: .scenes)
        
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
    }
   
    static func ==(lhs:Project, rhs:Project) -> Bool {
        return lhs.uuid == rhs.uuid
    }

    init(_ name: String = "")
    {
        self.name = name
        
        let scene = Scene("Untitled")
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
