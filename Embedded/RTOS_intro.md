# RTOS (Real-Time Operating System)

An RTOS is an operating system whose main goal is **predictable timing**: a task or interrupt handler must react within a known,
bounded worst-case time (its **deadline**). Most RTOSes used in hobby and product work are small kernels that run on microcontrollers
(FreeRTOS, Zephyr), but larger real-time systems exist too (QNX, VxWorks, Linux with PREEMPT_RT).

"Real-time" does not mean "fast". It means the **worst case** is known and short enough. A system that usually answers in 1 µs but sometimes in 50 ms is not real-time;
one that always answers within 100 µs can be.

## 1. Real-time basics

| Kind | Missing a deadline | Example |
| --- | --- | --- |
| Hard real-time | Is a system failure | Airbag trigger, motor commutation, brake control |
| Firm real-time | Makes that result useless, but the system continues | A dropped video frame or a late sensor sample that is discarded |
| Soft real-time | Lowers quality | Audio glitch, laggy UI |

+ **Latency**: time from an event (interrupt, message) until the code that handles it runs.
+ **Jitter**: how much that latency varies. An RTOS keeps both small and bounded.
+ The guarantee comes from the whole design (hardware, interrupt priorities, task priorities, how long code holds locks), not from the RTOS alone.

## 2. Bare metal vs RTOS vs general-purpose OS

| | Bare metal (super loop) | RTOS | General-purpose OS (Linux, Windows) |
| --- | --- | --- | --- |
| Structure | One `while (1)` loop plus interrupt handlers | Several tasks with priorities | Processes and threads, virtual memory |
| Scheduling | You decide the order in the loop | Preemptive, priority-based, deterministic | Optimized for fairness and throughput |
| Typical latency | Very low, but grows as the loop grows | Microseconds, bounded | Usually low, worst case not guaranteed (PREEMPT_RT improves it) |
| Memory | KB | KB to hundreds of KB | MB to GB, needs an MMU |
| Good for | Simple devices, one main job | Several concurrent jobs with timing needs | Rich applications, networking, files, UI |

PREEMPT_RT, which makes most of the Linux kernel preemptible, was merged into mainline Linux in 6.12 (2024).
It reduces worst-case latency but Linux still isn't used for the hardest deadlines; those often go to a separate microcontroller or core running an RTOS.

## 3. Core concepts

**Tasks** (threads): each task is a function with its own stack, usually an endless loop. For example, one task reads a sensor, one updates a display, one handles Wi-Fi.

```text
              vTaskResume()               scheduler selects it
  Suspended ─────────────────▶ Ready ──────────────────────────▶ Running
      ▲                          ▲   ◀──────────────────────────    │
      │ vTaskSuspend()           │      preempted or yields         │ waits for a delay,
      │ (from any state)         │                                  │ queue, or semaphore
                                 └──── event or timeout ──── Blocked ◀┘
```

+ **Scheduler**: always runs the highest-priority **ready** task. Tasks of equal priority can share the CPU in time slices (round-robin).
+ **Preemption**: when a higher-priority task becomes ready (for example an interrupt gives it a semaphore), it runs immediately instead of waiting for the current task to yield.
+ **Tick**: a periodic timer interrupt (often 1 ms) used for delays, timeouts, and time slicing. Tickless idle stops it during sleep to save power.
+ **Blocking**: a task waiting for a delay, queue, or semaphore uses no CPU. This is why an RTOS doesn't "freeze" when one part waits for Wi-Fi:
  the waiting task is blocked and the others keep running.

**Communication and synchronization**:

| Object | Use |
| --- | --- |
| Queue | Pass data (copies of messages) between tasks, or from an ISR to a task |
| Binary semaphore / task notification | Signal an event, e.g. ISR → task ("data ready") |
| Counting semaphore | Count events or available resources |
| Mutex | Protect a shared resource (I2C bus, UART, global struct). Supports **priority inheritance** |
| Event group | Wait for one or several flags |
| Software timer | Run a callback after a delay or periodically, without a dedicated task |

**Interrupts**: keep ISRs short. Do the minimum, then wake a task with an ISR-safe call (in FreeRTOS the `...FromISR()` functions) and do the real work there ("deferred interrupt processing").

## 4. Common problems

+ **Priority inversion**: a high-priority task waits for a mutex held by a low-priority task, which is preempted by a medium-priority task.
  The high-priority task now waits for the medium one. Fix: use a mutex with priority inheritance (not a plain binary semaphore) for shared resources.
+ **Deadlock**: two tasks each hold one lock and wait for the other's. Always take locks in the same order, and use timeouts.
+ **Stack overflow**: every task has its own fixed-size stack. Enable stack overflow checking and measure the high-water mark (FreeRTOS: `uxTaskGetStackHighWaterMark()`).
+ **Starvation**: a high-priority task that never blocks (busy-waits) stops all lower-priority tasks. Every task should block somewhere.
+ **Calling blocking APIs from an ISR**: not allowed. Use the ISR-safe variants.
+ **Shared data without protection**: tasks and ISRs can interrupt each other at any point. Use a mutex, a queue, or a critical section.

## 5. Example: FreeRTOS producer and consumer

Two tasks with different priorities exchange data through a queue:

