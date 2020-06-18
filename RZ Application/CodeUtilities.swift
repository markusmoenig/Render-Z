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

// Inserts an SIMD2<Float> value to a given fragment
func insertValueToFragment2(_ fragment: CodeFragment,_ value: SIMD2<Float>)
{
    if fragment.fragmentType == .ConstantDefinition {
        let components = fragment.evaluateComponents()
        if components == 2  {
            if fragment.arguments.count == components {
                for (index,arg) in fragment.arguments.enumerated() {
                    if index >= 2 {
                        break
                    }
                    arg.fragments[0].values["value"]! = value[index]
                }
            }
        }
    }
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
    if componentToUse.values["_rotate"] != nil { componentToUse.values["_rotate"] = 0.0 }
    if componentToUse.values["_rotateX"] != nil { componentToUse.values["_rotateX"] = 0.0 }
    if componentToUse.values["_rotateY"] != nil { componentToUse.values["_rotateY"] = 0.0 }
    if componentToUse.values["_rotateZ"] != nil { componentToUse.values["_rotateZ"] = 0.0 }
    componentToUse.values["2DIn3D"] = nil
    
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
                if component.libraryCategory == "Pattern 3D" {
                    libName += " :: Pattern3D"
                } else
                if component.libraryCategory == "Mixer" {
                    libName += " :: PatternMixer"
                } else {
                    libName += " :: Pattern2D"
                }
            } else
            if component.componentType == .PostFX {
                libName += " :: PostFX"
            } else
            if component.componentType == .Fog3D {
                libName += " :: Fog3D"
            } else
            if component.componentType == .Clouds3D {
                libName += " :: Clouds3D"
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
                print("error", error)
            }

            if savedRecords != nil {
                #if DEBUG
                print("Uploaded successfully")
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

/// Decode StageItem from JSON
func decodeStageItemFromJSON(_ json: String) -> StageItem?
{
    if let jsonData = json.data(using: .utf8)
    {
        if let stageItem =  try? JSONDecoder().decode(StageItem.self, from: jsonData) {
            return stageItem
        }
    }
    return nil
}

/// Decode StageItem and process the items
func decodeStageItemAndProcess(_ json: String) -> StageItem?
{
    var replaced        : [UUID:UUID] = [:]

    var referseCount    : Int = 0
    var propertyCount   : Int = 0
    
    func processComponent(_ component: CodeComponent)
    {
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
        
        let old = component.uuid
        component.uuid = UUID()
        replaced[old] = component.uuid

        let conn = component.connections
        component.connections = [:]
        
        for (uuid,cc) in conn {
            let newUUID = replaced[uuid] == nil ? uuid : replaced[uuid]
            
            var newCCUUID = cc.componentUUID
            if newCCUUID != nil && replaced[newCCUUID!] != nil {
                newCCUUID = replaced[newCCUUID!]
            }
            
            let newCC = CodeConnection(newCCUUID!, cc.outName!)
            component.connections[newUUID!] = newCC
        }

        //print("Properties replaced: ", propertyCount, "Referse replaced: ", referseCount)
    }

    
    if let jsonData = json.data(using: .utf8)
    {
        if let stageItem =  try? JSONDecoder().decode(StageItem.self, from: jsonData) {
            
            if let patterns = stageItem.componentLists["patterns"] {
                for p in patterns.reversed() {
                    processComponent(p)
                }
            }
            
            if let def = stageItem.components[stageItem.defaultName] {
                processComponent(def)
            }
            
            return stageItem
        }
    }
    return nil
}

/// Decode component and adjust uuids
func decodeComponentAndProcess(_ json: String, replaced: [UUID:UUID] = [:]) -> CodeComponent?
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
    
    if typeName.hasSuffix("2x2") {
        components = 4
        compName.remove(at: compName.index(before: compName.endIndex))
    } else
    if typeName.hasSuffix("3x3") {
        components = 9
        compName.remove(at: compName.index(before: compName.endIndex))
    } else
    if typeName.hasSuffix("4x4") {
        components = 16
        compName.remove(at: compName.index(before: compName.endIndex))
    } else
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
        if globalApp!.currentSceneMode == .ThreeD {
            comp.values["_posX"] = 0
            comp.values["_posY"] = 0
            comp.values["_posZ"] = 0
            comp.values["_rotateX"] = 0
            comp.values["_rotateY"] = 0
            comp.values["_rotateZ"] = 0
            comp.values["2DIn3D"] = 1
            comp.values["_extrusion"] = 1
            comp.values["_revolution"] = 0
            comp.values["_rounding"] = 0
        } else {
            comp.values["_posX"] = 0
            comp.values["_posY"] = 0
            comp.values["_rotate"] = 0
        }
        if comp.componentType == .Transform2D {
            comp.values["_scale"] = 1
        }
    } else
    if comp.componentType == .SDF3D || comp.componentType == .Transform3D {
        comp.values["_posX"] = 0
        comp.values["_posY"] = 0
        comp.values["_posZ"] = 0
        comp.values["_rotateX"] = 0
        comp.values["_rotateY"] = 0
        comp.values["_rotateZ"] = 0
        if comp.componentType == .Transform3D {
            comp.values["_scale"] = 1
        }
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
                let components = rc.1!.evaluateComponents()
                if components == 4 {
                    result!.x = pow(result!.x, 2.2)
                    result!.y = pow(result!.y, 2.2)
                    result!.z = pow(result!.z, 2.2)
                }
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
                result.x = pow(transformed[name + "_x"]!, 2.2)
                result.y = pow(transformed[name + "_y"]!, 2.2)
                result.z = pow(transformed[name + "_z"]!, 2.2)
                result.w = transformed[name + "_w"]!
            }
        }
    }
    return result
}

