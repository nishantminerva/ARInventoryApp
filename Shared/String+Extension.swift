//
//  String+Extension.swift
//  ARInventoryApp
//
//  Created by Nishant Minerva on 26/01/24.
//

import Foundation

extension String: Error, LocalizedError {
    
    public var errorDescription: String? { self }
}
