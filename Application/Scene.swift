//
//  Scene.swift
//  Render-Z
//
//  Created by Markus Moenig on 8/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
/*
class TerrainLayer          : Codable, Equatable
{
    enum LayerNoiseType     : Int, Codable {
        case None, TwoD, ThreeD, Image
    }
    
    enum LayerBlendType     : Int, Codable {
        case Add, Subtract, Max
    }
    
    enum ShapesBlendType    : Int, Codable {
        case FactorTimesShape, Factor
    }
    
    var uuid                : UUID = UUID()
    
    var noiseType           : LayerNoiseType = .None
    var blendType           : LayerBlendType = .Add

    var noise2DFragment     : CodeFragment
    var noise3DFragment     : CodeFragment
    var imageFragment       : CodeFragment
    
    var shapesBlendType     : ShapesBlendType = .FactorTimesShape
    var shapes              : [CodeComponent] = []
    var material            : StageItem? = nil
    var object              : StageItem? = nil

    var shapeFactor         : Float = 0
    
    var objectSpacing       : Float = 5
    var objectRandom        : Float = 0
    var objectVisible       : Float = 1

    private enum CodingKeys : String, CodingKey {
        case uuid
        case noiseType
        case blendType
        case noise2DFragment
        case noise3DFragment
        case imageFragment
        case regionType
        case shapesBlendType
        case shapes
        case shapeFactor
        case material
        case object
        case objectSpacing
        case objectRandom
        case objectVisible
    }
     
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        noiseType = try container.decode(LayerNoiseType.self, forKey: .noiseType)
        blendType = try container.decode(LayerBlendType.self, forKey: .blendType)
        noise2DFragment = try container.decode(CodeFragment.self, forKey: .noise2DFragment)
        noise3DFragment = try container.decode(CodeFragment.self, forKey: .noise3DFragment)
        imageFragment = try container.decode(CodeFragment.self, forKey: .imageFragment)
        shapesBlendType = try container.decode(ShapesBlendType.self, forKey: .shapesBlendType)
        shapes = try container.decode([CodeComponent].self, forKey: .shapes)
        material = try container.decode(StageItem?.self, forKey: .material)
        if let obj = try container.decodeIfPresent(StageItem?.self, forKey: .object) {
            object = obj
        }
        shapeFactor = try container.decode(Float.self, forKey: .shapeFactor)
        if let spacing = try container.decodeIfPresent(Float.self, forKey: .objectSpacing) {
            self.objectSpacing = spacing
        }
        if let random = try container.decodeIfPresent(Float.self, forKey: .objectRandom) {
            self.objectRandom = random
        }
        if let visible = try container.decodeIfPresent(Float.self, forKey: .objectVisible) {
            self.objectVisible = visible
        }
    }
     
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(noiseType, forKey: .noiseType)
        try container.encode(blendType, forKey: .blendType)
        try container.encode(noise2DFragment, forKey: .noise2DFragment)
        try container.encode(noise3DFragment, forKey: .noise3DFragment)
        try container.encode(imageFragment, forKey: .imageFragment)
        try container.encode(shapesBlendType, forKey: .shapesBlendType)
        try container.encode(shapes, forKey: .shapes)
        try container.encode(shapeFactor, forKey: .shapeFactor)
        try container.encode(material, forKey: .material)
        try container.encode(object, forKey: .object)
        try container.encode(objectSpacing, forKey: .objectSpacing)
        try container.encode(objectRandom, forKey: .objectRandom)
        try container.encode(objectVisible, forKey: .objectVisible)
    }
     
    static func ==(lhs:TerrainLayer, rhs:TerrainLayer) -> Bool {
        return lhs.uuid == rhs.uuid
    }
     
    init()
    {
        noise2DFragment = CodeFragment(.Primitive)
        noise3DFragment = CodeFragment(.Primitive)
        imageFragment = CodeFragment(.Primitive)
    }
}*/

class Terrain               : Codable
{
    enum TerrainNoiseType     : Int, Codable {
        case None, TwoD, ThreeD, Image
    }
    
    var noiseType           : TerrainNoiseType = .None
    
    var noise2DFragment     : CodeFragment
    var noise3DFragment     : CodeFragment
    var imageFragment       : CodeFragment
    
    var texture             : MTLTexture? = nil
    var terrainData         : Data!
    var terrainSize         : Float = 1024
    var terrainScale        : Float = 0.1
    var terrainHeightScale  : Float = 0.5
    
    var rayMarcher          : CodeComponent? = nil

    private enum CodingKeys: String, CodingKey {
        case noiseType
        case layers
        case materials
        case terrainData
        case terrainSize
        case terrainScale
        case noise2DFragment
        case noise3DFragment
        case imageFragment
        case terrainHeightScale
        case rayMarcher
    }
     
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        terrainData = try container.decode(Data.self, forKey: .terrainData)
        terrainSize = try container.decode(Float.self, forKey: .terrainSize)
        terrainScale = try container.decode(Float.self, forKey: .terrainScale)
        terrainHeightScale = try container.decode(Float.self, forKey: .terrainHeightScale)
        rayMarcher = try container.decode(CodeComponent?.self, forKey: .rayMarcher)

        noiseType = try container.decode(TerrainNoiseType.self, forKey: .noiseType)
        noise2DFragment = try container.decode(CodeFragment.self, forKey: .noise2DFragment)
        noise3DFragment = try container.decode(CodeFragment.self, forKey: .noise3DFragment)
        imageFragment = try container.decode(CodeFragment.self, forKey: .imageFragment)
        
        texture = globalApp!.currentPipeline?.checkTextureSize(terrainSize, terrainSize, texture, .r8Sint)
        
