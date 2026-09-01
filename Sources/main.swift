import Foundation
import CoreAudio
import CoreGraphics
import AppKit

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

final class MicrophoneVolumeManager {

    // the mic volume before setting to 0
    private var savedVolume: Float32?

    // whether the current 0% volume was set by this program (could have already been at 0)
    private(set) var isVolumeZeroed = false


    // toggles between: normal -> 0 and 0 -> previously saved volume
    func toggle() {

        let deviceID = getDefaultInputDevice()

        // restore the saved volume
        if isVolumeZeroed {

            guard let savedVolume else {
                print("ERROR: No saved microphone volume.")
                return
            }

            print(
                String(
                    format: "Restoring input volume to %.1f%%...",
                    savedVolume * 100
                )
            )

            let success = setInputVolume(
                deviceID: deviceID,
                volume: savedVolume
            )

            guard success else {
                print("Failed to restore input volume.")
                return
            }

            // the mic is no longer zeroed, update
            self.savedVolume = nil
            self.isVolumeZeroed = false

            print("Microphone volume restored.")

            return
        }

        // save the current volume and set it to 0
        guard let currentVolume = getInputVolume(
            deviceID: deviceID
        ) else {
            print("Could not read current input volume.")
            return
        }

        // save the exact value to restore later
        savedVolume = currentVolume

        print(
            String(
                format: "Saving current volume: %.1f%%",
                currentVolume * 100
            )
        )

        let success = setInputVolume(
            deviceID: deviceID,
            volume: 0.0
        )

        guard success else {
            print("Failed to set input volume to 0%.")
            savedVolume = nil
            return
        }

        isVolumeZeroed = true

        print("Microphone volume set to 0%.")
    }
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
// print("Setting input volume to 0%...")

// let success = setInputVolume(
//     deviceID: deviceID,
//     volume: 0.0
// )

// guard success else {
//     print("Failed to change input volume.")
//     exit(1)
// }

// // read input volume again to confirm change
// guard let newVolume = getInputVolume(
//     deviceID: deviceID
// ) else {

//     print("Volume was changed, but could not be read back.")
//     exit(1)
// }

// print(
//     String(
//         format: "New input volume: %.1f%%",
//         newVolume * 100
//     )
// )

// print()
// print("Done.")

// let microphone = MicrophoneVolumeManager()

// print("Testing microphone volume toggle.")
// print()
// print("Press ENTER to set the microphone to 0%.")

// _ = readLine()

// microphone.toggle()

// print()
// print("Press ENTER to restore the previous volume.")

// _ = readLine()

// microphone.toggle()

// print()
// print("Done.")

// mic manager is still created here, but we're not calling toggle() yet
// keyboard handling will be connected to it in a later step
let microphone = MicrophoneVolumeManager()

print("MicVolumeKey starting...")

// ============================================================
// MARK: - Keyboard Event Diagnostic
// ============================================================

// kCGEventSystemDefined = 14.
//
// We use the raw value because Swift's CGEventType does not
// expose this event type as `.systemDefined` in this SDK.
// Normal keyboard press/release events.
// We only need keyDown.
//
// We don't want the microphone to toggle twice when the key
// is pressed and then released.
let eventMask =
    CGEventMask(1) << CGEventType.keyDown.rawValue


// This callback receives system-defined events.
let callback: CGEventTapCallBack = {
    proxy,
    type,
    event,
    userInfo in

    // We only asked for keyDown events, but keep this check
    // for safety.
    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(
    .keyboardEventKeycode
    )

// Ignore auto-repeat events.
//
// A single physical press of the Dictation key can produce
// multiple keyDown events. The first one has autorepeat = 0;
// subsequent repeated events have autorepeat = 1.
let isAutoRepeat = event.getIntegerValueField(
    .keyboardEventAutorepeat
) != 0

if keyCode == 176 {

    let flags = event.flags.rawValue

    // A single physical Dictation-key press produces two
    // keyDown events on this Mac.
    //
    // The first event:
    //     flags = 0x00800100
    //
    // The second event:
    //     flags = 0xE0800000
    //
    // We only want to respond to the first event.
    //
    // For now, use the observed flag value to distinguish it.
    let isFirstDictationEvent = flags == 0x00800100

    if isFirstDictationEvent {
        print("Dictation key pressed.")
        microphone.toggle()
    }
}
// Return the event unchanged for now.
// This means macOS still receives the Dictation key.
return Unmanaged.passUnretained(event)
}
// ============================================================
// MARK: - Create Event Tap
// ============================================================

guard let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: eventMask,
    callback: callback,
    userInfo: nil
) else {

    print("""
    
    ERROR: Could not create keyboard event tap.
    
    Make sure Terminal has permission under:
    
        System Settings
        → Privacy & Security
        → Accessibility
    
    and, if necessary:
    
        System Settings
        → Privacy & Security
        → Input Monitoring
    
    After changing permissions, completely quit Terminal
    and reopen it.
    
    """)

    exit(1)
}


// Create a RunLoop source for the event tap.
guard let runLoopSource = CFMachPortCreateRunLoopSource(
    kCFAllocatorDefault,
    eventTap,
    0
) else {

    print("ERROR: Could not create event tap RunLoop source.")
    exit(1)
}


// Attach the event tap to the RunLoop.
CFRunLoopAddSource(
    CFRunLoopGetCurrent(),
    runLoopSource,
    .commonModes
)


// Enable the event tap.
CGEvent.tapEnable(
    tap: eventTap,
    enable: true
)


// ============================================================
// MARK: - Start Monitoring
// ============================================================

print("""
    
============================================================
Keyboard event monitor running.

Press the physical 🎙️ Dictation key.

The program is ONLY observing the event.
It will NOT change your microphone volume yet.

Press Ctrl+C to quit.
============================================================
""")


// Keep the program alive.
CFRunLoopRun()