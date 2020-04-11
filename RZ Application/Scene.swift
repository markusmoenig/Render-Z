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
    var componentLabels     : [String:MMTextLabel] = [:]
    
    var builderInstance     : CodeBuilderInstance? = nil

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
        
        values["_graphShapesX"] = 150
        values["_graphShapesY"] = 0
        
        values["_graphDomainX"] = -170
        values["_graphDomainY"] = -50
        
        values["_graphModifierX"] = 20
        values["_graphModifierY"] = -120
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
        
        for it in children {
            it.updateStageItem(item)
        }
    }
    
    /// Return the component list of the given base name
    func getComponentList(_ name: String ) -> [CodeComponent]?
    {
        let id = name + (globalApp!.currentSceneMode == .TwoD ? "2D" : "3D")
        return componentLists[id]
    }
    
    /// Adds a material to this item
    func addMaterial()
    {
        let materialItem = StageItem(.ShapeStage, "Material")
        //var codeComponent = decodeComponentFromJSON(defaultRender2D)!
        var codeComponent = CodeComponent(.Material3D, "Material")
        codeComponent.createDefaultFunction(.Material3D)
        codeComponent.uuid = UUID()
        codeComponent.selected = nil
        materialItem.components[materialItem.defaultName] = codeComponent
        children.append(materialItem)
        placeChild(modeId: "3D", parent: self, child: materialItem, stepSize: 60, radius: 110, defaultStart: 10)
        
        let uvItem = StageItem(.ShapeStage, "UV Map")
        //var codeComponent = decodeComponentFromJSON(defaultRender2D)!
        codeComponent = CodeComponent(.UVMAP3D, "UV Map")
        codeComponent.createDefaultFunction(.UVMAP3D)
        codeComponent.uuid = UUID()
        codeComponent.selected = nil
        uvItem.components[uvItem.defaultName] = codeComponent
        children.append(uvItem)
        placeChild(modeId: "3D", parent: self, child: uvItem, stepSize: 50, radius: 110)
    }
}

class Stage                 : Codable, Equatable
{
    enum StageType          : Int, Codable {
        case PreStage, ShapeStage, LightStage, RenderStage, PostStage, VariablePool
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
        values["_graphY"] = -40
        
        if stageType == .PreStage {
            var item = StageItem(.PreStage, "Background")
            var codeComponent = CodeComponent(.Colorize)
            codeComponent.createDefaultFunction(.Colorize)
            item.components[item.defaultName] = codeComponent
            children2D.append(item)
            placeChild(modeId: "2D", parent: self, child: item, stepSize: 50, radius: 150)
            
            item = StageItem(.PreStage, "Camera")
            //codeComponent = CodeComponent(.Camera2D)
            //codeComponent.createDefaultFunction(.Camera2D)
            codeComponent = decodeComponentFromJSON(defaultCamera2D)!
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children2D.append(item)
            placeChild(modeId: "2D", parent: self, child: item, stepSize: 50, radius: 150)
            
            item = StageItem(.PreStage, "Sky Dome")
            codeComponent = CodeComponent(.SkyDome)
            codeComponent.createDefaultFunction(.SkyDome)
            item.components[item.defaultName] = codeComponent
            children3D.append(item)
            placeChild(modeId: "3D", parent: self, child: item, stepSize: 50, radius: 150)
            
            item = StageItem(.PreStage, "Camera")
            //codeComponent = CodeComponent(.Camera3D)
            //codeComponent.createDefaultFunction(.Camera3D)
            codeComponent = decodeComponentFromJSON(defaultCamera3D)!
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children3D.append(item)
            placeChild(modeId: "3D", parent: self, child: item, stepSize: 50, radius: 150)
            
            folderIsOpen = true
        }
        
