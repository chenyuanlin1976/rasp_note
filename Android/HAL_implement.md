# HAL implementation

To see how a Hardware Abstraction Layer (HAL) is actually implemented,  
let's look at the real-world source code for `HAL_GPIO_WritePin`,  
a famous function from STMicroelectronics' STM32 HAL library used to control hardware pins on a microcontroller.

## 1. The Function Signature

When you write code for your microcontroller, you call a clean, human-readable function:  
`HAL_GPIO_WritePin(GPIOC, GPIO_PIN_13, GPIO_PIN_SET);`

+ `GPIOC`: The specific GPIO port (Port C).
+ `GPIO_PIN_13`: The specific pin on that port (Pin 13, often connected to an onboard LED).
+ `GPIO_PIN_SET`: The state (High / Turn ON).

## 2. How the HAL Implements It Under the Hood

If you open up the actual vendor-supplied C source code for the STM32 HAL,  
the implementation of `HAL_GPIO_WritePin` looks something like this:

```c
void HAL_GPIO_WritePin(GPIO_TypeDef *GPIOx, uint16_t GPIO_Pin, GPIO_PinState PinState)
{
    // Check the parameters using assertions (debugging guardrails)
    assert_param(IS_GPIO_PIN(GPIO_Pin));
    assert_param(IS_GPIO_PIN_ACTION(PinState));

    if (PinState != GPIO_PIN_RESET)
    {
        // Set the pin HIGH using the Bit Set/Reset Register (BSRR)
        // Writing to the upper or lower half of BSRR alters the pin atomically
        GPIOx->BSRR = (uint32_t)GPIO_Pin;
    }
    else
    {
        // Reset the pin LOW 
        // Shifting by 16 bits targets the "reset" half of the BSRR register
        GPIOx->BSRR = (uint32_t)(GPIO_Pin << 16U);
    }
}
```

## 3. Decoding What's Happening Under the Hood

To understand how this C code actually touches the physical silicon, let's break down its key mechanics:

### A. Memory-Mapped I/O (GPIO_TypeDef *GPIOx)

In embedded systems, hardware registers (physical electronic switches inside the chip) are mapped directly to specific memory addresses.

+ `GPIOC` isn't a magical keyword; it's a pointer to a C struct placed at a hardcoded memory address  
  (e.g., 0x40020800 for Port C on certain chips).
+ The `GPIO_TypeDef` struct maps out the exact layout of the hardware registers for that port:

```c
typedef struct {
    volatile uint32_t MODER;    // Mode register
    volatile uint32_t OTYPER;   // Output type register
    volatile uint32_t OSPEEDR;  // Speed register
    volatile uint32_t PUPDR;    // Pull-up/pull-down register
    volatile uint32_t IDR;      // Input data register
    volatile uint32_t ODR;      // Output data register
    volatile uint32_t BSRR;     // Bit set/reset register <- Used above!
} GPIO_TypeDef;
```

### B. Direct Register Manipulation (GPIOx->BSRR = ...)

Instead of making an OS system call (like you would on Linux or Windows),  
**the C code directly writes a binary value to a specific memory address** (BSRR).

+ When the CPU writes a 1 to a specific bit position in the BSRR (Bit Set/Reset Register) of Port C,  
  the hardware circuitry inside the microchip automatically sends electrical current to that physical output pin.

## Why Use the HAL Instead of Writing to Registers Directly?

You could write to the registers yourself without the HAL:  
`GPIOC->BSRR = (1 << 13); // Direct register manipulation`

However, the HAL wraps this in `HAL_GPIO_WritePin(...)` to provide:

+ Portability: If you switch from an STM32 chip to a completely different manufacturer's chip,  
  the raw register names and memory maps will change entirely.  
  But if the new chip also provides a HAL, your high-level application logic can remain untouched.
+ Safety & Readability: It prevents developers from accidentally overwriting neighboring control bits in the same register  
  by handling the bit-shifting and atomic operations safely under the hood.
