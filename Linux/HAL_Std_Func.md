# Vendor MCU HAL libraries: standard functions

Microcontroller vendors ship C libraries that wrap every on-chip peripheral (GPIO, UART, SPI, I2C, ADC, timers, DMA, ...).
Examples are **STM32Cube HAL** (STMicroelectronics), the **MCUXpresso SDK** (NXP), **DriverLib** (TI), and **ESP-IDF** drivers (Espressif).

"**Standard**" here means a **consistent API within one vendor's product line**.
The same function names, handle structures, and call patterns are used across that line's chip families.
It is **not** a cross-vendor standard:

+ ST's HAL covers the 32-bit STM32 families (F0/F1/F4/G0/H7/...). STM8 used a different library (SPL).
+ NXP's MCUXpresso SDK and TI's DriverLib have their own, different APIs, and they differ between some families even within one vendor.

## 1. The common function groups (STM32 HAL naming: `HAL_<PPP>_...`, PPP = peripheral)

| Group | STM32 examples | Purpose |
| --- | --- | --- |
| Init / de-init | `HAL_UART_Init()`, `HAL_UART_DeInit()` | Configure the peripheral from an init structure inside a **handle** |
| Low-level init hooks (weak) | `HAL_UART_MspInit()` | **You** implement these: enable clocks, configure pins (alternate function), set NVIC priorities. CubeMX generates them |
| Blocking I/O | `HAL_UART_Transmit()`, `HAL_UART_Receive()` | Polls until done or timeout |
| Interrupt / DMA I/O | `HAL_UART_Transmit_IT()`, `HAL_UART_Transmit_DMA()` | Starts the transfer and returns immediately |
| IRQ dispatch | `HAL_UART_IRQHandler(&huart2)` | Called from the vector (`USART2_IRQHandler`); it updates the state and calls callbacks |
| Callbacks (weak) | `HAL_UART_TxCpltCallback()`, `HAL_UART_RxCpltCallback()`, `HAL_UART_ErrorCallback()` | Override to react to events |
| State / errors | `HAL_UART_GetState()`, `HAL_UART_GetError()` | Query the handle |

Almost every function returns `HAL_StatusTypeDef` (`HAL_OK`, `HAL_ERROR`, `HAL_BUSY`, `HAL_TIMEOUT`). **Check it.**

## 2. Example: sending text over UART (STM32F4)

```c
#include <string.h>
#include "stm32f4xx_hal.h"

UART_HandleTypeDef huart2;

/* Called by HAL_UART_Init(): clocks and pins (USART2 on PA2/PA3, AF7) */
void HAL_UART_MspInit(UART_HandleTypeDef *huart)
{
    if (huart->Instance == USART2) {
        __HAL_RCC_USART2_CLK_ENABLE();
        __HAL_RCC_GPIOA_CLK_ENABLE();

        GPIO_InitTypeDef gpio = {0};
        gpio.Pin       = GPIO_PIN_2 | GPIO_PIN_3;
        gpio.Mode      = GPIO_MODE_AF_PP;
        gpio.Pull      = GPIO_PULLUP;
        gpio.Speed     = GPIO_SPEED_FREQ_VERY_HIGH;
        gpio.Alternate = GPIO_AF7_USART2;
        HAL_GPIO_Init(GPIOA, &gpio);
    }
}

static void UART2_Setup(void)
{
    huart2.Instance          = USART2;
    huart2.Init.BaudRate     = 115200;
    huart2.Init.WordLength   = UART_WORDLENGTH_8B;
    huart2.Init.StopBits     = UART_STOPBITS_1;
    huart2.Init.Parity       = UART_PARITY_NONE;
    huart2.Init.Mode         = UART_MODE_TX_RX;
    huart2.Init.HwFlowCtl    = UART_HWCONTROL_NONE;
    huart2.Init.OverSampling = UART_OVERSAMPLING_16;

    if (HAL_UART_Init(&huart2) != HAL_OK) {
        Error_Handler();
    }
}

static void Send_Message(void)
{
    const char msg[] = "Hello, Hardware!\r\n";
    /* Handle, buffer, length in bytes (without the '\0'), timeout in ms */
    HAL_UART_Transmit(&huart2, (const uint8_t *)msg, (uint16_t)strlen(msg), 100);
}

int main(void)
{
    HAL_Init();               /* SysTick, flash prefetch, NVIC grouping */
    SystemClock_Config();     /* clock tree (CubeMX-generated) */
    UART2_Setup();
    Send_Message();
    while (1) { }
}
```

Use `strlen(msg)` (18 bytes here), not a hand-counted constant.
A count of 19 would also send the terminating `'\0'`.
The `pData` parameter of `HAL_UART_Transmit` is `const uint8_t*` in current STM32Cube HAL versions; older versions use a non-const `uint8_t*`.

## 3. Why vendor HALs are useful

1. **Consistent API within a vendor**: `HAL_UART_Transmit()` works the same on STM32F4, G0, and H7, so the knowledge and much of the code transfer.
   You still need to check per-family differences in clocks, pin alternate functions, and some peripheral features.
2. **Code generation**: STM32CubeMX (in STM32CubeIDE), MCUXpresso Config Tools, and TI SysConfig generate
   the init code, `MspInit` functions, and clock setup from a graphical configuration.
3. **Hidden sequencing**: flag polling, timeouts, error recovery, and DMA/interrupt state machines are handled inside the library.

## 4. Limits

+ **Overhead**: the HAL is generic: it does parameter checks, keeps a state machine, and adds layers.
  For tight timing or small flash, ST also provides **LL (Low-Layer)** drivers, which are thin inline register helpers.
  You can also write the registers directly (see [../Android/HAL/HAL_STM32_example.md](../Android/HAL/HAL_STM32_example.md)).
+ **Blocking calls**: `HAL_UART_Transmit()` busy-waits. Use the `_IT` or `_DMA` variants in real firmware, or with an RTOS.
+ **Vendor lock-in**: code written against `HAL_UART_*` doesn't port to NXP or TI.
  To port across vendors, wrap it in your own interface (see [HAL_intro.md](HAL_intro.md)),
  or use a portable layer such as Zephyr, CMSIS-Driver, or Arduino.

## Related notes

+ [HAL_intro.md](HAL_intro.md): C++ interfaces over a vendor HAL
+ [HAL_mmio_vs_sysfs.md](HAL_mmio_vs_sysfs.md): why Linux uses kernel drivers instead
+ [../Android/HAL/HAL_STM32_example.md](../Android/HAL/HAL_STM32_example.md): `HAL_GPIO_WritePin` at the register level

## Reference

+ [STM32CubeF4 (GitHub)](https://github.com/STMicroelectronics/STM32CubeF4)
+ UM1725: Description of STM32F4 HAL and low-layer drivers (ST)
