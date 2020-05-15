//
//  UploadDialogs.swift
//  Render-Z
//
//  Created by Markus Moenig on 15/5/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

import AVFoundation
import Photos

class UploadMaterialsDialog: MMDialog {

    enum HoverMode          : Float {
        case None, NodeUI, NodeUIMouseLocked
    }
    
    var hoverMode               : HoverMode = .None
        
    var hoverUIItem             : NodeUI? = nil
    var hoverUITitle            : NodeUI? = nil
    
    var c1Node                  : Node? = nil
    var c2Node                  : Node? = nil
            
    var nameVar                 : NodeUIText!
    var authorVar               : NodeUIText!

    var categoryVar             : NodeUISelector!
    var databaseVar             : NodeUISelector!

    var descriptionVar          : NodeUIText!

    var statusVar               : NodeUIText!
    var material                : StageItem
    
    let categoryItems           = ["Architecture", "Metal", "Organic", "Stone", "Wood"]

    init(_ view: MMView, material: StageItem) {
        self.material = material
        super.init(view, title: "Upload Material", cancelText: "Cancel", okText: "Upload")
        instantClose = false
        
        rect.width = 500
        rect.height = 280
        
        c1Node = Node()
        c1Node?.rect.x = 60
        c1Node?.rect.y = 60
        
        c2Node = Node()
        c2Node?.rect.x = 280
        c2Node?.rect.y = 60
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverMode = .None
        
        nameVar = NodeUIText(c1Node!, variable: "name", title: "Name", value: material.name)
        c1Node!.uiItems.append(nameVar)
        
        var authorName = "Anonymous"
        if material.libraryAuthor.count > 0 {
            authorName = material.libraryAuthor
        }
        
        authorVar = NodeUIText(c1Node!, variable: "author", title: "Author", value: authorName)
        c1Node!.uiItems.append(authorVar)
        
        statusVar = NodeUIText(c1Node!, variable: "status", title: "Status", value: "Ready")
        c1Node!.uiItems.append(statusVar)
                
        var categoryIndex : Float = 0
        if let cIndex = categoryItems.firstIndex(of: material.libraryCategory) {
            categoryIndex = Float(cIndex)
        }
        
        categoryVar = NodeUISelector(c2Node!, variable: "category", title: "Category", items: categoryItems, index: categoryIndex)
        c2Node!.uiItems.append(categoryVar)
        
        databaseVar = NodeUISelector(c2Node!, variable: "database", title: "Database", items: ["Public", "Private"])
        c2Node!.uiItems.append(databaseVar)
        
        descriptionVar = NodeUIText(c2Node!, variable: "description", title: "Description", value: material.libraryDescription)
        c2Node!.uiItems.append(descriptionVar)
        
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
        
        widgets.append(self)
    }
    
    func show()
    {
        mmView.showDialog(self)
    }
    
    override func cancel() {
        cancelButton!.removeState(.Checked)
        _cancel()
    }
    
    override func ok() {
        
        okButton.removeState(.Checked)
        
        material.libraryCategory = categoryItems[Int(categoryVar.index)]
        material.libraryDescription = descriptionVar.value
        material.libraryAuthor = authorVar.value

        let recordID  = CKRecord.ID(recordName: nameVar.value + " :: " + material.libraryCategory)
        let record    = CKRecord(recordType: "materials", recordID: recordID)
        
        record["json"] = ""

        let encodedData = try? JSONEncoder().encode(material)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
            record["json"] = encodedObjectJsonString
        }
        
        record["author"] = authorVar.value
        record["description"] = descriptionVar.value

        var uploadComponents = [CKRecord]()
        uploadComponents.append(record)

        let operation = CKModifyRecordsOperation(recordsToSave: uploadComponents, recordIDsToDelete: nil)
        operation.savePolicy = .allKeys

        operation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, operationError in

            if let error = operationError {
                // error
                self.statusVar.value = "Error: " + error.localizedDescription
                self.mmView.update()
            }

            if savedRecords != nil {
                // Success
                self.statusVar.value = "Success"
                self.mmView.update()
            }
        }

        if databaseVar.index == 1 {
            globalApp!.privateDatabase.add(operation)
        } else {
            globalApp!.publicDatabase.add(operation)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if hoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseMoved(event)
            return
        }
        
        // Disengage hover types for the ui items
        if hoverUIItem != nil {
            hoverUIItem!.mouseLeave()
        }
        
        if hoverUITitle != nil {
            hoverUITitle?.titleHover = false
            hoverUITitle = nil
            mmView.update()
        }
        
        let oldHoverMode = hoverMode
        
        hoverUIItem = nil
        hoverUITitle = nil
        hoverMode = .None
                
        func checkNodeUI(_ node: Node)
        {
            // --- Look for NodeUI item under the mouse, master has no UI
            let uiItemX = rect.x + node.rect.x
            var uiItemY = rect.y + node.rect.y
            let uiRect = MMRect()
            
            for uiItem in node.uiItems {
                
                if uiItem.supportsTitleHover {
                    uiRect.x = uiItem.titleLabel!.rect.x - 2
                    uiRect.y = uiItem.titleLabel!.rect.y - 2
                    uiRect.width = uiItem.titleLabel!.rect.width + 4
                    uiRect.height = uiItem.titleLabel!.rect.height + 6
                    
                    if uiRect.contains(event.x, event.y) {
                        uiItem.titleHover = true
                        hoverUITitle = uiItem
                        mmView.update()
                        return
                    }
                }
                
                uiRect.x = uiItemX
                uiRect.y = uiItemY
                uiRect.width = uiItem.rect.width
                uiRect.height = uiItem.rect.height
                
                if uiRect.contains(event.x, event.y) {
                    
                    hoverUIItem = uiItem
                    hoverMode = .NodeUI
                    hoverUIItem!.mouseMoved(event)
                    mmView.update()
                    return
                }
                uiItemY += uiItem.rect.height
            }
        }
        
        if let node = c1Node {
            checkNodeUI(node)
        }
        
        if let node = c2Node, hoverMode == .None {
            checkNodeUI(node)
        }
        
        if oldHoverMode != hoverMode {
            mmView.update()
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        #if os(iOS)
        mouseMoved(event)
        #endif

        #if os(OSX)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
        
        if hoverMode == .NodeUI {
            hoverUIItem!.mouseDown(event)
            hoverMode = .NodeUIMouseLocked
            //globalApp?.mmView.mouseTrackWidget = self
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if hoverMode == .NodeUIMouseLocked {
            hoverUIItem!.mouseUp(event)
        }
        
        #if os(iOS)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
        
        hoverMode = .None
        mmView.mouseTrackWidget = nil
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0) {
        super.draw(xOffset: xOffset, yOffset: yOffset)
        
        if let node = c1Node {
            
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
        
        if let node = c2Node {
                        
            let uiItemX : Float = rect.x + node.rect.x
            var uiItemY : Float = rect.y + node.rect.y
            
            for uiItem in node.uiItems {
                uiItem.rect.x = uiItemX
                uiItem.rect.y = uiItemY
                uiItemY += uiItem.rect.height
            }
            
            for uiItem in node.uiItems {
                uiItem.draw(mmView: mmView, maxTitleSize: node.uiMaxTitleSize, maxWidth: node.uiMaxWidth, scale: 1)
            }
        }
    }
}