// Image Functions

// Setup an ImageUI
func setupImageUI(_ node: Node, _ fragment: CodeFragment, title: String = "Image") -> NodeUIImage
{
    var items : [String] = []
    for i in globalApp!.images {
        let components = i.0.components(separatedBy: ".")
        items.append(components[1])
    }
    let imageIndex = fragment.values["imageIndex"] == nil ? 0 : fragment.values["imageIndex"]!
    return NodeUIImage(node, variable: "imageIndex", title: title, items: items, index: imageIndex, fragment: fragment)
}

func generateImageFunction(_ ctx: CodeContext,_ fragment: CodeFragment) -> String
{
    let component = ctx.cComponent!
    let funcName = generateToken()
        
    func addToolProperty(_ name: String, defaultValue: Float) -> Int
    {
        var dataIndex = ctx.propertyDataOffset + ctx.cComponent!.inputDataList.count
        if component.toolPropertyIndex[fragment.uuid] == nil {
            component.toolPropertyIndex[fragment.uuid] = []
            
            component.inputDataList.append(fragment.uuid)
            component.inputComponentList.append(component)
        } else {
            dataIndex += component.toolPropertyIndex[fragment.uuid]!.count - 1
        }
        
        //print("tool dataIndex", ctx.cComponent!.uuid, dataIndex, name)
        component.toolPropertyIndex[fragment.uuid]!.append((name, fragment))
        if fragment.values[name] == nil {
            fragment.values[name] = defaultValue
        }
        return dataIndex
    }
    
    let imageIndex = fragment.values["imageIndex"] == nil ? 0 : fragment.values["imageIndex"]!

    let token = generateToken()
    let textureName = globalApp!.images[Int(imageIndex)].0
    component.textures.append((textureName, token, 0))
        
    let imageScale = addToolProperty("imageScale", defaultValue: 1)
    
    let funcCode =
    """

    float4 \(funcName)(float2 uv, thread struct FuncData *__funcData)
    {
        __CREATE_TEXTURE_DEFINITIONS__

        return __interpolateTexture(\(token), uv * __funcData->__data[\(imageScale)].x);
    }
    
    """
    
    component.globalCode! += funcCode
    
    return funcName
}

