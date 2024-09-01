//
//  ServerManager.swift
//  ServerManager
//
//  Created by Thiết Dương on 1/9/24.
//

import Foundation
import Photos
import AVKit

public extension FileManager {
    
    // Get the Documents directory URL
    func getDocumentsDirectory() -> URL {
        return try! self.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
    
    // Create a temporary file directory in Documents
    func createTempDirectory() -> URL {
        let tempDirURL = getDocumentsDirectory().appendingPathComponent("tmp")
        if !fileExists(atPath: tempDirURL.path) {
            do {
                try createDirectory(at: tempDirURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating temp directory: \(error.localizedDescription)")
            }
        }
        return tempDirURL
    }
    
    // Delete the temporary directory and its contents
    func deleteTempDirectory() {
        let tempDirURL = createTempDirectory()
        do {
            if fileExists(atPath: tempDirURL.path) {
                try removeItem(at: tempDirURL)
                print("Deleted temp directory at: \(tempDirURL.path)")
            }
        } catch {
            print("Error deleting temp directory: \(error.localizedDescription)")
        }
    }
    
    // Copy PHAsset to the temporary directory
    func copyPHAssetToTempDirectory(asset: PHAsset, completion: @escaping (URL?, Error?) -> Void) {
        let options = PHContentEditingInputRequestOptions()
        options.isNetworkAccessAllowed = true
        
        asset.requestContentEditingInput(with: options) { (contentEditingInput, info) in
            guard let input = contentEditingInput else {
                completion(nil, NSError(domain: "com.yourapp.error", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve content from PHAsset"]))
                return
            }
            
            let resources = PHAssetResource.assetResources(for: asset)
            let originalFilename = resources.first?.originalFilename ?? UUID().uuidString
            let filenameWithoutExtension = (originalFilename as NSString).deletingPathExtension
            let tempFileURL = self.createTempDirectory().appendingPathComponent(filenameWithoutExtension)
            
            switch asset.mediaType {
            case .image:
                self.handleImageAsset(input: input, filename: tempFileURL, completion: completion)
                
            case .video:
                self.handleVideoAsset(input: input, filename: tempFileURL, completion: completion)
                
            default:
                completion(nil, NSError(domain: "com.yourapp.error", code: -5, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type"]))
            }
        }
    }
    
    // Save photo data to the temporary directory
    func saveCameraPhoto(photoData: Data, completion: @escaping (URL?) -> Void) {
        do {
            let photoURL = createTempDirectory().appendingPathComponent(UUID().uuidString).appendingPathExtension(FileExtension.jpeg.rawValue)
            try photoData.write(to: photoURL)
            completion(photoURL)
        } catch {
            print("Error saving photo: \(error.localizedDescription)")
            completion(nil)
        }
    }
    
    // Private helper method to handle image assets
     func handleImageAsset(input: PHContentEditingInput, filename: URL, completion: @escaping (URL?, Error?) -> Void) {
        guard let url = input.fullSizeImageURL, let ciImage = CIImage(contentsOf: url) else {
            completion(nil, NSError(domain: "com.yourapp.error", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve image from PHAsset"]))
            return
        }
        
        let context = CIContext()
        let jpegData = context.jpegRepresentation(of: ciImage, colorSpace: ciImage.colorSpace!, options: [:])
        let tempFileURL = filename.appendingPathExtension(FileExtension.jpeg.rawValue)
        
        do {
            try jpegData?.write(to: tempFileURL)
            completion(tempFileURL, nil)
        } catch {
            completion(nil, error)
        }
    }
    
    // Private helper method to handle video assets
     func handleVideoAsset(input: PHContentEditingInput, filename: URL, completion: @escaping (URL?, Error?) -> Void) {
        guard let avAsset = input.audiovisualAsset else {
            completion(nil, NSError(domain: "com.yourapp.error", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to retrieve video from PHAsset"]))
            return
        }
        
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
        let tempFileURL = filename.appendingPathExtension(FileExtension.mp4.rawValue)
        
        exportSession?.outputURL = tempFileURL
        exportSession?.outputFileType = .mp4
        exportSession?.exportAsynchronously {
            switch exportSession?.status {
            case .completed:
                completion(tempFileURL, nil)
            case .failed:
                completion(nil, exportSession?.error)
            default:
                completion(nil, NSError(domain: "com.yourapp.error", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to export video from PHAsset"]))
            }
        }
    }
}

// Define supported file extensions
public enum FileExtension: String {
    case jpeg = "jpeg"
    case mp4 = "mp4"
}
