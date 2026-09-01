import Foundation
import CoreAudio

// Gets the audio device that macOS currently considers the default input device.
// This is normally MacBook's built-in mic, unless you selected another mic.
func getDefaultInputDevice() -> AudioDeviceID {
    var deviceID = AudioDeviceID(0)

    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var size = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size,
        &deviceID
    )

    guard status == noErr else {
        print("Failed to get default input device.")
        print("OSStatus: \(status)")
        exit(1)
    }

    return deviceID
}


// get the human-readable name of the audio device
func getDeviceName(deviceID: AudioDeviceID) -> String {

    var name: Unmanaged<CFString>?

    var address = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

    let status = withUnsafeMutablePointer(to: &name) { pointer in
        AudioObjectGetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            &size,
            pointer
        )
    }

    guard status == noErr, let name else {
        return "Unknown"
    }

    return name.takeUnretainedValue() as String
}


// Reads the input volume for a particular channel.
// Core Audio represents scalar volume as:
//     0.0 → 0%
//     0.5 → 50%
//     1.0 → 100%
//
// Channel 0 represents the device's master input volume when the device provides one.
func getInputVolume(deviceID: AudioDeviceID) -> Float32? {

    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,

        // scope is only input volume (not output)
        mScope: kAudioObjectPropertyScopeInput,

        // Channel 0 = master channel
        mElement: kAudioObjectPropertyElementMain
    )

    var volume = Float32(0)
    var size = UInt32(MemoryLayout<Float32>.size)

    let status = AudioObjectGetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        &size,
        &volume
    )

    guard status == noErr else {
        print("Failed to read input volume.")
        print("OSStatus: \(status)")
        return nil
    }

    return volume
}

// set the master input volume to 0
func setInputVolume(deviceID: AudioDeviceID,volume: Float32) -> Bool {

    var address = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyVolumeScalar,
        mScope: kAudioObjectPropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
    )

    // make sure the value stays between 0 and 1
    var newVolume = min(max(volume, 0.0),1.0)

    let size = UInt32(
        MemoryLayout<Float32>.size
    )

    let status = AudioObjectSetPropertyData(
        deviceID,
        &address,
        0,
        nil,
        size,
        &newVolume
    )

    guard status == noErr else {

        print("Failed to set input volume.")
        print("OSStatus: \(status)")

        return false
    }

    return true
}


// main
let deviceID = getDefaultInputDevice()

let deviceName = getDeviceName(
    deviceID: deviceID
)

print("Default input device: \(deviceName)")
print("Device ID: \(deviceID)")

if let volume = getInputVolume(
    deviceID: deviceID
) {

    let percentage = volume * 100

    print(
        String(
            format: "Input volume: %.1f%%",
            percentage
        )
    )

} else {

    print("Could not read input volume.")
}

// set volume to 0
print("Setting input volume to 0%...")

let success = setInputVolume(
    deviceID: deviceID,
    volume: 0.0
)

guard success else {
    print("Failed to change input volume.")
    exit(1)
}

// read input volume again to confirm change
guard let newVolume = getInputVolume(
    deviceID: deviceID
) else {

    print("Volume was changed, but could not be read back.")
    exit(1)
}

print(
    String(
        format: "New input volume: %.1f%%",
        newVolume * 100
    )
)

print()
print("Done.")