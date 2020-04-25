//
//  NewDialog.swift
//  Render-Z
//
//  Created by Markus Moenig on 25/4/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import CloudKit

class TemplateItem {
    
    var titleLabel          : MMTextLabel
    var rect                : MMRect = MMRect()
    var type                : String = ""
    var fileName            : String = ""

    init(_ mmView: MMView,_ title: String, _ fileName: String = "")
    {
        self.fileName = fileName
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: 0.30, color: SIMD4<Float>(mmView.skin.Item.textColor))
    }
}

class Template {
    
    var titleLabel          : MMTextLabel
    var rect                : MMRect = MMRect()
    var type                : String = ""
    
    var items               : [TemplateItem] = []
    
    init(_ mmView: MMView,_ title: String)
    {
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: 0.30, color: SIMD4<Float>(mmView.skin.Item.textColor))
    }
}

class NewDialog: MMDialog {
    
    enum Style {
        case Templates, Files
    }
    
    var style           : Style = .Templates

    var templates       : [Template] = []
    var selectedTempItem: TemplateItem? = nil
    var hoverTempItem   : TemplateItem? = nil

    var files           : [MMFileDialogItem] = []
    var hoverFileItem   : MMFileDialogItem? = nil
    var selectedFileItem: MMFileDialogItem? = nil
    
    var fileTexture     : MTLTexture? = nil
    
    var fileScrollOffset: Float = 0
    var tempScrollOffset: Float = 0
    var dispatched      : Bool = false
    
    var currentType     : String = ""
    
    var _cb             : ((String)->())? = nil
    
    var borderlessSkin  : MMSkinButton
    var publicPrivateTab: MMTabButtonWidget
    
    var currentId       : String = ""
    var possibleIds     : [String] = []
    
    var buttonSkin      : MMSkinButton
    var buttons         : [MMWidget] = []
    
    var scrollRect      : MMRect? = nil
    var alpha           : Float = 0

    init(_ view: MMView) {
        
        borderlessSkin = MMSkinButton()
        borderlessSkin.margin = MMMargin( 4, 4, 4, 4 )
        borderlessSkin.borderSize = 0
        borderlessSkin.height = view.skin.Button.height - 5
        borderlessSkin.fontScale = 0.44
        borderlessSkin.round = 24
        
        buttonSkin = MMSkinButton()
        buttonSkin.margin = MMMargin( 8, 4, 8, 4 )
        buttonSkin.borderSize = 0
        buttonSkin.height = view.skin.Button.height - 5
        buttonSkin.fontScale = 0.40
        buttonSkin.round = 20
        
        publicPrivateTab = MMTabButtonWidget(view, skinToUse: borderlessSkin)
        
        publicPrivateTab.addTab("Templates")
        publicPrivateTab.addTab("iCloud")
        
        super.init(view, title: "New Project", cancelText: "Artist", okText: "Developer")
        
        publicPrivateTab.clicked = { (event) in
            if self.publicPrivateTab.index == 0 {
                self.style = .Templates
            } else {
                self.style = .Files
            }
        }
        
        // Template Items
        let templates3D = Template(view, "3D Templates")
        templates3D.items.append(TemplateItem(view, "Minimal", "Minimal"))
        templates3D.items.append(TemplateItem(view, "Test"))
        templates.append(templates3D)
        
        let materials3D = Template(view, "Material Examples")
        materials3D.items.append(TemplateItem(view, "Bricks"))
        templates.append(materials3D)
        
        selectedTempItem = templates3D.items[0]
        
        // File Items
        let fc = NSFileCoordinator()
        for item in globalApp!.mmFile.result
        {
            let itemUrl = item.value(forAttribute: NSMetadataItemURLKey) as! URL
            fc.coordinate(readingItemAt: itemUrl, options: .resolvesSymbolicLink, error: nil, byAccessor: { url in
                files.append( MMFileDialogItem(mmView, url ) )
            })
        }
        selectedFileItem = files.first
        
        rect.width = 800
        rect.height = 600

        widgets.append(publicPrivateTab)
        widgets.append(self)
        
        fileTexture = view.icons["fileicon"]
    }
    
