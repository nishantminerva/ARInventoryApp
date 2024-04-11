//
//  ARInventoryAppApp.swift
//  ARInventoryApp
//
//  Created by Nishant Minerva on 26/01/24.
//

import SwiftUI

@main
struct ARInventoryAppApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                InventoryListView()
            }
        }
    }
}
