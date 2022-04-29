.syntax unified
.global init_heap, calculate_heap_size, allocate, deallocate, NULL_POINTER

/*
    Developed by Nicholas Miehlbradt, 2019
*/

/*
    TODOs: 
    - Add capability for block headers to hold metadata
    - Add more capabilities to allocate (e.g. enforce max heap size etc.)
    - Add macros for easier allocation
    - Possibly add some pointer verification (put some hash in header to ensure address is actually the correct pointer)
    - Update data in heap object when allocation or deallocation occurs
*/

.equiv NULL_POINTER, 0x0

/*
    SOME INFO ABOUT BLOCK HEADERS
*/
.equiv BLOCK_HEADER_SIZE, 8

/*

    Heap Data Object The heap data object contains information about the heap and 
    is updated during allocation and deallocation. It should never be deallocated. 
    Doing this is undefined and most probably breaks everything.

    Heap Data Object Fields:
    Heap Maximum Size - The maximum size of the heap. Used when max heap size is enforced during allocation. (R/W)
    Heap Current Size - The current size of the heap (Read only)
    Heap Blocks Allocated - The number of blocks allocated (Read only)

    Heap object constants
*/
.equiv HEAP_OBJ_SIZE, 2*4
.equiv HEAP_MAX_SIZE_OFFSET, 0x0
.equiv HEAP_COUNT_OFFSET, HEAP_MAX_SIZE_OFFSET + 0x4


/*
    Initialises the heap and creates a heap data object.
    Parameters:
    r0: pointer to start of heap
    r1: max heap size
    Returns:
    r0: pointer to heap object, or NULL_POINTER if init failed
*/
.type init_heap, %function
init_heap:  
    mov r2, r0

    @ ------- Set up initial frame ------- @

    @ r0 contains the heap base pointer
    @ r1 contains the max heap size
    @ r2 contains the address of the current pointer
    @ r3 contains the value of the current pointer

    ldr r3, =(16 + HEAP_OBJ_SIZE) @ Calculate offset to gap start
    add r3, r0 @ Add offset to absolute value
    str r3, [r2], #4 @ Store gap start in gap start pointer, inc to next pointer

    ldr r3, =(8 + HEAP_OBJ_SIZE) @ Calculate offset to block end
    add r3, r0 @ Add offset to absolute value
    str r3, [r2], (4 + HEAP_OBJ_SIZE) @ Store block end in block end pointer, inc to next pointer

    add r3, r0, #8 @ Calculate position of block start
    str r3, [r2], #4 @ @ Store block start in block start pointer, inc to next pointer

    str r0, [r2], -(4 + HEAP_OBJ_SIZE) @ Store gap end in gap end pointer, dec to start of head data object

    @ ------- Setup heap data object ------- @
    
    str r1, [r2, HEAP_MAX_SIZE_OFFSET]

    ldr r0, =1
    str r0, [r2, HEAP_COUNT_OFFSET]

    mov r0, r2

    bx lr
.size init_heap, .-init_heap

/*
    Attempts to allocate a specific number of bytes
    Options can be set to specify behaviour
    Parameters:
    r0: n bytes
    r1: heap base pointer
    r2: options // Not used
    Returns
    r0: Pointer to start of object of successfull, otherwise null pointer
*/

