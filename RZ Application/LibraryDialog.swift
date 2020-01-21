//
//  LibraryChooser.swift
//  Render-Z
//
//  Created by Markus Moenig on 15/1/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

class LibraryItem {
    
    var titleLabel          : MMTextLabel
    var descriptionLabel    : MMTextLabel
    var rect                : MMRect = MMRect()
    var thumbnail           : MTLTexture? = nil
    var json                : String
    var type                : String
    
    init(_ mmView: MMView,_ title: String,_ description: String = "", _ json: String = "",_ type: String = "")
    {
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title)
        self.descriptionLabel = MMTextLabel(mmView, font: mmView.openSans, text: description, scale: 0.36, color: SIMD4<Float>(mmView.skin.Item.textColor))
        self.json = json
        self.type = type
    }
}

class LibraryDialog: MMDialog {
    
    var itemMap         : [String:[LibraryItem]] = [:]

    var currentItems    : [LibraryItem]? = nil

    var hoverItem       : LibraryItem? = nil
    var selectedItem    : LibraryItem? = nil
    
    var blueTexture     : MTLTexture? = nil
    var greyTexture     : MTLTexture? = nil
    
    var scrollOffset    : Float = 0
    var dispatched      : Bool = false
    
    var currentType     : String = ""
    var contextItem     : ContextItem? = nil

    init(_ view: MMView) {
        super.init(view, title: "Choose Library Item", cancelText: "Cancel", okText: "Select")
        
        rect.width = 800
        rect.height = 600
        
        //items.append( TemplateChooserItem(mmView, "Empty Project" ) )
        //items.append( TemplateChooserItem(mmView, "Pinball", "Pinball", "Physics" ) )
        //items.append( TemplateChooserItem(mmView, "Pong", "Pong", "Customized Physics (Collision), AI" ) )
        //items.append( TemplateChooserItem(mmView, "Marble", "Marble", "iOS Accelerometer, Customized Physics (Gravity)" ) )

        widgets.append(self)
        //selItem = items[0]
        
        blueTexture = view.icons["sz_ui_blue"]
        greyTexture = view.icons["sz_ui_grey"]
        
        let query = CKQuery(recordType: "components", predicate: NSPredicate(value: true))
        CKContainer.init(identifier: "iCloud.com.moenig.renderz").publicCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            
            records?.forEach({ (record) in
                
                //currentItems.append(item)
                
                // System Field from property
                //let recordName_fromProperty = record.recordID.recordName
                //print("System Field, recordName: \(recordName_fromProperty)")
                //let deeplink = record.value(forKey: "deeplink")
                //print("Custom Field, deeplink: \(deeplink ?? "")")
                
                let arr = record.recordID.recordName.components(separatedBy: " - ")
                let name = arr[0]
                let type = arr[1]

                let item = LibraryItem(view, name, "", record.value(forKey: "json") as! String, record.recordID.recordName)
                
                if self.itemMap[type] == nil {
                    self.itemMap[type] = []
                }
                
                var list = self.itemMap[type]!
                list.append(item)
                self.itemMap[type] = list
            })
        }
    }
    
    func setType(_ id: String,_ contextItem: ContextItem)
    {
        currentItems = itemMap[id]
        self.contextItem = contextItem
    }
    
    override func cancel() {
        super.cancel()
        cancelButton!.removeState(.Checked)
    }
    
    override func ok() {
        super.ok()
        
        if let selected = selectedItem {
            if let context = contextItem {
                globalApp!.context.replaceJSONForItem(context, selected.json)
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
        if currentItems == nil { return }
        let items = currentItems!
        
        let itemSize : Float = (rect.width - 4 - 6) / 5
        var y : Float = rect.y + 38

        if rect.y == 0 {
            
            let itemWidth : Float = (rect.width - 4 - 2)
            let scrollHeight : Float = rect.height - 90 - 46
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
        for (index,item) in items.enumerated() {
            
            var x : Float = rect.x + 3
            
            let borderColor = selectedItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
            let textColor = selectedItem === item ? mmView.skin.Item.selectionColor : SIMD4<Float>(1,1,1,1)

            x += (Float(index).truncatingRemainder(dividingBy: 3)) * (itemSize + 2)

            mmView.drawBox.draw( x: x, y: y, width: itemSize, height: itemSize, round: 26, borderSize: 2, fillColor: mmView.skin.Item.color, borderColor: borderColor)//, maskRoundingSize: 26, maskRect: SIMD4<Float>(boxRect.x, boxRect.y, boxRect.width, boxRect.height))
            
            if let thumb = item.thumbnail {
                mmView.drawTexture.draw(thumb, x: x + (itemSize - Float(100)) / 2, y: y + 15, zoom: 2)
            } else
            if oneThumbnailOnly == false {
                oneThumbnailOnly =  true
                item.thumbnail = globalApp!.thumbnail.request(item.type, decodeComponentFromJSON(item.json)!)
                mmView.update()
            }

            if selectedItem === item {
                //mmView.drawTexture.draw(blueTexture!, x: x + (itemSize - Float(blueTexture!.width)*0.8) / 2, y: y + 45, zoom: 1.2)
            } else {
                //mmView.drawTexture.draw(greyTexture!, x: x + (itemSize - Float(greyTexture!.width)*0.8) / 2, y: y + 45, zoom: 1.2)
            }
            
            item.rect.set(x, y, itemSize, itemSize)
            item.titleLabel.color = textColor
            item.titleLabel.drawCentered(x: x, y: y + itemSize - 40, width: itemSize, height: 35)
            
            if index > 0 && Float(index).truncatingRemainder(dividingBy: 2) == 0 {
                y += itemSize + 2
                
                if rect.y != 0 {
                    break
                }
            }
        }
        
        if rect.y == 0 {
            mmView.renderer.setClipRect()
        }
        
        let boxRect : MMRect = MMRect(rect.x, rect.y + 35, rect.width, rect.height - 90 - 40)
        
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
