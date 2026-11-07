# SunSpec Modbus

**SunSpec Modbus** is an open specification from the SunSpec Alliance.
It defines **standard register maps ("models")** for solar inverters, meters, batteries, and other distributed energy resources (DER).
It uses ordinary Modbus TCP or Modbus RTU ([Modbus_intro.md](Modbus_intro.md), [Modbus_RTU.md](Modbus_RTU.md)).
What it adds is a common layout, so one client can read any compliant device without a vendor-specific register list.

IEEE 1547-2018 (DER interconnection) requires DER to support at least one of a few standard protocols,
and **SunSpec Modbus** is one of them, together with IEEE 2030.5 and IEEE 1815 (DNP3).

## 1. Discovering the models

The SunSpec map is a chain of models in the **holding registers**, starting at a well-known base address:

```text
base + 0..1   "SunS" marker  (0x5375 0x6E53)
base + 2      model ID  = 1   (common model)
base + 3      length L  = 66  (registers that follow)
base + 4..    common model: manufacturer, model, options, version, serial number, device address
              model ID, L, data...   (for example 103 = three-phase inverter)
              model ID, L, data...
              ...
              0xFFFF, 0       end model
```

1. Read 2 registers at offset **40000** (reference 40001). If they aren't `"SunS"`, try offset **50000**, then **0**.
2. Read the model ID and length, read or skip `L` registers, and repeat until the model ID is `0xFFFF`.
3. Use the model definitions to interpret each block.

## 2. Models and points

Each model is a list of **points** with a name, type, size, units, and an optional scale factor.
The definitions are published as JSON in the `sunspec/models` repository. Examples:

| Model | Name | Some points |
| --- | --- | --- |
| 1 | Common | `Mn` manufacturer (16 regs), `Md` model (16), `Opt`, `Vr` version, `SN` serial (16), `DA` device address |
| 101 / 102 / 103 | Inverter, single / split / three phase | `A` current, `PhVphA` voltage, `W` power, `Hz`, `WH` energy, `St` state |
| 120 / 121 / 122 / 123 | Nameplate, basic settings, status, immediate controls | Ratings, limits, on/off, power-limit commands |
| 7xx (701, 702, 705, 711, ...) | DER models (IEEE 1547-2018 functions) | AC measurement, capacity, volt-var, frequency droop, ... |

### 2.1 Scale factors

Measurements are integers with a separate **scale-factor** point (type `sunssf`, a signed power of 10):

```text
value = raw × 10^SF        W = 2345, W_SF = -1   ->  234.5 W
```

Special "not implemented" values: `0x8000` for int16, `0xFFFF` for uint16, `0x80000000` for int32, and so on.
Accumulators (`acc32`, `acc64`, for example `WH`) only count up and wrap around.

## 3. Practical notes

+ Most inverters offer **SunSpec over Modbus TCP** (port 502), and many also over RS-485 RTU.
  The Unit ID / server address is set on the device.
+ Read whole models where possible (≤ 125 registers per request), so related values and their scale factors come from the same moment.
+ Strings are 2 ASCII characters per register, padded with `0x00`.
+ Open-source clients: the `pysunspec2` Python library scans and decodes models from the published JSON definitions.

## Related notes

+ [Modbus_intro.md](Modbus_intro.md), [Modbus_RTU.md](Modbus_RTU.md), [IoT_Network.md](IoT_Network.md)

## Reference

+ [SunSpec model definitions (GitHub: sunspec/models)](https://github.com/sunspec/models)
+ [pysunspec2](https://github.com/sunspec/pysunspec2)
+ [SunSpec Alliance](https://sunspec.org/)
