//
//  LibraryChooser.swift
//  Render-Z
//
//  Created by Markus Moenig on 15/1/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

class LibraryComponent      : Codable
{
    var name                : String
    var author              : String
    var description         : String
    var json                : String

    private enum CodingKeys : String, CodingKey {
        case name
        case author
        case description
        case json
    }
     
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        author = try container.decode(String.self, forKey: .author)
        description = try container.decode(String.self, forKey: .description)
        json = try container.decode(String.self, forKey: .json)
    }
     
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(author, forKey: .author)
        try container.encode(description, forKey: .description)
        try container.encode(json, forKey: .json)
    }
     
    init(name: String, author: String?, description: String?, json: String?)
    {
        self.name = name
        self.author = author == nil ? "" : author!
        self.description = description == nil ? "" : description!
        self.json = json == nil ? "" : json!
    }
}

class LibraryBackup         : Codable
{
    var components          : [LibraryComponent] = []
    var objects             : [LibraryComponent] = []
    var materials           : [LibraryComponent] = []

    private enum CodingKeys : String, CodingKey {
        case components
        case objects
        case materials
    }
     
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        components = try container.decode([LibraryComponent].self, forKey: .components)
        objects = try container.decode([LibraryComponent].self, forKey: .objects)
        materials = try container.decode([LibraryComponent].self, forKey: .materials)
    }
     
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(components, forKey: .components)
        try container.encode(objects, forKey: .objects)
        try container.encode(materials, forKey: .materials)
    }
     
    init()
    {
    }
    
    func write()
    {
        let encodedData = try? JSONEncoder().encode(self)
        if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
        {
            globalApp!.mmFile.saveAs(encodedObjectJsonString, globalApp!)
            print("Written to Disk: components \(components.count), objects \(objects.count), materials \(materials.count)")
        }
    }
    
    func read()
    {
        let fileURL = globalApp!.mmFile.customUrl(fileName: "backup")
        do {
            let json = try String(contentsOf: fileURL!, encoding: .utf8)
            
            if let jsonData = json.data(using: .utf8)
            {
                if let backup =  try? JSONDecoder().decode(LibraryBackup.self, from: jsonData) {
                    self.components = backup.components
                    self.objects = backup.objects
                    self.materials = backup.materials
                    print("Read from Disk: components \(components.count), objects \(objects.count), materials \(materials.count)")
                    upload()
                }
            }
        }
        catch {}
    }
    
    func upload()
    {
        for c in components {
            let recordID  = CKRecord.ID(recordName: c.name)
            let record    = CKRecord(recordType: "components", recordID: recordID)
            
            record["json"] = c.json
            record["description"] = c.description
            record["author"] = c.author

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

            globalApp!.publicDatabase.add(operation)
        }
        
        for c in objects {
            let recordID  = CKRecord.ID(recordName: c.name)
            let record    = CKRecord(recordType: "objects", recordID: recordID)
            
            record["json"] = c.json
            record["description"] = c.description
            record["author"] = c.author

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

            globalApp!.publicDatabase.add(operation)
        }
        
        for c in materials {
            let recordID  = CKRecord.ID(recordName: c.name)
            let record    = CKRecord(recordType: "materials", recordID: recordID)
            
            record["json"] = c.json
            record["description"] = c.description
            record["author"] = c.author

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

            globalApp!.publicDatabase.add(operation)
        }
    }
}

class LibraryItem {
    
    var titleLabel          : MMTextLabel
    var descriptionLabel    : MMTextLabel
    var categoryLabel       : MMTextLabel? = nil
    var rect                : MMRect = MMRect()
    var thumbnail           : MTLTexture? = nil
    var json                : String
    var type                : String
    
    init(_ mmView: MMView,_ title: String,_ description: String = "", _ json: String = "",_ type: String = "",_ category: String = "")
    {
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title)
        descriptionLabel = MMTextLabel(mmView, font: mmView.openSans, text: description, scale: 0.36, color: SIMD4<Float>(mmView.skin.Item.textColor))
        
        var categoryText : String = ""
        if category.starts(with: "Func") {
            categoryText = String(category.dropFirst(4))
        } else
        if category == "Boolean" {
            categoryText = "Boolean"
        } else
        if category.starts(with: "Render") {
            categoryText = category
        }

