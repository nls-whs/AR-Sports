//
//  VideoRecorder.swift
//  ARSports
//
//  Created by Frederic on 21/12/2019.
//  Copyright © 2019 Frederic. All rights reserved.
//

import Metal
import AVFoundation
/// VideoRecorder Class: Includes functions to create a video from given frames/buffers.
class VideoRecorder {
    var isRecording = false
    
    private var assetWriter: AVAssetWriter
    private var assetWriterVideoInput: AVAssetWriterInput
    private var assetWriterPixelBufferInput: AVAssetWriterInputPixelBufferAdaptor
    
    var currentCaptureMillisecondsTime: Int?
    var currentSampleTime: CMTime?
    
    /// Helper method that returns the current time since unix epoch time.
    func currentTimeInMilliSeconds()-> Int
    {
        let currentDate = Date()
        let unixEpoch = currentDate.timeIntervalSince1970
        return Int(unixEpoch * 1000)
    }
    
    /// Initialize the AVAssetWriter to start recording.
    init?(outputURL url: URL, size: CGSize) {
        
        do {
            assetWriter = try AVAssetWriter(outputURL: url, fileType: .mov)
        } catch {
            return nil
        }
        // Configure the output seetings, use h264 for now
        let outputSettings: [String: Any] = [ AVVideoCodecKey : AVVideoCodecType.h264,
                                              AVVideoWidthKey : size.width,
                                              AVVideoHeightKey : size.height ]
        
        assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        
        // Use 420YpCbCr right now, to lower the filesize, experiment with taking a lower quality format
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String : kCVPixelFormatType_420YpCbCr8PlanarFullRange,
            kCVPixelBufferWidthKey as String : size.width,
            kCVPixelBufferHeightKey as String : size.height ]
        
        assetWriterPixelBufferInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoInput, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
        
        assetWriter.add(assetWriterVideoInput)
        
    }
    
    /// Method to start recording
    func startRecording() {
        // tell the assetWriter to start writing
        let result = assetWriter.startWriting()
        assert(result)
        // Start the session at time 0
        assetWriter.startSession(atSourceTime: CMTime.zero)
        currentCaptureMillisecondsTime = currentTimeInMilliSeconds()
        currentSampleTime = CMTime.zero
        isRecording = true
    }
    
    /// Method to end the recording
    func endRecording(_ completionHandler: @escaping () -> ()) {
        isRecording = false
        // Tell the asserWriter to finish writing, before mark the video as finished.
        assetWriterVideoInput.markAsFinished()
        assetWriter.finishWriting(completionHandler: completionHandler)
    }
    
    /// The write frame function, gets a image (as PixelBuffer) and the time, add them to the video
    /// Timing Explanation: We might call this method between 24/90/120 times per second
    /// So some images will need to be longer in the video as others. If we dont respect the offset
    /// and use the same interval per picture, we get wrong timings and weird video timing
    /// To fix this, we can save the last time we ran the method and calculate the offset interval
    /// General problem fix found at: https://stackoverflow.com/a/58757844
    func writeFrame(forTexture pixelBuffer: CVPixelBuffer, time: TimeInterval) {
        if !isRecording {
            return
        }
        
        while !assetWriterVideoInput.isReadyForMoreMediaData {}
        
        // Lock the Buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        // Organize timing stuff before
        let lastCalledMilliseconds = self.currentCaptureMillisecondsTime!
        let nowTimeMilliseconds = currentTimeInMilliSeconds()
        let millisecondsDifference = nowTimeMilliseconds - lastCalledMilliseconds
        
        // remember when we called this method
        self.currentCaptureMillisecondsTime = nowTimeMilliseconds
        // convert the difference to seconds
        let seconds:Float64 = Double(millisecondsDifference) * 0.001
        
        let sampleTimeOffset = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1000000000)
        
        self.currentSampleTime = CMTimeAdd(currentSampleTime!, sampleTimeOffset)
        
        // Add the image to the video for duration the image was on screen.
        assetWriterPixelBufferInput.append(pixelBuffer, withPresentationTime: currentSampleTime!)
        
        // Unlock the buffer again
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }
}
