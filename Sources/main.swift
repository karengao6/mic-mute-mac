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


// Find and print the current default input device.
let deviceID = getDefaultInputDevice()

print("Default input device ID: \(deviceID)")