        if categoryText.count > 0 {
            categoryLabel = MMTextLabel(mmView, font: mmView.openSans, text: categoryText, scale: 0.36, color: SIMD4<Float>(mmView.skin.Item.textColor))
        }

        self.json = json
        self.type = type
    }
}

class LibraryDialog: MMDialog {
    
    enum Style {
        case Icon, List
    }
    
    var style           : Style = .Icon
    
    var itemMap         : [String:[LibraryItem]] = [:]
    var privateItemMap  : [String:[LibraryItem]] = [:]

    var materialsItemMap: [String:[LibraryItem]] = [:]
    var privateMaterialsItemMap: [String:[LibraryItem]] = [:]
    
    var objectsItemMap  : [String:[LibraryItem]] = [:]
    var privateObjectsItemMap: [String:[LibraryItem]] = [:]
    
    var currentItems    : [LibraryItem]? = nil

    var hoverItem       : LibraryItem? = nil
    var selectedItem    : LibraryItem? = nil
    
    var blueTexture     : MTLTexture? = nil
    var greyTexture     : MTLTexture? = nil
    
    var scrollOffset    : Float = 0
    var dispatched      : Bool = false
    
    var currentType     : String = ""
    
    var _cb             : ((String)->())? = nil
    var _cbMaterials    : ((String)->())? = nil
    var _cbObjects      : ((String)->())? = nil

    var borderlessSkin  : MMSkinButton
    var publicPrivateTab: MMTabButtonWidget
    
    var currentId       : String = ""
    var possibleIds     : [String] = []
    
    var buttonSkin      : MMSkinButton
    var buttons         : [MMWidget] = []
    
    //var backup          : LibraryBackup = LibraryBackup()
    
    var textMap         : [String:String] = [
        "FuncHash"      : "Hash",
        "FuncNoise"     : "Noise",
        "FuncMisc"      : "Misc",
        "FuncMaterial"  : "Material",
        "FuncSDF"       : "SDF",
        "FuncAnalytical": "Analytical",
        "Pattern2D"     : "Pattern 2D",
        "Pattern3D"     : "Pattern 3D",
        "PatternMixer"  : "Mixer",
        "SDF2D"         : "Shape 2D",
        "SDF3D"         : "Shape 3D",
        "Modifier3D"    : "Modifier 3D",
        "Modifier2D"    : "Modifier 2D",
        "Domain3D"      : "Domain 3D",
        "Domain2D"      : "Domain 2D"
    ]

