//
//  CodeUtilities.swift
//  Shape-Z
//
//  Created by Markus Moenig on 10/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

/// String extension for counting characters
extension String {
    func count(of needle: Character) -> Int {
        return reduce(0) {
            $1 == needle ? $0 + 1 : $0
        }
    }
}

// Extracts an SIMD4<Float> value from a given fragment
func extractValueFromFragment(_ fragment: CodeFragment) -> SIMD4<Float>
{
    var value: SIMD4<Float> = SIMD4<Float>(0,0,0,0)
    
    if fragment.fragmentType == .ConstantValue {
        value.x = fragment.values["value"]!
    }
    if fragment.fragmentType == .ConstantDefinition {
        let components = fragment.evaluateComponents()

        if fragment.arguments.count == components {
            for (index,arg) in fragment.arguments.enumerated() {
                value[index] = arg.fragments[0].values["value"]!
            }
        }
    }
    return value
}

// Extracts an SIMD3<Float> value from a given fragment
func extractValueFromFragment3(_ fragment: CodeFragment) -> SIMD3<Float>
{
    var value: SIMD3<Float> = SIMD3<Float>(0,0,0)
    
    if fragment.fragmentType == .ConstantValue {
        value.x = fragment.values["value"]!
    }
    if fragment.fragmentType == .ConstantDefinition {
        let components = fragment.evaluateComponents()

        if fragment.arguments.count == components {
            for (index,arg) in fragment.arguments.enumerated() {
                value[index] = arg.fragments[0].values["value"]!
            }
        }
    }
    return value
}

// Inserts an SIMD3<Float> value to a given fragment
func insertValueToFragment3(_ fragment: CodeFragment,_ value: SIMD3<Float>)
{
    if fragment.fragmentType == .ConstantDefinition {
        let components = fragment.evaluateComponents()
        if components == 3 || components == 4 {
            if fragment.arguments.count == components {
                for (index,arg) in fragment.arguments.enumerated() {
                    if index >= 3 {
                        break
                    }
                    arg.fragments[0].values["value"]! = value[index]
                }
            }
        }
    }
}

// Inserts an SIMD4<Float> value to a given fragment
func insertValueToFragment4(_ fragment: CodeFragment,_ value: SIMD4<Float>)
{
    if fragment.fragmentType == .ConstantDefinition {
        let components = fragment.evaluateComponents()
        if components == 4 {
            if fragment.arguments.count == components {
                for (index,arg) in fragment.arguments.enumerated() {
                    if index >= 4 {
                        break
                    }
                    arg.fragments[0].values["value"]! = value[index]
                }
            }
        }
    }
}

// Inserts an SIMD3<Float> value to a given fragment
func insertMinMaxToFragment(_ fragment: CodeFragment,_ minMax: SIMD2<Float>)
{
    if fragment.fragmentType == .ConstantDefinition {
        let components = fragment.evaluateComponents()
        if fragment.arguments.count == components {
            for arg in fragment.arguments {
                arg.fragments[0].values["min"]! = minMax.x
                arg.fragments[0].values["max"]! = minMax.y
            }
        }
    } else
    if fragment.fragmentType == .ConstantValue {
        fragment.values["min"]! = minMax.x
        fragment.values["max"]! = minMax.y
    }
}

import CloudKit

