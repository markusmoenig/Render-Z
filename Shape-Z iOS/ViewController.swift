//
//  ViewController.swift
//  Shape-Z iOS
//
//  Created by Markus Moenig on 13/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import UIKit
import MobileCoreServices

class ViewController: UIViewController, UIDocumentPickerDelegate {

    var app         : App!
    var mmView      : MMView!
    
    var stringData  : String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mmView = view as? MMView
        app = App( mmView )
        
        app.viewController = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //getSampleProject(view: app.mmView, title: "New Project", message: "Select the project type", sampleProjects: ["Empty Project", "Pinball"], cb: { (index) -> () in
           // print("Result", index)
        //} )
        
        let dialog = MMTemplateChooser(app.mmView)
        app.mmView.showDialog(dialog)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func importFile() {
        
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(documentTypes: ["com.moenig.shapez.document"], in: UIDocumentPickerMode.import)
        documentPicker.delegate = self
        
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func exportFile(_ stringData: String) {
        self.stringData = stringData
        let documentPicker: UIDocumentPickerViewController = UIDocumentPickerViewController(url: URL(string: kUTTypeText as String)!, in: UIDocumentPickerMode.exportToService)
        documentPicker.delegate = self
        
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        if controller.documentPickerMode == UIDocumentPickerMode.import {

            do {
                let string = try String(contentsOf: url, encoding: .utf8)

                app.loadFrom(string)
                app.mmFile.name = url.deletingPathExtension().lastPathComponent
            } catch {
                print(error.localizedDescription)
            }
        } else
        if controller.documentPickerMode == UIDocumentPickerMode.exportToService {
            
            print( url )
            
            do {
                try stringData.write(to: url, atomically: true, encoding: .utf8)
                mmView.undoManager!.removeAllActions()
            } catch
            {
                print(error.localizedDescription)
            }
        }
    }
}