    func loadSelected() {
        if style == .Templates {
            if let selected = selectedTempItem {
                if !selected.fileName.isEmpty {
                    let path = Bundle.main.path(forResource: selected.fileName, ofType: globalApp!.mmFile.appExtension)!
                    let data = NSData(contentsOfFile: path)! as Data
                    let dataString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)

                    globalApp!.loadFrom(dataString! as String)
                    globalApp!.mmView.undoManager!.removeAllActions()
                }
            }
        } else {
            if let selected = selectedFileItem {
                let string = globalApp!.mmFile.loadJSON(url: selected.url)
                globalApp!.loadFrom(string)
                globalApp!.mmView.undoManager!.removeAllActions()
            }
        }
    }
    
    override func cancel() {
        super.cancel()
        
        loadSelected()
        
        globalApp!.currentEditor.deactivate()
        globalApp!.currentEditor = globalApp!.artistEditor
        globalApp!.currentEditor.activate()
        globalApp!.topRegion!.switchButton.state = .Left
        
        cancelButton!.removeState(.Checked)
    }
    
    override func ok() {
        super.ok()
        
        loadSelected()
        
        globalApp!.currentEditor.deactivate()
        globalApp!.currentEditor = globalApp!.developerEditor
        globalApp!.currentEditor.activate()
        globalApp!.topRegion!.switchButton.state = .Right
        
        okButton.removeState(.Checked)
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        super.mouseMoved(event)
        
        if style == .Templates {
            hoverTempItem = nil
            for t in templates {
                for item in t.items {
                    if item.rect.contains(event.x, event.y) {
                        hoverTempItem = item
                        break
                    }
                }
            }
        } else {
            hoverFileItem = nil
            for item in files {
                if item.rect.contains(event.x, event.y) {
                    hoverFileItem = item
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
        
        if style == .Templates {
            selectedTempItem = hoverTempItem
        } else {
            if let item = hoverFileItem {
                selectedFileItem = item
            }
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        if style == .Templates {
            //tempScrollOffset += event.deltaY! * 4
        } else {
            fileScrollOffset += event.deltaY! * 4
        }
        
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
    
    override func scrolledIn() {
        DispatchQueue.main.async {
            self.mmView.startAnimate( startValue: 0, endValue: 1, duration: 200, cb: { (value,finished) in
                self.alpha = value
                if finished {
                }
            } )
        }
    }
    
    override func cleanup(finished:@escaping ()->())
    {
        DispatchQueue.main.async {
            self.mmView.startAnimate( startValue: 1, endValue: 0, duration: 200, cb: { (value,hasFinished) in
                self.alpha = value
                if hasFinished {
                    finished()
                }
            } )
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
            w.rect.y = rect.y + 34
            w.draw()
            left += w.rect.width + 5
        }

        if style == .Templates {
            drawTemplates(xOffset: xOffset, yOffset: yOffset)
        } else {
            drawFileList(xOffset: xOffset, yOffset: yOffset)
        }
    }
    
    func drawFileList(xOffset: Float = 0, yOffset: Float = 0) {
        
        let headerHeight : Float = 30
        
        let itemWidth : Float = (rect.width - 4 - 2)
        let itemHeight : Float = 30
        var y : Float = rect.y + 41 + headerHeight

        if rect.y == 0 {
            let scrollHeight : Float = rect.height - 93 - headerHeight
            scrollRect = MMRect(rect.x + 3, y, itemWidth, scrollHeight)
            mmView.renderer.setClipRect(scrollRect)
            
            var maxHeight : Float = Float(files.count) * itemHeight
            if files.count > 0 {
                maxHeight += 2 * Float(files.count-1)
            }
            
            if fileScrollOffset < -(maxHeight - scrollHeight) {
                fileScrollOffset = -(maxHeight - scrollHeight)
            }
            
            if fileScrollOffset > 0 {
                fileScrollOffset = 0
            }
            
            y += fileScrollOffset
            var fillColor = mmView.skin.Item.color
            fillColor.w = alpha
            
            for item in files {
                let x : Float = rect.x + 3
                
                var borderColor = selectedFileItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
                var textColor = selectedFileItem === item ? mmView.skin.Item.selectionColor : SIMD4<Float>(1,1,1,1)
                borderColor.w = alpha
                textColor.w = alpha

                mmView.drawBox.draw( x: x, y: y, width: itemWidth, height: itemHeight, round: 26, borderSize: 2, fillColor: fillColor, borderColor: borderColor)
                
                item.rect.set(x, y, itemWidth, itemHeight)
                item.titleLabel.color = textColor
                item.titleLabel.drawCenteredY(x: x + 10, y: y, width: itemWidth, height: itemHeight)
                
                item.dateLabel.color = textColor
                item.dateLabel.drawCenteredY(x: x + itemWidth - 10 - item.dateLabel.rect.width, y: y, width: itemWidth, height: itemHeight)
                
                y += itemHeight + 2
            }
            mmView.renderer.setClipRect()
        }
            
        if rect.y == 0 {
            mmView.renderer.setClipRect()
        }
        
        let boxRect : MMRect = MMRect(rect.x, rect.y + 38 + headerHeight, rect.width, rect.height - 90 - headerHeight)
        
        let cb : Float = 1
        // Erase Edges
        mmView.drawBox.draw( x: boxRect.x - cb, y: boxRect.y - cb, width: boxRect.width + 2*cb, height: boxRect.height + 2*cb, round: 30, borderSize: 4, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.color)
        
        // Box Border
        mmView.drawBox.draw( x: boxRect.x, y: boxRect.y, width: boxRect.width, height: boxRect.height, round: 30, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
                
        // Renew dialog border
        mmView.drawBox.draw( x: rect.x, y: rect.y - yOffset, width: rect.width, height: rect.height, round: 40, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.borderColor )
    }
    
    func drawTemplates(xOffset: Float = 0, yOffset: Float = 0) {
        let headerHeight : Float = 30
        var y : Float = rect.y + 38 + headerHeight

        let itemWidth : Float = (rect.width - 4 - 2)
        let scrollHeight : Float = rect.height - 90 - headerHeight
        scrollRect = MMRect(rect.x + 3, y, itemWidth, scrollHeight)

        if rect.y == 0 {
        
            mmView.renderer.setClipRect(scrollRect)
            
            //let rows : Float = Float(Int(max(Float(items.count)/2, 1)))
            //let maxHeight : Float = 500//rows * itemSize + (rows - 1) * 2
            
            //if tempScrollOffset < -(maxHeight - tempScrollOffset) {
            //    tempScrollOffset = -(maxHeight - tempScrollOffset)
            //}
            
            if tempScrollOffset > 0 {
                tempScrollOffset = 0
            }
                        
            y += tempScrollOffset
        }

        var x       : Float = 0
        let zoom    : Float = 1.5

        let textureWidth = Float(fileTexture!.width) / zoom
        let textureHeight = Float(fileTexture!.height) / zoom
        
        for (index,template) in templates.enumerated() {
                       
            x = rect.x + 20

            if index > 0 {
                mmView.drawBox.draw( x: x, y: y + 5, width: scrollRect!.width - 40, height: 1, round: 0, borderSize: 0, fillColor: mmView.skin.Dialog.borderColor)
                y += 5
            }
            
            template.titleLabel.rect.x = x
            template.titleLabel.rect.y = y + 8
            template.titleLabel.draw()
            
            mmView.drawBox.draw( x: x, y: y + 34, width: scrollRect!.width - 40, height: 1, round: 0, borderSize: 0, fillColor: mmView.skin.Dialog.borderColor)
            
            y += 48
            x = rect.x + 50

            for item in template.items {
                                
                let width = max(item.titleLabel.rect.width, textureWidth)
                
                item.rect.set( x - 6, y - 6, width + 12, textureHeight + 30)
                
                if item === selectedTempItem {
                    mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height, round: 12, borderSize: 0, fillColor: mmView.skin.Dialog.borderColor)
                }

                mmView.drawTexture.draw(fileTexture!, x: x + (width - textureWidth) / 2, y: y, zoom: zoom)
                
                item.titleLabel.rect.x = x + (width - item.titleLabel.rect.width) / 2
                item.titleLabel.rect.y = y + textureHeight + 5
                item.titleLabel.draw()
                
                x += textureWidth + 40
            }
            
            y += textureHeight + 28
            /*
            let borderColor = selectedItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
            let textColor = selectedItem === item ? mmView.skin.Item.selectionColor : SIMD4<Float>(1,1,1,1)

            //x += (Float(index).truncatingRemainder(dividingBy: 3)) * (itemSize + 2)

            mmView.drawBox.draw( x: x, y: y, width: itemSize, height: itemSize, round: 26, borderSize: 2, fillColor: mmView.skin.Item.color, borderColor: borderColor)//, maskRoundingSize: 26, maskRect: SIMD4<Float>(boxRect.x, boxRect.y, boxRect.width, boxRect.height))
            
            if let thumb = item.thumbnail {
                mmView.drawTexture.draw(thumb, x: x + (itemSize - Float(100)) / 2, y: y + 15, zoom: 2)
            } else
            if oneThumbnailOnly == false {
                oneThumbnailOnly =  true
                item.thumbnail = globalApp!.thumbnail.request(item.type)
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
            
            if (index+1) % 5 == 0 {
                x = rect.x + 3
                y += itemSize + 2
            } else {
                x += itemSize + 2
            }
            */
        }
        
        if rect.y == 0 {
            mmView.renderer.setClipRect()
        }
        
        let boxRect : MMRect = MMRect(rect.x, rect.y + 35 + headerHeight, rect.width, rect.height - 90 - headerHeight)
        
        let cb : Float = 1
        // Erase Edges
        mmView.drawBox.draw( x: boxRect.x - cb, y: boxRect.y - cb, width: boxRect.width + 2*cb, height: boxRect.height + 2*cb, round: 30, borderSize: 4, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.color)
        
        // Box Border
        mmView.drawBox.draw( x: boxRect.x, y: boxRect.y, width: boxRect.width, height: boxRect.height, round: 30, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        
        // Renew dialog border
        mmView.drawBox.draw( x: rect.x, y: rect.y - yOffset, width: rect.width, height: rect.height, round: 40, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.borderColor )
    }
}
