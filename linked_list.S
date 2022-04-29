.syntax unified
.global create_linked_list, add_to_list, remove_from_list, get_list_length, get_from_list, OUT_OF_BOUNDS_EXCEPTION

.equiv OUT_OF_BOUNDS_EXCEPTION, 0x1

/*
    Developed by Nicholas Miehlbradt, 2019
    Note: documentation for this library still needs work.
    Some comments are just notes to myself, or ideas I have.
*/

@ Requires allocator.S

@ Create list
@ Add to list
@ Remove from list

@ Creates an empty linked list
@ r0: heap base pointer
@ r1: size of object in list
@ Returns pointer in r0
.type create_linked_list, %function
create_linked_list:
    push {lr}
    push {r1} @ stores size of object on stack
    mov r1, r0 @ moves heap base pointer to r1
    ldr r0, =8 @ Loads 8 into r0 to allocate 8 bytes (4 bytes object size, 4 bytes pointer)
    bl allocate @ Allocates
    cmp r0, 0x0 @ Checks allocation is not null
    beq return_from_create_list @ if it is return null pointer
    pop {r1} @ pop r1 (size of object) from stack
    str r1, [r0, #0] @ Stores size of object in first header word
    ldr r1, =0x0 @ Loads 0 (null pointer)
    str r1, [r0, #4] @ Stores null pointer in second word of list header
return_from_create_list:
    pop {lr}
    bx lr
.size create_linked_list, .-create_linked_list

@ Adds a block to a list
@ r0: list base pointer
@ r1: heap base pointer
@ Returns pointer to new block in r0
.type add_to_list, %function
add_to_list:
    push {lr}
@ Allocate a new block
    ldr r2, [r0] @ Load size of list object into r2
    add r2, #4 @ Account for pointer to next object
    push {r0, r2} @ save for function call
    mov r0, r2 @ move requested block size into r0
    bl allocate
    cmp r0, 0x0
    beq return_from_add
    pop {r1, r2} @ load after funciton call (r0 - new block pointer, r1 - list base pointer, r2, size of object)
    sub r2, #4 @ Get length of object from length of block
@ Now link the new block to the end of the list
    ldr r3, [r1, #4]! @ Load next block pointer of header
go_to_end_loop:
    cmp r3, 0x0 @ Check if pointer is null
    beq link_new_block @ If it is end of list has been reached. Link new block
    mov r1, r3 @ Move pointer to next block into r1
    add r1, r2 @ Add length of object so that r1 points at next pointer
    ldr r3, [r1] @ Load next pointer into r3
    b go_to_end_loop @ Loop back
link_new_block: @ At this point expect r3 to be pointing to the pointer to be changed
    str r0, [r1] @ store pointer to new block in end pointer of list
    ldr r1, =0x0 @ Load null pointer to r1
    str r1, [r0, r2] @ Store null pointer at end of new block to indicate end of list
return_from_add:
    pop {lr}
    bx lr
.size add_to_list, .-add_to_list

@ Removes the block at the specified index from a linked list
@ Returns OUT_OF_BOUNDS_EXCEPTION code (0x1) if index is out of bounds
@ r0: index of block to remove
@ r1: list base pointer
@ r2: heap base pointer
.type remove_from_list, %function
remove_from_list:
    push {lr}
    push {r2} @ push heap base pointer to stack
    ldr r3, [r1] @ Load object size into r3
@ First iterate through list to find block to remove
    ldr r2, [r1, #4]! @ r2 contains pointer to block 0, r1 points to this pointer
remove_search_loop_0:
    cmp r2, 0x0 @ Check if r2 is null pointer (end of list)
    bne remove_search_loop_1 @ if r2 is zero, out of bounds exception
    ldr r0, =OUT_OF_BOUNDS_EXCEPTION @ Load error code
    pop {r1}
    b return_from_remove @ branch to escape
remove_search_loop_1:
    cmp r0, #0 @ check if next block is the one to be removed
    beq remove_remove_block @ if it is then go remove it
    mov r1, r2 @ Move pointer to next block into r1
    add r1, r3 @ Increment r1 by object size to get to pointer to block after
    ldr r2, [r1] @ Load pointer for block after into r2
    sub r0, #1 @ Decrement index
    b remove_search_loop_0

@ Remove the block
@ Join the block before to the block after
@ r2 contains pointer to block to be removed
@ r1 contains pointer to prev block pointer
remove_remove_block:
    ldr r0, [r2, r3] @ r0 contains pointer to block after block to be removed
    str r0, [r1] @ Store pointer to block after in block before's next block pointer
    @ Set up call to deallocate
    mov r0, r2 @ move pointer to block to be deallocated to r0
    pop {r1} @ pop heap base pointer to r1
    bl deallocate @ call function
    ldr r0, =0x0 @ Load null pointer to r0 to indicate success
return_from_remove:
    pop {lr}
    bx lr
.size remove_from_list, .-remove_from_list

@ Gets the length (number of items) of a linked list
@ r0: list base pointer
@ Returns length in r0
.type get_list_length, %function
get_list_length:
    ldr r3, =0 @ load counter into r3
    ldr r2, [r0] @ Load length of object into r2
    ldr r1, [r0, #4]! @ loads pointer to next block into r1
get_list_length_loop_0:
    cmp r1, 0x0 @ Check if is null pointer (end of list)
    beq return_from_get_list_length @ if pointer is null we are at the end
    mov r0, r1 @ Load pointer to start of next block into r0
    add r0, r2 @ Increments r0 to be pointing to the next block pointer
    ldr r1, [r0] @ Loads pointer to next block into r1
    add r3, #1 @ Increment counter
    b get_list_length_loop_0
return_from_get_list_length:
    mov r0, r3 @ Move list length into r0
    bx lr
.size get_list_length, .-get_list_length

@ Gets the pointer to object at index i
@ r0: the index i
@ r1: list base pointer
@ Returns pointer to block in r0 or OUT_OF_BOUNDS_EXCEPTION
.type get_from_list, %function
get_from_list:
    ldr r3, [r1] @ Load object size into r3
    ldr r2, [r1, #4]! @ Load pointer to first block into r2
get_search_loop_0:
    cmp r2, 0x0 @ Check if r2 is a null pointer
    bne get_search_loop_1
    ldr r0, =OUT_OF_BOUNDS_EXCEPTION
    b return_from_get
get_search_loop_1:
    cmp r0, #0 @ Check if this block is the one wanted
    bne get_search_loop_2 @ If not equal keep searching
    mov r0, r2 @ Move pointer to block into r0 for return
    b return_from_get
get_search_loop_2:
    mov r1, r2 @ Move pointer to next block into r1
    add r1, r3 @ Add object length to get to next block pointer
    ldr r2, [r1] @ Load next block pointer
    sub r0, #1 @ Decrement index
    b get_search_loop_0
return_from_get:
    bx lr
.size get_from_list, .-get_from_list

/*
    Additional funtions
    - Get array of object pointers
*/