    init(_ view: MMView) {
        
        borderlessSkin = MMSkinButton()
        borderlessSkin.margin = MMMargin( 14, 4, 14, 4 )
        borderlessSkin.borderSize = 0
        borderlessSkin.height = view.skin.Button.height - 1
        borderlessSkin.fontScale = 0.44
        borderlessSkin.round = 28
                
        buttonSkin = MMSkinButton()
        buttonSkin.margin = MMMargin( 8, 4, 8, 4 )
        buttonSkin.borderSize = 0
        buttonSkin.height = view.skin.Button.height - 5
        buttonSkin.fontScale = 0.40
        buttonSkin.round = 20
        
        publicPrivateTab = MMTabButtonWidget(view, skinToUse: borderlessSkin)
        
        publicPrivateTab.addTab("Public")
        publicPrivateTab.addTab("Private")
        
        super.init(view, title: "Choose Library Item", cancelText: "Cancel", okText: "Select")
        
        publicPrivateTab.clicked = { (event) in
            self.setCurrentItems()
        }
        
        rect.width = 800
        rect.height = 600

        widgets.append(publicPrivateTab)
        widgets.append(self)
        
        blueTexture = view.icons["sz_ui_blue"]
        greyTexture = view.icons["sz_ui_grey"]
        
        let publicQuery = CKQuery(recordType: "components", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").publicCloudDatabase.perform(publicQuery, inZoneWith: nil) { (records, error) in
            
            records?.forEach({ (record) in

                if !record.recordID.recordName.contains(" :: ") {
                    return
                }
                let arr = record.recordID.recordName.components(separatedBy: " :: ")
                let name = arr[0]
                let type = arr[1]
                                
                //self.backup.components.append(LibraryComponent(name: record.recordID.recordName, author: record.value(forKey: "author") as? String, description: record.value(forKey: "description") as? String, json: record.value(forKey: "json") as? String))
                
                var description : String = ""
                if let desc = record.value(forKey: "description") {
                    description = desc as! String
                }

                let item = LibraryItem(view, name, description, record.value(forKey: "json") as! String, record.recordID.recordName, type)
                if self.itemMap[type] == nil {
                    self.itemMap[type] = []
                }
                var list = self.itemMap[type]!
                list.append(item)
                self.itemMap[type] = list
            })
            
            globalApp!.topRegion!.libraryButton.isDisabled = false
            DispatchQueue.main.async {
                self.mmView.update()
                globalApp!.sceneGraph.libraryLoaded()
                globalApp!.thumbnail.libraryLoaded()
            }
        }
        
        let privateQuery = CKQuery(recordType: "components", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").privateCloudDatabase.perform(privateQuery, inZoneWith: nil) { (records, error) in
            
            records?.forEach({ (record) in

                if !record.recordID.recordName.contains(" :: ") {
                    return
                }
                let arr = record.recordID.recordName.components(separatedBy: " :: ")
                let name = arr[0]
                let type = arr[1]
                
                var description : String = ""
                if let desc = record.value(forKey: "description") {
                    description = desc as! String
                }

                let item = LibraryItem(view, name, description, record.value(forKey: "json") as! String, record.recordID.recordName, type)
                if self.privateItemMap[type] == nil {
                    self.privateItemMap[type] = []
                }
                var list = self.privateItemMap[type]!
                list.append(item)
                self.privateItemMap[type] = list
            })
        }
        
        // --- Materials
        
        let publicMaterialsQuery = CKQuery(recordType: "materials", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").publicCloudDatabase.perform(publicMaterialsQuery, inZoneWith: nil) { (records, error) in
            
            records?.forEach({ (record) in

                if !record.recordID.recordName.contains(" :: ") {
                    return
                }
                let arr = record.recordID.recordName.components(separatedBy: " :: ")
                let name = arr[0]
                let type = arr[1]
                
                //self.backup.materials.append(LibraryComponent(name: record.recordID.recordName, author: record.value(forKey: "author") as? String, description: record.value(forKey: "description") as? String, json: record.value(forKey: "json") as? String))
                
                var description : String = ""
                if let desc = record.value(forKey: "description") {
                    description = desc as! String
                }

                let item = LibraryItem(view, name, description, record.value(forKey: "json") as! String, record.recordID.recordName, type)
                if self.materialsItemMap[type] == nil {
                    self.materialsItemMap[type] = []
                }
                var list = self.materialsItemMap[type]!
                list.append(item)
                self.materialsItemMap[type] = list
            })
        }
        
        let privateMaterialsQuery = CKQuery(recordType: "materials", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").privateCloudDatabase.perform(privateMaterialsQuery, inZoneWith: nil) { (records, error) in
            
            records?.forEach({ (record) in

                if !record.recordID.recordName.contains(" :: ") {
                    return
                }
                let arr = record.recordID.recordName.components(separatedBy: " :: ")
                let name = arr[0]
                let type = arr[1]
                
                var description : String = ""
                if let desc = record.value(forKey: "description") {
                    description = desc as! String
                }

                let item = LibraryItem(view, name, description, record.value(forKey: "json") as! String, record.recordID.recordName, type)
                if self.privateMaterialsItemMap[type] == nil {
                    self.privateMaterialsItemMap[type] = []
                }
                var list = self.privateMaterialsItemMap[type]!
                list.append(item)
                self.privateMaterialsItemMap[type] = list
            })
        }
        
        // --- Objects
        
        let publicObjectsQuery = CKQuery(recordType: "objects", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").publicCloudDatabase.perform(publicObjectsQuery, inZoneWith: nil) { (records, error) in
            
            records?.forEach({ (record) in

                if !record.recordID.recordName.contains(" :: ") {
                    return
                }
                let arr = record.recordID.recordName.components(separatedBy: " :: ")
                let name = arr[0]
                let type = arr[1]
                
                //self.backup.objects.append(LibraryComponent(name: record.recordID.recordName, author: record.value(forKey: "author") as? String, description: record.value(forKey: "description") as? String, json: record.value(forKey: "json") as? String))
                
                var description : String = ""
                if let desc = record.value(forKey: "description") {
                    description = desc as! String
                }

                let item = LibraryItem(view, name, description, record.value(forKey: "json") as! String, record.recordID.recordName, type)
                if self.objectsItemMap[type] == nil {
                    self.objectsItemMap[type] = []
                }
                var list = self.objectsItemMap[type]!
                list.append(item)
                self.objectsItemMap[type] = list
            })
            
            globalApp!.topRegion!.libraryButton.isDisabled = false
            DispatchQueue.main.async {
                self.mmView.update()
                globalApp!.sceneGraph.libraryLoaded()
                globalApp!.thumbnail.libraryLoaded()
            }
        }
        
        let privateObjectsQuery = CKQuery(recordType: "objects", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").privateCloudDatabase.perform(privateObjectsQuery, inZoneWith: nil) { (records, error) in
            
            records?.forEach({ (record) in

                if !record.recordID.recordName.contains(" :: ") {
                    return
                }
                let arr = record.recordID.recordName.components(separatedBy: " :: ")
                let name = arr[0]
                let type = arr[1]
                
                var description : String = ""
                if let desc = record.value(forKey: "description") {
                    description = desc as! String
                }

                let item = LibraryItem(view, name, description, record.value(forKey: "json") as! String, record.recordID.recordName, type)
                if self.privateObjectsItemMap[type] == nil {
                    self.privateObjectsItemMap[type] = []
                }
                var list = self.privateObjectsItemMap[type]!
                list.append(item)
                self.privateObjectsItemMap[type] = list
            })
        }
        
        //DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        //    self.backup.write()
        //}
        
        //DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        //    self.backup.read()
        //}
        
        /*
        // Code to create a subscription
        let predicate = NSPredicate(value: true)
        let newSubscription = CKQuerySubscription(recordType: "objects", predicate: predicate, options: [.firesOnRecordCreation, .firesOnRecordDeletion, .firesOnRecordUpdate])
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.alertBody = ""
        newSubscription.notificationInfo = info

        globalApp!.publicDatabase.save(newSubscription, completionHandler: { (subscription, error) in
            print("here")
            if error != nil {
                print("Error Creating Subscription")
                print(error)
            } else {
                //userSettings.set(true, forKey: "subscriptionSaved")
                print(subscription)
            }
        })*/
    }
    
