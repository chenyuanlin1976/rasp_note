# Microcontroller HAL example: STM32 `HAL_GPIO_WritePin`

This note shows what a **microcontroller vendor HAL** does under the hood,
using `HAL_GPIO_WritePin()` from STMicroelectronics' STM32 HAL library (STM32F4 family).

It is **not** an Android HAL. The MCU HAL is a C library compiled into the firmware:
there are no processes, no IPC, and no kernel.
The idea is the same, though: a standard API in front of chip-specific registers.
For the Android meaning, see [HAL_intro.md](HAL_intro.md).

## 1. The call

```c
HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_SET);
```

+ `GPIOC`: the GPIO **port** C, which is a pointer to that port's register block.
+ `GPIO_PIN_13`: a **bit mask** (`0x2000` = `1 << 13`), not the number 13.
  Because it's a mask, you can OR several pins together: `GPIO_PIN_13 | GPIO_PIN_14`.
+ `GPIO_PIN_SET`: drive the pin high (`GPIO_PIN_RESET` = low).

## 2. The implementation

From the STM32F4 HAL (`stm32f4xx_hal_gpio.c`):

```c
void HAL_GPIO_WritePin(GPIO_TypeDef *GPIOx, uint16_t GPIO_Pin, GPIO_PinState PinState)
{
    /* Parameter checks; compiled in only when USE_FULL_ASSERT is defined */
    assert_param(IS_GPIO_PIN(GPIO_Pin));
    assert_param(IS_GPIO_PIN_ACTION(PinState));

    if (PinState != GPIO_PIN_RESET)
    {
        GPIOx->BSRR = GPIO_Pin;                    /* bits 0..15: SET these pins   */
    }
    else
    {
        GPIOx->BSRR = (uint32_t)GPIO_Pin << 16U;   /* bits 16..31: RESET these pins */
    }
}
```

## 3. What's happening

### A. Memory-mapped I/O (`GPIO_TypeDef *GPIOx`)

The peripheral registers are mapped to fixed physical addresses.
`GPIOC` is a macro that casts the port's base address to a struct pointer.
On STM32F4, that address is `0x40020800`; other families use other addresses and other layouts.

```c
/* STM32F4 layout: each field is one 32-bit register, in address order */
typedef struct {
    volatile uint32_t MODER;    /* 0x00 mode: input / output / alternate / analog */
    volatile uint32_t OTYPER;   /* 0x04 output type: push-pull / open-drain       */
    volatile uint32_t OSPEEDR;  /* 0x08 output speed                              */
    volatile uint32_t PUPDR;    /* 0x0C pull-up / pull-down                       */
    volatile uint32_t IDR;      /* 0x10 input data   (read pin levels)            */
    volatile uint32_t ODR;      /* 0x14 output data                               */
    volatile uint32_t BSRR;     /* 0x18 bit set/reset (write-only)  <- used above */
    volatile uint32_t LCKR;     /* 0x1C configuration lock                        */
    volatile uint32_t AFR[2];   /* 0x20 alternate function select                 */
} GPIO_TypeDef;

#define GPIOC ((GPIO_TypeDef *) 0x40020800UL)
```

`volatile` tells the compiler that every access really goes to the hardware, so it must not cache or remove it.

### B. Atomic set/reset through BSRR

There is no system call: the CPU just **stores a value to an address**,
and the GPIO peripheral changes the pin's output driver.

+ Writing a `1` to bit *n* (0–15) of BSRR sets pin *n* high.
+ Writing a `1` to bit *n + 16* resets pin *n* low.
+ A `0` bit has **no effect**, so other pins on the same port are left alone.

That is why the HAL uses BSRR instead of the obvious `GPIOC->ODR |= (1 << 13);`.
`|=` on `ODR` is a **read-modify-write** (load, OR, store).
If an interrupt changes another pin of port C between the load and the store, that change is lost.
A single store to BSRR is **atomic**.

Before this works, the pin must already be configured as an output.
`HAL_GPIO_Init()` does that by writing `MODER`, `OTYPER`, `OSPEEDR`, and `PUPDR`,
and the port's clock must be enabled first (`__HAL_RCC_GPIOC_CLK_ENABLE()`).

## 4. Why use the HAL instead of registers?

You can write the register directly:

```c
GPIOC->BSRR = GPIO_PIN_13;   /* same effect, no function call */
```

The HAL adds:

+ **Portability across STM32 families**: register layouts differ.
  For example, STM32F1 configures pins with `CRL`/`CRH` instead of `MODER`, and older F4 headers split BSRR into `BSRRL`/`BSRRH`.
  Code that calls `HAL_GPIO_WritePin()` doesn't change.
+ **Correctness by default**: atomic BSRR writes, parameter checks (`assert_param`), and init sequences done in the right order.
+ **Readability**: the code names the intent instead of bit positions.

The cost is a function call and some code size.
Time-critical code (for example, bit-banging) often uses direct register writes or the lighter **LL** (Low-Layer) drivers instead.

Porting to another vendor's MCU (NXP, Microchip, ...) still means changing code,
because each vendor's HAL has its own API. Portability across vendors needs a further layer, such as CMSIS-Driver, Zephyr, or Arduino.

## Related notes

+ [HAL_intro.md](HAL_intro.md)

## Reference

+ [STM32CubeF4 HAL and LL drivers (GitHub)](https://github.com/STMicroelectronics/stm32f4xx-hal-driver)
+ RM0090 (STM32F405/407 reference manual), section "GPIO registers"
