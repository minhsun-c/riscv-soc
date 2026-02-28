## RISC-V 5-Stage Pipelined Processor (RV32I)

This project is a cycle-accurate implementation of a **RISC-V 32-bit Base Integer Instruction Set (RV32I)** processor. It features a classic 5-stage pipeline designed for educational clarity and modularity, utilizing **Verilator** for high-performance C++ simulation and testing.

---

## 📁 Project Structure

```text
.
├── core/
│   ├── include/          # Verilog Header files (*.vh) for opcodes and control constants
│   └── riscv/            # Modular RTL implementation of each pipeline stage
├── test/
│   ├── core_test/        # Assembly-level test cases for the integrated Core
│   ├── cpu_test/         # System-level test cases for CPU + Memory integration
│   ├── test_program/     # Complex C programs (Merge Sort, Josephus) for validation
│   ├── tb_*.cpp          # Unit testbenches for individual Verilog modules
│   └── checker.h         # Verification macros for automated result checking
├── docs/                 # RISC-V Architecture manuals and reference PDFs
└── Makefile              # Centralized build system for simulation and testing

```

---

## 🧩 Pipeline Components

The processor is divided into five stages, with dedicated pipeline registers and control units to manage data flow and hazards.

### 1. Instruction Fetch (IF)

* **`pc.v`**: Program Counter with stall and branch redirection support.
* **`if_stage.v`**: Calculates the next PC and fetches instructions from memory.
* **`if_id.v`**: Pipeline register that buffers fetched instructions; supports flushing for branch mispredictions.

### 2. Instruction Decode (ID)

* **`id_stage.v`**: Top-level decode stage encapsulating logic for control and register access.
* **`decoder.v`**: Slices raw 32-bit instructions into architectural fields.
* **`ctrl.v`**: Central control unit generating datapath signals.
* **`imm_gen.v`**: Extracts and sign-extends immediates for I, S, B, U, and J types.
* **`regfile.v`**: 32 x 32-bit register file; `x0` is internally hardwired to zero.
* **`id_ex.v`**: Pipeline register passing decoded data and control signals to the execution stage.

### 3. Execute (EX)

* **`ex_stage.v`**: Manages operand selection and functional unit execution.
* **`alu.v`**: Performs arithmetic, logic, and shifting operations.
* **`bcu.v`**: Branch Control Unit; evaluates branch conditions (BEQ, BLT, etc.) to determine PC redirection.
* **`ex_mem.v`**: Pipeline register passing ALU results and store data to the memory stage.

### 4. Memory (MEM)

* **`sram.v`**: Byte-addressable memory module handling Load/Store alignment (LB, LH, LW, SB, SH, SW).
* **`mem_wb.v`**: Pipeline register passing loaded data or ALU results to the write-back stage.

### 5. Write-Back (WB)

* **`wb_stage.v`**: Final multiplexer selecting data (ALU, Memory, or PC+4) to be retired into the Register File.

### System Support

* **`hdu.v`**: **Hazard Detection Unit**. Detects data hazards and asserts `stall` to resolve dependencies by freezing the IF/ID stages.
* **`mux2.v`**: Parametric 2-to-1 multiplexer used for datapath selection.
* **`core.v`**: Integrated 5-stage pipeline.
* **`cpu.v`**: Top-level SoC wrapper connecting the Core to separate Instruction and Data SRAMs.

---

## 🛠️ Prerequisites

Ensure your environment (Ubuntu/WSL recommended) has the following installed:

* **Verilator**: `sudo apt install verilator`
* **Build Essentials**: `sudo apt install build-essential`
* **GTKWave**: `sudo apt install gtkwave`

---

## 🚀 Usage & Verification

The project features a highly automated testing framework. Each `.v` module has a corresponding `tb_*.cpp` testbench in the `test/` directory.

### Unit Testing

To test a specific module (e.g., the ALU, Program Counter), run:

```bash
make alu
```

The Makefile compiles the RTL into a C++ model, links it with the testbench, and runs the simulation. Results are verified automatically via `checker.h`.

### Integrated Testing

To verify the entire CPU against complex software programs, run:

```bash
make cpu
```

The system currently supports **Testcases 1–8**, which include both assembly-level validation and C-compiled programs.

### Supported Testcases (1–8)

* **Normal Testing (Test 1–4):** Validates basic RV32I instruction functionality.
* **C Compiled Programs (Test 5–8):** Verifies the SoC's ability to execute complex algorithms, including:
  * **Merge Sort:** Testing recursion and memory indexing.
  * **Linked List:** Testing pointer manipulation and memory patterns.
  * **Josephus Problem:** Testing logical flow and mathematical computation.

To run a specific assigned test case, use:

```bash
make cpu TESTNUM=7
```

### Debugging with Waveforms

If a test fails, you can generate and view VCD (Value Change Dump) files:

1. Run the test (e.g., `make core`).
2. Open the waveform:
```bash
gtkwave waveform.vcd
```
