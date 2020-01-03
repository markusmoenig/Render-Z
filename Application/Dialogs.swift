//
//  Dialogs.swift
//  Shape-Z
//
//  Created by Markus Moenig on 29/8/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class TemplateChooserItem {
    
    var fileName            : String = ""
    var description         : String = ""

    var titleLabel          : MMTextLabel
    var descriptionLabel    : MMTextLabel
    var rect                : MMRect = MMRect()
    
    init(_ mmView: MMView,_ title: String, _ fileName: String = "", _ description: String = "")
    {
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title)
        descriptionLabel = MMTextLabel(mmView, font: mmView.openSans, text: description, scale: 0.36, color: float4(mmView.skin.Item.textColor))
        self.fileName = fileName
    }
}

class MMTemplateChooser : MMDialog {
    
    var items           : [TemplateChooserItem] = []

    var hoverItem       : TemplateChooserItem? = nil
    var selItem         : TemplateChooserItem? = nil
    
    var blueTexture     : MTLTexture? = nil
    var greyTexture     : MTLTexture? = nil
    
    var scrollOffset    : Float = 0
    var dispatched      : Bool = false

    init(_ view: MMView) {
        super.init(view, title: "Choose Project Template", cancelText: "", okText: "Create Project")
        
        rect.width = 600
        rect.height = 400
        
        items.append( TemplateChooserItem(mmView, "Empty Project" ) )
        items.append( TemplateChooserItem(mmView, "Pinball", "Pinball", "Physics" ) )
        items.append( TemplateChooserItem(mmView, "Pong", "Pong", "Customized Physics (Collision), AI" ) )
        items.append( TemplateChooserItem(mmView, "Marble", "Marble", "iOS Accelerometer, Customized Physics (Gravity)" ) )

        widgets.append(self)
        selItem = items[0]
        
        blueTexture = view.icons["sz_ui_blue"]
        greyTexture = view.icons["sz_ui_grey"]
    }
    