/// Upload the given component to the public or private libraries
func uploadToLibrary(_ component: CodeComponent, _ privateLibrary: Bool = true,_ functionOnly: CodeFunction? = nil)
{
    var name = component.libraryName
    if let function = functionOnly {
        name = function.libraryName
    }
    if name == "" {return}
    
    let subComponent = component.subComponent
    component.subComponent = nil
    
    var componentToUse : CodeComponent = component
    
    if let function = functionOnly {
        componentToUse = CodeComponent(.FunctionContainer)
        componentToUse.libraryCategory = component.libraryCategory
        componentToUse.libraryName = component.libraryName
        componentToUse.libraryComment = function.libraryComment

        componentToUse.functions.append(function)

        // Recursively add all functions the function depends on
        func addFunctions(_ function: CodeFunction)
        {
            for f in function.dependsOn {
                if componentToUse.functions.contains(f) == false {
                    componentToUse.functions.insert(f, at: 0)
                }
                addFunctions(f)
            }
        }
                
        for f in function.dependsOn {
            if componentToUse.functions.contains(f) == false {
                componentToUse.functions.insert(f, at: 0)
            }
            addFunctions(f)
        }
    }
    
    // For the upload reset the position of the component to 0
    let oldValues = componentToUse.values
    //let oldSelected = componentToUse.selected
    
    componentToUse.selected = nil
    if componentToUse.values["_posX"] != nil { componentToUse.values["_posX"] = 0.0 }
    if componentToUse.values["_posY"] != nil { componentToUse.values["_posY"] = 0.0 }
    if componentToUse.values["_posZ"] != nil { componentToUse.values["_posZ"] = 0.0 }

    let encodedData = try? JSONEncoder().encode(componentToUse)
    
    componentToUse.values = oldValues
    componentToUse.selected = nil//oldSelected

    if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
    {
        var libName = name
        if let function = functionOnly {
            libName += " :: Func"
            libName += function.libraryCategory
        } else {
            if component.componentType == .Colorize {
                libName += " :: Colorize"
            } else
            if component.componentType == .SkyDome {
                libName += " :: SkyDome"
            } else
            if component.componentType == .SDF2D {
                libName += " :: SDF2D"
            } else
            if component.componentType == .SDF3D {
                libName += " :: SDF3D"
            } else
            if component.componentType == .Render2D {
                libName += " :: Render2D"
            } else
            if component.componentType == .Render3D {
                libName += " :: Render3D"
            } else
            if component.componentType == .Boolean {
                libName += " :: Boolean"
            } else
            if component.componentType == .Camera2D {
                libName += " :: Camera2D"
            } else
            if component.componentType == .Camera3D {
                libName += " :: Camera3D"
            } else
            if component.componentType == .RayMarch3D {
                libName += " :: RayMarch3D"
            } else
            if component.componentType == .Ground3D {
                libName += " :: Ground3D"
            } else
            if component.componentType == .RegionProfile3D {
                libName += " :: RegionProfile3D"
            } else
            if component.componentType == .AO3D {
                libName += " :: AO3D"
            } else
            if component.componentType == .Shadows3D {
                libName += " :: Shadows3D"
            } else
            if component.componentType == .Normal3D {
                libName += " :: Normal3D"
            } else
            if component.componentType == .Material3D {
                libName += " :: Material3D"
            } else
            if component.componentType == .UVMAP3D {
                libName += " :: UVMAP3D"
            } else
            if component.componentType == .Domain2D {
                libName += " :: Domain2D"
            } else
            if component.componentType == .Domain3D {
                libName += " :: Domain3D"
            } else
            if component.componentType == .Modifier2D {
                libName += " :: Modifier2D"
            } else
            if component.componentType == .Modifier3D {
                libName += " :: Modifier3D"
            } else
            if component.componentType == .Light3D {
                libName += " :: Light3D"
            } else
            if component.componentType == .Pattern {
                libName += " :: Pattern"
            } else
            if component.componentType == .PostFX {
                libName += " :: PostFX"
            }
        }
        
        let recordID  = CKRecord.ID(recordName: libName)
        let record    = CKRecord(recordType: "components", recordID: recordID)
        
        record["json"] = encodedObjectJsonString
        record["description"] = componentToUse.libraryComment

        var uploadComponents = [CKRecord]()
        uploadComponents.append(record)

        let operation = CKModifyRecordsOperation(recordsToSave: uploadComponents, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys

        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in

            if let error = operationError {
                // error
                print("error", error)
            }

            if let saved = savedRecords {
                // print artist.name, or count the array, or whatever..
                #if DEBUG
                print("saved", saved)
                #endif
            }
        }

        if privateLibrary {
            globalApp!.privateDatabase.add(operation)
        } else {
            globalApp!.publicDatabase.add(operation)
        }
    }
    
    component.subComponent = subComponent
}

/// Decode Component into JSON
func decodeComponentFromJSON(_ json: String) -> CodeComponent?
{
    if let jsonData = json.data(using: .utf8)
    {
        if let component =  try? JSONDecoder().decode(CodeComponent.self, from: jsonData) {
            return component
        }
    }
    return nil
}

