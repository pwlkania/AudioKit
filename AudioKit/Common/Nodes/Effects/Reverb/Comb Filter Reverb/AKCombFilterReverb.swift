//
//  AKCombFilterReverb.swift
//  AudioKit
//
//  Created by Aurelius Prochazka, revision history on Github.
//  Copyright (c) 2016 Aurelius Prochazka. All rights reserved.
//

import AVFoundation

/// This filter reiterates input with an echo density determined by
/// loopDuration. The attenuation rate is independent and is determined by
/// reverbDuration, the reverberation duration (defined as the time in seconds
/// for a signal to decay to 1/1000, or 60dB down from its original amplitude).
/// Output from a comb filter will appear only after loopDuration seconds.
///
/// - Parameters:
///   - input: Input node to process
///   - reverbDuration: The time in seconds for a signal to decay to 1/1000, or 60dB from its original amplitude. (aka RT-60).
///   - loopDuration: The loop time of the filter, in seconds. This can also be thought of as the delay time. Determines frequency response curve, loopDuration * sr/2 peaks spaced evenly between 0 and sr/2.
///
open class AKCombFilterReverb: AKNode, AKToggleable {

    // MARK: - Properties

    internal var internalAU: AKCombFilterReverbAudioUnit?
    internal var token: AUParameterObserverToken?

    fileprivate var reverbDurationParameter: AUParameter?

    /// Ramp Time represents the speed at which parameters are allowed to change
    open var rampTime: Double = AKSettings.rampTime {
        willSet {
            if rampTime != newValue {
                internalAU?.rampTime = newValue
                internalAU?.setUpParameterRamp()
            }
        }
    }

    /// The time in seconds for a signal to decay to 1/1000, or 60dB from its original amplitude. (aka RT-60).
    open var reverbDuration: Double = 1.0 {
        willSet {
            if reverbDuration != newValue {
                if internalAU!.isSetUp() {
                    reverbDurationParameter?.setValue(Float(newValue), originator: token!)
                } else {
                    internalAU?.reverbDuration = Float(newValue)
                }
            }
        }
    }

    /// Tells whether the node is processing (ie. started, playing, or active)
    open var isStarted: Bool {
        return internalAU!.isPlaying()
    }

    // MARK: - Initialization

    /// Initialize this filter node
    ///
    /// - Parameters:
    ///   - input: Input node to process
    ///   - reverbDuration: The time in seconds for a signal to decay to 1/1000, or 60dB from its original amplitude. (aka RT-60).
    ///   - loopDuration: The loop time of the filter, in seconds. This can also be thought of as the delay time. Determines frequency response curve, loopDuration * sr/2 peaks spaced evenly between 0 and sr/2.
    ///
    public init(
        _ input: AKNode,
        reverbDuration: Double = 1.0,
        loopDuration: Double = 0.1) {

        self.reverbDuration = reverbDuration

        var description = AudioComponentDescription()
        description.componentType         = kAudioUnitType_Effect
        description.componentSubType      = fourCC("comb")
        description.componentManufacturer = fourCC("AuKt")
        description.componentFlags        = 0
        description.componentFlagsMask    = 0

        AUAudioUnit.registerSubclass(
            AKCombFilterReverbAudioUnit.self,
            as: description,
            name: "Local AKCombFilterReverb",
            version: UInt32.max)

        super.init()
        AVAudioUnit.instantiate(with: description, options: []) {
            avAudioUnit, error in

            guard let avAudioUnitEffect = avAudioUnit else { return }

            self.avAudioNode = avAudioUnitEffect
            self.internalAU = avAudioUnitEffect.auAudioUnit as? AKCombFilterReverbAudioUnit

            AudioKit.engine.attach(self.avAudioNode)
            input.addConnectionPoint(self)
            self.internalAU!.setLoopDuration(Float(loopDuration))
        }

        guard let tree = internalAU?.parameterTree else { return }

        reverbDurationParameter = tree.value(forKey: "reverbDuration") as? AUParameter

        token = tree.token (byAddingParameterObserver: {
            address, value in

            DispatchQueue.main.async {
                if address == self.reverbDurationParameter!.address {
                    self.reverbDuration = Double(value)
                }
            }
        })

        internalAU?.reverbDuration = Float(reverbDuration)
    }

    // MARK: - Control

    /// Function to start, play, or activate the node, all do the same thing
    open func start() {
        self.internalAU!.start()
    }

    /// Function to stop or bypass the node, both are equivalent
    open func stop() {
        self.internalAU!.stop()
    }
}
