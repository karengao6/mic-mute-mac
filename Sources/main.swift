// The Swift Programming Language
// https://docs.swift.org/swift-book

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


// find and print the current default input device
let deviceID = getDefaultInputDevice()

// get the human-readable name of the audio device
var name: CFString = "" as CFString

var nameAddress = AudioObjectPropertyAddress(
    mSelector: kAudioObjectPropertyName,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
)

var nameSize = UInt32(MemoryLayout<CFString?>.size)

let nameStatus = withUnsafeMutablePointer(to: &name) { pointer in
    AudioObjectGetPropertyData(
        deviceID,
        &nameAddress,
        0,
        nil,
        &nameSize,
        pointer
    )
}

if nameStatus == noErr {
    print("Default input device: \(name)")
} else {
    print("Could not get device name.")
}

print("Device ID: \(deviceID)")