/// Decode component and adjust uuids
func decodeComponentAndProcess(_ json: String) -> CodeComponent?
{
    var replaced        : [UUID:UUID] = [:]

    var referseCount    : Int = 0
    var propertyCount   : Int = 0

    if let component = decodeComponentFromJSON(json) {

        component.connections = [:]
        component.uuid = UUID()
        
        func processFragment(_ fragment: CodeFragment) {

            let old = fragment.uuid
            
            fragment.uuid = UUID()
            replaced[old] = fragment.uuid
            
            // Property ?
            if let index = component.properties.firstIndex(of: old) {
                component.properties[index] = fragment.uuid
                propertyCount += 1
                
                // Replace artistName
                if let artistName = component.artistPropertyNames[old] {
                    component.artistPropertyNames[old] = nil
                    component.artistPropertyNames[fragment.uuid] = artistName
                }
                
                // Replace gizmo type
                if let gizmoName = component.propertyGizmoName[old] {
                    component.propertyGizmoName[old] = nil
                    component.propertyGizmoName[fragment.uuid] = gizmoName
                }
            }
            
            // This fragment referse to another one ? If yes replace it
            if let referse = fragment.referseTo {
                if let wasReplaced = replaced[referse] {
                    fragment.referseTo = wasReplaced
                    referseCount += 1
                } else {
                    //fragment.referseTo = nil
                }
            }
        }
        
        for f in component.functions {
            for b in f .body {
                parseCodeBlock(b, process: processFragment)
            }
        }

        //print("Properties replaced: ", propertyCount, "Referse replaced: ", referseCount)
        
        return component
    }
    return nil
}

func parseCodeBlock(_ b: CodeBlock, process: ((CodeFragment)->())? = nil)
{
    func parseFragments(_ fragment: CodeFragment)
    {
        process!(fragment)
        for statement in fragment.arguments {
            for arg in statement.fragments {
                parseFragments(arg)
            }
        }
    }
    
    // Check for the left sided fragment
    parseFragments(b.fragment)
    
    for bchild in b.children {
        parseCodeBlock(bchild, process: process)
    }
    
    // recursively parse the right sided fragments
    for fragment in b.statement.fragments {
        parseFragments(fragment)
    }
}

// Encode Component into JSON
func encodeComponentToJSON(_ component: CodeComponent) -> String
{
    let encodedData = try? JSONEncoder().encode(component)
    if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
    {
        return encodedObjectJsonString
    }
    return ""
}

/// Runs the component to generate code without any drawing
func dryRunComponent(_ comp: CodeComponent,_ propertyOffset: Int = 0, patternList: [CodeComponent] = [])
{
    let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
    ctx.reset(globalApp!.developerEditor.codeEditor.rect.width, propertyOffset, patternList: patternList)
    comp.draw(globalApp!.mmView, ctx)
}

/// Creates a constant for the given type
func defaultConstantForType(_ typeName: String) -> CodeFragment
{
    //print("defaultConstantForType", typeName)
    
    let constant    : CodeFragment
    var components  : Int = 0
    var compName    : String = typeName
    
    if typeName.hasSuffix("2") {
        components = 2
        compName.remove(at: compName.index(before: compName.endIndex))
    } else
    if typeName.hasSuffix("3") {
        components = 3
        compName.remove(at: compName.index(before: compName.endIndex))
    } else
    if typeName.hasSuffix("4") {
        components = 4
        compName.remove(at: compName.index(before: compName.endIndex))
    }
    
    if components == 0 {
        constant = CodeFragment(.ConstantValue, typeName, typeName, [.Selectable, .Dragable, .Targetable], [typeName], typeName)
    } else {
        constant = CodeFragment(.ConstantDefinition, typeName, typeName, [.Selectable, .Dragable, .Targetable], [typeName], typeName)
        
        for _ in 0..<components {
            let argStatement = CodeStatement(.Arithmetic)
            
            let constValue = CodeFragment(.ConstantValue, compName, "", [.Selectable, .Dragable, .Targetable], [compName], compName)
            argStatement.fragments.append(constValue)
            constant.arguments.append(argStatement)
        }
    }
    
    return constant
}