        if stageType == .ShapeStage {
            
            let item = StageItem(.ShapeStage, "Ground")
            //let codeComponent = CodeComponent(.Ground3D, "Plane")
            //codeComponent.createDefaultFunction(.Ground3D)
            let codeComponent = decodeComponentFromJSON(defaultGround3D)!
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children3D.append(item)
            
            item.values["_graphX"] = 80
            item.values["_graphY"] = 120
            
            item.addMaterial()
        }
        
        
        if stageType == .RenderStage {
            
            values["_graphX"] = 240
            values["_graphY"] = -40
            
            var item = StageItem(.RenderStage, "Color")
            var codeComponent = decodeComponentFromJSON(defaultRender2D)!
            //let codeComponent = CodeComponent(.Render2D, "Black")
            //codeComponent.createDefaultFunction(.Render2D)
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children2D.append(item)
            
            item = StageItem(.RenderStage, "Color")
            //codeComponent = decodeComponentFromJSON(defaultRender2D)!
            codeComponent = CodeComponent(.Render3D, "Black")
            codeComponent.createDefaultFunction(.Render3D)
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            item.components[item.defaultName] = codeComponent
            children3D.append(item)
                        
            // RayMarch
            let rayMarchItem = StageItem(.RenderStage, "RayMarch")
            children3D.append(rayMarchItem)
            placeChild(modeId: "3D", parent: self, child: rayMarchItem, stepSize: 50, radius: 150)
            
            codeComponent = CodeComponent(.RayMarch3D, "RayMarch")
            codeComponent.createDefaultFunction(.RayMarch3D)
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            rayMarchItem.components[item.defaultName] = codeComponent
            
            // Occlusion
            let aoItem = StageItem(.RenderStage, "Occlusion")
            children3D.append(aoItem)
            placeChild(modeId: "3D", parent: self, child: aoItem, stepSize: 80, radius: 140)
            
            //codeComponent = CodeComponent(.AO3D, "AO")
            //codeComponent.createDefaultFunction(.AO3D)
            codeComponent = decodeComponentFromJSON(defaultAO3D)!
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            aoItem.components[item.defaultName] = codeComponent
            
            // Normal
            let normalItem = StageItem(.RenderStage, "Normal")
            children3D.append(normalItem)
            placeChild(modeId: "3D", parent: self, child: normalItem, stepSize: 120, radius: 90)
            
            codeComponent = CodeComponent(.Normal3D, "Normal")
            codeComponent.createDefaultFunction(.Normal3D)
            //codeComponent = decodeComponentFromJSON(defaultAO3D)!
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            normalItem.components[item.defaultName] = codeComponent
            
            // Shadows
            let shadowsItem = StageItem(.RenderStage, "Shadows")
            children3D.append(shadowsItem)
            placeChild(modeId: "3D", parent: self, child: shadowsItem, stepSize: 50, radius: 70)
            
            codeComponent = CodeComponent(.Shadows3D, "Shadows")
            codeComponent.createDefaultFunction(.Shadows3D)
            //codeComponent = decodeComponentFromJSON(defaultAO3D)!
            codeComponent.uuid = UUID()
            codeComponent.selected = nil
            shadowsItem.components[item.defaultName] = codeComponent
        }
        
