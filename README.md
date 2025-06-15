# HCMUS FETEL Graduation Thesis Report

Work in progress!

## Mục tiêu
- Hiểu cấu trúc Chipyard
- Dùng chipyard, xây dựng RocketChip kết hợp Gemmini 
- Chạy Linux trên RocketChip có core Gemmini
- Xây dựng mô hình (chưa làm)

## Kết quả hiện tại

Trước tiên, đã hiểu được rằng Chipyard là một framework. 
Sau đó, đã xây dựng được một hệ thống Rocket Chip (cấu hình 1 Big Core có Gemmini Accelerator (Rocket64b1gem16 , https://github.com/eugene-tarassov/vivado-risc-v)) trên board VC707.
Sau đó, chạy Linux trên hệ thống đó (https://github.com/eugene-tarassov/vivado-risc-v)
Sau đó, build và chạy https://github.com/ucb-bar/gemmini-rocc-tests/blob/dev/bareMetalC/template.c này thử, và thành công.

## Chuẩn bị làm (aka chưa làm)

Mô hình Machine Learning Arrhythmia Time-Series Anomaly Detection.

## Cơ sở lý thuyết
- Chipyard
- Rocket Chip (RISC-V, Scala and Chisel)
- Gemmini Accelerator
- Linux (và những thứ trong https://github.com/eugene-tarassov/vivado-risc-v mà đã giúp cho hệ thống boot được vào Debian)
- ... phần Anomaly Dectection sẽ làm, hiện tại chưa thực hiện

## Implementation

Using config Rocket64b1gem16:

class WithGemmini(mesh_size: Int, bus_bits: Int) extends Config((site, here, up) => {
  case BuildRoCC => up(BuildRoCC) ++ Seq(
    (p: Parameters) => {
      implicit val q = p
      implicit val v = implicitly[ValName]
      LazyModule(new gemmini.Gemmini(gemmini.GemminiConfigs.defaultConfig.copy(
        meshRows = mesh_size, meshColumns = mesh_size, dma_buswidth = bus_bits)))
    }
  )
  case SystemBusKey => up(SystemBusKey).copy(beatBytes = bus_bits/8)
})

class BaseConfig extends Config(
  new WithDefaultMemPort ++
  new WithDefaultMMIOPort ++
  new WithDefaultSlavePort ++
  new WithTimebase(BigInt(1000000)) ++ // 1 MHz
  new WithDTS("freechips,rocketchip-unknown", Nil) ++
  new WithNExtTopInterrupts(2) ++
  new BaseSubsystemConfig
)

class RocketBaseConfig extends Config(
  new WithBootROMFile("workspace/bootrom.img") ++
  new WithExtMemSize(0x380000000L) ++
  new WithNExtTopInterrupts(8) ++
  new WithDTS("freechips,rocketchip-vivado", Nil) ++
  new WithDebugSBA ++
  new WithEdgeDataBits(64) ++
  new WithCoherentBusTopology ++
  new WithoutTLMonitors ++
  new BaseConfig)


class Rocket64b1gem16 extends Config(
  new WithGemmini(16, 64) ++
  new WithInclusiveCache  ++
  new WithNBreakpoints(8) ++
  new WithNBigCores(1)    ++
  new RocketBaseConfig)


  