func setDefaultComponentValues(_ comp: CodeComponent)
{
    if comp.componentType == .SDF2D || comp.componentType == .Transform2D {
        comp.values["_posX"] = 0
        comp.values["_posY"] = 0
        comp.values["_rotate"] = 0
    } else
    if comp.componentType == .SDF3D || comp.componentType == .Transform3D {
        comp.values["_posX"] = 0
        comp.values["_posY"] = 0
        comp.values["_posZ"] = 0
        comp.values["_rotateX"] = 0
        comp.values["_rotateY"] = 0
        comp.values["_rotateZ"] = 0
    } else
    if comp.componentType == .Light3D {
        comp.values["_posX"] = 0
        comp.values["_posY"] = 0
        comp.values["_posZ"] = 0
        comp.values["_rotateX"] = 0
        comp.values["_rotateY"] = 0
        comp.values["_rotateZ"] = 0
    }
}

func getCurrentModeId() -> String
{
    let modeId : String = globalApp!.currentSceneMode == .TwoD ? "2D" : "3D"
    return modeId
}

func getFirstComponentOfType(_ list: [StageItem],_ type: CodeComponent.ComponentType) -> CodeComponent?
{
    for item in list {
        if let c = item.components[item.defaultName] {
            if c.componentType == type {
                return c
            }
        }
    }
    return nil
}

func getFirstStageItemOfComponentOfType(_ list: [StageItem],_ type: CodeComponent.ComponentType) -> StageItem?
{
    for item in list {
        if let c = item.components[item.defaultName] {
            if c.componentType == type {
                return item
            }
        }
    }
    return nil
}

func getFirstItemOfType(_ list: [StageItem],_ type: CodeComponent.ComponentType) -> (StageItem?, CodeComponent?)
{
    for item in list {
        if let c = item.components[item.defaultName] {
            if c.componentType == type {
                return (item, c)
            }
        }
    }
    return (nil,nil)
}

/// Returns a random token of the given length
func generateToken(length: Int = 6) -> String
{
    let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let randomCharacters = (0..<length).map{_ in characters.randomElement()!}
    return String(randomCharacters)
}

/// Places a child in a circle around the parent
func placeChild(modeId: String, parent: Stage, child: StageItem, stepSize: Float, radius: Float, defaultStart: Float = 90)
{
    let id : String = "childLocator" + modeId
    
    if parent.values[id] == nil {
        parent.values[id] = defaultStart
    }
    
    let angle = toRadians(parent.values[id]!)
    
    child.values["_graphX"] = radius * sin( angle )
    child.values["_graphY"] = radius * cos( angle )

    parent.values[id]! += -stepSize
}

/// Places a child in a circle around the parent
func placeChild(modeId: String, parent: StageItem, child: StageItem, stepSize: Float, radius: Float, defaultStart: Float = 90)
{
    let id : String = "childLocator" + modeId
    
    if parent.values[id] == nil {
        parent.values[id] = defaultStart
    }
    
    let angle = toRadians(parent.values[id]!)
    
    child.values["_graphX"] = radius * sin( angle )
    child.values["_graphY"] = radius * cos( angle )

    parent.values[id]! += -stepSize
}

/// Find the child component of the stage of the given type
func findDefaultComponentForStageChildren(stageType: Stage.StageType, componentType: CodeComponent.ComponentType) -> CodeComponent?
{
    var result : CodeComponent? = nil
    let renderStage = globalApp!.project.selected!.getStage(stageType)
    let children = renderStage.getChildren()
    for c in children {
        if let defaultComponent = c.components[c.defaultName] {
            if defaultComponent.componentType == componentType {
                result = defaultComponent
                break
            }
        }
    }
    return result
}

func getGlobalVariableValue(withName: String) -> SIMD4<Float>?
{
    var result: SIMD4<Float>? = nil
    let globalVars = globalApp!.project.selected!.getStage(.VariablePool).getGlobalVariable()
    if let variableComp = globalVars[withName] {
        for uuid in variableComp.properties {
            let rc = variableComp.getPropertyOfUUID(uuid)
            if rc.0!.values["variable"] == 1 {
                result = extractValueFromFragment(rc.1!)
            }
        }
    }
    return result
}