    func show(ids: [String], style: Style = .List, cb: ((String)->())? = nil )
    {
        _cb = cb
        _cbMaterials = nil
        _cbObjects = nil

        self.style = style

        currentId = ids[0]
        setCurrentItems()
        
        createButtons(ids)
        
        mmView.showDialog(self)
    }
    
    func showMaterials(style: Style = .List, cb: ((String)->())? = nil )
    {
        _cb = nil
        _cbMaterials = cb
        _cbObjects = nil
        
        self.style = style

        currentId = "Basic"
        setCurrentItems()
        
        createButtons(["Basic", "Architecture", "Metal", "Organic", "Stone", "Wood"])
        
        mmView.showDialog(self)
    }
    
    func showObjects(style: Style = .List, cb: ((String)->())? = nil )
    {
        _cb = nil
        _cbMaterials = nil
        _cbObjects = cb

        self.style = style

        currentId = "Architecture"
        setCurrentItems()
        
        createButtons(["Architecture", "Metal", "Organic", "Stone", "Wood"])
        
        mmView.showDialog(self)
    }
    
    func createButtons(_ list: [String] = [])
    {
        for b in buttons {
            if let index = widgets.firstIndex(where: {$0 === b}) {
                widgets.remove(at: index)
            }
        }
        
        buttons = []
        if list.count > 1 {
            for id in list {
                
                var text = id
                if let mapping = textMap[text] {
                    text = mapping
                }
                
                let button = MMButtonWidget(mmView, skinToUse: buttonSkin, text: text)
                button.name = id
                button.clicked = { (event) in
                    self.currentId = button.name
                    self.setCurrentItems()
                    
                    for b in self.buttons {
                        if b !== button {
                            b.removeState(.Checked)
                        }
                    }
                }
                buttons.append(button)
                widgets.insert(button, at: 0)
            }
        }
        
        if buttons.count > 0 {
            let b = buttons[0]
            b.addState(.Checked)
        }
    }
    
