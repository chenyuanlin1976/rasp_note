# android time zone

By default in Android 12 or higher, the framework prioritizes **NTP as the time source over NITZ** because NTP is more accurate and reliable than NITZ.

There are two main time detection origins configured for use by default in AOSP:

+ **Network**: Uses Network Time Protocol (NTP) time servers.
+ **Telephony**: Uses Network Identity and Time Zone (NITZ) telephony signals.

Both telephony and network origins require connectivity to external networks, which are not always available.  
Starting with Android 12, Android also supports the following origins, which are not configured for use by default:

+ **GNSS**: Uses the GPS location provider to obtain a time from a GNSS source.
+ **External**: Generic origin that allows device manufacturers to integrate their own source of Unix epoch time.

## refered website

| Time                                 | [time](https://source.android.com/docs/core/connect/time)                                           |
|--------------------------------------|-----------------------------------------------------------------------------------------------------|
| Location Time Zone Provider (LTZP)   | [location-tz-detection](https://source.android.com/docs/core/connect/time/location-tz-detection)    |
| Network Identity and Time Zone (NITZ)| [telephony-tz-detection](https://source.android.com/docs/core/connect/time/telephony-tz-detection)  |
| Simple Network Time Protocol (SNTP): | [network-time-detection](https://source.android.com/docs/core/connect/time/network-time-detection)  |

## NTP - Network Time Protocol

NTP (Network Time Protocol) itself **does not** "get" or manage time zones.  
NTP's function is to synchronize the system's clock to Coordinated Universal Time (UTC).  
Time zone information, including offsets from UTC and rules for daylight saving time, is **handled by the operating system of the device**.
The operating system then applies the configured local time zone to display the time in a human-readable format, converting it from the UTC time maintained by the system clock.

## time_detector

`adb shell cmd time_detector dump`
> mOriginPriorities=[network,telephony], mAutoDetectionEnabled=true  
> **Telephony** suggestion history: {Empty}  
> **Network** suggestion history: mNtpServerSocketAddress=time.android.com/216.239.35.12:123  
> **Gnss** suggestion history: {Empty}  
> **External** suggestion history: {Empty}

`adb shell cmd time_zone_detector dump`  
`adb shell cmd time_zone_detector is_auto_detection_enabled`  
`adb shell cmd time_zone_detector get_time_zone_state`  

## location-tz-detection

dump the current state: `adb shell cmd location_time_zone_manager dump`  
> LocationTimeZoneManagerService:  
> Primary provider config:  
> getMode()=disabled  
> getPackageName()=  
> Secondary provider config:  
> getMode()=disabled  
> getPackageName()=  
> {Stopped}  

## telephony-tz-detection

`adb shell dumpsys activity service com.android.phone/com.android.phone.TelephonyDebugService`
> NO **Time zone Logs**

## network-time-detection

`adb shell cmd network_time_update_service dump`

## Android coding

```XML
<uses-permission android:name="android.permission.SET_TIME_ZONE"/>
```

```Java
AlarmManager alarmManager = (AlarmManager) getSystemService(Context.ALARM_SERVICE);
alarmManager.setTimeZone("America/New_York"); // Example: Setting to New York time zone
```

## Debug

`adb shell cmd time_zone_detector  get_time_zone_state`  
> TimeZoneState{mZoneId=Pacific/Honolulu, mUserShouldConfirmId=false}

| command                                                            | result |
|--------------------------------------------------------------------|--------|
|`adb shell cmd time_zone_detector is_auto_detection_enabled`        | true   |
|`adb shell cmd time_zone_detector is_telephony_detection_supported` | false  |
|`adb shell cmd time_zone_detector is_geo_detection_supported`       | false  |
|`adb shell cmd time_zone_detector is_geo_detection_enabled`         | false  |

`adb shell cmd time_zone_detector dump_metrics`  
MetricsTimeZoneDetectorState:  
MetricsTimeZoneDetectorState{mConfigurationInternal=ConfigurationInternal{mUserId=0, mUserConfigAllowed=true, mTelephonyDetectionSupported=false, mGeoDetectionSupported=false, mTelephonyFallbackSupported=true, mGeoDetectionRunInBackgroundEnabled=false, mEnhancedMetricsCollectionEnabled=false, mAutoDetectionEnabledSetting=true, mLocationEnabledSetting=true, mGeoDetectionEnabledSetting=false}, mDeviceTimeZoneIdOrdinal=0, mDeviceTimeZoneId=null, mLatestManualSuggestion=null, mLatestTelephonySuggestion=null, mLatestGeolocationSuggestion=null}

## TimeZone: import class from API 36

`String temp = TimeZone.getAvailableIDs();`
