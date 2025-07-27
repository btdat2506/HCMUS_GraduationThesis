# RISC-V RocketChip Peripheral Architecture Overview

## Introduction

This document provides a comprehensive overview of the peripheral architecture implemented in the RISC-V RocketChip SoC design for the VC707 FPGA board. The system integrates multiple high-performance peripherals through a hierarchical AXI4 bus architecture, providing comprehensive I/O capabilities for embedded Linux and bare-metal applications.

## System Architecture

### Bus Hierarchy

The peripheral subsystem is organized around a two-tier AXI4 bus architecture:

```
                    RocketChip SoC Core
                    ┌─────────┴─────────┐
             MEM_AXI4             IO_AXI4
                    │                   │
             AXI SmartConnect    AXI SmartConnect 
              (Memory Bus)       (I/O Peripherals)
                    │                   │
              DDR Controller      ┌─────┼─────┐
                                 │     │     │     
                             UART   SD  Ethernet
                                       │
                                     XADC
```

### Address Map Overview

| Component | Base Address | Range | Description |
|-----------|--------------|-------|-------------|
| DDR Memory | 0x80000000 | 2GB | Main system memory via MIG controller |
| SD Card | 0x60000000 | 64KB | AXI4-Lite interface to SD controller |
| UART | 0x60010000 | 64KB | AXI4-Lite interface to UART controller |
| Ethernet | 0x60020000 | 64KB | AXI4-Lite interface to Ethernet MAC |
| XADC | 0x60030000 | 64KB | AXI4-Lite interface to XADC/thermal |

## Peripheral Subsystems

### 1. Control Bus Peripherals

**Location**: On-chip RocketChip core  
**Documentation**: `control_bus_peripherals_implementation.md`

These peripherals are integrated directly within the RocketChip Scala/Chisel design:

- **BootROM**: 64KB bootstrap ROM with first-stage bootloader
- **CLINT** (Core-Local Interruptor): Timer and software interrupts
- **PLIC** (Platform-Level Interrupt Controller): External interrupt management  
- **Debug Unit**: JTAG-based debug support with system bus access

### 2. Memory Subsystem

**Location**: FPGA fabric  
**Documentation**: `ddr_memory_controller_implementation.md`

- **DDR3 Controller**: Xilinx MIG 7-Series IP core
- **Capacity**: 2GB DDR3 SODIMM (expandable)
- **Performance**: 512-bit AXI4 interface, 800 MT/s
- **Features**: ECC support, memory calibration, advanced timing closure

### 3. Communication Peripherals

#### UART Controller
**Documentation**: `uart_controller_implementation.md`

- **Implementation**: Custom Verilog with AXI4-Lite interface
- **Features**: Hardware flow control (XON/XOFF), interrupt support
- **Performance**: Configurable baud rates up to 3 Mbaud
- **Buffer**: 16-entry TX/RX FIFOs with programmable thresholds

#### Ethernet Controller  
**Documentation**: `ethernet_implementation_subsection.md`

- **Implementation**: Custom AXI4 streaming with 1G MAC integration
- **Features**: Hardware checksum offload, scatter-gather DMA
- **Performance**: 1 Gigabit Ethernet with SGMII PHY interface
- **Buffer**: Packet-based buffering with descriptor rings

### 4. Storage Interface

**Location**: FPGA fabric  
**Documentation**: `sd_card_controller_implementation.md`

- **Implementation**: Custom Verilog with dual AXI4 interface
- **Features**: SD/SDHC/SDXC support, DMA transfers, card detection
- **Performance**: Up to 50 MHz SD clock, burst DMA transfers
- **Interface**: SDIO-compatible 4-bit interface

### 5. System Monitoring

**Location**: FPGA fabric  
**Documentation**: `xadc_fan_control_implementation.md`

- **XADC**: Xilinx 12-bit ADC with temperature and voltage monitoring
- **Fan Control**: PWM-based thermal management with alarm override
- **Features**: Continuous monitoring, programmable alarms, IIO support
- **Integration**: AXI4-Lite register interface with Linux driver support

## Key Design Features

### 1. Hierarchical Interrupt Architecture

```
External Interrupts → PLIC → RocketChip Core
Timer Interrupts   → CLINT → RocketChip Core
Software Interrupts → CLINT → RocketChip Core
```

- **PLIC**: Manages 3 external interrupt sources (UART, SD, Ethernet)
- **CLINT**: Provides timer and IPI support for SMP operation
- **Priority-based**: Hardware interrupt prioritization and masking

### 2. Clock Domain Architecture

- **System Clock**: 100 MHz (AXI peripherals, CPU)
- **Memory Clock**: 200 MHz input, 400/800 MHz DDR3 interface
- **Ethernet Clock**: 125 MHz SGMII, 200 MHz processing
- **SD Clock**: Variable 400 kHz - 50 MHz
- **Clock Crossing**: SmartConnect provides domain crossing

