//
//  NavigationVM.swift
//  ARInventoryApp
//
//  Created by Nishant Minerva on 26/01/24.
//

import Foundation
import SwiftUI

class NavigationViewModel: ObservableObject {
    
    @Published var selectedItem: InventoryItem?
    
    init(selectedItem: InventoryItem? = nil) {
        self.selectedItem = selectedItem
    }
}


