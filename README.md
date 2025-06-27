# HCMUS FETEL Graduation Thesis Report

To build the latex pdf file, run the following code block in the terminal at the repository directory:

```powershell
./build.ps1
```

For the documents of the system implementation of the ```Rocket64b1gem16``` on the VC707: 
- DDR: [docs/ddr_memory_controller_implementation.md](docs/ddr_memory_controller_implementation.md)
- UART: [docs/uart_controller_implementation.md](docs/uart_controller_implementation.md)
- Ethernet: [docs/ethernet_implementation_subsection.md](docs/ethernet_implementation_subsection.md)
- Control Bus: [docs/control_bus_peripherals_implementation.md](docs/control_bus_peripherals_implementation.md)
- SD Card: [docs/sd_card_controller_implementation.md](docs/sd_card_controller_implementation.md)
- XADC Fan Control: [docs/xadc_fan_control_implementation.md](docs/xadc_fan_control_implementation.md)
- Gemmini: [docs/gemmini.md](docs/gemmini.md)



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


Let's first take a look what what examples Chipyard provides for constructing a SoC (Rocket-chip based in this case).

//Below is from (https://raw.githubusercontent.com/ucb-bar/chipyard/refs/heads/stable/docs/Advanced-Concepts/Top-Testharness.rst ; https://chipyard.readthedocs.io/en/stable/Advanced-Concepts/Top-Testharness.html) Chipyard documentation

Tops, Test-Harnesses, and the Test-Driver
===========================================

The three highest levels of hierarchy in a Chipyard
SoC are the ``ChipTop`` (DUT), ``TestHarness``, and the ``TestDriver``.
The ``ChipTop`` and ``TestHarness`` are both emitted by Chisel generators.
The ``TestDriver`` serves as our testbench, and is a Verilog
file in Rocket Chip.


ChipTop/DUT
-------------------------

``ChipTop`` is the top-level module that instantiates the ``System`` submodule, usually an instance of the concrete class ``DigitalTop``.
The vast majority of the design resides in the ``System``.
Other components that exist inside the ``ChipTop`` layer are generally IO cells, clock receivers and multiplexers, reset synchronizers, and other analog IP that needs to exist outside of the ``System``.
The ``IOBinders`` are responsible for instantiating the IO cells for ``ChipTop`` IO that correspond to IO of the ``System``.
The ``HarnessBinders`` are responsible for instantiating test harness collateral that connects to the ``ChipTop`` ports.
Most types of devices and testing collateral can be instantiated using custom ``IOBinders`` and ``HarnessBinders``.

Custom ChipTops
^^^^^^^^^^^^^^^^^^^^^^^^^

The default standard ``ChipTop`` provides a mimimal, barebones template for ``IOBinders`` to generate IOCells around ``DigitalTop`` traits.
For tapeouts, integrating Analog IP, or other non-standard use cases, Chipyard supports specifying a custom ``ChipTop`` using the ``BuildTop`` key.
An example of a custom ChipTop which uses non-standard IOCells is provided in `generators/chipyard/src/main/scala/example/CustomChipTop.scala <https://github.com/ucb-bar/chipyard/blob/main/generators/chipyard/src/main/scala/example/CustomChipTop.scala>`__


System/DigitalTop
-------------------------

The system module of a Rocket Chip SoC is composed via cake-pattern.
Specifically, ``DigitalTop`` extends a ``System``, which extends a ``Subsystem``, which extends a ``BaseSubsystem``.


BaseSubsystem
^^^^^^^^^^^^^^^^^^^^^^^^^

The ``BaseSubsystem`` is defined in ``generators/rocketchip/src/main/scala/subsystem/BaseSubsystem.scala``.
Looking at the ``BaseSubsystem`` abstract class, we see that this class instantiates the top-level buses
(frontbus, systembus, peripherybus, etc.), but does not specify a topology.
We also see this class define several ``ElaborationArtefacts``, files emitted after Chisel elaboration
(e.g. the device tree string, and the diplomacy graph visualization GraphML file).

Subsystem
^^^^^^^^^^^^^^^^^^^^^^^^^

Looking in `generators/chipyard/src/main/scala/Subsystem.scala <https://github.com/ucb-bar/chipyard/blob/main/generators/chipyard/src/main/scala/Subsystem.scala>`__, we can see how Chipyard's ``Subsystem``
extends the ``BaseSubsystem`` abstract class. ``Subsystem`` mixes in the ``HasBoomAndRocketTiles`` trait that
defines and instantiates BOOM or Rocket tiles, depending on the parameters specified.
We also connect some basic IOs for each tile here, specifically the hartids and the reset vector.