### 3. Reset Architecture

- **Power-on Reset**: Board-level reset from push button
- **System Reset**: Distributed through clock domains
- **Peripheral Reset**: Individual reset control per peripheral
- **Memory Reset**: Coordinated with DDR calibration

### 4. DMA Architecture

Multiple peripherals implement DMA capabilities:

- **Ethernet**: Descriptor-based scatter-gather DMA
- **SD Card**: Burst DMA with 4KB boundary handling  
- **Memory**: High-performance AXI4 bursts to DDR

## Software Integration

### Boot Sequence

1. **BootROM**: First-stage bootloader (Xilinx FSBL equivalent)
2. **OpenSBI**: Supervisor Binary Interface and M-mode runtime
3. **U-Boot**: Universal bootloader with peripheral drivers
4. **Linux**: Full OS with device driver support

### Device Tree Integration

All peripherals are described in device tree with proper:
- Memory-mapped register regions
- Interrupt routing through PLIC  
- Clock specifications
- DMA channel assignments
- Board-specific pin configurations

### Driver Support

- **Standard Drivers**: Linux subsystem integration (tty, net, mmc, iio)
- **Custom Drivers**: Board-specific patches for AXI peripherals
- **U-Boot Support**: Early boot peripheral access
- **Bare-metal**: Direct register access examples

## Performance Characteristics

### Memory Bandwidth
- **Peak DDR3**: ~6.4 GB/s theoretical (800 MT/s × 64-bit interface)
- **Sustained**: ~4-5 GB/s typical with RocketChip workloads
- **Latency**: ~80-100 ns first-word latency

### I/O Throughput
- **Ethernet**: 1 Gbps line rate with hardware acceleration
- **UART**: Up to 3 Mbaud with flow control
- **SD Card**: Up to 400 Mbps (50 MHz × 8-bit theoretical)

### Interrupt Latency
- **PLIC**: ~10-20 cycles interrupt delivery
- **Total**: <1 us typical interrupt response time

## Debug and Development Features

### Hardware Debug
- **JTAG**: Full system debug through OpenOCD
- **Debug Unit**: Hardware breakpoints, memory access
- **System Bus**: Debug access to all peripherals

### Software Debug
- **UART Console**: Primary debug interface
- **Ethernet**: Network-based debugging and file transfer
- **Instrumentation**: Performance counters, tracing support

### Development Tools
- **Vivado**: FPGA synthesis and implementation
- **Scala/Chisel**: RocketChip customization
- **GNU Toolchain**: RISC-V cross-compilation
- **OpenOCD**: JTAG debugging interface

## Verification and Testing

### Hardware Verification
- **Simulation**: ModelSim/VCS testbenches for each peripheral
- **FPGA Testing**: Real-world validation on VC707 board
- **Timing Closure**: Static timing analysis at target frequencies

### Software Testing
- **Linux Boot**: Full OS bring-up and regression testing
- **Driver Testing**: Peripheral-specific test suites
- **Performance**: Benchmarking and profiling tools
- **Stress Testing**: Long-term stability validation

## Future Extensions

The peripheral architecture supports easy extension through:

### Additional AXI4 Peripherals
- **GPIO Controller**: General-purpose I/O expansion
- **SPI Controller**: Additional serial peripheral support
- **I2C Controller**: System management bus
- **CAN Controller**: Automotive networking

### Performance Enhancements
- **PCIe Integration**: High-speed expansion interface
- **Accelerator Integration**: Custom compute units
- **Multi-core Scaling**: Additional RocketChip cores
- **Memory Expansion**: DDR4 support, increased capacity

### Board Variants
- **Artix-7**: Cost-optimized implementation
- **Zynq UltraScale+**: ARM+FPGA hybrid platform
- **Custom Boards**: Application-specific variants

## Conclusion

The RISC-V RocketChip peripheral architecture provides a comprehensive, high-performance platform for embedded systems development. The hierarchical bus architecture, comprehensive peripheral set, and robust software support enable rapid development of complex embedded applications while maintaining excellent performance and reliability characteristics.

The modular design allows for easy customization and extension, making it suitable for both educational use and commercial applications requiring a flexible, open-source embedded platform.

## Related Documentation

- `control_bus_peripherals_implementation.md` - Control Bus Peripherals
- `ddr_memory_controller_implementation.md` - DDR Memory Subsystem  
- `uart_controller_implementation.md` - UART Communication
- `ethernet_implementation_subsection.md` - Ethernet Networking
- `sd_card_controller_implementation.md` - Storage Interface
- `xadc_fan_control_implementation.md` - System Monitoring

For board-specific details, refer to the `/board/vc707/` directory containing Vivado TCL scripts, pin constraints, and timing specifications.