func generateImagePreview(domain: String, imageIndex: Float, width: Float, height: Float, fragment: CodeFragment) -> MTLTexture?
{
    let pipeline = globalApp!.currentPipeline!
    let texture = pipeline.checkTextureSize(width, height)
    
    var code = pipeline.codeBuilder.getHeaderCode()
    
    code +=
    """
    
    kernel void imagePreview(
    texture2d<half, access::write>          __outTexture  [[texture(0)]],
    texture2d<half, access::sample>          __inTexture  [[texture(2)]],
    uint2 __gid                               [[thread_position_in_grid]])
    {
        constexpr sampler __textureSampler(mag_filter::linear, min_filter::linear);

        float2 uv = float2(__gid.x, __gid.y);
        float2 size = float2(__outTexture.get_width(), __outTexture.get_height() );
        uv /= size;
    
        float4 outColor = __interpolateTexture(__inTexture, uv * \(fragment.values["imageScale"]!));
        __outTexture.write(half4(outColor), __gid);
    }

    """
    
    code = code.replacingOccurrences(of: "__FUNCDATA_TEXTURE_LIST__", with: "")
    
    let library = pipeline.codeBuilder.compute.createLibraryFromSource(source: code)
    let previewState = pipeline.codeBuilder.compute.createState(library: library, name: "imagePreview")
    
    let imageTexture = globalApp!.images[Int(imageIndex)].1
    
    if let state = previewState {
        pipeline.codeBuilder.compute.run( state, outTexture: texture, inTexture: imageTexture)
        pipeline.codeBuilder.compute.commandBuffer.waitUntilCompleted()
    }
        
    return texture
}

// 2D Noise Functions

func getAvailable2DNoises() -> ([String], [String])
{
    return (["Value"], ["__valueNoise2D"])
}

// Setup a NodeUINoise2D
func setupNoise2DUI(_ node: Node, _ fragment: CodeFragment, title: String = "2D Noise") -> NodeUINoise2D
{
    let items : [String] = getAvailable2DNoises().0
    let noiseIndex = fragment.values["noise2D"] == nil ? 0 : fragment.values["noise2D"]!
    return NodeUINoise2D(node, variable: "noise2D", title: title, items: items, index: noiseIndex, fragment: fragment)
}

func generateNoise2DFunction(_ ctx: CodeContext,_ fragment: CodeFragment) -> String
{
    let component = ctx.cComponent!
    let funcName = generateToken()
        
    func addToolProperty(_ name: String, defaultValue: Float) -> Int
    {
        var dataIndex = ctx.propertyDataOffset + ctx.cComponent!.inputDataList.count
        if component.toolPropertyIndex[fragment.uuid] == nil {
            component.toolPropertyIndex[fragment.uuid] = []
            
            component.inputDataList.append(fragment.uuid)
            component.inputComponentList.append(component)
        } else {
            dataIndex += component.toolPropertyIndex[fragment.uuid]!.count - 1
        }
        
        //print("tool dataIndex", ctx.cComponent!.uuid, dataIndex, name)
        component.toolPropertyIndex[fragment.uuid]!.append((name, fragment))
        if fragment.values[name] == nil {
            fragment.values[name] = defaultValue
        }
        return dataIndex
    }
    
    let noiseList = getAvailable2DNoises().1

    func getNoiseName(_ noiseType: String, secondary: Bool = false) -> String
    {
        var noiseIndex = fragment.values[noiseType] == nil ? 0 : fragment.values[noiseType]!
        if secondary {
            noiseIndex -= 1
        }

        if noiseIndex < 0 {
            return "None"
        } else {
            return noiseList[Int(noiseIndex)]
        }
    }
    
    var funcCode =
    """

    float \(funcName)(float2 pos, thread struct FuncData *__funcData)
    {
        float baseNoise = \(getNoiseName("noise2D"))
    """
    
    let baseOctavesIndex = addToolProperty("noiseBaseOctaves", defaultValue: 4)
    let basePersistanceIndex = addToolProperty("noiseBasePersistance", defaultValue: 0.5)
    let baseScaleIndex = addToolProperty("noiseBaseScale", defaultValue: 1)

    funcCode +=
    """
    ( pos, int(__funcData->__data[\(baseOctavesIndex)].x), __funcData->__data[\(basePersistanceIndex)].x, __funcData->__data[\(baseScaleIndex)].x );
    
    
    """
    
    let mixOctavesIndex = addToolProperty("noiseMixOctaves", defaultValue: 4)
    let mixPersistanceIndex = addToolProperty("noiseMixPersistance", defaultValue: 0.5)
    let mixScaleIndex = addToolProperty("noiseMixScale", defaultValue: 1)
    
    let mixDisturbance = addToolProperty("noiseMixDisturbance", defaultValue: 1.0)
    let mixValue = addToolProperty("noiseMixValue", defaultValue: 0.5)
    let resultScale = addToolProperty("noiseResultScale", defaultValue: 0.5)

    let secondary = getNoiseName("noiseMix2D", secondary: true)
    if secondary != "None" {
        
        funcCode +=
        """
            float mixNoise = \(secondary)
        """

        funcCode +=
        """
        ( pos + (float2(baseNoise * __funcData->__data[\(mixDisturbance)].x)), int(__funcData->__data[\(mixOctavesIndex)].x), __funcData->__data[\(mixPersistanceIndex)].x, __funcData->__data[\(mixScaleIndex)].x );
        
        baseNoise = mix(baseNoise, mixNoise, __funcData->__data[\(mixValue)].x);
        """
    }
    
    funcCode +=
    """
    
        return baseNoise * __funcData->__data[\(resultScale)].x;
    }
    
    """
    
    component.globalCode! += funcCode
    
    return funcName
}

