// josephus.c
struct Node {
    int id;
    struct Node *next;
};

// Use static to ensure these are placed in Data Memory correctly
static struct Node nodes[6];

int main()
{
    int n = 6;  // Number of people
    int k = 3;  // Step count

    // 1. Initialize Circular Linked List
    // We replace (i + 1) % n with an if-statement to avoid __modsi3
    for (int i = 0; i < n; i++) {
        nodes[i].id = i + 1;

        int next_idx = i + 1;
        if (next_idx >= n) {
            next_idx = 0;
        }
        nodes[i].next = &nodes[next_idx];
    }

    // Initialize pointers for elimination
    // Start with prev at the end of the list and curr at the start
    struct Node *prev = &nodes[n - 1];
    struct Node *curr = &nodes[0];

    // 2. The Elimination Loop
    // Continue until only one node remains (points to itself)
    while (curr->next != curr) {
        // Count k-1 steps
        for (int count = 1; count < k; count++) {
            prev = curr;
            curr = curr->next;
        }

        // "Remove" the current node by skipping it in the linked chain
        // This is the classic "Pointer Chasing" hardware test
        prev->next = curr->next;
        curr = prev->next;
    }

    // 3. Export the winner's ID to 0x00000800 (dmem[512])
    // We use volatile to prevent the compiler from optimizing this write away
    volatile int *export_ptr = (volatile int *) 0x00000800;
    *export_ptr = curr->id;

    // Final infinite loop to prevent the CPU from executing random memory
    while (1)
        ;

    return 0;
}