System
^^^^^^^^^^^^^^^^^^^^^^^^^

``generators/chipyard/src/main/scala/System.scala`` completes the definition of the ``System``.

- ``HasHierarchicalBusTopology`` is defined in Rocket Chip, and specifies connections between the top-level buses
- ``HasAsyncExtInterrupts`` and ``HasExtInterruptsModuleImp`` adds IOs for external interrupts and wires them appropriately to tiles
- ``CanHave...AXI4Port`` adds various Master and Slave AXI4 ports, adds TL-to-AXI4 converters, and connects them to the appropriate buses
- ``HasPeripheryBootROM`` adds a BootROM device

Tops
^^^^^^^^^^^^^^^^^^^^^^^^^

A SoC Top then extends the ``System`` class with traits for custom components.
In Chipyard, this includes things like adding a NIC, UART, and GPIO as well as setting up the hardware for the bringup method.
Please refer to :ref:`Advanced-Concepts/Chip-Communication:Communicating with the DUT` for more information on these bringup methods.

TestHarness
-------------------------

The wiring between the ``TestHarness`` and the Top are performed in methods defined in traits added to the Top.
When these methods are called from the ``TestHarness``, they may instantiate modules within the scope of the harness,
and then connect them to the DUT. For example, the ``connectSimAXIMem`` method defined in the
``CanHaveMasterAXI4MemPortModuleImp`` trait, when called from the ``TestHarness``, will instantiate ``SimAXIMems``
and connect them to the correct IOs of the top.

While this roundabout way of attaching to the IOs of the top may seem to be unnecessarily complex, it allows the designer to compose
custom traits together without having to worry about the details of the implementation of any particular trait.

TestDriver
-------------------------

The ``TestDriver`` is defined in ``generators/rocketchip/src/main/resources/vsrc/TestDriver.v``.
This Verilog file executes a simulation by instantiating the ``TestHarness``, driving the clock and reset signals, and interpreting the success output.
This file is compiled with the generated Verilog for the ``TestHarness`` and the ``Top`` to produce a simulator.


//End of Chipyard documentation references


So here I create a custom config:

```Scala code
package chipyard

import org.chipsalliance.cde.config.{Config, Parameters}
import freechips.rocketchip.system._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tile.{BuildRoCC, OpcodeSet}
import freechips.rocketchip.diplomacy._

...


class Rocket64b1gem16 extends Config(
  new WithGemmini(16, 64) ++
  new WithInclusiveCache  ++
  new WithNBreakpoints(8) ++
  new WithNBigCores(1)    ++
  new WithBootROMFile("workspace/bootrom.img") ++
  new WithExtMemSize(0x380000000L) ++
  new WithNExtTopInterrupts(8) ++
  new WithDTS("freechips,rocketchip-vivado", Nil) ++
  new WithDebugSBA ++
  new WithEdgeDataBits(64) ++
  new WithCoherentBusTopology ++
  new WithoutTLMonitors ++
  new BaseConfig)
```

This is Rocket 64-bit (1 Big Core) with 16x16 Gemmini (called Rocket64b1gem16 for short).

Here's the BaseConfig which it uses:

```scala
package freechips.rocketchip.system

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem._
import freechips.rocketchip.rocket._

class WithJtagDTMSystem extends freechips.rocketchip.subsystem.WithJtagDTM
class WithDebugSBASystem extends freechips.rocketchip.subsystem.WithDebugSBA
class WithDebugAPB extends freechips.rocketchip.subsystem.WithDebugAPB

class BaseConfig extends Config(
  new WithDefaultMemPort ++
  new WithDefaultMMIOPort ++
  new WithDefaultSlavePort ++
  new WithTimebase(BigInt(1000000)) ++ // 1 MHz
  new WithDTS("freechips,rocketchip-unknown", Nil) ++
  new WithNExtTopInterrupts(2) ++
  new BaseSubsystemConfig
)

```

