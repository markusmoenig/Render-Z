//
//  ViewController.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    var app : App!
    var mmView : MMView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mmView = view as? MMView
        app = App( mmView )
        
        (NSApplication.shared.delegate as! AppDelegate).app = app
        
/*
        
        let myDocumentUrl = self.containerUrl//?
//            .appendingPathComponent("testing")
//            .appendingPathExtension("shape-z")
        
        var string = "Lots of data"
        do {
//            try string.write(to: myDocumentUrl!, atomically: true, encoding: .utf8)
            
//            let test = try String(contentsOf: myDocumentUrl!)
//            print( test )
            
            let contents = try FileManager.default.contentsOfDirectory(at: myDocumentUrl!,
                                                            includingPropertiesForKeys: nil,
                                                            options: [.skipsHiddenFiles])
//            print( contents )
            
            var isDir : ObjCBool = false
            for file in contents {
//                print( file )
//                let attr = try FileManager.default.attributesOfItem(atPath:file.path)
//                print( file.lastPathComponent )
                
                let dd = try FileManager.default.fileExists(atPath: file.path, isDirectory:&isDir)
                print( file.lastPathComponent, file.path, isDir )

//                try FileManager.default.removeItem(at: file.absoluteURL)

            }

        } catch {
            print(error.localizedDescription)
        }*/

    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

