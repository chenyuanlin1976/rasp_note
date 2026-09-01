# ADC values

On Rockchip RK3566 running Android,  
the SAR-ADC (Successive Approximation Register Analog-to-Digital Converter) is handled via the Linux Industrial I/O (IIO) subsystem.  
You can easily read raw ADC values directly from user space using ADB shell commands without writing any custom applications.

1. Open an ADB Shell:  
   Connect your device and open a terminal window on your computer: `adb shell`
2. Locate the IIO Device Directory:  
   Rockchip's SAR-ADC registers as an IIO device under `/sys/bus/iio/devices/`.  
   Navigate to the device folder to check available channels:  
   `cd /sys/bus/iio/devices/iio:device0; ls`
3. Read Specific ADC Channels:  
   The RK3566 SAR-ADC typically supports up to 6 single-ended channels (in_voltage0 through in_voltage5).  
   You can read the raw digital value of a specific channel using cat:  
   To read Channel 0: `cat in_voltage0_raw`
4. Convert Raw Values to Voltage:  
   The RK3566 SAR-ADC has a 10-bit resolution 2**10 - 1 = **1023**  
   and standard reference voltage V_ref of typically 1.8V (though some boards or channels may vary).  
   Calculate the real-world voltage using this formula:  
   **Voltage (mV) = V_ref x Raw_Value / 1023**