```scala
package freechips.rocketchip.subsystem

import chisel3.util._

import org.chipsalliance.cde.config._
import org.chipsalliance.diplomacy.lazymodule._

import freechips.rocketchip.devices.debug.{DebugModuleKey, DefaultDebugModuleParams, ExportDebug, JTAG, APB}
import freechips.rocketchip.devices.tilelink.{
  BuiltInErrorDeviceParams, BootROMLocated, BootROMParams, CLINTKey, DevNullDevice, CLINTParams, PLICKey, PLICParams, DevNullParams
}
import freechips.rocketchip.prci.{SynchronousCrossing, AsynchronousCrossing, RationalCrossing, ClockCrossingType}
import freechips.rocketchip.diplomacy.{
  AddressSet, MonitorsEnabled,
}
import freechips.rocketchip.resources.{
  DTSModel, DTSCompat, DTSTimebase, BigIntHexContext
}
import freechips.rocketchip.tile.{
  MaxHartIdBits, RocketTileParams, BuildRoCC, AccumulatorExample, OpcodeSet, TranslatorExample, CharacterCountExample, BlackBoxExample
}
import freechips.rocketchip.util.{ClockGateModelFile, SystemFileName}
import scala.reflect.ClassTag

case object MaxXLen extends Field[Int]

class BaseSubsystemConfig extends Config ((site, here, up) => {
  // Tile parameters
  case MaxXLen => (site(PossibleTileLocations).flatMap(loc => site(TilesLocated(loc)))
    .map(_.tileParams.core.xLen) :+ 32).max
  case MaxHartIdBits => log2Up((site(PossibleTileLocations).flatMap(loc => site(TilesLocated(loc)))
      .map(_.tileParams.tileId) :+ 0).max+1)
  // Interconnect parameters
  case SystemBusKey => SystemBusParams(
    beatBytes = 8,
    blockBytes = site(CacheBlockBytes))
  case ControlBusKey => PeripheryBusParams(
    beatBytes = 8,
    blockBytes = site(CacheBlockBytes),
    dtsFrequency = Some(100000000), // Default to 100 MHz cbus clock
    errorDevice = Some(BuiltInErrorDeviceParams(
      errorParams = DevNullParams(List(AddressSet(0x3000, 0xfff)), maxAtomic=8, maxTransfer=4096))))
  case PeripheryBusKey => PeripheryBusParams(
    beatBytes = 8,
    blockBytes = site(CacheBlockBytes),
    dtsFrequency = Some(100000000)) // Default to 100 MHz pbus clock
  case MemoryBusKey => MemoryBusParams(
    beatBytes = 8,
    blockBytes = site(CacheBlockBytes))
  case FrontBusKey => FrontBusParams(
    beatBytes = 8,
    blockBytes = site(CacheBlockBytes))
  // Additional device Parameters
  case BootROMLocated(InSubsystem) => Seq(BootROMParams(contentFileName = SystemFileName("./bootrom/bootrom.img")))
  case HasTilesExternalResetVectorKey => false
  case DebugModuleKey => Some(DefaultDebugModuleParams(64))
  case CLINTKey => Some(CLINTParams())
  case PLICKey => Some(PLICParams())
  case TilesLocated(InSubsystem) => Nil
  case PossibleTileLocations => Seq(InSubsystem)
})
```

```scala
package freechips.rocketchip.rocket

import chisel3.util._

import org.chipsalliance.cde.config._
import org.chipsalliance.diplomacy.lazymodule._

import freechips.rocketchip.prci.{SynchronousCrossing, AsynchronousCrossing, RationalCrossing, ClockCrossingType}
import freechips.rocketchip.subsystem.{TilesLocated, NumTiles, HierarchicalLocation, RocketCrossingParams, SystemBusKey, CacheBlockBytes, RocketTileAttachParams, InSubsystem, InCluster, HierarchicalElementMasterPortParams, HierarchicalElementSlavePortParams, CBUS, CCBUS, ClustersLocated, TileAttachConfig, CloneTileAttachParams}
import freechips.rocketchip.tile.{RocketTileParams, RocketTileBoundaryBufferParams, FPUParams}
import freechips.rocketchip.util.{RationalDirection, Flexible}
import scala.reflect.ClassTag

class WithNBigCores(
  n: Int,
  location: HierarchicalLocation,
  crossing: RocketCrossingParams,
) extends Config((site, here, up) => {
  case TilesLocated(`location`) => {
    val prev = up(TilesLocated(`location`), site)
    val idOffset = up(NumTiles)
    val big = RocketTileParams(
      core   = RocketCoreParams(mulDiv = Some(MulDivParams(
        mulUnroll = 8,
        mulEarlyOut = true,
        divEarlyOut = true))),
      dcache = Some(DCacheParams(
        rowBits = site(SystemBusKey).beatBits,
        nMSHRs = 0,
        blockBytes = site(CacheBlockBytes))),
      icache = Some(ICacheParams(
        rowBits = site(SystemBusKey).beatBits,
        blockBytes = site(CacheBlockBytes))))
    List.tabulate(n)(i => RocketTileAttachParams(
      big.copy(tileId = i + idOffset),
      crossing
    )) ++ prev
  }
  case NumTiles => up(NumTiles) + n
}) {
  def this(n: Int, location: HierarchicalLocation = InSubsystem) = this(n, location, RocketCrossingParams(
    master = HierarchicalElementMasterPortParams.locationDefault(location),
    slave = HierarchicalElementSlavePortParams.locationDefault(location),
    mmioBaseAddressPrefixWhere = location match {
      case InSubsystem => CBUS
      case InCluster(clusterId) => CCBUS(clusterId)
    }
  ))
}
```