    func setCurrentItems()
    {
        if _cb != nil || (_cbMaterials == nil && _cbObjects == nil) {
            if publicPrivateTab.index == 0 {
                if itemMap[currentId] == nil { itemMap[currentId] = [] }
                currentItems = itemMap[currentId]!
            } else {
                if privateItemMap[currentId] == nil { privateItemMap[currentId] = [] }
                currentItems = privateItemMap[currentId]!
            }
        } else
        if _cbMaterials != nil {
            if currentId == "Basic" {
                if publicPrivateTab.index == 0 {
                    if itemMap["Material3D"] == nil { itemMap["Material3D"] = [] }
                    currentItems = itemMap["Material3D"]!
                } else {
                    if privateItemMap["Material3D"] == nil { privateItemMap["Material3D"] = [] }
                    currentItems = privateItemMap["Material3D"]!
                }
            } else {
                if publicPrivateTab.index == 0 {
                    if materialsItemMap[currentId] == nil { materialsItemMap[currentId] = [] }
                    currentItems = materialsItemMap[currentId]!
                } else {
                    if privateMaterialsItemMap[currentId] == nil { privateMaterialsItemMap[currentId] = [] }
                    currentItems = privateMaterialsItemMap[currentId]!
                }
            }
        } else
        if _cbObjects != nil {
            if publicPrivateTab.index == 0 {
                if objectsItemMap[currentId] == nil { objectsItemMap[currentId] = [] }
                currentItems = objectsItemMap[currentId]!
            } else {
                if privateObjectsItemMap[currentId] == nil { privateObjectsItemMap[currentId] = [] }
                currentItems = privateObjectsItemMap[currentId]!
            }
        }
                
        if currentItems != nil && currentItems!.count > 0 {
            currentItems = currentItems!.sorted(by: { $0.titleLabel.text < $1.titleLabel.text })
            selectedItem = currentItems![0]
        }
    }
    
    func getItem(ofId: String, withName: String = "") -> CodeComponent?
    {
        var json = ""
        
        if let typeList = itemMap[ofId] {
            if withName == "" {
                if typeList.count > 0 {
                    json = typeList[0].json
                }
            } else {
                for item in typeList {
                    if item.titleLabel.text == withName {
                        json = item.json
                        break
                    }
                }
            }
        }
        
        if json == "" {
            return nil
        } else {
            return decodeComponentAndProcess(json)
        }
    }
    
    func getMaterial(ofId: String, withName: String = "") -> CodeComponent?
    {
        var json = ""
        
        if ofId == "Basic" {
            if let typeList = itemMap["Material3D"] {
                if withName == "" {
                    if typeList.count > 0 {
                        json = typeList[0].json
                    }
                } else {
                    for item in typeList {
                        if item.titleLabel.text == withName {
                            json = item.json
                            break
                        }
                    }
                }
            }
        } else {
            if let typeList = materialsItemMap[ofId] {
                if withName == "" {
                    if typeList.count > 0 {
                        json = typeList[0].json
                    }
                } else {
                    for item in typeList {
                        if item.titleLabel.text == withName {
                            json = item.json
                            break
                        }
                    }
                }
            }
        }
        
        if json == "" {
            return nil
        } else {
            return decodeComponentAndProcess(json)
        }
    }
    
    // Gets a list of library items for the given id
    func getItems(ofId: String) -> [LibraryItem]
    {
        if let list = itemMap[ofId] {
            return list
        }
        return []
    }
    
    override func cancel() {
        super.cancel()
        cancelButton!.removeState(.Checked)
    }
    
