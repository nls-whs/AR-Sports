//
//  VideoPlayer.swift
//  ARSports
//
//  Created by Frederic on 02/01/2020.
//  Copyright © 2020 Frederic. All rights reserved.
//

import Foundation
import AVKit
/// VideoPlayer Class used to display and play a video.
class VideoPlayer: UIViewController {
    var playerController = AVPlayerViewController()
    /// Plays the video.
    func playVideo(videoURL: URL) {
        
        let player = AVPlayer(url: videoURL)
        // Rotate the source video
        let affineTransform = CGAffineTransform(rotationAngle: .pi * 0.5)
        
            player.actionAtItemEnd = AVPlayer.ActionAtItemEnd.none
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: nil,
                                               queue: nil) { [weak self] note in
                                                player.seek(to: CMTime.zero)
                                                player.play()
        }
        let playerLayer = AVPlayerLayer(player: player)
            playerLayer.setAffineTransform(affineTransform)
        // set the siye of the video player
            playerLayer.frame = CGRect(x: 10,y: 90,width: self.view.frame.size.width/3,height: self.view.frame.size.height/3)
        // fancy corner radius to look modern
            playerLayer.cornerRadius = 14
            playerLayer.masksToBounds = true
        self.view.layer.addSublayer(playerLayer)
        player.play()
        
    }
    
    /// Same function as before with a different size
    func playLargerVideo(videoURL: URL) {
        
        let player = AVPlayer(url: videoURL)
        let affineTransform = CGAffineTransform(rotationAngle: .pi * 0.5)
        
        player.actionAtItemEnd = AVPlayer.ActionAtItemEnd.none
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                               object: nil,
                                               queue: nil) { [weak self] note in
                                                player.seek(to: CMTime.zero)
                                                player.play()
        }
        let playerLayer = AVPlayerLayer(player: player)
            playerLayer.setAffineTransform(affineTransform)
            playerLayer.frame = CGRect(x: 0,y: 0,width: self.view.frame.size.width / 1.4 ,height: self.view.frame.size.height / 1.4)
            playerLayer.cornerRadius = 0
            playerLayer.masksToBounds = true
        self.view.layer.addSublayer(playerLayer)
            player.play()
        
        
    }
    /// Stops the video.
    func stopVideo() {
        self.playerController.player!.pause()
    }
    
}
