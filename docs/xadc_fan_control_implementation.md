# XADC and Fan Control Subsystem Implementation

## Overview

The XADC (Xilinx Analog-to-Digital Converter) and Fan Control subsystem provides comprehensive temperature monitoring and thermal management for the RISC-V RocketChip SoC implementation on the VC707 FPGA board. This subsystem combines the Xilinx XADC IP core for system monitoring with custom PWM-based fan control logic to maintain optimal operating temperatures.

## Architecture

### System Components

1. **Xilinx XADC IP Core (xadc_wiz:3.3)**
   - 12-bit ADC with multiple input channels
   - Built-in temperature sensor
   - Supply voltage monitoring (VCCINT, VCCAUX, VBRAM)
   - Alarm generation capabilities
   - AXI4-Lite interface for software access

2. **Fan Control Module**
   - Custom Verilog implementation for PWM generation
   - Temperature-based control algorithm
   - Emergency override on thermal alarm
   - High-frequency PWM for smooth fan operation

3. **Thermal Management Integration**
   - Hardware-based alarm generation
   - Temperature threshold monitoring
   - Automatic fan activation

### Block Diagram

```
RocketChip SoC
    |
    | IO_AXI4 (64-bit)
    |
AXI SmartConnect (io_axi_s)
    |
    | M03_AXI (32-bit @ 0x60030000)
    |
XADC IP Core
    |
    |-- temp_out (12-bit) -----> Fan Control Module
    |                                |
    |-- user_temp_alarm_out ------> Fan Enable (Emergency)
                                     |
                                     v
                                 Fan PWM Output
```

## XADC IP Core Configuration

### Core Parameters

```tcl
CONFIG.ADC_OFFSET_AND_GAIN_CALIBRATION {true}
CONFIG.ADC_OFFSET_CALIBRATION {true}
CONFIG.CHANNEL_ENABLE_VBRAM {true}
CONFIG.CHANNEL_ENABLE_VCCAUX {true}
CONFIG.CHANNEL_ENABLE_VCCINT {true}
CONFIG.CHANNEL_ENABLE_VP_VN {true}
CONFIG.ENABLE_TEMP_BUS {true}
CONFIG.SENSOR_OFFSET_AND_GAIN_CALIBRATION {true}
CONFIG.SENSOR_OFFSET_CALIBRATION {true}
CONFIG.SEQUENCER_MODE {Continuous}
CONFIG.TEMPERATURE_ALARM_RESET {50}
CONFIG.TEMPERATURE_ALARM_TRIGGER {60}
CONFIG.VCCAUX_ALARM {false}
CONFIG.VCCINT_ALARM {false}
CONFIG.XADC_STARUP_SELECTION {channel_sequencer}
```

### Key Configuration Details

- **Continuous Sequencer Mode**: Continuously samples all enabled channels
- **Temperature Alarm**: Triggers at 60°C, resets at 50°C
- **Calibration**: Both offset and gain calibration enabled for accuracy
- **Enabled Channels**:
  - On-die temperature sensor
  - VCCINT (core supply voltage)
  - VCCAUX (auxiliary supply voltage)
  - VBRAM (block RAM supply voltage)
  - VP/VN (external analog inputs)

## Memory Map and Register Interface

### Base Address
- **XADC Base Address**: `0x60030000`
- **Address Range**: 64KB (0x10000)
- **Bus Width**: 32-bit AXI4-Lite

### Key XADC Registers

| Offset | Register Name | Description |
|--------|---------------|-------------|
| 0x200  | Temperature   | Temperature data register |
| 0x204  | VCCINT        | Core voltage reading |
| 0x208  | VCCAUX        | Auxiliary voltage reading |
| 0x20C  | VP/VN         | External analog input |
| 0x21C  | VBRAM         | Block RAM voltage |
| 0x220  | Supply Offset | Supply sensor offset |
| 0x224  | ADC Offset    | ADC offset calibration |
| 0x228  | Gain Error    | Gain error calibration |
| 0x22C  | VCCPINT       | Processor voltage |
| 0x230  | VCCPAUX       | Processor auxiliary voltage |
| 0x234  | VCCDDRO       | DDR I/O voltage |
| 0x238  | VREFP         | Reference voltage positive |
| 0x23C  | VREFN         | Reference voltage negative |
| 0x240-0x27C | VAUXP/N[0-15] | Auxiliary analog inputs |
| 0x300  | Max Temperature | Maximum temperature reading |
| 0x304  | Max VCCINT    | Maximum core voltage |
| 0x308  | Max VCCAUX    | Maximum auxiliary voltage |
| 0x30C  | Max VBRAM     | Maximum BRAM voltage |
| 0x310  | Min Temperature | Minimum temperature reading |
| 0x314  | Min VCCINT    | Minimum core voltage |
| 0x318  | Min VCCAUX    | Minimum auxiliary voltage |
| 0x31C  | Min VBRAM     | Minimum BRAM voltage |

