import Foundation
import AVFoundation
import AudioToolbox
import MediaToolbox
import CoreMedia

// MARK: - NBandEQ constants
//
// Numeric values from AudioToolbox (AUComponent.h / AudioUnitParameters.h /
// AudioUnitProperties.h), defined locally so this file does not depend on
// the SDK exposing every kAUNBandEQ* symbol to Swift.

private enum NBandEQ {
    static let subType: OSType = 0x6E62_6571 // 'nbeq' — kAudioUnitSubType_NBandEQ

    // Per-band parameter IDs: base + band index.
    static let paramGlobalGain: AudioUnitParameterID = 0     // kAUNBandEQParam_GlobalGain
    static let paramBypassBand: AudioUnitParameterID = 1000  // kAUNBandEQParam_BypassBand
    static let paramFilterType: AudioUnitParameterID = 2000  // kAUNBandEQParam_FilterType
    static let paramFrequency: AudioUnitParameterID = 3000   // kAUNBandEQParam_Frequency
    static let paramGain: AudioUnitParameterID = 4000        // kAUNBandEQParam_Gain
    static let paramBandwidth: AudioUnitParameterID = 5000   // kAUNBandEQParam_Bandwidth

    static let numberOfBandsProperty: AudioUnitPropertyID = 2200 // kAUNBandEQProperty_NumberOfBands
}

// MARK: - Settings bridge

/// Thread-safe bridge between the main-actor EqualizerManager and the audio
/// pipeline. Holds the latest snapshot and the set of live NBandEQ units so
/// settings changes apply to the currently playing track immediately
/// (AudioUnitSetParameter is safe to call from any thread).
final class EQSettingsBridge: @unchecked Sendable {
    static let shared = EQSettingsBridge()

    private let lock = NSLock()
    private var snapshot = EQSnapshot(enabled: false, preamp: 0, bands: [])
    private var liveUnits: [AudioUnit] = []

    func update(_ newSnapshot: EQSnapshot) {
        lock.lock()
        snapshot = newSnapshot
        let units = liveUnits
        lock.unlock()

        for unit in units {
            Self.apply(newSnapshot, to: unit)
        }
    }

    func register(_ unit: AudioUnit) {
        lock.lock()
        liveUnits.append(unit)
        let current = snapshot
        lock.unlock()

        Self.apply(current, to: unit)
    }

    func unregister(_ unit: AudioUnit) {
        lock.lock()
        liveUnits.removeAll { $0 == unit }
        lock.unlock()
    }

    private static func apply(_ snapshot: EQSnapshot, to unit: AudioUnit) {
        let preamp: Float = snapshot.enabled ? snapshot.preamp : 0
        AudioUnitSetParameter(unit, NBandEQ.paramGlobalGain, kAudioUnitScope_Global, 0, preamp, 0)

        for band in 0..<EQSnapshot.maxBands {
            let element = AudioUnitElement(0)
            let offset = AudioUnitParameterID(band)

            if snapshot.enabled, band < snapshot.bands.count {
                let values = snapshot.bands[band]
                AudioUnitSetParameter(unit, NBandEQ.paramFilterType + offset, kAudioUnitScope_Global, element, values.filterType, 0)
                AudioUnitSetParameter(unit, NBandEQ.paramFrequency + offset, kAudioUnitScope_Global, element, values.frequency, 0)
                AudioUnitSetParameter(unit, NBandEQ.paramBandwidth + offset, kAudioUnitScope_Global, element, values.bandwidth, 0)
                AudioUnitSetParameter(unit, NBandEQ.paramGain + offset, kAudioUnitScope_Global, element, values.gain, 0)
                AudioUnitSetParameter(unit, NBandEQ.paramBypassBand + offset, kAudioUnitScope_Global, element, 0, 0)
            } else {
                AudioUnitSetParameter(unit, NBandEQ.paramBypassBand + offset, kAudioUnitScope_Global, element, 1, 0)
            }
        }
    }
}

// MARK: - Tap context

/// Per-tap state. Accessed from MediaToolbox's tap callbacks; lifetime is
/// managed via the tap's storage pointer (retained at creation, released in
/// the finalize callback).
private final class EQTapContext: @unchecked Sendable {
    var audioUnit: AudioUnit?
    var sampleTime: Float64 = 0
}

// MARK: - Audio mix factory

enum EQAudioTap {
    /// Builds an AVAudioMix whose tap routes the item's audio through Apple's
    /// built-in N-band parametric EQ. Returns nil when the asset has no
    /// addressable audio track (e.g. HLS streams) — playback then continues
    /// without EQ rather than failing.
    static func makeAudioMix(for asset: AVURLAsset) async -> AVAudioMix? {
        guard let assetTrack = try? await asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }

        let context = EQTapContext()
        let clientInfo = UnsafeMutableRawPointer(Unmanaged.passRetained(context).toOpaque())

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: clientInfo,
            init: eqTapInit,
            finalize: eqTapFinalize,
            prepare: eqTapPrepare,
            unprepare: eqTapUnprepare,
            process: eqTapProcess
        )

        var tapOut: Unmanaged<MTAudioProcessingTap>?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tapOut
        )

        guard status == noErr, let tap = tapOut?.takeRetainedValue() else {
            Unmanaged<EQTapContext>.fromOpaque(clientInfo).release()
            return nil
        }

        let inputParameters = AVMutableAudioMixInputParameters(track: assetTrack)
        inputParameters.audioTapProcessor = tap

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [inputParameters]
        return audioMix
    }
}

// MARK: - Tap callbacks (C conventions, no captures)

private func eqTapInit(
    tap: MTAudioProcessingTap,
    clientInfo: UnsafeMutableRawPointer?,
    tapStorageOut: UnsafeMutablePointer<UnsafeMutableRawPointer?>
) {
    tapStorageOut.pointee = clientInfo
}

private func eqTapFinalize(tap: MTAudioProcessingTap) {
    Unmanaged<EQTapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).release()
}

private func eqTapPrepare(
    tap: MTAudioProcessingTap,
    maxFrames: CMItemCount,
    processingFormat: UnsafePointer<AudioStreamBasicDescription>
) {
    let context = Unmanaged<EQTapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()

    var description = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: NBandEQ.subType,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    guard let component = AudioComponentFindNext(nil, &description) else { return }

    var instance: AudioUnit?
    guard AudioComponentInstanceNew(component, &instance) == noErr, let unit = instance else { return }

    var format = processingFormat.pointee
    let formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format, formatSize)
    AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &format, formatSize)

    var bandCount = UInt32(EQSnapshot.maxBands)
    AudioUnitSetProperty(unit, NBandEQ.numberOfBandsProperty, kAudioUnitScope_Global, 0, &bandCount, UInt32(MemoryLayout<UInt32>.size))

    var maxFramesPerSlice = UInt32(maxFrames)
    AudioUnitSetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFramesPerSlice, UInt32(MemoryLayout<UInt32>.size))

    // The EQ pulls its input from the tap's source audio.
    var renderCallback = AURenderCallbackStruct(
        inputProc: eqTapRenderInput,
        inputProcRefCon: UnsafeMutableRawPointer(Unmanaged.passUnretained(tap).toOpaque())
    )
    AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &renderCallback, UInt32(MemoryLayout<AURenderCallbackStruct>.size))

    guard AudioUnitInitialize(unit) == noErr else {
        AudioComponentInstanceDispose(unit)
        return
    }

    context.audioUnit = unit
    context.sampleTime = 0
    EQSettingsBridge.shared.register(unit)
}

private func eqTapUnprepare(tap: MTAudioProcessingTap) {
    let context = Unmanaged<EQTapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()
    if let unit = context.audioUnit {
        EQSettingsBridge.shared.unregister(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        context.audioUnit = nil
    }
}

private func eqTapProcess(
    tap: MTAudioProcessingTap,
    numberFrames: CMItemCount,
    flags: MTAudioProcessingTapFlags,
    bufferListInOut: UnsafeMutablePointer<AudioBufferList>,
    numberFramesOut: UnsafeMutablePointer<CMItemCount>,
    flagsOut: UnsafeMutablePointer<MTAudioProcessingTapFlags>
) {
    let context = Unmanaged<EQTapContext>.fromOpaque(MTAudioProcessingTapGetStorage(tap)).takeUnretainedValue()

    guard let unit = context.audioUnit else {
        // No EQ unit (creation failed): pass source audio straight through.
        _ = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
        return
    }

    var timeStamp = AudioTimeStamp()
    timeStamp.mSampleTime = context.sampleTime
    timeStamp.mFlags = .sampleTimeValid

    var actionFlags = AudioUnitRenderActionFlags(rawValue: 0)
    let status = AudioUnitRender(unit, &actionFlags, &timeStamp, 0, UInt32(numberFrames), bufferListInOut)

    if status != noErr {
        _ = MTAudioProcessingTapGetSourceAudio(tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
        return
    }

    context.sampleTime += Float64(numberFrames)
    numberFramesOut.pointee = numberFrames
}

private func eqTapRenderInput(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    guard let ioData else { return kAudio_ParamError }
    let tap = Unmanaged<MTAudioProcessingTap>.fromOpaque(inRefCon).takeUnretainedValue()
    return MTAudioProcessingTapGetSourceAudio(tap, CMItemCount(inNumberFrames), ioData, nil, nil, nil)
}