        if stageType == .VariablePool {
            values["_graphX"] = 380
            values["_graphY"] = 140
            
            // Create World Pool
            let worldPool = StageItem(.VariablePool, "World")
            worldPool.values["locked"] = 1
            children3D.append(worldPool)
            placeChild(modeId: "3D", parent: self, child: worldPool, stepSize: 70, radius: 150)
            
            let worldAmbientComponent = CodeComponent(.Variable, "Ambient Color")
            worldAmbientComponent.values["locked"] = 1
            worldAmbientComponent.createVariableFunction("worldAmbient", "float4", "Ambient Color", defaultValue: SIMD4<Float>(0.05,0.15,0.25, 1), gizmo: 2)
            
            let worldFogDensityComponent = CodeComponent(.Variable, "Fog Density")
            worldFogDensityComponent.values["locked"] = 1
            worldFogDensityComponent.createVariableFunction("worldFogDensity", "float", "Fog Density", defaultValue: Float(0), gizmo: 2)
            
            worldPool.componentLists["variables"] = [worldAmbientComponent, worldFogDensityComponent]

            // Create Sun Pool
            let sunPool = StageItem(.VariablePool, "Sun")
            sunPool.values["locked"] = 1
            children3D.append(sunPool)
            placeChild(modeId: "3D", parent: self, child: sunPool, stepSize: 70, radius: 150)
            
            let sunDirComponent = CodeComponent(.Variable, "Sun Direction")
            sunDirComponent.values["locked"] = 1
            sunDirComponent.createVariableFunction("sunDirection", "float3", "Sun Direction", defaultValue: SIMD3<Float>(0,1,0), defaultMinMax: SIMD2<Float>(-1,1), gizmo: 2)
            
            let sunColorComponent = CodeComponent(.Variable, "Sun Color")
            sunColorComponent.values["locked"] = 1
            sunColorComponent.createVariableFunction("sunColor", "float4", "Sun Color", defaultValue: SIMD4<Float>(0.9,0.55,0.35,1), gizmo: 2)
            
            let sunStrengthComponent = CodeComponent(.Variable, "Sun Strength")
            sunStrengthComponent.values["locked"] = 1
            sunStrengthComponent.createVariableFunction("sunStrength", "float", "Sun Strength", defaultValue: Float(5.0), defaultMinMax: SIMD2<Float>(0,20))

            sunPool.componentLists["variables"] = [sunDirComponent,sunColorComponent, sunStrengthComponent]
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
    @discardableResult func createChild(_ name: String = "", parent: StageItem? = nil ) -> StageItem
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
            
            //let defComponent3D = CodeComponent(.Domain3D, "domain")
            //defComponent3D.createDefaultFunction(.Domain3D)
            
            stageItem.componentLists["domain2D"] = []
            stageItem.componentLists["domain3D"] = []
            
            //let defComponent3D = CodeComponent(.Modifier3D, "modifier")
            //defComponent3D.createDefaultFunction(.Modifier3D)
            
            stageItem.componentLists["modifier2D"] = []
            stageItem.componentLists["modifier3D"] = []//defComponent3D
            
            if parent == nil {
                stageItem.addMaterial()
            }
        } else
        if stageItem.stageItemType == .LightStage {
            
            let transformComponent = CodeComponent( globalApp!.currentSceneMode == .TwoD ? .Transform2D : .PointLight3D, "Light")
            transformComponent.createDefaultFunction(globalApp!.currentSceneMode == .TwoD ? .Transform2D : .PointLight3D)
            stageItem.components[stageItem.defaultName] = transformComponent
            setDefaultComponentValues(transformComponent)
        }

        if let parent = parent {
            parent.children.append(stageItem)
        } else {
            if globalApp!.currentSceneMode == .TwoD
            {
                children2D.append(stageItem)
            } else {
                children3D.append(stageItem)
            }
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
        
        for it in children2D {
            it.updateStageItem(item)
        }
        for it in children3D {
            it.updateStageItem(item)
        }
    }
    
    /// Finds the parent of a given StageItem
    func getParentOfStageItem(_ stageItem: StageItem) -> (Stage?, StageItem?)
    {
        if children2D.contains(stageItem) || children3D.contains(stageItem) {
            return (self, nil)
        }
        
        func parseTree(_ tree: [StageItem]) -> StageItem?
        {
            for item in tree {
                if item.children.contains(stageItem) {
                    return item
                } else {
                    if let found = parseTree(item.children) {
                        return found
                    }
                }
            }
            return nil
        }
        
        if let item = parseTree(children2D) {
            return(self,item)
        }
        if let item = parseTree(children3D) {
            return(self,item)
        }
        
        return(nil,nil)
    }
    
    // Only for VariablePool, get all Variable Components
    func getGlobalVariable() -> [String:CodeComponent]
    {
        var compMap : [String:CodeComponent] = [:]
        for child in getChildren() {
            if let vars = child.componentLists["variables"] {
                for c in vars {
                    for uuid in c.properties {
                        let rc = c.getPropertyOfUUID(uuid)
                        if rc.0!.values["variable"] == 1 {
                            compMap[child.name + "." + rc.0!.name] = c
                        }
                    }
                }
            }
        }
        return compMap
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
            if sceneMode == .TwoD {
                globalApp!.currentPipeline = globalApp!.pipeline2D
            } else {
                globalApp!.currentPipeline = globalApp!.pipeline3D
            }
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
        stages.append(Stage(.VariablePool, "Variables"))

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
        } else
        if stageType == .RenderStage {
            return stages[3]
        } else
        if stageType == .PostStage {
            return stages[4]
        } else
        if stageType == .VariablePool {
            return stages[5]
        }
        return stages[0]
    }
    