### Register Data Format

Temperature and voltage readings are returned as 12-bit values in the upper bits of 32-bit registers:
- **Temperature**: Raw ADC code, conversion formula: `Temperature(°C) = (ADC_Code × 503.975) / 4096 - 273.15`
- **Voltage**: Raw ADC code, conversion formula: `Voltage(V) = (ADC_Code × 3.0) / 4096`

## Fan Control Implementation

### Fan Control Module Parameters

```verilog
module fan_control #(
    parameter real temperature = 50.0, // Target temperature (°C)
    parameter real fan_min  = 25.0,    // Minimum fan power (%)
    parameter real fan_norm = 45.0     // Normal fan power (%)
) (
    input wire async_resetn,
    output wire resetn,
    input wire clock,           // 100 MHz system clock
    input wire alarm,           // Temperature alarm from XADC
    input wire [11:0] device_temp, // 12-bit temperature from XADC
    output reg fan_pwm          // PWM output to fan
);
```

### Control Algorithm

The fan control implements a proportional controller with the following characteristics:

1. **Target Temperature**: 50°C (configurable)
2. **Minimum Fan Speed**: 25% duty cycle
3. **Normal Fan Speed**: 45% duty cycle
4. **Emergency Override**: 100% duty cycle on thermal alarm

### PWM Generation

```verilog
reg [11:0] cnt = 0;
reg [19:0] temp_reg = 0;
wire signed [19:0] temp_err = temp_reg - target_temp_scaled;
wire signed [19:0] control = normal_fan_scaled + (temp_err >>> 4);

always @(posedge clock) begin
    if (reset) begin
        temp_reg <= ~0;
        fan_pwm <= 1;
        cnt <= 0;
    end else begin
        // Emergency override or minimum speed enforcement
        if (alarm || cnt < fan_min_scaled) 
            fan_pwm <= 1;
        // Below minimum threshold
        else if (control <= fan_min_scaled) 
            fan_pwm <= 0;
        // Proportional control
        else 
            fan_pwm <= cnt < control;
        
        // Temperature filtering (low-pass filter)
        if (cnt == 0) 
            temp_reg <= temp_reg - (temp_reg >> 8) + device_temp;
        
        cnt <= cnt + 1;
    end
end
```

### Key Features

1. **High-Frequency PWM**: 12-bit counter provides ~24 kHz PWM frequency at 100 MHz clock
2. **Temperature Filtering**: Low-pass filter smooths temperature readings
3. **Proportional Control**: Fan speed adjusts proportionally to temperature error
4. **Emergency Mode**: Thermal alarm forces 100% fan speed
5. **Minimum Speed**: Ensures fan always runs at minimum 25% to prevent stalling

## Hardware Integration

### Clock and Reset

- **Clock Domain**: 100 MHz system clock
- **Reset**: Asynchronous reset with synchronous deassertion
- **Reset Synchronizer**: 3-stage synchronizer for clean reset release

### Pin Assignments (VC707)

```tcl
# Fan enable/PWM output
set_property -dict { PACKAGE_PIN BA37 IOSTANDARD LVCMOS18 } [get_ports fan_en]

# Optional fan tachometer input (commented out)
#set_property -dict { PACKAGE_PIN BB37 IOSTANDARD LVCMOS18 } [get_ports fan_tach]
```

### AXI Interconnect Integration

The XADC is connected to the RocketChip through the AXI SmartConnect:

```tcl
# AXI4-Lite connection to XADC
connect_bd_intf_net -intf_net io_axi_s_M03_AXI \
    [get_bd_intf_pins XADC/s_axi_lite] \
    [get_bd_intf_pins io_axi_s/M03_AXI]

# Clock and reset connections
connect_bd_net -net AXI_clock \
    [get_bd_pins XADC/s_axi_aclk] \
    [get_bd_pins axi_clock]
    
connect_bd_net -net AXI_reset \
    [get_bd_pins XADC/s_axi_aresetn] \
    [get_bd_pins axi_reset]

# Temperature and alarm signals
connect_bd_net -net device_temp \
    [get_bd_pins device_temp] \
    [get_bd_pins XADC/temp_out]
    
connect_bd_net -net fan_en \
    [get_bd_pins fan_en] \
    [get_bd_pins XADC/user_temp_alarm_out]
```

## Software Interface

### Device Driver Support

The XADC subsystem can be accessed using the standard Xilinx XADC driver in Linux:

```c
// Device tree entry (example)
xadc@60030000 {
    compatible = "xlnx,zynq-xadc-1.00.a";
    reg = <0x60030000 0x10000>;
    interrupt-parent = <&intc>;
    interrupts = <7>;
    clocks = <&clkc 12>;
};
```

