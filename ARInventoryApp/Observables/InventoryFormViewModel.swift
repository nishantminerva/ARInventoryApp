//
//  InventoryFormViewModel.swift
//  ARInventoryApp
//
//  Created by Nishant Minerva on 26/01/24.
//


import FirebaseFirestore
import FirebaseStorage
import Foundation
import SwiftUI
import QuickLookThumbnailing

class InventoryFormViewModel : ObservableObject {
    let db = Firestore.firestore()
    let formType: FormType
    let id: String
    
    @Published var name = ""
    @Published var quantity  = 0
    @Published var usdzURL : URL?
    @Published var thumbnailURL : URL?
    @Published var loadingState = LoadingType.none
    @Published var error : String?
    @Published var uploadProgress : uploadProgress?
    @Published var showUSDZSource = false
    @Published var selectedUSDZSource : USDZSourceType?
    
    let byteCountFormatter : ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
    
    var navigationTitle : String {
        switch formType {
        case .add:
            return "Add item"
        case .edit:
            return "Edit item"
        }
    }
    
    init(formType : FormType = .add){
        self.formType = formType
        switch formType {
        case .add :
            id = UUID().uuidString
        case .edit(let item) :
            id = item.id
            name = item.name
            quantity = item.quantity
            if let usdzURL = item.usdzURL {
                self.usdzURL = usdzURL
            }
            if let thumbnailURL = item.thumbnailURL {
                self.thumbnailURL = thumbnailURL
            }
        }
    }
    
    func save() throws {
        loadingState = .savingItem
        defer {loadingState = .none}
        
        var item : InventoryItem
        switch formType {
        case .add:
            item = .init(id: id, name: name, quantity: quantity)
        case .edit(let inventoryItem):
            item = inventoryItem
            item.name = name
            item.quantity = quantity
        }
        
        item.usdzLink = usdzURL?.absoluteString
        item.thumbnailLink = thumbnailURL?.absoluteString
        
        do {
            try db.document("items/\(item.id)")
                .setData(from: item)
        } catch {
            self.error = error.localizedDescription
            throw error
        }
        
    }
    
    @MainActor
    func uploadUSZD(fileURL : URL) async {
        let getAccess = fileURL.startAccessingSecurityScopedResource()
        guard getAccess, let data = try? Data(contentsOf: fileURL) else {
            return
        }
        fileURL.stopAccessingSecurityScopedResource()
        uploadProgress = .init(fractionCompleted: 0, totalUnitCount: 0, completedUnitCount: 0)
        loadingState = .uploading(.usdz)
        
        defer {loadingState = .none}
        do {
//            upload usdz to firebase storage
            let storageRef = Storage.storage().reference()
            let usdzRef = storageRef.child("\(id).usdz")
            
            _ = try await usdzRef.putDataAsync(data, metadata: .init(dictionary: ["contentType" : "model/vnd.usd+zip"])){
                [weak self] progress in guard let self, let progress else { return }
                self.uploadProgress = .init(fractionCompleted: progress.fractionCompleted, totalUnitCount: progress.totalUnitCount, completedUnitCount: progress.completedUnitCount)
            }
            
            let downloadURl = try await usdzRef.downloadURL()
            
            let cacheDirURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let fileCacheURL = cacheDirURL.appending(path: "temp_\(id).usdz")
            try? data.write(to: fileCacheURL)
            
            let thumbnailRequest = QLThumbnailGenerator.Request(fileAt: fileCacheURL, size: .init(width: 300, height: 300), scale: UIScreen.main.scale, representationTypes: .all)
            
            if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: thumbnailRequest), let jpgData = thumbnail.uiImage.jpegData(compressionQuality: 0.5) {
                loadingState = .uploading(.thumbnail)
                let thumbnailRef = storageRef.child("\(id).jpg")
                
                _ = try? await thumbnailRef.putDataAsync(jpgData, metadata: .init(dictionary: ["contentType" : "Image/jpeg"]), onProgress : { [weak self] progress in
                    guard let self,  let progress else {return}
                    self.uploadProgress = .init(fractionCompleted: progress.fractionCompleted, totalUnitCount: progress.totalUnitCount, completedUnitCount: progress.completedUnitCount)
                })
                if let thumbnailURL = try? await thumbnailRef.downloadURL() {
                    self.thumbnailURL = thumbnailURL
                }
            }
            self.usdzURL = downloadURl
            
        } catch {
            self.error = error.localizedDescription
        }
    }
}

enum FormType: Identifiable {
    case add
    case edit(InventoryItem)
    
    var id: String {
        switch self {
        case .add:
            return "add"
        case .edit(let inventoryItem):
            return "edit \(inventoryItem.id)"
        }
    }
}

enum LoadingType : Equatable {
    case none
    case savingItem
    case uploading(uploadType)
}

enum USDZSourceType {
    case fileImporter, objectCapture
}

enum uploadType : Equatable {
    case usdz, thumbnail
}

struct uploadProgress {
    var fractionCompleted : Double
    var totalUnitCount : Int64
    var completedUnitCount : Int64
}