For the RoCC connection:

Let's go back to this:

```Scala code
package chipyard

import org.chipsalliance.cde.config.{Config, Parameters}
import freechips.rocketchip.system._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tile.{BuildRoCC, OpcodeSet}
import freechips.rocketchip.diplomacy._

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

class Rocket64b1gem16 extends Config(
  new WithGemmini(16, 64) ++
  new WithInclusiveCache  ++
  new WithNBreakpoints(8) ++
  new WithNBigCores(1)    ++
  new WithBootROMFile("workspace/bootrom.img") ++
  new WithExtMemSize(0x380000000L) ++
  new WithNExtTopInterrupts(8) ++
  new WithDTS("freechips,rocketchip-vivado", Nil) ++
  new WithDebugSBA ++
  new WithEdgeDataBits(64) ++
  new WithCoherentBusTopology ++
  new WithoutTLMonitors ++
  new BaseConfig)
```

In the rocket-chip/src/main/scala/tile/LazyRoCC.scala will have definition of an RoCC.
So, integrating Gemmini RoCC using LazyModule and LazyRoCC (via BuildRoCC)

Now come how the Gemmini give RoCC ports:

```scala generators/gemmini/src/main/scala/gemmini/Controller.scala
class Gemmini[T <: Data : Arithmetic, U <: Data, V <: Data](val config: GemminiArrayConfig[T, U, V])
                                     (implicit p: Parameters)
  extends LazyRoCC (
    opcodes = config.opcodes,
    nPTWPorts = if (config.use_shared_tlb) 1 else 2) {

  Files.write(Paths.get(config.headerFilePath), config.generateHeader().getBytes(StandardCharsets.UTF_8))
  if (System.getenv("GEMMINI_ONLY_GENERATE_GEMMINI_H") == "1") {
    System.exit(1)
  }

  val xLen = p(XLen)
  val spad = LazyModule(new Scratchpad(config))

  override lazy val module = new GemminiModule(this)
  override val tlNode = if (config.use_dedicated_tl_port) spad.id_node else TLIdentityNode()
  override val atlNode = if (config.use_dedicated_tl_port) TLIdentityNode() else spad.id_node

  val node = if (config.use_dedicated_tl_port) tlNode else atlNode
}

class GemminiModule[T <: Data: Arithmetic, U <: Data, V <: Data]
    (outer: Gemmini[T, U, V])
    extends LazyRoCCModuleImp(outer)
    with HasCoreParameters {

...
```

We see the in the Gemmini class, it uses the config from GemminiArrayConfig. Take a look inside of GemminiArrayConfig, we see it uses the OpcodeSet.custom3