    override func ok() {
        super.ok()
        
        if let selected = selItem {
            if !selected.fileName.isEmpty {
                let path = Bundle.main.path(forResource: selected.fileName, ofType: globalApp!.mmFile.appExtension)!
                let data = NSData(contentsOfFile: path)! as Data
                let dataString = NSString(data: data, encoding: String.Encoding.utf8.rawValue)

                globalApp!.loadFrom(dataString! as String)
            }
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        super.mouseMoved(event)
        
        hoverItem = nil
        for item in items {
            if item.rect.contains(event.x, event.y) {
                hoverItem = item
                break
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        #if os(iOS)
        mouseMoved(event)
        #endif
        super.mouseDown(event)
        
        if let hover = hoverItem {
            selItem = hover
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
        
        let itemSize : Float = (rect.width - 4 - 6) / 3
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
        
        for (index,item) in items.enumerated() {
            
            var x : Float = rect.x + 3
            
            let borderColor = selItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
            let textColor = selItem === item ? mmView.skin.Item.selectionColor : float4(1,1,1,1)

            x += (Float(index).truncatingRemainder(dividingBy: 3)) * (itemSize + 2)

            mmView.drawBox.draw( x: x, y: y, width: itemSize, height: itemSize, round: 26, borderSize: 2, fillColor: mmView.skin.Item.color, borderColor: borderColor)//, maskRoundingSize: 26, maskRect: SIMD4<Float>(boxRect.x, boxRect.y, boxRect.width, boxRect.height))
            
            if selItem === item {
                mmView.drawTexture.draw(blueTexture!, x: x + (itemSize - Float(blueTexture!.width)*0.8) / 2, y: y + 45, zoom: 1.2)
            } else {
                mmView.drawTexture.draw(greyTexture!, x: x + (itemSize - Float(greyTexture!.width)*0.8) / 2, y: y + 45, zoom: 1.2)
            }
            
            item.rect.set(x, y, itemSize, itemSize)
            item.titleLabel.color = textColor
            item.titleLabel.drawCentered(x: x, y: y + itemSize - 59, width: itemSize, height: 35)
            
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
        mmView.drawBox.draw( x: boxRect.x - cb, y: boxRect.y - cb, width: boxRect.width + 2*cb, height: boxRect.height + 2*cb, round: 30, borderSize: 4, fillColor: float4(0,0,0,0), borderColor: mmView.skin.Dialog.color)
        
        // Box Border
        mmView.drawBox.draw( x: boxRect.x, y: boxRect.y, width: boxRect.width, height: boxRect.height, round: 30, borderSize: 2, fillColor: float4(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        
        y = rect.y + 35 + rect.height - 90 - 30
        
        mmView.drawBox.draw( x: rect.x + 10, y: y, width: rect.width - 20, height: 30, round: 26, borderSize: 2, fillColor: float4(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        if let item = selItem {
            item.descriptionLabel.drawCentered(x: rect.x + 10, y: y, width: rect.width - 20, height: 30)
        }
        
        // Renew dialog border
        mmView.drawBox.draw( x: rect.x, y: rect.y - yOffset, width: rect.width, height: rect.height, round: 40, borderSize: 2, fillColor: SIMD4<Float>(0,0,0,0), borderColor: mmView.skin.Dialog.borderColor )
    }
}

class MMFileDialogItem {
    
    var url                 : URL
    var description         : String = ""
    
    var titleLabel          : MMTextLabel
    var dateLabel           : MMTextLabel
    var rect                : MMRect = MMRect()
    
    init(_ mmView: MMView,_ url: URL)
    {
        self.url = url
        var title: String = ""
        var date: String = ""
        
        do {
            let values = try? url.resourceValues(forKeys: [.nameKey, .contentModificationDateKey])
            title = values!.name!.replacingOccurrences(of: ".shape-z", with: "")
            
            let dateFormatter = DateFormatter()
            let localFormatter = DateFormatter.dateFormat(fromTemplate: "MM/dd HH-mm", options: 0, locale: NSLocale.current)
            dateFormatter.dateFormat = localFormatter

            date = dateFormatter.string(from: values!.contentModificationDate!)
        }

        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text: title, scale: 0.36, color: float4(mmView.skin.Item.textColor))
        dateLabel = MMTextLabel(mmView, font: mmView.openSans, text: date, scale: 0.36, color: float4(mmView.skin.Item.textColor))
    }
}

class MMFileDialog : MMDialog {
    
    enum Mode {
        case Open, Save
    }
    
    var mode            : Mode = .Open
    var items           : [MMFileDialogItem] = []
    
    var hoverItem       : MMFileDialogItem? = nil
    var selItem         : MMFileDialogItem? = nil
    var nameRect        : MMRect = MMRect()
    
    var scrollOffset    : Float = 0
    var dispatched      : Bool = false

    var alpha           : Float = 0
    
    var hasTextFocus    : Bool = false

    #if os(iOS)
    var textField       : UITextField!
    var fileNameLabel   : MMTextLabel!
    #endif
    
    init(_ view: MMView,_ mode: Mode = .Open) {
        self.mode = mode
        super.init(view, title: mode == .Open ? "Open Project from iCloud" : "Save Project to iCloud", cancelText: "Cancel", okText: mode == .Open ? "Open" : "Save")
        
        rect.width = 600
        rect.height = 400
        
        #if os(iOS)
        if mode == .Save {
            textField = UITextField(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            
            textField.keyboardType = UIKeyboardType.alphabet
            textField.isHidden = true
            textField.text = globalApp!.mmFile!.name
            mmView.addSubview(textField)
            
            textField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
            textField.addTarget(self, action: #selector(textFieldEditingDidEnd(textField:)), for: .editingDidEnd)

            fileNameLabel = MMTextLabel(mmView, font: mmView.openSans, text: globalApp!.mmFile!.name, scale: 0.36, color: float4(mmView.skin.Item.textColor))
        }
        #endif
        
        let mmFile = globalApp!.mmFile!
        var contents : [URL] = []
        
        do {
            contents = try FileManager.default.contentsOfDirectory(at: mmFile.containerUrl!, includingPropertiesForKeys: nil, options: [])
            
            for item in contents {
                
                let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .nameKey])

                if values!.isRegularFile! {
                    if values!.name!.contains(".shape-z") && !values!.name!.starts(with: ".") {
                        items.append( MMFileDialogItem(mmView, item ) )
                    }
                }
            }
        }
        catch {
            print(error.localizedDescription)
        }

        widgets.append(self)
    }
    
    override func cancel() {
        super.ok()
        
        #if os(iOS)
        if mode == .Save {
            textField.removeFromSuperview()
        }
        #endif
    }
    
    override func ok() {
        super.ok()
        
        if mode == .Open {
            if let selected = selItem {
                let string = globalApp!.mmFile.loadJSON(url: selected.url)
                globalApp!.loadFrom(string)
                globalApp!.mmView.undoManager!.removeAllActions()
            }
        }
        
        #if os(iOS)
        if mode == .Save {
            textField.removeFromSuperview()
            
            let mmFile = globalApp!.mmFile!
            let path = mmFile.containerUrl!.appendingPathComponent(textField.text!).appendingPathExtension(globalApp!.mmFile.appExtension)
            mmFile.name = textField.text!

            do {
                let json = globalApp!.nodeGraph.encodeJSON()
                try json.write(to: path, atomically: false, encoding: .utf8)
            } catch
            {
                print(error.localizedDescription)
            }
        }
        #endif
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        super.mouseMoved(event)
        
        hoverItem = nil
        for item in items {
            if item.rect.contains(event.x, event.y) {
                hoverItem = item
                break
            }
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        #if os(iOS)
        mouseMoved(event)
        #endif
        super.mouseDown(event)
        
        #if os(iOS)
        if mode == .Save {
            if nameRect.contains(event.x, event.y) {
                textField.becomeFirstResponder()
                hasTextFocus = true
            }
        }
        #endif
        
        if let hover = hoverItem {
            #if os(iOS)
            if mode == .Save {
                textField.text = hover.titleLabel.text
                fileNameLabel.setText(hover.titleLabel.text)
            }
            #endif
            selItem = hover
            mmView.update()
        }
    }
    
    #if os(iOS)
    @objc func textFieldDidChange(textField: UITextField) {
        fileNameLabel.setText(textField.text!)
        mmView.update()
    }
    @objc func textFieldEditingDidEnd(textField: UITextField) {
        hasTextFocus = false
        mmView.update()
    }
    #endif
    
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
        
        let itemWidth : Float = (rect.width - 4 - 2)
        let itemHeight : Float = 30
        
        mmView.drawBox.draw( x: rect.x, y: rect.y + 35, width: rect.width, height: rect.height - 90 - 40, round: 30, borderSize: 2, fillColor: float4(0,0,0,0), borderColor: mmView.skin.Item.borderColor)
        
        var y : Float = rect.y + 38
        if rect.y == 0 {
            let scrollHeight : Float = rect.height - 90 - 46
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
            var fillColor = mmView.skin.Item.color
            fillColor.w = alpha
            
            for item in items {
                
                let x : Float = rect.x + 3
                
                var borderColor = selItem === item ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor
                var textColor = selItem === item ? mmView.skin.Item.selectionColor : float4(1,1,1,1)
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
        
        y = rect.y + 35 + rect.height - 90 - 30
        
        nameRect.x = rect.x + 10
        nameRect.y = y
        nameRect.width = rect.width - 20
        nameRect.height = 30
        
        mmView.drawBox.draw( x: nameRect.x, y: nameRect.y, width: nameRect.width, height: nameRect.height, round: 26, borderSize: 2, fillColor: float4(0,0,0,0), borderColor: hasTextFocus ? mmView.skin.Item.selectionColor : mmView.skin.Item.borderColor)
        
        var drawTitle : Bool = true
        #if os(iOS)
        if mode == .Save {
            fileNameLabel.color = mmView.skin.Item.selectionColor
            fileNameLabel.drawCenteredY(x: rect.x + 20, y: y, width: rect.width - 20, height: 30)
            drawTitle = false
        }
        #endif
        
        if drawTitle {
            if let item = selItem {
                item.titleLabel.drawCenteredY(x: rect.x + 20, y: y, width: rect.width - 20, height: 30)
            }
        }
    }
}