    override func ok() {
        super.ok()
        
        if let selected = selectedItem {
            if _cb != nil {
                DispatchQueue.main.async {
                    if let cb = self._cb {
                        if let comp = decodeComponentAndProcess(selected.json) {
                            let recoded = encodeComponentToJSON(comp)
                            cb(recoded)
                        }
                    }
                }
            } else
            if _cbMaterials != nil {
                DispatchQueue.main.async {
                    if let cb = self._cbMaterials {
                        if self.currentId == "Basic" {
                            cb(selected.json)
                        } else {
                            cb(selected.json)
                        }
                    }
                }
            }
            if _cbObjects != nil {
                DispatchQueue.main.async {
                    if let cb = self._cbObjects {
                        cb(selected.json)
                    }
                }
            } else {
                if globalApp?.currentEditor === globalApp?.developerEditor {
                    if let component = globalApp?.developerEditor.codeEditor.codeComponent {
                        if let from = decodeComponentFromJSON(selected.json) {
                            var counter : Int = 0
                            var inserted : [UUID] = []
                            
                            for f in component.functions {
                                if f.functionType == .Prototype {
                                    counter += 1
                                } else {
                                    break;
                                }
                            }
                            
                            for f in from.functions {
                                if from.functions.count == 1 {
                                    f.uuid = UUID()
                                }
                                if inserted.contains(f.uuid) == false {
                                    component.functions.insert(f, at: counter)
                                    counter += 1
                                    inserted.append(f.uuid)
                                }
                            }
                            globalApp?.currentEditor.updateOnNextDraw()
                        }
                    }
                }
            }
        }
        
        okButton.removeState(.Checked)
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        super.mouseMoved(event)
        
        hoverItem = nil
        if let items = currentItems {
            for item in items {
                if item.rect.contains(event.x, event.y) {
                    hoverItem = item
                    break
                }
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        #if os(iOS)
        mouseMoved(event)
        #endif
        super.mouseDown(event)
        
        if let hover = hoverItem {
            selectedItem = hover
            mmView.update()
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        scrollOffset += event.deltaY! * 4
        
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.mmView.unlockFramerate()
                self.dispatched = false
            }
            dispatched = true
        }
        
        if mmView.maxFramerateLocks == 0 {
            mmView.lockFramerate()
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0) {
        super.draw(xOffset: xOffset, yOffset: yOffset)

        publicPrivateTab.rect.x = rect.right() - 12 - publicPrivateTab.rect.width
        publicPrivateTab.rect.y = rect.y + 34
        publicPrivateTab.draw()
        
        var left: Float = 12
        for w in buttons {
            w.rect.x = rect.x + left
            w.rect.y = rect.y + 35
            w.draw()
            left += w.rect.width + 5
        }

        if style == .Icon {
            drawIconView(xOffset: xOffset, yOffset: yOffset)
        } else {
            drawListView(xOffset: xOffset, yOffset: yOffset)
        }
    }
    
    func drawListView(xOffset: Float = 0, yOffset: Float = 0) {
        if currentItems == nil { return }
        let items = currentItems!
        
        let headerHeight : Float = 30
        
        let itemWidth : Float = (rect.width - 4 - 2)
        let itemHeight : Float = 30
        var y : Float = rect.y + 38 + headerHeight

        if rect.y == 0 {
            
            let scrollHeight : Float = rect.height - 90 - 46 - headerHeight
            let scrollRect = MMRect(rect.x + 3, y, itemWidth, scrollHeight)
            
            mmView.renderer.setClipRect(scrollRect)
            var maxHeight : Float = Float(items.count) * itemHeight
            if items.count > 0 {
                maxHeight += 2 * Float(items.count-1)
            }
            
            if scrollOffset < -(maxHeight - scrollHeight) {
                scrollOffset = -(maxHeight - scrollHeight)
            }
            
            if scrollOffset > 0 {
                scrollOffset = 0
            }
                        
            y += scrollOffset
        }
        
        var fillColor = mmView.skin.Item.color
        let alpha : Float = 1
        fillColor.w = alpha
        
        for item in items {
            
            let x : Float = rect.x + 3
            
            var borderColor = selectedItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
            var textColor = selectedItem === item ? mmView.skin.Item.selectionColor : SIMD4<Float>(1,1,1,1)
            borderColor.w = alpha
            textColor.w = alpha

            mmView.drawBox.draw( x: x, y: y, width: itemWidth, height: itemHeight, round: 26, borderSize: 2, fillColor: fillColor, borderColor: borderColor)
            
            item.rect.set(x, y, itemWidth, itemHeight)
            item.titleLabel.color = textColor
            item.titleLabel.drawCenteredY(x: x + 10, y: y, width: itemWidth, height: itemHeight)
            
            if item.categoryLabel != nil {
                item.categoryLabel!.color = textColor
                item.categoryLabel!.drawCenteredY(x: x + itemWidth - 10 - item.categoryLabel!.rect.width, y: y, width: itemWidth, height: itemHeight)
            }
            
            y += itemHeight + 2
        }
        
        if rect.y == 0 {
            mmView.renderer.setClipRect()
        }
        
        let boxRect : MMRect = MMRect(rect.x, rect.y + 35 + headerHeight, rect.width, rect.height - 90 - 40 - headerHeight)
        
        let cb : Float = 1
        // Erase Edges
        mmView.drawBox.draw( x: boxRect.x - cb, y: boxRect.y - cb, width: boxRect.width + 2*cb, height: boxRect.height + 2*cb, round: 30, borderSize: 4, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.color)
        
        // Box Border
        mmView.drawBox.draw( x: boxRect.x, y: boxRect.y, width: boxRect.width, height: boxRect.height, round: 30, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        
        y = rect.y + 35 + rect.height - 90 - 30
        
        mmView.drawBox.draw( x: rect.x + 10, y: y, width: rect.width - 20, height: 30, round: 26, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        if let item = selectedItem {
            item.descriptionLabel.drawCentered(x: rect.x + 10, y: y, width: rect.width - 20, height: 30)
        }
        
        // Renew dialog border
        mmView.drawBox.draw( x: rect.x, y: rect.y - yOffset, width: rect.width, height: rect.height, round: 40, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.borderColor )
    }
    
    func drawIconView(xOffset: Float = 0, yOffset: Float = 0) {
        if currentItems == nil { return }
        let items = currentItems!
        
        let headerHeight : Float = 30

        let itemSize : Float = (rect.width - 14) / 5
        var y : Float = rect.y + 38 + headerHeight

        if rect.y == 0 {
            
            let itemWidth : Float = (rect.width - 4 - 2)
            let scrollHeight : Float = rect.height - 90 - 46 - headerHeight
            let scrollRect = MMRect(rect.x + 3, y, itemWidth, scrollHeight)
            
            mmView.renderer.setClipRect(scrollRect)
            
            let rows : Float = Float(Int(max(Float(items.count)/2, 1)))
            let maxHeight : Float = rows * itemSize + (rows - 1) * 2
            
            if scrollOffset < -(maxHeight - scrollHeight) {
                scrollOffset = -(maxHeight - scrollHeight)
            }
            
            if scrollOffset > 0 {
                scrollOffset = 0
            }
                        
            y += scrollOffset
        }
        
        var oneThumbnailOnly : Bool = false
        var x : Float = rect.x + 3

        for (index,item) in items.enumerated() {
                        
            let borderColor = selectedItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
            let textColor = selectedItem === item ? mmView.skin.Item.selectionColor : SIMD4<Float>(1,1,1,1)

            //x += (Float(index).truncatingRemainder(dividingBy: 3)) * (itemSize + 2)

            mmView.drawBox.draw( x: x, y: y, width: itemSize, height: itemSize, round: 26, borderSize: 2, fillColor: mmView.skin.Item.color, borderColor: borderColor)//, maskRoundingSize: 26, maskRect: SIMD4<Float>(boxRect.x, boxRect.y, boxRect.width, boxRect.height))
            
            if let thumb = item.thumbnail {
                mmView.drawTexture.draw(thumb, x: x + (itemSize - Float(100)) / 2, y: y + 15, zoom: 2)
            } else
            if oneThumbnailOnly == false && rect.y == 0 {
                oneThumbnailOnly =  true
                item.thumbnail = globalApp!.thumbnail.request(item.type)
                mmView.update()
            }
            
            item.rect.set(x, y, itemSize, itemSize)
            item.titleLabel.color = textColor
            item.titleLabel.drawCentered(x: x, y: y + itemSize - 40, width: itemSize, height: 35)
            
            if (index+1) % 5 == 0 {
                x = rect.x + 3
                y += itemSize + 2
            } else {
                x += itemSize + 2
            }
        }
        
        if rect.y == 0 {
            mmView.renderer.setClipRect()
        }
        
        let boxRect : MMRect = MMRect(rect.x, rect.y + 35 + headerHeight, rect.width, rect.height - 90 - 40 - headerHeight)
        
        let cb : Float = 1
        // Erase Edges
        mmView.drawBox.draw( x: boxRect.x - cb, y: boxRect.y - cb, width: boxRect.width + 2*cb, height: boxRect.height + 2*cb, round: 30, borderSize: 4, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.color)
        
        // Box Border
        mmView.drawBox.draw( x: boxRect.x, y: boxRect.y, width: boxRect.width, height: boxRect.height, round: 30, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        
        y = rect.y + 35 + rect.height - 90 - 30
        
        mmView.drawBox.draw( x: rect.x + 10, y: y, width: rect.width - 20, height: 30, round: 26, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        if let item = selectedItem {
            item.descriptionLabel.drawCentered(x: rect.x + 10, y: y, width: rect.width - 20, height: 30)
        }
        
        // Renew dialog border
        mmView.drawBox.draw( x: rect.x, y: rect.y - yOffset, width: rect.width, height: rect.height, round: 40, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.borderColor )
    }
}