func generateNoisePreview2D(domain: String, noiseIndex: Float, width: Float, height: Float, fragment: CodeFragment) -> MTLTexture?
{
    let pipeline = globalApp!.currentPipeline!
    let texture = pipeline.checkTextureSize(width, height)
    
    var code = pipeline.codeBuilder.getHeaderCode()
    
    code +=
    """
    
    kernel void noisePreview(
    texture2d<half, access::write>          __outTexture  [[texture(0)]],
    uint2 __gid                               [[thread_position_in_grid]])
    {
        float2 uv = float2(__gid.x, __gid.y);
        float2 size = float2(__outTexture.get_width(), __outTexture.get_height() );
        uv /= size;
        uv.y = 1.0 - uv.y;
        uv *= 3.0;
    
        float4 outColor = float4(1);

    """
        
    var funcName = ""
    let noiseList = getAvailable2DNoises().1

    funcName = noiseList[Int(noiseIndex)]
    
    code +=
    """
    
    float noise = \(funcName)(float2(uv.x, uv.y), \(fragment.values["noiseBaseOctaves"]!), \(fragment.values["noiseBasePersistance"]!), \(fragment.values["noiseBaseScale"]!));
    
    """
    
    let mixNoiseIndex = fragment.values["noiseMix2D"] == nil ? -1 : fragment.values["noiseMix2D"]! - 1
    
    funcName = "None"
    
    if mixNoiseIndex >= 0 {
        funcName = noiseList[Int(mixNoiseIndex)]
    }
    
    if funcName != "None" {
        
        code +=
        """
        
        float mixNoise = \(funcName)(float2(uv.x, uv.y) + (float2( noise *  \(fragment.values["noiseMixDisturbance"]!) )), \(fragment.values["noiseMixOctaves"]!), \(fragment.values["noiseMixPersistance"]!), \(fragment.values["noiseMixScale"]!));
        
        noise = mix(noise, mixNoise, \(fragment.values["noiseMixValue"]!));
        """
    }
    
    code +=
    """
        outColor = mix(float4(float3(0), 0.8), float4(1,1,1, 0.8), noise * \(fragment.values["noiseResultScale"]!));
        __outTexture.write(half4(outColor), __gid);
    }
    
    """
    
    code = code.replacingOccurrences(of: "__FUNCDATA_TEXTURE_LIST__", with: "")
    
    let library = pipeline.codeBuilder.compute.createLibraryFromSource(source: code)
    let previewState = pipeline.codeBuilder.compute.createState(library: library, name: "noisePreview")
    
    if let state = previewState {
        pipeline.codeBuilder.compute.run( state, outTexture: texture)
        pipeline.codeBuilder.compute.commandBuffer.waitUntilCompleted()
    }
        
    return texture
}

// 3D Noise Functions

func getAvailable3DNoises() -> ([String], [String])
{
    return (["Value", "Perlin", "Worley", "Simplex"], ["__valueNoise3D", "__perlinNoise3D", "worleyFbm", "simplexFbm"])
}

// Setup a NodeUINoise3D
func setupNoise3DUI(_ node: Node, _ fragment: CodeFragment, title: String = "3D Noise") -> NodeUINoise3D
{
    let items : [String] = getAvailable3DNoises().0
    let noiseIndex = fragment.values["noise3D"] == nil ? 0 : fragment.values["noise3D"]!
    return NodeUINoise3D(node, variable: "noise3D", title: title, items: items, index: noiseIndex, fragment: fragment)
}

