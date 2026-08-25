# Keyboard-specific leader keys

## Question

Can Switchr use a different leader key for each connected keyboard?

## Conclusion

Yes, if the rule is based on **which keyboard is connected**. Switchr can watch keyboard connection and removal events, resolve the applicable profile, and replace its registered Carbon hotkey.

Using a different leader key based on **which physical keyboard produced the key press** is not directly supported by the current Carbon hotkey interface. That version needs a prototype because it must combine two event systems that do not share a documented device identifier.

## What macOS provides

### Connected keyboard discovery

`IOHIDManager` can match keyboard devices and register device connection and removal callbacks. Apple's HID guide shows keyboard matching with the Generic Desktop usage page and Keyboard usage, and documents matching and removal callbacks for hot-plugged devices.[^hid-guide]

A keyboard can expose properties such as product name, transport, vendor ID, product ID, serial number, and location ID. These keys are declared in `IOHIDDeviceKeys.h` in the macOS 26.5 SDK.[^device-keys]

A profile identity should prefer:

1. Serial number, when present.
2. Vendor ID, product ID, and location ID.
3. Vendor ID, product ID, product name, and transport as a weaker fallback.

The fallback cannot distinguish two identical keyboards reliably. A location ID can also change when a USB keyboard moves to another port.

### Physical source of each key

`IOHIDManagerRegisterInputValueCallback` receives values from matching HID devices. `IOHIDValueGetElement` returns the input element, and `IOHIDElementGetDevice` returns the device associated with that element.[^hid-guide][^hid-headers]

This means Switchr can observe which keyboard produced a HID value.

Listening to HID input requires user approval. The macOS 26.5 SDK states that `kIOHIDRequestTypeListenEvent` access is required to receive reports through `IOHIDManager` or `IOHIDDevice`. The system can request this access when the manager or device is opened.[^hid-access]

### Current Carbon hotkey limitation

Switchr currently uses `RegisterEventHotKey`. The documented `kEventHotKeyPressed` payload contains the registered `EventHotKeyID`, but it does not contain a HID device reference or physical keyboard identifier.[^carbon-hotkey]

Core Graphics keyboard events provide a virtual key code and a keyboard-type field, but the documented event fields do not provide a unique physical HID device identifier.[^cg-events]

Therefore, the current hotkey callback cannot directly answer, “Which keyboard produced this hotkey?”

## Feasible designs

### Design A: Profile selected by connected keyboard

This is the recommended first version.

1. Add a `KeyboardDeviceMonitor` that reports connected keyboard identities.
2. Store leader-key profiles against those identities.
3. Add a pure `LeaderKeyResolver` that selects a profile from the connected-device set.
4. Call `HotKeyCenter.replace` when the selected profile changes.
5. Keep the current leader key as the fallback.

This design keeps Carbon's reliable hotkey consumption and fits the current `HotKeyCenter` interface.

The only open platform question is whether connection-only monitoring can avoid Input Monitoring approval on the supported macOS version. A small prototype must verify this. If `IOHIDManagerOpen` requests listen access even without input callbacks, an I/O Registry connection monitor is the next option.

A precedence rule is required when several profiled keyboards are connected. Recommended order:

1. An exact serial-number profile.
2. The most recently connected matching profile.
3. The default profile.

### Design B: Profile selected by the keyboard that produced the leader

This is possible only as an experiment, not as a guaranteed design with the documented interfaces.

A prototype could:

1. Observe HID values to identify the physical keyboard and timestamp.
2. Register all configured hotkeys with Carbon.
3. Correlate the Carbon hotkey callback with the latest HID value.
4. Accept the hotkey only when the profile and device match.

Risks:

- Apple does not document callback ordering between HID and Carbon.
- A hotkey from the wrong keyboard can still be consumed before Switchr rejects it.
- Matching by key and timestamp can fail under load.
- It requires Input Monitoring approval.

Using an event tap does not remove the main problem because documented `CGEvent` fields do not include a unique physical device ID.

Opening keyboards with `kIOHIDOptionsTypeSeizeDevice` provides exclusive access, but Switchr would then have to recreate normal keyboard delivery safely. That is too invasive for this app and is not recommended.[^hid-guide]

## Prototype result

A connection-only prototype opened `IOHIDManager` successfully on macOS 26.5 and identified the built-in keyboard by product name, location ID, transport, and built-in state. Running the same monitor in Switchr did not show a new approval prompt. An external USB or Bluetooth keyboard is still needed to validate connection callbacks and identity stability on real hardware.

## Recommendation

Build and validate **Design A** first. It should answer only these questions:

1. Can Switchr receive keyboard connection and removal events without new approval?
2. Are serial number and location properties stable for the keyboards in use?
3. Does hot-plugging reliably replace the registered leader key?
4. What should happen when two configured keyboards are connected?

Do not implement per-key physical-source routing until the connection-based version is tested and shown to be insufficient.

## Sources

[^hid-guide]: Apple, [Accessing a HID Device](https://developer.apple.com/library/archive/documentation/DeviceDrivers/Conceptual/HID/new_api_10_5/tn2187.html). Documents keyboard matching, device matching/removal callbacks, input-value callbacks, device properties, and exclusive access.
[^device-keys]: Apple macOS 26.5 SDK, `IOKit.framework/Headers/hid/IOHIDDeviceKeys.h`. Declares `kIOHIDTransportKey`, `kIOHIDVendorIDKey`, `kIOHIDProductIDKey`, `kIOHIDProductKey`, `kIOHIDSerialNumberKey`, and `kIOHIDLocationIDKey`.
[^hid-headers]: Apple macOS 26.5 SDK, `IOKit.framework/Headers/hid/IOHIDManager.h`, `IOHIDValue.h`, and `IOHIDElement.h`. Documents `IOHIDManagerRegisterInputValueCallback`, `IOHIDValueGetElement`, and `IOHIDElementGetDevice`.
[^hid-access]: Apple macOS 26.5 SDK, `IOKit.framework/Headers/hid/IOHIDLib.h`. Documents `IOHIDCheckAccess`, `IOHIDRequestAccess`, and `kIOHIDRequestTypeListenEvent`.
[^carbon-hotkey]: Apple macOS 26.5 SDK, `Carbon.framework/Frameworks/HIToolbox.framework/Headers/CarbonEvents.h`. The `kEventHotKeyPressed` event documents only `kEventParamDirectObject` with type `EventHotKeyID`.
[^cg-events]: Apple macOS 26.5 SDK, `CoreGraphics.framework/Headers/CGEventTypes.h`. The documented keyboard fields include `kCGKeyboardEventKeycode` and `kCGKeyboardEventKeyboardType`, but no physical HID device identifier.