    /// Update the stage
    func updateStage(_ stage: Stage)
    {
        if stage.stageType == .PreStage {
            stages[0] = stage
        } else
        if stage.stageType == .ShapeStage {
            stages[1] = stage
        } else
        if stage.stageType == .LightStage {
            stages[2] = stage
        } else
        if stage.stageType == .RenderStage {
            stages[3] = stage
        } else
        if stage.stageType == .PostStage {
            stages[4] = stage
        } else
        if stage.stageType == .VariablePool {
            stages[5] = stage
        }
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
    
    /// Get the stage item for the given component and optionally select it
    @discardableResult func getStageItem(_ component: CodeComponent, selectIt: Bool = false) -> StageItem?
    {
        class SearchInfo {
            var stageItem   : StageItem? = nil
            var component   : CodeComponent? = nil
        }
        
        var result = SearchInfo()
        
        func findInItem(_ stageItem: StageItem)
        {
            if result.component == nil {
                for (_,c) in stageItem.components {
                    if  c === component {
                        result.component = c
                        result.stageItem = stageItem
                        break
                    } else
                    if c.subComponent === component {
                        result.component = c.subComponent
                        result.stageItem = stageItem
                    }
                }
            }
            if result.component == nil {
                for (_,cl) in stageItem.componentLists {
                    for c in cl {
                        if  c === component {
                            result.component = c
                            result.stageItem = stageItem
                            break
                        } else
                        if c.subComponent === component {
                            result.component = c.subComponent
                            result.stageItem = stageItem
                        }
                    }
                }
            }
            if result.component == nil {
                findInChildren(stageItem.children)
            }
        }
        
        func findInChildren(_ children: [StageItem])
        {
            for c in children {
                findInItem(c)
            }
        }
        
        func findInStage(_ stage: Stage)
        {
            findInChildren(stage.children2D)
            findInChildren(stage.children3D)
        }
        
        for s in stages {
            if result.component == nil {
                findInStage(s)
                if result.component != nil {
                    if selectIt {
                        globalApp!.sceneGraph.setCurrent(stage: s, stageItem: result.stageItem, component: result.component)
                    }
                    break
                }
            }
        }
        
        return result.stageItem
    }
    
    /// Invalidate all compiler infos
    func invalidateCompilerInfos()
    {
        func findInItem(_ stageItem: StageItem)
        {
            stageItem.builderInstance = nil
            findInChildren(stageItem.children)
        }
        
        func findInChildren(_ children: [StageItem])
        {
            for c in children {
                findInItem(c)
            }
        }
        
        func findInStage(_ stage: Stage)
        {
            findInChildren(stage.children2D)
            findInChildren(stage.children3D)
        }
        
        for s in stages {
            findInStage(s)
        }
        
        globalApp!.currentPipeline?.resetIds()
    }
    
    // Adds the default images to the variable stage
    func addDefaultImages()
    {
        let stage = getStage(.VariablePool)
        
        var imageItem : StageItem? = nil
        // Find image pool stage
        for item in stage.children3D {
            if item.name == "Images" {
                imageItem = item
            }
        }
        
        if imageItem == nil {
            imageItem = StageItem(.VariablePool, "Images")
            imageItem!.values["locked"] = 1
            placeChild(modeId: "3D", parent: stage, child: imageItem!, stepSize: 60, radius: 90, defaultStart: 10)
            stage.children3D.append(imageItem!)
        }
        
        imageItem!.componentLists["images"] = []
                
        for (name, texture) in globalApp!.images {
            let component = CodeComponent(.Image)
            component.libraryName = name
            component.texture = texture
            imageItem!.componentLists["images"]!.append(component)
        }
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