```scala generators/gemmini/src/main/scala/gemmini/GemminiConfigs.scala

case class GemminiArrayConfig[T <: Data : Arithmetic, U <: Data, V <: Data](
                                                                             opcodes: OpcodeSet = OpcodeSet.custom3,

                                                                             inputType: T,
                                                                             spatialArrayOutputType: T,
                                                                             accType: T,

                                                                             dataflow: Dataflow.Value = Dataflow.BOTH,

                                                                             tileRows: Int = 1,
                                                                             tileColumns: Int = 1,
                                                                             meshRows: Int = 16,
                                                                             meshColumns: Int = 16,

                                                                             ld_queue_length: Int = 8,
                                                                             st_queue_length: Int = 2,
                                                                             ex_queue_length: Int = 8,

                                                                             reservation_station_entries_ld: Int = 8,
                                                                             reservation_station_entries_st: Int = 4,
                                                                             reservation_station_entries_ex: Int = 16,

                                                                             sp_banks: Int = 4, // TODO support one-bank designs
                                                                             sp_singleported: Boolean = false,
                                                                             sp_capacity: GemminiMemCapacity = CapacityInKilobytes(256),
                                                                             spad_read_delay: Int = 4,

                                                                             acc_banks: Int = 2,
                                                                             acc_singleported: Boolean = false,
                                                                             acc_sub_banks: Int = -1,
                                                                             acc_capacity: GemminiMemCapacity = CapacityInKilobytes(64),
                                                                             acc_latency: Int = 2,

                                                                             dma_maxbytes: Int = 64, // TODO get this from cacheblockbytes
                                                                             dma_buswidth: Int = 128, // TODO get this from SystemBusKey

                                                                             shifter_banks: Int = 1, // TODO add separate parameters for left and up shifter banks

                                                                             aligned_to: Int = 1, // TODO we should align to inputType and accType instead

                                                                             mvin_scale_args: Option[ScaleArguments[T, U]] = None,
                                                                             mvin_scale_acc_args: Option[ScaleArguments[T, U]] = None,
                                                                             mvin_scale_shared: Boolean = false,
                                                                             acc_scale_args: Option[ScaleArguments[T, V]] = None,

                                                                             acc_read_full_width: Boolean = true,
                                                                             acc_read_small_width: Boolean = true,
                                                                             use_dedicated_tl_port: Boolean = true,

                                                                             tlb_size: Int = 4,
                                                                             use_tlb_register_filter: Boolean = true,
                                                                             max_in_flight_mem_reqs: Int = 16,

                                                                             ex_read_from_spad: Boolean = true,
                                                                             ex_read_from_acc: Boolean = true,
                                                                             ex_write_to_spad: Boolean = true,
                                                                             ex_write_to_acc: Boolean = true,

                                                                             hardcode_d_to_garbage_addr: Boolean = false,
                                                                             use_shared_tlb: Boolean = true,

                                                                             tile_latency: Int = 0,
                                                                             mesh_output_delay: Int = 1,

                                                                             use_tree_reduction_if_possible: Boolean = true,

                                                                             num_counter: Int = 8,

                                                                             has_training_convs: Boolean = true,
                                                                             has_max_pool: Boolean = true,
                                                                             has_nonlinear_activations: Boolean = true,
                                                                             has_dw_convs: Boolean = true,
                                                                             has_normalizations: Boolean = false,
                                                                             has_first_layer_optimizations: Boolean = true,

                                                                             use_firesim_simulation_counters: Boolean = false,

                                                                             use_shared_ext_mem: Boolean = false,
                                                                             clock_gate: Boolean = false,

                                                                             headerFileName: String = "gemmini_params.h"
                                                       ) {
```

Back to the LazyRoCC.scala, we see:

```scala rocket-chip/src/main/scala/tile/LazyRoCC.scala
object OpcodeSet {
  def custom0 = new OpcodeSet(Seq("b0001011".U))
  def custom1 = new OpcodeSet(Seq("b0101011".U))
  def custom2 = new OpcodeSet(Seq("b1011011".U))
  def custom3 = new OpcodeSet(Seq("b1111011".U))
  def all = custom0 | custom1 | custom2 | custom3
}
```

Build Process (if has RoCC): 

When building the whole Rocket Tile, it looks up if the RoCC is not empty (thanks to Scala/Chisel being OOP):
```scala rocket-chip/src/main/scala/tile/BaseTile.scala
// See LICENSE.SiFive for license details.

package freechips.rocketchip.tile

import chisel3._
import chisel3.util.{log2Ceil, log2Up}
import org.chipsalliance.cde.config._
import freechips.rocketchip.subsystem._
import freechips.rocketchip.diplomacy._

import freechips.rocketchip.interrupts._
import freechips.rocketchip.rocket._
import freechips.rocketchip.tilelink._
import freechips.rocketchip.util._
import freechips.rocketchip.prci.{ClockSinkParameters}

case object TileVisibilityNodeKey extends Field[TLEphemeralNode]
case object TileKey extends Field[TileParams]
case object LookupByHartId extends Field[LookupByHartIdImpl]

trait TileParams {
  val core: CoreParams
  val icache: Option[ICacheParams]
  val dcache: Option[DCacheParams]
  val btb: Option[BTBParams]
  val hartId: Int
  val beuAddr: Option[BigInt]
  val blockerCtrlAddr: Option[BigInt]
  val name: Option[String]
  val clockSinkParams: ClockSinkParameters
}

abstract class InstantiableTileParams[TileType <: BaseTile] extends TileParams {
  def instantiate(crossing: TileCrossingParamsLike, lookup: LookupByHartIdImpl)
                 (implicit p: Parameters): TileType
}

/** These parameters values are not computed based on diplomacy negotiation
  * and so are safe to use while diplomacy itself is running.
  */
trait HasNonDiplomaticTileParameters {
  implicit val p: Parameters
  def tileParams: TileParams = p(TileKey)

  def usingVM: Boolean = tileParams.core.useVM
  def usingUser: Boolean = tileParams.core.useUser || usingSupervisor
  def usingSupervisor: Boolean = tileParams.core.hasSupervisorMode
  def usingHypervisor: Boolean = usingVM && tileParams.core.useHypervisor
  def usingDebug: Boolean = tileParams.core.useDebug
  def usingRoCC: Boolean = !p(BuildRoCC).isEmpty
  ...
```

