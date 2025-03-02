//=========================================================================
// riscv-addi.S
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //-----------------------------------------------------------------
        // Arithmetic tests
        //-----------------------------------------------------------------
        // A test case requiring a value to be bypassed from the ROB(i.e.,bypassing a value that has been written back but not yet committed)

        li   x1,1;
        li   x2,2;
        li   x3,3;
        li   x4,4;
        li   x5,5;
        add x3,x4,x5;
        mul x12,x3,x2;
        add x6,x4,x5;
        add x7,x4,x5;
        add x8,x4,x5;
        add x9,x4,x5;
        add x10,x4,x5;
        add x11,x4,x5;

        TEST_CHECK_EQ( x12, 18)

        TEST_RISCV_END

