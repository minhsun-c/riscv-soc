// linked_list.c

// Define the Node structure
struct Node {
    int value;
    struct Node *next;
};

// 1. Statically allocate the nodes in Data Memory (.data)
// We use 0 instead of NULL since we don't have <stddef.h>
struct Node node4 = {40, 0};
struct Node node3 = {30, &node4};
struct Node node2 = {20, &node3};
struct Node node1 = {10, &node2};

int main()
{
    // 2. Set the head pointer
    struct Node *current = &node1;
    int sum = 0;

    // 3. Traverse the Linked List (Pointer Chasing!)
    while (current != 0) {
        sum += current->value;
        current = current->next;  // Load the next address from memory
    }

    // 4. Export the sum to a fixed memory address for the testbench
    // Address 0x00000800 is dmem[512]
    volatile int *export_ptr = (volatile int *) 0x00000800;
    *export_ptr = sum;

    return 0;
}