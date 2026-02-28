#ifndef TEST8_H
#define TEST8_H

#include <cstring>
#include <fstream>

void load_program(const char *filename)
{
    printf("Loading Josephus Test: %s...\n", filename);
    std::ifstream file(filename, std::ios::binary);
    if (!file) {
        exit(1);
    }
    file.read((char *) imem, sizeof(imem));
    file.close();
    memcpy(dmem, imem, sizeof(imem));
}

void verify_results(Vcore *dut)
{
    printf("\n--- Verifying Test 8 (Josephus Problem) ---\n");
    // For n=6, k=3, the winner is 1.
    // Address 0x800 is dmem[512]
    EXPECT_EQ(dmem[512], 1, "Josephus Winner ID should be 1");
}

#endif