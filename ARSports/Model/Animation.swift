//
//  Animation.swift
//  ARSports
//
//  Created by Frederic on 21/11/2019.
//  Copyright © 2019 Frederic. All rights reserved.
//

import Foundation
import ARKit
import RealityKit

/// Animation Class: Defines an object that contains elements of an recorded excercise.
/// This class is used to store a recorded excercise in CoreData
public class Animation : NSObject, NSCoding {
    
    public func encode(with coder: NSCoder) {
        coder.encode(title, forKey: Keys.title.rawValue)
        coder.encode(frames, forKey: Keys.frames.rawValue)
        coder.encode(keyframes, forKey: Keys.keyframes.rawValue)
        coder.encode(rootBasedPositions, forKey: Keys.rootPosition.rawValue)
    }
    
    required convenience public init?(coder: NSCoder) {
        let title = coder.decodeObject(forKey: Keys.title.rawValue) as! String
        let frames = coder.decodeObject(forKey: Keys.frames.rawValue) as! Array<[QuatfContainer]>
        let keyframes = coder.decodeObject(forKey: Keys.keyframes.rawValue) as! Array<[QuatfContainer]>
        let rootBasedPositions = coder.decodeObject(forKey: Keys.rootPosition.rawValue) as! Array<[Simd4x4Container]>

        self.init(title: title, frames: frames, keyframes: keyframes, rootBasedPositions: rootBasedPositions)
    }
    
    enum Keys: String {
      case title = "title"
      case frames = "frames"
      case keyframes = "keyframes"
      case rootPosition = "rootBasedPositions"
    }
    
    var frames: Array<[QuatfContainer]>? // the whole animation
    var keyframes: Array<[QuatfContainer]>? // a filtered version with keyframes
    var rootBasedPositions: Array<[Simd4x4Container]>? // a filtered version with keyframes
    var title: String?
    
    init(frames: Array<[QuatfContainer]>, rootBasedPositions: Array<[Simd4x4Container]>){
        self.frames = frames
        self.rootBasedPositions = rootBasedPositions
    }
    
    init(title: String, frames: Array<[QuatfContainer]>, keyframes: Array<[QuatfContainer]>, rootBasedPositions: Array<[Simd4x4Container]>){
        self.frames = frames
        self.title = title
        self.keyframes = keyframes
        self.rootBasedPositions = rootBasedPositions
    }
    
    init(title: String){
        self.title = title
        self.frames = []
    }
    
    func setKeyframe(position: Int, rotations: [QuatfContainer]){
        keyframes?.insert(rotations, at: position)
    }
    
    func printAnimationInformation(){
        print("Current Frames in Animation: \(frames?.count)")
    }
}