In the RocketTile.scala, we see:
```scala rocket-chip/src/main/scala/tile/RocketTile.scala

class RocketTile private(
      val rocketParams: RocketTileParams,
      crossing: ClockCrossingType,
      lookup: LookupByHartIdImpl,
      q: Parameters)
    extends BaseTile(rocketParams, crossing, lookup, q)
    with SinksExternalInterrupts
    with SourcesExternalNotifications
    with HasLazyRoCC  // implies CanHaveSharedFPU with CanHavePTW with HasHellaCache
    with HasHellaCache
    with HasICacheFrontend
{
...
class RocketTileModuleImp(outer: RocketTile) extends BaseTileModuleImp(outer)
    with HasFpuOpt
    with HasLazyRoCCModule
    with HasICacheFrontendModule {
  Annotated.params(this, outer.rocketParams)
...
  // Connect the coprocessor interfaces
  if (outer.roccs.size > 0) {
    cmdRouter.get.io.in <> core.io.rocc.cmd
    outer.roccs.foreach{ lm =>
      lm.module.io.exception := core.io.rocc.exception
      lm.module.io.fpu_req.ready := DontCare
      lm.module.io.fpu_resp.valid := DontCare
      lm.module.io.fpu_resp.bits.data := DontCare
      lm.module.io.fpu_resp.bits.exc := DontCare
    }
    core.io.rocc.resp <> respArb.get.io.out
    core.io.rocc.busy <> (cmdRouter.get.io.busy || outer.roccs.map(_.module.io.busy).reduce(_ || _))
    core.io.rocc.interrupt := outer.roccs.map(_.module.io.interrupt).reduce(_ || _)
    (core.io.rocc.csrs zip roccCSRIOs.flatten).foreach { t => t._2 <> t._1 }
  } else {
    // tie off
    core.io.rocc.cmd.ready := false.B
    core.io.rocc.resp.valid := false.B
    core.io.rocc.resp.bits := DontCare
    core.io.rocc.busy := DontCare
    core.io.rocc.interrupt := DontCare
  }
  // Dont care mem since not all RoCC need accessing memory
  core.io.rocc.mem := DontCare
```
In rocket-chip/src/main/scala/rocket/CustomInstructions.scala and IDecode.scala

```scala IDecode.scala
class RoCCDecode(aluFn: ALUFN = ALUFN())(implicit val p: Parameters) extends DecodeConstants
{
  val table: Array[(BitPat, List[BitPat])] = Array(
    CUSTOM0->           List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM0_RS1->       List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM0_RS1_RS2->   List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM0_RD->        List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM0_RD_RS1->    List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM0_RD_RS1_RS2->List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM1->           List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM1_RS1->       List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM1_RS1_RS2->   List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM1_RD->        List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM1_RD_RS1->    List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM1_RD_RS1_RS2->List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM2->           List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM2_RS1->       List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM2_RS1_RS2->   List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM2_RD->        List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM2_RD_RS1->    List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM2_RD_RS1_RS2->List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM3->           List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM3_RS1->       List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM3_RS1_RS2->   List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,N,CSR.N,N,N,N,N),
    CUSTOM3_RD->        List(Y,N,Y,N,N,N,N,N,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM3_RD_RS1->    List(Y,N,Y,N,N,N,N,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N),
    CUSTOM3_RD_RS1_RS2->List(Y,N,Y,N,N,N,Y,Y,A2_ZERO,A1_RS1, IMM_X, DW_XPR,aluFn.FN_ADD,   N,M_X,N,N,N,N,N,N,Y,CSR.N,N,N,N,N))
}
```

