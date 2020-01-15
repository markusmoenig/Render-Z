//
//  CodeUtilities.swift
//  Shape-Z
//
//  Created by Markus Moenig on 10/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

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
        if component.componentType == .SDF2D {
            libName += " - SDF2D"
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

/// Generate a preview thumbnail for the component
func generateThumbnailForComponent(_ comp: CodeComponent, _ width: Float = 100, height: Float = 100) -> MTLTexture?
{
    let codeBuilder = globalApp!.codeBuilder
    let texture : MTLTexture? = codeBuilder.compute.allocateTexture(width: width, height: height, output: false)
    
    dryRunComponent(comp)
    
    if let tex = texture {
        let instance = codeBuilder.build(comp)
        codeBuilder.render(instance, tex)
    }
    
    return texture
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

/// Runs the component to generate code without any drawing
func dryRunComponent(_ comp: CodeComponent)
{
    let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, 0.5)
    ctx.reset(100)
    comp.draw(globalApp!.mmView, ctx)
}
