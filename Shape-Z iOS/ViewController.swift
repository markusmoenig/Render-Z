//
//  ViewController.swift
//  Shape-Z iOS
//
//  Created by Markus Moenig on 13/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIDocumentPickerDelegate {

    var app : App!
    var mmView : MMView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mmView = view as? MMView
        app = App( mmView )
        
        app.viewController = self
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func importFile() {
        
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(documentTypes: ["com.moenig.shapez.document"], in: UIDocumentPickerMode.import)
        documentPicker.delegate = self
        
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        if controller.documentPickerMode == UIDocumentPickerMode.import {

            do {
                let string = try String(contentsOf: url, encoding: .utf8)
                print( string )

                app.loadFrom(string)

                app.mmFile.name = url.deletingPathExtension().lastPathComponent
            } catch
            {
                
            }
        }
    }
}