```c
#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"

static QueueHandle_t q;

static void producer_task(void *arg)
{
    (void)arg;
    uint32_t n = 0;

    for (;;) {
        xQueueSend(q, &n, portMAX_DELAY);    /* blocks while the queue is full */
        n++;
        vTaskDelay(pdMS_TO_TICKS(100));      /* blocked for 100 ms, other tasks run */
    }
}

static void consumer_task(void *arg)
{
    (void)arg;
    uint32_t value;

    for (;;) {
        if (xQueueReceive(q, &value, portMAX_DELAY) == pdPASS)   /* blocks until data arrives */
            printf("received %lu\n", (unsigned long)value);
    }
}

int main(void)
{
    /* board/stdio init here, e.g. stdio_init_all() with the Pico SDK */

    q = xQueueCreate(8, sizeof(uint32_t));
    if (q == NULL)
        return 1;

    xTaskCreate(producer_task, "producer", 256, NULL, 2, NULL);   /* stack depth in words, priority 2 */
    xTaskCreate(consumer_task, "consumer", 256, NULL, 1, NULL);

    vTaskStartScheduler();   /* never returns unless there wasn't enough heap */
    for (;;) {
    }
}
```

+ In standard FreeRTOS the stack depth is in **words** (`StackType_t`), not bytes.
+ On **ESP-IDF**, the scheduler is already running when `app_main()` is called (it is itself a task), so don't call `vTaskStartScheduler()`.
  Include `"freertos/FreeRTOS.h"`, and note that ESP-IDF's stack sizes are in **bytes**.

## 6. Do you need an RTOS?

Not for simple projects. A super loop with interrupts, timers, and non-blocking code (state machines) is often enough,
and the Pico SDK can run a second loop on the second core with `pico_multicore`.

Consider an RTOS when:

+ Several activities with different timing needs run at once (control loop + communication + UI).
+ You need guaranteed response to some events while slow work (Wi-Fi, file system, display) is going on.
+ You use a networking or Bluetooth stack that expects an RTOS (common on ESP32 and with lwIP).
+ The code base is growing and you want independent, testable modules with clear communication between them.

The cost: RAM for each task's stack, more complex debugging (races, priorities), and some learning curve.

## 7. Popular RTOSes

| RTOS | License | Maintained by | Notes |
| --- | --- | --- | --- |
| FreeRTOS | MIT | Amazon (AWS) | Small kernel, the most widely ported; SMP support for multi-core chips in recent kernel versions |
| Zephyr | Apache 2.0 | Zephyr Project (Linux Foundation) | Full platform: drivers, device tree, Kconfig, networking, Bluetooth; many boards |
| RT-Thread | Apache 2.0 | RT-Thread (community and company) | Kernel plus many software packages; popular in China |
| Apache NuttX | Apache 2.0 | Apache Software Foundation | POSIX-style APIs and a shell (NSH); used by PX4 drone autopilots |
| Eclipse ThreadX | MIT | Eclipse Foundation (formerly Azure RTOS) | Safety certifications; common on STM32 (STM32Cube) |

### Raspberry Pi Pico (RP2040 / RP2350)

No RTOS is preinstalled; programs normally run on bare metal with the Pico SDK.

+ **FreeRTOS**: the most common choice. The RP2040/RP2350 ports support SMP, so tasks run on both cores; tasks can also be pinned to one core.
  The ports are in the FreeRTOS kernel repository (and Raspberry Pi's fork of it); check which kernel version supports your chip.
+ **Zephyr**: supports the Pico, Pico W, and Pico 2 boards (`rpi_pico`, `rpi_pico2`, ...).
+ **RT-Thread** and **NuttX**: both include RP2040 board support.

### ESP32

+ **FreeRTOS is always there**: ESP-IDF is built on it, and the Wi-Fi and Bluetooth stacks run as FreeRTOS tasks.
  Espressif ships its own SMP variant for the dual-core chips; `xTaskCreatePinnedToCore()` pins a task to core 0 or 1.
+ **Arduino on ESP32** runs on top of ESP-IDF, so `setup()` and `loop()` run inside a FreeRTOS task and you can create more tasks.
+ Not every ESP32 is dual-core: ESP32-S2, ESP32-C3, and ESP32-C6 have one core.
+ **Zephyr** and **NuttX** also support many ESP32 chips; useful when the same product code must run on other vendors' MCUs too (Nordic, STM32, NXP).

## Related notes

+ [RPi_pico_Cxx_SDK.md](RPi_pico_Cxx_SDK.md): Pico C/C++ SDK (bare metal, `pico_multicore`)
+ [RPi_pico_PIO.md](RPi_pico_PIO.md): offloading timing-critical I/O to PIO instead of tasks
+ [../Linux/HAL_Std_Func.md](../Linux/HAL_Std_Func.md): STM32 HAL functions, blocking vs `_IT`/`_DMA` variants
+ [../Linux/HAL_mmio_vs_sysfs.md](../Linux/HAL_mmio_vs_sysfs.md): hardware access on Linux vs microcontrollers

## Reference

+ FreeRTOS documentation: <https://www.freertos.org/>
+ FreeRTOS kernel source (including RP2040/RP2350 ports): <https://github.com/FreeRTOS/FreeRTOS-Kernel>
+ ESP-IDF FreeRTOS: <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-reference/system/freertos.html>
+ Zephyr documentation: <https://docs.zephyrproject.org/>
+ Apache NuttX: <https://nuttx.apache.org/>
+ RT-Thread: <https://www.rt-thread.io/>
+ Eclipse ThreadX: <https://github.com/eclipse-threadx>
+ Linux real-time (PREEMPT_RT): <https://wiki.linuxfoundation.org/realtime/start>
