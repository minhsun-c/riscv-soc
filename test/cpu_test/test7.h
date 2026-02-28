#ifndef TEST7_H
#define TEST7_H

#include <cstring>
#include <fstream>

void load_program(const char *filename)
{
    printf("Loading binary file: %s...\n", filename);
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "ERROR: Failed to open " << filename << "\n";
        exit(1);
    }
    file.read((char *) imem, sizeof(imem));
    file.close();
    memcpy(dmem, imem, sizeof(imem));
}

void verify_results(Vcpu *dut)
{
    printf("\n--- Verifying Test 7 (Linked List) ---\n");

    // Check the exported sum at 0x00000800 (dmem[512])
    EXPECT_EQ(dmem[512], 100, "Linked List traversal sum should be 100");
}

#endif  // TEST7_H