//
//  MMFile.swift
//  Shape-Z
//
//  Created by Markus Moenig on 18/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

#if os(OSX)
import AppKit
#else
import UIKit
#endif

class MMFile : NSObject
{
    var mmView              : MMView!
    var name                : String = "Untitled"
    let appExtension        : String
    
    var query               : NSMetadataQuery!
    var result              : [NSMetadataItem] = []
    
    var containerUrl: URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
//        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    init(_ view: MMView,_ ext: String)
    {
        mmView = view
        appExtension = ext
        
        super.init()
        
        // --- Check for iCloud container existence
        if let url = self.containerUrl, !FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        
        query = NSMetadataQuery()
        query.predicate = NSPredicate.init(format: "%K BEGINSWITH %@", argumentArray: [NSMetadataItemPathKey, self.containerUrl!.path])
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateCloudData), name: NSNotification.Name.NSMetadataQueryDidFinishGathering, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateCloudData), name: NSNotification.Name.NSMetadataQueryDidUpdate, object: nil)
        
        query.enableUpdates()
        query.start()
    }
    
    @objc func updateCloudData(notification: NSNotification)
    {        
        query.disableUpdates()
        result = query.results as! [NSMetadataItem]
        query.enableUpdates()

        for item in query.results as! [NSMetadataItem] {
            let url = item.value(forAttribute: NSMetadataItemURLKey) as! URL
            let values = try? url.resourceValues(forKeys: [.nameKey, .contentModificationDateKey])
            if values == nil {
                let fc = NSFileCoordinator()
                fc.coordinate(readingItemAt: url, options: .resolvesSymbolicLink, error: nil, byAccessor: { url in
                })
            }
        }
    }
    
    /// Returns the file url
    func url() -> URL?
    {
        let documentUrl = self.containerUrl?
                    .appendingPathComponent(name)
                    .appendingPathExtension(appExtension)
        return documentUrl
    }
    
    /// Saves the file to iCloud
    func save(_ stringData: String)
    {
        do {
            /*
            try FileManager.default.createDirectory(at: (self.containerUrl?
                .appendingPathComponent("Temp"))!,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            
            print( url()! )
            */
            try stringData.write(to: url()!, atomically: true, encoding: .utf8)
        } catch
        {
            print(error.localizedDescription)
        }
    }
    
    func saveAs(_ stringData: String, _ app: App)
    {
        #if os(OSX)

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = false
        savePanel.title = "Select Project"
        savePanel.directoryURL =  containerUrl
        savePanel.showsHiddenFiles = false
        savePanel.allowedFileTypes = [appExtension]
        savePanel.nameFieldStringValue = name
        
        func save(url: URL)
        {
            do {
                try stringData.write(to: url, atomically: true, encoding: .utf8)
            }
            catch {
                print(error.localizedDescription)
            }
        }
        
        savePanel.beginSheetModal(for: self.mmView.window!) { (result) in
            if result == .OK {
                save(url: savePanel.url!)
                
                self.name = savePanel.url!.deletingPathExtension().lastPathComponent
                app.mmView.window!.title = self.name
                app.mmView.window!.representedURL = self.url()
                
                self.mmView.undoManager!.removeAllActions()
            }
        }
        
        #elseif os(iOS)
        
        app.viewController?.exportFile(stringData)

        /*
        do {
            try stringData.write(to: url()!, atomically: true, encoding: .utf8)
            self.mmView.undoManager!.removeAllActions()
        } catch
        {
            print(error.localizedDescription)
        }*/
        
        #endif
    }
    
    func saveImage(image: CGImage)
    {
        #if os(OSX)

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = false
        savePanel.title = "Select Image"
        savePanel.directoryURL =  containerUrl
        savePanel.showsHiddenFiles = false
        savePanel.allowedFileTypes = ["png"]
        
        func save(url: URL)
        {
            if let imageDestination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) {
                CGImageDestinationAddImage(imageDestination, image, nil)
                CGImageDestinationFinalize(imageDestination)
            }
        }
        
        savePanel.beginSheetModal(for: self.mmView.window!) { (result) in
            if result == .OK {
                save(url: savePanel.url!)
            }
        }
        
        #elseif os(iOS)
                
        let image = UIImage(cgImage: image)
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(savingToPhotoLibraryComplete(image:err:context:)), nil)
        
        #endif
    }
    
    #if os(iOS)
    @objc func savingToPhotoLibraryComplete(image:UIImage, err:NSError, context:UnsafeMutableRawPointer?) {
    }
    #endif
    
    func loadJSON(url: URL) -> String
    {
        var string : String = ""
        
        let fc = NSFileCoordinator()
        fc.coordinate(readingItemAt: url, options: .forUploading, error: nil, byAccessor: { url in
            do {
                string = try String(contentsOf: url, encoding: .utf8)
            } catch {
                print(error.localizedDescription)
            }
        })
        return string
    }

    ///
    func chooseFile(app: App)
    {
        #if os(OSX)

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.title = "Select Project"
        openPanel.directoryURL =  containerUrl
        openPanel.showsHiddenFiles = false
        openPanel.allowedFileTypes = [appExtension]
        
        func load(url: URL) -> String
        {
            var string : String = ""
            
            do {
                string = try String(contentsOf: url, encoding: .utf8)
            }
            catch {
                print(error.localizedDescription)
            }
            
            return string
        }
        
        openPanel.beginSheetModal(for:self.mmView.window!) { (response) in
            if response == NSApplication.ModalResponse.OK {
                let string = load(url: openPanel.url!)
                app.loadFrom(string)
                
                self.name = openPanel.url!.deletingPathExtension().lastPathComponent
                
                app.mmView.window!.title = self.name
                app.mmView.window!.representedURL = self.url()
                
                app.mmView.undoManager!.removeAllActions()
            }
            openPanel.close()
        }
        
        #elseif os(iOS)
        
        app.viewController?.importFile()
        
        #endif
    }
}
