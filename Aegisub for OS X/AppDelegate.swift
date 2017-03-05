//
//  AppDelegate.swift
//  Aegisub for OS X
//
//  Created by Nico Linnemann on 2016/05/08.
//  Copyright © 2016年 Nico Linnemann. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSUserNotificationCenterDelegate, NSToolbarDelegate {

    private var preferences: Preferences?

    @IBAction func showPreferences(_ sender: NSMenuItem) {
        if preferences == nil {
            preferences = Preferences()
        }
        preferences?.showWindow(self)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

