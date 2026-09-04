# ADC values

On Rockchip RK3566 running Android,  
the SAR-ADC (Successive Approximation Register Analog-to-Digital Converter) is handled  
via the **Linux Industrial I/O (IIO)** subsystem.  
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

## The Industrial I/O (IIO) subsystem

`/sys/bus/iio/devices/iio:device0` is a virtual directory representing a specific hardware sensor  
managed by the Industrial I/O (IIO) subsystem.

The IIO subsystem is designed to handle devices that **output analog-to-digital**  
or **digital-to-analog measurements** - typically sensors  
like accelerometers, gyroscopes, magnetometers, light sensors, pressure sensors, and humidity sensors.

### Key Components of the Directory

When you inspect `/sys/bus/iio/devices/iio:device0` using the `ls` command,  
you will typically find a set of files and subdirectories. Here is what they generally mean:

+ **name**: A file containing the actual name of the driver or chip (e.g., *mpu6050*, *bme280*).  
  Reading this file tells you what physical hardware device0 corresponds to.  
  Example: `cat /sys/bus/iio/devices/iio:device0/name`
+ `in_accel_x_raw` or `in_temp_raw`: Data files representing specific sensor channels.  
  Reading these files triggers a raw measurement read from the hardware.
+ **scale / offset**: Files used to convert raw sensor readings into standard engineering units  
  (like meters per second squared, degrees Celsius, or Pascals).
+ **sampling_frequency**: Allows you to view or configure how many samples per second the sensor takes.
+ `buffer/`: A subdirectory used if you are streaming data continuously from the sensor  
  (often tied to a hardware FIFO buffer or kernel ring buffer).