// Basic allocation done (first fit, forced)
// TODO: Implement options
.type allocate, %function
allocate:
    push {r4, r5, r6, r7, lr}
    mov r4, r1 @ Save heap base in r4
    mov r5, r2 @ Save options in r5
    add r0, #16 @ To account for heap overhead on each object
    
    mov r6, NULL_POINTER
    mov r7, 0xFFFFFFFF

    @ ------- Search loop ------- @
    @ Looks through the heap to find a gap between frames of sufficient size

    gap_search_loop_0:
    @ Loop starts with r1 containing the address of the gap start pointer
    add r1, #4 @ r1 contains block end pointer
    ldr r1, [r1] @ r1 contains block start pointer
    add r1, #4 @ r1 contains gap end pointer

    ldr r2, [r1] @ r2 stores gap end (also the next gap start pointer)
    ldr r1, [r2] @ r1 stores gap start
    subs r3, r2, r1 @ r3 contains size of gap

    blo set_up_frame_0 @End has been reached -> break and allocate based on location pointer
    cmp r3, r0 @ Compare available space with needed space
    blo gap_search_loop_1 @ Gap has not enough space

    @ Gap has enough space -> designate pointers and jump to frame setup
    // TODO: Select gap based on selection mode
    mov r6, r1
    mov r7, r3
    b set_up_frame_0

    gap_search_loop_1:
    mov r1, r2 @ Move gap start pointer to r1
    b gap_search_loop_0

    @ ------- Set up new frame ------- @
    @ Code sets up heap frame at pointer in r6
    @ Assumes that r6 points to the beginning of a gap or null pointer if no gap was found
    @ ie. previous frame's gap end pointer is at [r6 - 4]
    set_up_frame_0:

    cbnz r6, set_up_frame_1 @ If r6 is not zero a gap has been found
    // TODO: check if expanding heap is permitted, if not then terminate and return null pointer
    ldr r6, [r4] @ If r6 is zero then create a new frame on the end

    set_up_frame_1:
    sub r0, #16 @ Remove the 16 bytes to get the size of the object

    mov r1, r6

    ldr r3, [r1, #-4] @ Get previous frame's gap end pointer
    str r6, [r1, #-4] @ Update previous frame's gap end pointer
    str r6, [r1], #4 @ Initialise new frame's gap start pointer

    add r2, r0, #8 @ get offset to block end
    add r2, r6 @ Get absolute address of block end
    str r2, [r1], #4 @ Store address of block end in pointer
    mov r2, r1 @ Move address of block start to r2
    add r1, r0 @ Add block size so r1 points to block start pointer
    str r2, [r1], #4 @ Store block start pointer
    str r3, [r1], #4 @ Point gap end pointer at next frame
    str r1, [r3] @ Update next frame's gap start pointer to start of new gap

    add r0, r6, #8 @ Set r0 to point at new block start

    pop {r4, r5, r6, r7, lr}
    bx lr
.size allocate, .-allocate

/*
    Deallocates a block and marks it as a gap
    Parameters:
    r0: pointer to start of block to be deallocated
    r1: heap base pointer
    Returns:
    r0: 0x0 if successful
*/
// TODO: Update heap data object
.type deallocate, %function
deallocate:
    push {lr}
    mov r3, r1

    sub r0, #4 @ r0 has address of block end pointer
    ldr r1, [r0] @ r1 has address of block end (also block start pointer)
    add r1, #4 @ r1 has address of gap end pointer
    ldr r1, [r1] @ r1 has address of next frame's gap start pointer

    sub r0, #4 @ r0 has address of gap start pointer
    ldr r2, [r0] @ r2 has address of gap start

    str r2, [r1] @ store gap start into next frame's gap start pointer
    sub r2, #4 @ Decrement r2 to get address of prev frame's gap end pointer
    str r1, [r2] @ Store address of gap end (also gap start pointer) in prev frame's gap end pointer

    mov r0, 0x0 @ Output 0x0 to show success
    pop {lr}
    bx lr
.size deallocate, .-deallocate

/*
    Gets the max size of the heap as stored in the heap data object.
    Parameters:
    r0: heap base pointer
    Returns:
    r0: max size of heap
*/
.type get_heap_max_size, %function
get_heap_max_size:
    ldr r0, [r0, #8 + HEAP_MAX_SIZE_OFFSET]
.size get_heap_max_size, .-get_heap_max_size

/*
    Sets the max size of the heap in the heap data object.
    This value is used on any future calls for allocated.
    Does NOT update the heap to fit within this size.
    Parameters:
    r0: new max size
    r1: heap base pointer
    Returns:
    None
*/
.type set_heap_max_size, %function
set_heap_max_size:
    str r0, [r1, #8 + HEAP_MAX_SIZE_OFFSET]
.size set_heap_max_size, .-set_heap_max_size

/*
    Gets the number of blocks allocated.
    Parameters:
    r0: heap base pointer
    Returns:
    r0: number of allocated blocks
*/
.type get_heap_nblocks, %function
get_heap_nblocks:
    ldr r0, [r0, #8 + HEAP_COUNT_OFFSET]
.size get_heap_nblocks, .-get_heap_nblocks

/*
    Calculates the size of the heap
    Parameters:
    r0: heap base pointer
    Returns:
    r0: size of heap
*/
.type get_heap_size, %function
get_heap_size:
    ldr r1, [r0]
    rsb r0, r1

    bx lr
.size get_heap_size, .-get_heap_size
    