func generateNoise3DFunction(_ ctx: CodeContext,_ fragment: CodeFragment) -> String
{
    let component = ctx.cComponent!
    let funcName = generateToken()
        
    func addToolProperty(_ name: String, defaultValue: Float) -> Int
    {
        var dataIndex = ctx.propertyDataOffset + ctx.cComponent!.inputDataList.count
        if component.toolPropertyIndex[fragment.uuid] == nil {
            component.toolPropertyIndex[fragment.uuid] = []
            
            component.inputDataList.append(fragment.uuid)
            component.inputComponentList.append(component)
        } else {
            dataIndex += component.toolPropertyIndex[fragment.uuid]!.count - 1
        }
        
        //print("tool dataIndex", ctx.cComponent!.uuid, ctx.cComponent!.libraryName, dataIndex, name)
        component.toolPropertyIndex[fragment.uuid]!.append((name, fragment))
        if fragment.values[name] == nil {
            fragment.values[name] = defaultValue
        }
        return dataIndex
    }
    
    let noiseList = getAvailable3DNoises().1

    func getNoiseName(_ noiseType: String, secondary: Bool = false) -> String
    {
        var noiseIndex = fragment.values[noiseType] == nil ? 0 : fragment.values[noiseType]!
        if secondary {
            noiseIndex -= 1
        }

        if noiseIndex < 0 {
            return "None"
        } else {
            return noiseList[Int(noiseIndex)]
        }
    }
    
    var funcCode =
    """

    float \(funcName)(float3 pos, thread struct FuncData *__funcData)
    {
        float baseNoise = \(getNoiseName("noise3D"))
    """
    
    let baseOctavesIndex = addToolProperty("noiseBaseOctaves", defaultValue: 4)
    let basePersistanceIndex = addToolProperty("noiseBasePersistance", defaultValue: 0.5)
    let baseScaleIndex = addToolProperty("noiseBaseScale", defaultValue: 1)

    funcCode +=
    """
    ( pos, int(__funcData->__data[\(baseOctavesIndex)].x), __funcData->__data[\(basePersistanceIndex)].x, __funcData->__data[\(baseScaleIndex)].x );
    
    
    """
    
    let mixOctavesIndex = addToolProperty("noiseMixOctaves", defaultValue: 4)
    let mixPersistanceIndex = addToolProperty("noiseMixPersistance", defaultValue: 0.5)
    let mixScaleIndex = addToolProperty("noiseMixScale", defaultValue: 1)
    
    let mixDisturbance = addToolProperty("noiseMixDisturbance", defaultValue: 1.0)
    let mixValue = addToolProperty("noiseMixValue", defaultValue: 0.5)
    let resultScale = addToolProperty("noiseResultScale", defaultValue: 0.5)

    let secondary = getNoiseName("noiseMix3D", secondary: true)
    if secondary != "None" {
        
        funcCode +=
        """
            float mixNoise = \(secondary)
        """

        funcCode +=
        """
        ( pos + (float3(baseNoise * __funcData->__data[\(mixDisturbance)].x)), int(__funcData->__data[\(mixOctavesIndex)].x), __funcData->__data[\(mixPersistanceIndex)].x, __funcData->__data[\(mixScaleIndex)].x );
        
        baseNoise = mix(baseNoise, mixNoise, __funcData->__data[\(mixValue)].x);
        """
    }
    
    funcCode +=
    """
    
        return baseNoise * __funcData->__data[\(resultScale)].x;
    }
    
    """
    
    component.globalCode! += funcCode
    
    return funcName
}


