#ifndef TEST6_H
#define TEST6_H

#include <cstring>  // For memcpy
#include <fstream>

void load_program(const char *filename)
{
    printf("Loading binary file: %s...\n", filename);

    // Open the compiled .bin file
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        std::cerr << "ERROR: Failed to open " << filename << "\n";
        exit(1);
    }

    // Read the binary file directly into the Instruction Memory array
    file.read((char *) imem, sizeof(imem));
    file.close();

    // CRITICAL: Your CPU has separate IM and DM interfaces, but C Compilers
    // assume a unified memory (Von Neumann).
    // We must copy the program into Data Memory too, so the Load/Store
    // instructions can access the global arrays and constants!
    memcpy(dmem, imem, sizeof(imem));
}

void verify_results(Vcpu *dut)
{
    printf("\n--- Verifying Test 6 Memory States (C Compiler Output) ---\n");

    // The C code was instructed to export the sorted array to 0x00000800
    // 0x800 / 4 = 512.
    int base_idx = 512;

    EXPECT_EQ(dmem[base_idx + 0], -4, "Array[0] should be -4");
    EXPECT_EQ(dmem[base_idx + 1], -3, "Array[1] should be -3");
    EXPECT_EQ(dmem[base_idx + 2], 0, "Array[2] should be 0");
    EXPECT_EQ(dmem[base_idx + 3], 1, "Array[3] should be 1");
    EXPECT_EQ(dmem[base_idx + 4], 2, "Array[4] should be 2");
    EXPECT_EQ(dmem[base_idx + 5], 3, "Array[4] should be 3");
    EXPECT_EQ(dmem[base_idx + 6], 4, "Array[4] should be 4");
    EXPECT_EQ(dmem[base_idx + 7], 5, "Array[4] should be 5");
    EXPECT_EQ(dmem[base_idx + 8], 14, "Array[4] should be 14");
    EXPECT_EQ(dmem[base_idx + 9], 18, "Array[4] should be 18");
}

#endif  // TEST6_H