//
//  Dialogs.swift
//  Shape-Z
//
//  Created by Markus Moenig on 29/8/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class MMTemplateChooser : MMDialog {
    
    init(_ view: MMView) {
        super.init(view, title: "Choose Project Template", cancelText: "", okText: "Create Project")
        
        rect.width = 600
        rect.height = 400
    }
    
    override func ok() {
        super.ok()
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0) {
        super.draw(xOffset: xOffset, yOffset: yOffset)
    }
}