        let region = MTLRegionMake2D(0, 0, Int(terrainSize) - 1, Int(terrainSize)-1)
        terrainData.withUnsafeMutableBytes { texArrayPtr in
            if let ptr = texArrayPtr.baseAddress {
                if let texture = texture {
                    texture.replace(region: region, mipmapLevel: 0, withBytes: ptr, bytesPerRow: (MemoryLayout<Int8>.size * texture.width))
                }
            }
        }
    }
     
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(noiseType, forKey: .noiseType)

        let region = MTLRegionMake2D(0, 0, Int(terrainSize) - 1, Int(terrainSize)-1)
        var texArray = Array<Int8>(repeating: Int8(0), count: Int(terrainSize*terrainSize))
        texArray.withUnsafeMutableBytes { texArrayPtr in
            if let ptr = texArrayPtr.baseAddress {
                if let texture = getTexture() {
                    texture.getBytes(ptr, bytesPerRow: (MemoryLayout<Int8>.size * texture.width), from: region, mipmapLevel: 0)
                }
            }
        }
        let data = Data(bytes: texArray, count: Int(terrainSize*terrainSize))
        try container.encode(data, forKey: .terrainData)
        
        try container.encode(noise2DFragment, forKey: .noise2DFragment)
        try container.encode(noise3DFragment, forKey: .noise3DFragment)
        try container.encode(imageFragment, forKey: .imageFragment)
        
        try container.encode(terrainSize, forKey: .terrainSize)
        try container.encode(terrainScale, forKey: .terrainScale)
        try container.encode(terrainHeightScale, forKey: .terrainHeightScale)
        try container.encode(rayMarcher, forKey: .rayMarcher)
    }
     
    init()
    {
        texture = globalApp!.currentPipeline?.checkTextureSize(terrainSize, terrainSize, texture, .r8Sint)
        globalApp!.currentPipeline?.codeBuilder.renderClearTerrain(texture: texture!)
        
        if let materialComponent = globalApp!.libraryDialog.getMaterial(ofId: "Basic", withName: "PBR") {
            
            materialComponent.uuid = UUID()
        }
        
        noise2DFragment = CodeFragment(.Primitive)
        noise3DFragment = CodeFragment(.Primitive)
        imageFragment = CodeFragment(.Primitive)
        
        rayMarcher = globalApp!.libraryDialog.getItem(ofId: "RayMarch3D", withName: "RayMarch")
        if let raymarch = rayMarcher {
            setPropertyValue1(component: raymarch, name: "steps", value: 300)
            setPropertyValue1(component: raymarch, name: "stepSize", value: 1.0)
        }
    }
    
    func getTexture() -> MTLTexture?
    {
        return texture
    }
}

class Scene                 : Codable, Equatable
{
    var name                : String = ""
    var uuid                : UUID = UUID()

    var selectedUUID        : UUID? = nil

    var items               : [CodeComponent] = []

    private enum CodingKeys: String, CodingKey {
        case name
        case uuid
        case selectedUUID
        case items
    }
   
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)

        if let selected = try container.decodeIfPresent(UUID?.self, forKey: .selectedUUID) {
            selectedUUID = selected
        } else {
            selectedUUID = nil
        }
        
        if let i = try container.decodeIfPresent([CodeComponent].self, forKey: .items) {
            items = i
        } else {
            var items : [CodeComponent] = []
            
            let codeComponent = CodeComponent(.Shader, "Shader")
            codeComponent.createDefaultFunction(.Shader)
            
            items.append(codeComponent)
            self.items = items
        }
        
        globalApp!.currentPipeline = globalApp!.pipelineFX
    }
   
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(items, forKey: .items)
        try container.encode(selectedUUID, forKey: .selectedUUID)
    }
   
    static func ==(lhs:Scene, rhs:Scene) -> Bool {
       return lhs.uuid == rhs.uuid
    }

    init(_ name: String = "")
    {
        self.name = name
    }
    
    /// Returns the selected UUID
    func getSelectedUUID() -> UUID?
    {
        return selectedUUID
    }
    
    /// Sets the selected UUID
    func setSelectedUUID(_ uuid: UUID)
    {
        selectedUUID = uuid
    }
    
    /// Find the item of the given uuid
    func itemOfUUID(_ uuid: UUID) -> CodeComponent?
    {
        for item in items {
            if item.uuid == uuid {
                return item
            }
        }
        return nil
    }
    
    /// Find the item of the given uuid
    func componentOfUUID(_ uuid: UUID) -> CodeComponent?
    {
        for item in self.items {
            if item.uuid == uuid {
                return item
            }
        }
        return nil
    }
    
    /// Find the index of the given uuid
    func indexOfUUID(_ uuid: UUID) -> Int?
    {
        for (index, item) in self.items.enumerated() {
            if item.uuid == uuid {
                return index
            }
        }
        return nil
    }
    
    /// Returns the currently selected item
    func getSelected() -> CodeComponent?
    {
        if let uuid = getSelectedUUID() {
            return itemOfUUID(uuid)
        }
        return nil
    }
    
    /// Sets the selected item for the scene and updates the current editor
    func setSelected(_ item: CodeComponent)
    {
        setSelectedUUID(item.uuid)
        globalApp!.currentEditor.setComponent(item)
    }
    
    /// Invalidate all compiler infos
    func invalidateCompilerInfos()
    {
        for item in items {
            item.builderInstance = nil
        }
        
        globalApp!.currentPipeline?.resetIds()
    }
    
    // Adds the default images to the variable stage
    func addDefaultImages()
    {
        /*
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
        }*/
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
