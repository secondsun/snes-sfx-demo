This is the basic hello world SuperFX program from libSFX

# Conventions

## Register Use

There are several registers that have special meaning in this Project. `R10` is reserved for [stack](./common/stack.sgs) operations by the framework and isn't available for general use. The [function](./common/function.sgs) macros use `R0` as an input and `R3` as an output by convention.

## Function Calls

The [function](./common/function.sgs) macros provide convenient ways to call functions. They setup and tear down frames and update the stack as appropriate. This is why the register `R10` should not be used in general operations. Functions receive one input on `R0` and return their value (if any) on `R3`. `R0` and all other registers may be modified during function calls, and functions are expected to provide documentation if they do anything clever or considerate such as avoiding or using certain registers.

### Example Function Definition

Function names must be globally unique.

```gsu
; Input : the number of times to execute the loop
; Output : None
function example
   
   iwt R13, #label
   move R12, R0
   label:
      nop
      nop
      loop

   return
endfunction
```

### Example Function call
```gsu
call example
```