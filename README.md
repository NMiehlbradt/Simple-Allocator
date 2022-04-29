# Simple-Allocator
A simple memory allocator written in ARMv7 assembly

I implemented a simple memory allocator in 2019 as a part of an assignment. It can allocate and deallocate blocks of memory as well as store meta data about the heap and can include a header with each allocated block which can be used to store meta data about allocated regions.

`linked_list.S` contains a library implementing linked lists which demonstrates a use of the allocator.

Tested on an STM32L476G discovery board with an ARM Cortex-M4 processor.
