//
//  ThumbnailCell.swift
//  ARSports
//
//  Created by Frederic on 23/11/2019.
//  Copyright © 2019 Frederic. All rights reserved.
//

import Foundation
import UIKit

class ThumbnailCell: UICollectionViewCell {
    
    @IBOutlet weak var image: UIImageView!
    
    @IBOutlet weak var name: UILabel!
    
    func updateImage(){
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let docURL = URL(string: documentsDirectory)!
        let dataPath = docURL.appendingPathComponent(name.text!)
        
        if try FileManager.default.fileExists(atPath: dataPath.absoluteString){
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: dataPath, includingPropertiesForKeys: nil)
                let covers = directoryContents.filter{ $0.deletingPathExtension().lastPathComponent == "cover" }
                if covers.count > 0 {
                    do {
                        let imageData = try Data(contentsOf: covers.first!)
                        image.image = UIImage(data: imageData)
                        image.sizeToFit()
                    } catch {
                        print("Error loading image : \(error)")
                    }
                    
                }
            } catch {
            }
        }else{
            return
        }
        
    }
}
