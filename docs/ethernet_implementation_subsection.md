```
Ethernet Subsystem Flow:
┌─────────────────┐    ┌──────────────────┐    ┌─────────────┐    ┌─────────────┐
│ Ethernet DMA    │◄──►│ SGMII 1Gbps      │◄──►│ SGMII PHY   │◄──►│ RJ45 Port   │
│ Controller      │    │ Ethernet         │    │             │    │             │
│ (ethernet.v)    │    │ (eth_mac_1g_fifo)│    │ (Hardware)  │    │ (Physical)  │
└─────────────────┘    └──────────────────┘    └─────────────┘    └─────────────┘
```

**Verification from code**:
- **Ethernet DMA Controller**: ethernet.v - handles AXI4 DMA transactions
- **SGMII 1Gbps Ethernet**: `verilog-ethernet/rtl/eth_mac_1g_fifo.v` - MAC layer with FIFOs
- **SGMII PHY**: Hardware IP core in VC707 FPGA 
- **RJ45 Port**: Physical connector on VC707 board



# Ethernet Subsystem Implementation

## Overview

The Ethernet subsystem provides high-speed network connectivity for the RISC-V RocketChip SoC, enabling communication with external systems and networks. The implementation consists of a four-layer architecture that bridges the processor's AXI4 bus interface to the physical Ethernet connection on the VC707 FPGA board.

## Architecture

The Ethernet subsystem is implemented as a hierarchical design with four distinct functional blocks, as illustrated in Figure X.X:

### 1. Ethernet DMA Controller

The Ethernet DMA Controller serves as the primary interface between the RocketChip SoC and the Ethernet MAC layer. This component is implemented in the `ethernet.v` module and provides the following key functionalities:

- **AXI4 Master Interface**: Implements a full AXI4 master interface for direct memory access to the system memory, enabling efficient packet buffer management without CPU intervention
- **AXI4-Lite Slave Interface**: Provides a control and status register interface for configuration and monitoring of the Ethernet subsystem
- **Packet Buffer Management**: Manages up to 16 packet buffers (configurable via `pkt_ptr_bits` parameter) with automatic buffer allocation and deallocation
- **Burst Transfer Support**: Supports configurable burst sizes (default 16 transfers) for optimal memory bandwidth utilization
- **Interrupt Generation**: Generates interrupts to notify the processor of packet reception and transmission completion events

Key design parameters include:
- Burst size: 16 transfers
- DMA word width: 32 bits
- DMA address width: 32 bits
- AXIS word width: 8 bits
- Maximum packet buffers: 16 (4-bit pointer)

### 2. SGMII 1Gbps Ethernet MAC

The MAC (Media Access Control) layer is implemented using the open-source `eth_mac_1g_fifo` module from the verilog-ethernet project. This component provides:

- **IEEE 802.3 Compliance**: Full compliance with Ethernet MAC standards for 1 Gigabit operation
- **FIFO Buffering**: Integrated TX and RX FIFOs to handle clock domain crossing and provide buffering
  - TX FIFO depth: 4096 entries with frame-level FIFO support
  - RX FIFO depth: 16384 entries with frame-level FIFO support
- **Frame Processing**: Automatic frame padding, FCS generation and checking, and frame validation
- **AXIS Interface**: AXI4-Stream interface for data streaming to/from the DMA controller
- **GMII Interface**: Standard GMII (Gigabit Media Independent Interface) for connection to the PHY layer

Configuration features:
- Automatic padding enabled for minimum frame length compliance
- Minimum frame length: 64 bytes
- Frame-level FIFO operation for improved error handling
- Bad frame dropping disabled for debugging purposes

### 3. SGMII PHY Interface

The Physical Layer (PHY) interface is implemented using Xilinx's integrated SGMII IP core within the VC707 FPGA. This layer provides:

- **SGMII Protocol**: Serial Gigabit Media Independent Interface implementation for efficient high-speed signaling
- **Auto-negotiation**: Automatic speed and duplex negotiation with link partners
- **Clock Generation**: Generates the required 125 MHz clock for Gigabit operation
- **Signal Conditioning**: Provides proper signal levels and timing for the physical interface

The SGMII configuration includes:
- Auto-negotiation enabled
- Full-duplex operation
- Link status monitoring
- Speed adaptation (10/100/1000 Mbps)

### 4. Physical RJ45 Interface

The physical layer terminates at the RJ45 connector on the VC707 board, providing:

- **Standard RJ45 Connector**: Industry-standard 8P8C connector for Ethernet cables
- **Differential Signaling**: Supports standard Ethernet differential pair signaling
- **EMI/EMC Compliance**: Proper isolation and filtering for electromagnetic compatibility
- **LED Indicators**: Status LEDs for link activity and speed indication

## Integration with RocketChip

The Ethernet subsystem integrates with the RocketChip SoC through the following interfaces:

### Bus Connectivity
- **PeripheryBus Connection**: The Ethernet DMA controller connects to the RocketChip PeripheryBus as an AXI4 master device
- **Memory Access**: Direct access to system memory through the SystemBus for packet buffer operations
- **Control Interface**: Memory-mapped control registers accessible through the processor's memory map

### Interrupt Handling
- **PLIC Integration**: Ethernet interrupts are routed through the Platform-Level Interrupt Controller (PLIC)
- **Interrupt Sources**: 
  - Packet reception completion
  - Packet transmission completion
  - Error conditions (collision, CRC errors, etc.)

### Address Mapping
The Ethernet controller is mapped to the peripheral address space, typically at:
- Base address: 0x6200_0000 (configurable)
- Address range: 64KB for control registers and packet descriptors

## Software Interface

The Ethernet subsystem is supported by a custom Linux device driver that provides:

- **Network Device Interface**: Standard Linux network interface (eth0)
- **Buffer Management**: Efficient packet buffer allocation and management
- **Interrupt Handling**: Proper interrupt service routines for packet processing
- **Performance Optimization**: Support for NAPI (New API) for improved network performance

## Performance Characteristics

The implemented Ethernet subsystem provides the following performance characteristics:

- **Maximum Throughput**: Up to 1 Gbps full-duplex operation
- **Latency**: Low-latency packet processing with hardware-accelerated DMA
- **CPU Utilization**: Minimal CPU overhead due to hardware-accelerated packet processing
- **Memory Bandwidth**: Efficient burst transfers minimize memory bus utilization

## Design Considerations

Several key design decisions were made to optimize the Ethernet implementation:

### Clock Domain Crossing
- Proper clock domain crossing techniques are employed between the system clock and Ethernet clock domains
- Asynchronous FIFOs provide safe data transfer between domains

### Error Handling
- Comprehensive error detection and reporting at all layers
- Graceful handling of network errors and recovery mechanisms

### Configurability
- Parameterized design allows for easy adaptation to different FPGA platforms
- Configurable buffer sizes and burst parameters for performance tuning

### Xilinx-Specific Optimizations
- The design includes Xilinx-specific patches (ethernet.patch) to optimize RGMII timing
- Proper utilization of Xilinx SGMII IP cores for reliable high-speed operation

## Verification and Testing

The Ethernet implementation has been thoroughly verified through:

- **Functional Simulation**: Comprehensive testbenches verify proper protocol operation
- **Hardware Testing**: Validated on actual VC707 hardware with various network configurations
- **Performance Testing**: Throughput and latency measurements confirm design targets
- **Interoperability Testing**: Verified compatibility with standard network equipment

This multi-layered Ethernet implementation provides a robust, high-performance network interface that enables the RISC-V RocketChip SoC to participate effectively in modern network environments while maintaining the flexibility and configurability required for research and development applications.