// Get the variable from a variable component
func getVariable(from: CodeComponent) -> CodeFragment?
{
    for uuid in from.properties {
        let rc = from.getPropertyOfUUID(uuid)
        if rc.0!.values["variable"] == 1 {
            return rc.0
        }
    }
    return nil
}

func setPropertyValue3(component: CodeComponent, name: String, value: SIMD3<Float>)
{
    for uuid in component.properties {
        let rc = component.getPropertyOfUUID(uuid)
        if rc.0!.name == name {
            insertValueToFragment3(rc.1!, value)
        }
    }
}

func setPropertyValue1(component: CodeComponent, name: String, value: Float)
{
    for uuid in component.properties {
        let rc = component.getPropertyOfUUID(uuid)
        if rc.0!.name == name {
            rc.1!.values["value"] = value
        }
    }
}

/// Returns a "special" component in the scene graph
func getComponent(name: String) -> CodeComponent?
{
    if name == "Renderer"
    {
        let scene = globalApp!.project.selected!
        
        let renderStage = scene.getStage(.RenderStage)
        let renderChildren = renderStage.getChildren()
        if renderChildren.count > 0 {
            let render = renderChildren[0]
            let renderComp = render.components[render.defaultName]
            return renderComp
        }
    } else
    if name == "Ground"
    {
        let scene = globalApp!.project.selected!
        
        let shapeStage = scene.getStage(.ShapeStage)
        let shapeChildren = shapeStage.getChildren()
        for o in shapeChildren {
            if o.components[o.defaultName]!.componentType == .Ground3D {
                return o.components[o.defaultName]!
            }
        }
    }
    
    return nil
}

/// Returns the value of a float property of the given component
func getComponentPropertyInt(component: CodeComponent, name: String, defaultValue: Int = 1) -> Int
{
    for uuid in component.properties {
        let rc = component.getPropertyOfUUID(uuid)
        if rc.0 != nil && rc.0!.name == name {
            if let frag = rc.1 {
                return Int(frag.values["value"]!)
            }
        }
    }
    return defaultValue
}

// Returns the transformed values of a CodeComponent, used to get the current position of top level objects (lights)
func getTransformedComponentValues(_ component: CodeComponent) -> [String:Float]
{
    let timeline = globalApp!.artistEditor.timeline
    let properties : [String:Float] = component.values

    let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
    
    return transformed
}

func getTransformedComponentProperty(_ component: CodeComponent,_ name: String) ->  SIMD4<Float>
{
    let timeline = globalApp!.artistEditor.timeline
    var result = SIMD4<Float>(0,0,0,0)
    
    for uuid in component.properties {
        let rc = component.getPropertyOfUUID(uuid)
        if rc.0 != nil && rc.0!.name == name {
            
            let data = extractValueFromFragment(rc.1!)
            let components = rc.1!.evaluateComponents()
            
            // Transform the properties inside the artist editor
            
            let name = rc.0!.name
            var properties : [String:Float] = [:]
                            
            if components == 1 {
                properties[name] = data.x
                let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                result.x = transformed[name]!
            } else
            if components == 2 {
                properties[name + "_x"] = data.x
                properties[name + "_y"] = data.y
                let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                result.x = transformed[name + "_x"]!
                result.y = transformed[name + "_y"]!
            } else
            if components == 3 {
                properties[name + "_x"] = data.x
                properties[name + "_y"] = data.y
                properties[name + "_z"] = data.z
                let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                result.x = transformed[name + "_x"]!
                result.y = transformed[name + "_y"]!
                result.z = transformed[name + "_z"]!
            } else
            if components == 4 {
                properties[name + "_x"] = data.x
                properties[name + "_y"] = data.y
                properties[name + "_z"] = data.z
                properties[name + "_w"] = data.w
                let transformed = timeline.transformProperties(sequence: component.sequence, uuid: component.uuid, properties: properties, frame: timeline.currentFrame)
                result.x = transformed[name + "_x"]!
                result.y = transformed[name + "_y"]!
                result.z = transformed[name + "_z"]!
                result.w = transformed[name + "_w"]!
            }
        }
    }
    return result
}
