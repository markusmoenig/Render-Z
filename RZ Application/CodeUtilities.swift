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

// Inserts an SIMD3<Float> value to a given fragment
func insertValueToFragment(_ fragment: CodeFragment,_ value: SIMD3<Float>)
{
    if fragment.fragmentType == .ConstantDefinition {
        let components = fragment.evaluateComponents()
        if components == 3 || components == 4 {
            if fragment.arguments.count == components {
                for (index,arg) in fragment.arguments.enumerated() {
                    if index >= components - 1 {
                        break
                    }
                    arg.fragments[0].values["value"]! = value[index]
                }
            }
        }
    }
}

import CloudKit

/// Upload the given component to the public or private libraries
func uploadToLibrary(_ component: CodeComponent, _ privateLibrary: Bool = true)
{
    let name = component.libraryName
    if name == "" {return}
    
    let encodedData = try? JSONEncoder().encode(component)
    if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
    {
        //codeU = encodedObjectJsonString
        var libName = name
        if component.componentType == .Colorize {
            libName += " - Colorize"
        } else
        if component.componentType == .SkyDome {
            libName += " - SkyDome"
        } else
        if component.componentType == .SDF2D {
            libName += " - SDF2D"
        } else
        if component.componentType == .SDF3D {
            libName += " - SDF3D"
        } else
        if component.componentType == .Render2D {
            libName += " - Render2D"
        } else
        if component.componentType == .Render3D {
            libName += " - Render3D"
        }
        
        let recordID  = CKRecord.ID(recordName: libName)
        let record    = CKRecord(recordType: "components", recordID: recordID)
        
        record["json"] = encodedObjectJsonString
        
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
func dryRunComponent(_ comp: CodeComponent,_ propertyOffset: Int = 0)
{
    let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, 0.5)
    ctx.reset(1000, propertyOffset)
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
    if comp.componentType == .SDF2D {
        // Check values
        comp.values["_posX"] = 0
        comp.values["_posY"] = 0
        comp.values["_scaleX"] = 0
        comp.values["_scaleY"] = 0
        comp.values["_rotate"] = 0
    }
}
