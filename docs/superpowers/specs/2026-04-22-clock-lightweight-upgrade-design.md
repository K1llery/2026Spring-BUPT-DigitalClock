## TEC-8 Electronic Clock Lightweight Upgrade Design

### Background

The current project already satisfies the base electronic clock requirements from the course PDF:

- time display (`HH:MM:SS`)
- clock division and counting
- reset and time-setting controls
- stable module split for top-level integration, time core, control path, and display path

The remaining gaps are mostly in engineering quality rather than base functionality:

- key handling is edge-only and can be unstable on real hardware
- manual time setting is slow because adjustment requires repeated short presses
- simulation coverage is too narrow for a final course demonstration
- the CPLD is resource-constrained, so any improvement must remain lightweight

### Goal

Deliver a low-risk improvement package that is easy to demonstrate in acceptance:

1. keep the existing display interface and pin plan unchanged
2. improve key robustness with lightweight debouncing
3. add a visible bonus feature: long-press fast adjustment in time-setting modes
4. extend simulation to cover wrap-around, subtract, clear, and edit-mode hold behavior
5. preserve Quartus compilability on `EPM7128SLC84-15`

### Design Choice

Use a shared low-cost key processing strategy inside `input_timebase.v` instead of instantiating full debounce modules per key.

- keep the existing 1 Hz counter as the main time base
- derive coarse sample strobes from that counter for debounce sampling and hold-repeat timing
- debounce all three keys with short sampled history
- enable long-press repeat only on `pulse_in`, because it is the only adjustment key

This keeps the implementation aligned with the CPLD area constraint while adding an interaction upgrade that is easy to explain in the defense.

### Verification Plan

- rerun the existing Icarus flow after RTL changes
- extend `tb_clock.v` to cover:
  - reset to `00:00:00`
  - run-mode one-second increment
  - `23:59:59 -> 00:00:00`
  - edit mode freezes normal running
  - hour/minute/second decrement wrap-around
  - clear behavior in edit modes
  - mode loop with alarm disabled
  - long-press fast adjustment
- rerun Quartus `map/fit/asm/tan` and compare resource usage

### Non-Goals

- no top-level port rename
- no pin reassignment
- no unified scanned display redesign
- no full alarm/buzzer feature expansion in this iteration
