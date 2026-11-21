# Room coordinate convention

Hue Board reads room and zone membership from the paired Hue Bridge. A Hue Entertainment configuration supplies fixture positions, joined through exact light IDs or unambiguous Entertainment renderer references. Apple Home’s public room API describes associated accessories. Hue Board has no HomeKit coordinate reader. [Apple HMRoom](https://developer.apple.com/documentation/homekit/hmroom)

The archived Philips SDK defines positive X as right, Y as front and Z as up. The Room map puts the front at the top and leaves a 10% inset on each side. A multi-position renderer contributes one centroid. Height has no effect on the floor plan. [Philips SDK coordinate definition](https://github.com/PhilipsHue/HueSDK/blob/39cd6f6fff27969092af72def9384e9bb84f89e4/HueQuickStartApps/HueQuickStartApp-iOS/Dependencies/HueSDK/phone/device/HueSDK.framework/Headers/PHSGroupLightLocation.h#L16-L23)

| Physical point | Hue X, Y, Z | Map X, Y |
| --- | --- | --- |
| Left of center and toward the front | −0.5, 0.75, 0 | 0.30, 0.20 |
| Right of center and toward the back | 0.75, −0.5, 0 | 0.80, 0.70 |
| Above that fixture | 0.75, −0.5, 1 | 0.80, 0.70 |

The published definition is from the legacy SDK. The release qualification compares this convention against a known-direction CLIP v2 Entertainment area on a physical Bridge. Synthetic tests establish projection and preservation only.
