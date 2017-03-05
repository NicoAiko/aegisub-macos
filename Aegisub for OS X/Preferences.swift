//
//  Preferences.swift
//  Aegisub for OS X
//
//  Created by リネマン・ニコ on 04.03.17.
//  Copyright © 2017 Nico Linnemann. All rights reserved.
//

import Cocoa

class Preferences: NSWindowController {
    
    enum PreferencesViewType: Int {
        case kPreferencesViewTypeGeneral = 100
        case kPreferencesViewTypeChangelog
    }
    
    enum PreferencesLanguageTags: Int {
        case kPreferencesLanguageTagGerman = 100
        case kPreferencesLanguageTagEnglish
        case kPreferencesLanguageTagJapanese
        func getLocale() -> String {
            switch self {
            case .kPreferencesLanguageTagGerman:
                return "de"
            case .kPreferencesLanguageTagEnglish:
                return "en"
            case .kPreferencesLanguageTagJapanese:
                return "ja"
            /*default:
                return "error"*/
            }
        }
    }
    
    // TODO: Add Dictionary here for Languages
    // key: de - value: "Deutsch"
    
    let languageDictionary : [String:String] = [
        "de" : "Deutsch",
        "en" : "English",
        "ja" : "日本語"
    ]
    
    @IBOutlet weak var generalView: NSView!
    @IBOutlet weak var languagePopup: NSPopUpButton!
    
    @IBOutlet weak var changelogView: NSView!
    
    @IBOutlet weak var notificationWindow: NSWindow!
    
    
    
    var userSettings : NSDictionary?
    
    convenience init() {
        self.init(windowNibName: "Preferences")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        let window: NSWindow = self.window!
        let toolbar: NSToolbar = window.toolbar!
        let toolbarItems : NSArray = toolbar.items as NSArray
        let leftmostToolbarItem : NSToolbarItem = toolbarItems.object(at: 0) as! NSToolbarItem
        
        toolbar.selectedItemIdentifier = leftmostToolbarItem.itemIdentifier
        self.switchView(leftmostToolbarItem)
        
        window.center()
        
        if let path = Bundle.main.path(forResource: "UserSettings", ofType: "plist") {
            self.userSettings = NSDictionary(contentsOfFile: path)
        }
        
        languagePopup.selectItem(withTitle: languageDictionary[self.userSettings?.object(forKey: "Language") as! String]!)
        
    }
    
    @IBAction func switchView(_ sender: NSToolbarItem) {
        let viewType : PreferencesViewType = Preferences.PreferencesViewType(rawValue: sender.tag)!
        
        var newView : NSView? = nil
        
        switch viewType {
        case .kPreferencesViewTypeGeneral:
            newView = self.generalView
            break
        default:
            newView = self.changelogView
            break
        }
        
        let window : NSWindow = self.window!
        let contentView : NSView = window.contentView!
        let subViews : NSArray = contentView.subviews as NSArray
        
        for subView in subViews {
            (subView as AnyObject).removeFromSuperview()
        }
        
        window.title = sender.label
        
        let windowFrame : NSRect = window.frame
        var newWindowFrame : NSRect = window.frameRect(forContentRect: newView!.frame)
        newWindowFrame.origin.x = windowFrame.origin.x
        newWindowFrame.origin.y = windowFrame.origin.y + windowFrame.size.height - newWindowFrame.size.height
        window.setFrame(newWindowFrame, display: true, animate: true)
        
        contentView.addSubview(newView!)
        
    }
    
    // General View Actions
    
    @IBAction func changeLanguage(_ sender: NSPopUpButton) {
        let currentLanguageTag = Preferences.PreferencesLanguageTags.init(rawValue: (sender.selectedItem?.tag)!)?.getLocale()
        
        if currentLanguageTag != (userSettings?.object(forKey: "Language") as! String) {
            let path = Bundle.main.path(forResource: "UserSettings", ofType: "plist")
            userSettings?.setValue(currentLanguageTag, forKey: "Language")
            userSettings?.write(toFile: path!, atomically: true)
            
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            UserDefaults.standard.setValue([currentLanguageTag], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            var window = NSWindow()
            window = notificationWindow
            window.setFrameOriginToPositionWindowInCenterOfScreen()
            let controller = NSWindowController(window: window)
            
            controller.showWindow(self)
            
        }
    }
    
    // Notification Window Actions
    
    @IBAction func closeNotification(_ sender: NSButton) {
        sender.window?.close()
    }
    
    
}

extension NSWindow {
    public func setFrameOriginToPositionWindowInCenterOfScreen() {
        if let screenSize = screen?.frame.size {
            self.setFrameOrigin(NSPoint(x: (screenSize.width - frame.size.width) / 2, y: (screenSize.height - frame.size.height) / 2))
        }
    }
}
