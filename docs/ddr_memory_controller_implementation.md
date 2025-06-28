# DDR Memory Controller Implementation

## Overview

The DDR memory controller subsystem on the VC707 FPGA board provides high-performance memory access to the RISC-V RocketChip through Xilinx's Memory Interface Generator (MIG) 7-Series IP. This subsystem implements a complete DDR3 SDRAM interface with advanced features including memory reset control, calibration sequencing, and AXI4 bus bridging.

## Key Architectural Insight: 16GB Design Capability vs 1GB Physical Implementation

**Critical Design Feature**: The RocketChip processor is designed with **16GB memory addressing capability** (34-bit address width), but the VC707 board is configured with only **1GB physical DDR memory**. This allows for memory expansion up to 16GB by changing the MIG configuration and installing larger SODIMMs.

### Vivado Address Editor Configuration

Based on the Vivado Address Editor analysis:

**RocketChip Memory Interface (MEM_AXI4):**
- Address Range: **16GB** (16G in Vivado notation - full addressing capability)
- Base Address: 0x00000000
- High Address: 0x3FFFF_FFFF  
- Address Width: 34-bit (supports up to 16GB addressing)

**MIG Controller (S_AXI):**
- Address Range: **1GB** (1G in Vivado notation - actual physical memory)
- Base Address: 0x00000000
- High Address: 0x3FFF_FFFF
- Address Width: 30-bit (1GB memory addressing)

## Bus Architecture and Connectivity

### AXI4 Interface Hierarchy

```
RocketChip (MEM_AXI4 16GB) → AXI SmartConnect → MIG Controller (1GB) → DDR3 SODIMM
```

**Address Translation**: The AXI SmartConnect provides address width conversion from the 34-bit system address space (16GB capability) to the 30-bit MIG controller address space (1GB physical memory), handling the physical memory range of 0x00000000 to 0x3FFFFFFF.

## Memory Configuration

**Memory Device Specifications (VC707 Default):**
- Memory Type: DDR3 SDRAM SODIMM (MT8KTF25664HZ-1G6)
- Physical Capacity: 1GB (out of 16GB addressable space)
- Data Width: 64-bit
- Organization: Single rank (1Rx64)

**Performance Characteristics:**
- Peak Bandwidth: 6.4 GB/s (64-bit × 800 MHz)
- Memory Interface Clock: 200 MHz input, 400 MHz internal
- AXI Interface: 512-bit data width
- Physical Memory Range: 0x00000000 to 0x3FFFFFFF (1GB)
- Addressable Space: 0x00000000 to 0x3FFFF_FFFF (16GB capability)

## Memory Expansion Options

The system supports memory expansion through different MIG project files:
- 1GB: DDR3-1Rx64-1GB.prj (current VC707 default)
- 2GB: DDR3-1Rx64-2GB.prj 
- 4GB: DDR3-1Rx64-4GB.prj
- 8GB: DDR3-2Rx64-8GB.prj