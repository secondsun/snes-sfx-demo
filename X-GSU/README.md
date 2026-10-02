This is the basic hello world SuperFX program from libSFX

# Conventions

## Register Use

There are several registers that have special meaning in this Project. `R10` is reserved for [stack](./common/stack.i) operations by the framework and isn't available for general use. The [function](./common/function.i) macros use `R0` as a primary input and `R3` as an output by convention.

## Function Calls

The [function](./common/function.i) macros provide convenient ways to call functions. They setup and tear down frames and update the stack as appropriate. This is why the register `R10` should not be used in general operations. Functions typically receive their primary input on `R0` and return their value (if any) on `R3`. Additional operands are passed in registers (`R1`, `R2`, etc.) or on the stack, and should be documented in the function header comments. `R0` and all other registers may be modified during function calls, and functions are expected to provide documentation if they do anything clever or considerate such as avoiding or using certain registers.

When writing functions where the operand order matters (ie subtraction), the left hand side should be placed in `R0` by convention. 


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

# Special Thanks
 * SuperFX3 merge macro from : https://github.com/Sunlitspace542/ultrastarfox/tree/main
 * Randy Linden Doom-FX for SuperFX documentation :  https://github.com/RandalLinden/DOOM-FX/tree/master/docs