func generateNoisePreview3D(domain: String, noiseIndex: Float, width: Float, height: Float, fragment: CodeFragment) -> MTLTexture?
{
    let pipeline = globalApp!.currentPipeline!
    let texture = pipeline.checkTextureSize(width, height)
    
    var code = pipeline.codeBuilder.getHeaderCode()
    
    code +=
    """
    
    kernel void noisePreview(
    texture2d<half, access::write>          __outTexture  [[texture(0)]],
    uint2 __gid                               [[thread_position_in_grid]])
    {
        float2 uv = float2(__gid.x, __gid.y);
        float2 size = float2(__outTexture.get_width(), __outTexture.get_height() );
        uv /= size;
        uv.y = 1.0 - uv.y;
        uv *= 3.0;
    
        float4 outColor = float4(1);

    """
        
    var funcName = ""
    let noiseList = getAvailable3DNoises().1

    funcName = noiseList[Int(noiseIndex)]
    
    code +=
    """
    
    float noise = \(funcName)(float3(uv.x, 0.0, uv.y), \(fragment.values["noiseBaseOctaves"]!), \(fragment.values["noiseBasePersistance"]!), \(fragment.values["noiseBaseScale"]!));
    
    """
    
    let mixNoiseIndex = fragment.values["noiseMix3D"] == nil ? -1 : fragment.values["noiseMix3D"]! - 1
    
    funcName = "None"
    
    if mixNoiseIndex >= 0 {
        funcName = noiseList[Int(mixNoiseIndex)]
    }
    
    if funcName != "None" {
        
        code +=
        """
        
        float mixNoise = \(funcName)(float3(uv.x, 0.0, uv.y) + (float3( noise *  \(fragment.values["noiseMixDisturbance"]!) )), \(fragment.values["noiseMixOctaves"]!), \(fragment.values["noiseMixPersistance"]!), \(fragment.values["noiseMixScale"]!));
        
        noise = mix(noise, mixNoise, \(fragment.values["noiseMixValue"]!));
        """
    }
    
    code +=
    """
        outColor = mix(float4(float3(0), 0.8), float4(1,1,1, 0.8), noise * \(fragment.values["noiseResultScale"]!));
        __outTexture.write(half4(outColor), __gid);
    }
    
    """
    
    code = code.replacingOccurrences(of: "__FUNCDATA_TEXTURE_LIST__", with: "")
    
    let library = pipeline.codeBuilder.compute.createLibraryFromSource(source: code)
    let previewState = pipeline.codeBuilder.compute.createState(library: library, name: "noisePreview")
    
    if let state = previewState {
        pipeline.codeBuilder.compute.run( state, outTexture: texture)
        pipeline.codeBuilder.compute.commandBuffer.waitUntilCompleted()
    }
        
    return texture
}


/// Returns the used patterns in the pattern list
func getUsedPatterns(_ materialComponent: CodeComponent, patterns: [CodeComponent]) -> [CodeComponent]
{
    func getPatternOfUUID(_ uuid: UUID) -> CodeComponent?
    {
        for p in patterns {
            if p.uuid == uuid {
                return p
            }
        }
        return nil
    }
    
    var out : [CodeComponent] = []
    
    func resolvePatterns(_ component: CodeComponent)
    {
        for (_, conn) in component.connections {
            let uuid = conn.componentUUID!
            
            if let pattern = getPatternOfUUID(uuid) {
                if out.contains(pattern) == false {
                    out.append(pattern)
                    resolvePatterns(pattern)
                }
            }
        }
    }
    
    resolvePatterns(materialComponent)

    return out;
}

func drawLogo(_ rect: MMRect, _ alpha: Float = 1)
{
    globalApp!.mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, fillColor : SIMD4<Float>( 0.125, 0.129, 0.137, 1))
    
    if let icon = globalApp!.mmView.icons["render-z"] {
        let zoom : Float = 1
        globalApp!.mmView.drawTexture.draw(icon, x: rect.x + (rect.width - Float(icon.width)/zoom) / 2, y: rect.y + (rect.height - Float(icon.height)/zoom) / 2, zoom: zoom, globalAlpha: alpha)
    }
}

@discardableResult func drawPreview(mmView: MMView, _ rect: MMRect) -> Bool
{
    if let texture = globalApp!.currentPipeline!.finalTexture {
        mmView.drawTexture.draw(texture, x: rect.x, y: rect.y)
        globalApp!.currentPipeline!.renderIfResolutionChanged(rect.width, rect.height)
        return true
    }
    return false
}

/// Creates code for value modifiers
func getInstantiationModifier(_ variable: String,_ values: [String:Float],_ multiplier: Float = 1.0) -> String
{
    var result = ""
    
    if let value = values[variable] {
        if value != 0 {
            result = " + " + String(value) + " * (__funcData->hash - 0.5)"
        }
    }
    return result
}
