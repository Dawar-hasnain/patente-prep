//
//  MotionManager.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 27/11/25.
//

import CoreMotion
import SwiftUI

final class MotionManager {
    static let shared = MotionManager()
    
    private let motion = CMMotionManager()
    private let queue = OperationQueue()
    
    private init() {}
    
    /// Starts device motion updates with a smoothing handler.
    func startUpdates(_ handler: @escaping (_ pitch: Double, _ roll: Double) -> Void) {
        
        // Prevent multiple starts
        guard !motion.isDeviceMotionActive else { return }
        
        // 60 fps updates (best smoothness)
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        
        if motion.isDeviceMotionAvailable {
            motion.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: queue) { data, error in
                guard let attitude = data?.attitude, error == nil else { return }
                
                // Normalize tilt to a soft range
                let pitch = attitude.pitch.clamped(to: -0.4...0.4)
                let roll  = attitude.roll.clamped(to: -0.4...0.4)
                
                DispatchQueue.main.async {
                    handler(pitch, roll)
                }
            }
        }
    }
    
    /// Stops updates (use if needed; not required permanently)
    func stop() {
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
    }
}