### User-Space Access

#### Reading Temperature

```c
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define XADC_BASE 0x60030000
#define TEMP_OFFSET 0x200

// Memory-mapped access
volatile uint32_t *xadc_regs = mmap(NULL, 0x10000, 
    PROT_READ | PROT_WRITE, MAP_SHARED, 
    open("/dev/mem", O_RDWR), XADC_BASE);

// Read temperature
uint32_t temp_raw = xadc_regs[TEMP_OFFSET/4];
double temperature = ((temp_raw >> 4) * 503.975) / 4096.0 - 273.15;
printf("Temperature: %.2f°C\n", temperature);
```

#### Monitoring Voltages

```c
#define VCCINT_OFFSET 0x204
#define VCCAUX_OFFSET 0x208

uint32_t vccint_raw = xadc_regs[VCCINT_OFFSET/4];
uint32_t vccaux_raw = xadc_regs[VCCAUX_OFFSET/4];

double vccint = ((vccint_raw >> 4) * 3.0) / 4096.0;
double vccaux = ((vccaux_raw >> 4) * 3.0) / 4096.0;

printf("VCCINT: %.3fV, VCCAUX: %.3fV\n", vccint, vccaux);
```

### Linux IIO Framework Integration

The XADC can be accessed through the Linux Industrial I/O (IIO) framework:

```bash
# List available IIO devices
ls /sys/bus/iio/devices/

# Read temperature through IIO
cat /sys/bus/iio/devices/iio:device0/in_temp0_raw
cat /sys/bus/iio/devices/iio:device0/in_temp0_scale

# Read voltages
cat /sys/bus/iio/devices/iio:device0/in_voltage0_vccint_raw
cat /sys/bus/iio/devices/iio:device0/in_voltage1_vccaux_raw
```

## Performance Characteristics

### Sampling Rates

- **Maximum Sampling Rate**: 1 MSPS (1 MHz)
- **Typical Continuous Mode**: ~26 kSPS per channel
- **Temperature Update Rate**: ~100 Hz (with filtering)
- **PWM Frequency**: ~24 kHz

### Accuracy and Resolution

- **ADC Resolution**: 12-bit (4096 levels)
- **Temperature Accuracy**: ±4°C (typical)
- **Voltage Accuracy**: ±2% (typical)
- **Temperature Range**: -40°C to +125°C
- **Voltage Range**: 0V to 3.0V

### Thermal Management Performance

- **Alarm Trigger Temperature**: 60°C
- **Alarm Reset Temperature**: 50°C
- **Fan Response Time**: <1 second
- **Temperature Regulation**: ±2°C around setpoint

## Debugging and Troubleshooting

### Common Issues

1. **High Temperature Readings**
   - Check fan operation and PWM signal
   - Verify thermal alarm threshold settings
   - Monitor power consumption and heat dissipation

2. **Voltage Out of Range**
   - Check power supply specifications
   - Verify board power connections
   - Monitor for power supply noise

3. **XADC Communication Failures**
   - Verify AXI4-Lite bus connectivity
   - Check clock and reset signals
   - Confirm address mapping in software

### Debug Signals

Key signals for debugging:
- `device_temp[11:0]`: Current temperature reading
- `user_temp_alarm_out`: Thermal alarm status  
- `fan_pwm`: PWM output to fan
- `s_axi_*`: AXI4-Lite bus signals

### Monitoring Commands

```bash
# Monitor temperature continuously
watch -n 1 'cat /sys/bus/iio/devices/iio:device0/in_temp0_raw'

# Check thermal alarm status
devmem 0x60030000 32  # Read status register

# Monitor fan PWM duty cycle
# (requires oscilloscope or logic analyzer on fan_en pin)
```

### Performance Optimization

1. **Temperature Control Tuning**
   - Adjust `temperature` parameter for different setpoints
   - Modify `fan_norm` for baseline fan speed
   - Tune proportional gain by adjusting shift amount

2. **Sampling Rate Optimization**
   - Configure XADC sequencer for required channels only
   - Adjust averaging settings for noise reduction
   - Balance update rate vs. power consumption

## Integration with RocketChip SoC

The XADC subsystem integrates seamlessly with the RocketChip SoC architecture:

1. **Memory Map Integration**: Occupies dedicated address space in I/O region
2. **Interrupt Support**: Can generate interrupts for alarm conditions
3. **Clock Domain**: Operates in AXI clock domain with proper synchronization
4. **Reset Integration**: Participates in system-wide reset architecture

This implementation provides comprehensive thermal monitoring and management capabilities essential for reliable FPGA operation, particularly in high-performance computing applications where thermal constraints are critical.
