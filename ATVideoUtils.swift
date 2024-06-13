//
//  ATVideoUtils.swift
//  bikewise
//
//  Created by Ling Xu on 2024/5/14.
//  Copyright © 2024 victory. All rights reserved.
//

import Foundation
import AVFoundation

extension AVAsset {
    var atRenderedSize: CGSize? {
        if let track = tracks(withMediaType: .video).first {
            let size = __CGSizeApplyAffineTransform(track.naturalSize, track.preferredTransform)
            return CGSize(width: abs(size.width), height: abs(size.height))
        }
        return nil
    }
}

@objc open class ATVideoProcessResult : NSObject {
    @objc public var asset : AVAsset!
    @objc public var audioMix : AVAudioMix!
}

@objc
open class ATVideoUtils : NSObject {
    @objc public class func getRenderSize(asset:AVAsset) -> CGSize {
        return asset.atRenderedSize ?? CGSizeMake(1080, 1920)
    }
    
    @objc public class func addAudio(filePath:String, toAsset:AVAsset) -> ATVideoProcessResult? {
        let composition = AVMutableComposition()
        let audioMix = AVMutableAudioMix()
        var parameters : [AVAudioMixInputParameters] = []
        
        let fileURL =  URL(fileURLWithPath: filePath)
        let toAddedAsset = AVURLAsset(url:fileURL)
  
        guard let videoCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        guard let audioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        guard let addedAudioCompositionTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        
        guard let assetVideoTrack = toAsset.tracks(withMediaType: .video).first else {
            return nil
        }
        let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: toAsset.duration)
        
    
        do {
           try videoCompositionTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
        } catch {
            return nil
        }
        
        if let assetAudioTrack = toAsset.tracks(withMediaType: .audio).first {
            let param1 = AVMutableAudioMixInputParameters(track: assetAudioTrack)
            param1.setVolume(0.2, at: .zero)
            parameters.append(param1)
            do {
                try audioCompositionTrack.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
            
            } catch {
                return nil
            }
        }
        
        if let toAddAssetAudioTrack = toAddedAsset.tracks(withMediaType: .audio).first {
            let param2 = AVMutableAudioMixInputParameters(track: toAddAssetAudioTrack)
            param2.setVolume(0.8, at: .zero)
            parameters.append(param2)
            do {
                var insertTime : CMTimeValue = 0
                let duration = CMTimeValue(CMTimeGetSeconds(toAsset.duration))
                let newDuration = CMTimeValue(CMTimeGetSeconds(toAddedAsset.duration))
                while insertTime < duration {
                    let start = CMTimeMake(value: insertTime, timescale: 1)
                    let addDuration = min((duration - insertTime),newDuration)
                    try addedAudioCompositionTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: CMTimeMake(value: addDuration, timescale: 1)), of: toAddAssetAudioTrack, at: start)
                    insertTime += addDuration
                }
                
                
            } catch {
                return nil
            }
        }
        
        audioMix.inputParameters = parameters
        videoCompositionTrack.preferredTransform = toAsset.preferredTransform
        
        let result = ATVideoProcessResult()
        result.asset = composition
        result.audioMix = audioMix
        return result
        
    }
    
    
    @objc public class func compressVideo(filePath:String, complete:((_ isSuccess:Bool) -> Void)?) {
        let sourceAsset = AVURLAsset(url: URL(fileURLWithPath: filePath))
        guard let exportSession = AVAssetExportSession(asset: sourceAsset, presetName: AVAssetExportPresetPassthrough) else {
            complete?(false)
            return
        }
//        let composition = AVMutableComposition()
//        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
//            complete?(false)
//            return
//        }
//        guard let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
//            complete?(false)
//            return
//        }
        guard let assetVideoTrack = sourceAsset.tracks(withMediaType: .video).first else {
            complete?(false)
            return
        }
//        guard let assetAudioTrack = sourceAsset.tracks(withMediaType: .audio).first else {
//            complete?(false)
//            return
//        }
//        do {
//            try videoTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: sourceAsset.duration), of: assetVideoTrack, at: CMTime.zero)
//            try audioTrack.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: sourceAsset.duration), of: assetAudioTrack, at: CMTime.zero)
//        } catch {
//            complete?(false)
//            return
//        }
        
        if (assetVideoTrack.nominalFrameRate <= 30 ) {
            complete?(false)
            return
        }
        
    
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        
        let size = __CGSizeApplyAffineTransform(assetVideoTrack.naturalSize, assetVideoTrack.preferredTransform)
        videoComposition.renderSize = CGSize(width: abs(size.width), height: abs(size.height))
//        videoComposition
        let instrution = AVMutableVideoCompositionInstruction()
        instrution.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: sourceAsset.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: assetVideoTrack)
        layerInstruction.setTransform(assetVideoTrack.preferredTransform, at: CMTime.zero)
        instrution.layerInstructions = [layerInstruction]
        
        videoComposition.instructions = [instrution]
        let destFilePath = filePath.replacingOccurrences(of: ".mp4", with: "_updated.mp4")
        exportSession.outputURL = URL(fileURLWithPath: destFilePath)
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = videoComposition
        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                switch exportSession.status {
                case .completed:
                    complete?(true)
                default:
                    complete?(false)
                }
            }
        }
        
    }
    
}
