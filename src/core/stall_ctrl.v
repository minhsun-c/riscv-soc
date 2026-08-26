`timescale 1ns / 1ps

/**
 * Module: stall_ctrl (Pipeline Stall Arbitration)
 *
 * Description:
 * One place that decides whether the pipeline moves this cycle.
 *
 * Until week 18 there was exactly one reason to stall -- a load-use hazard --
 * so hdu's output went straight to every stall port. Memory that can make the
 * pipeline wait is a second reason, and week 20's peripherals will be slower
 * again. Collecting them here means the next reason is a port, not a rewrite.
 *
 * All three are ORed rather than prioritised, because stalling is not a
 * choice between reasons: if any of them says wait, the pipeline waits. What
 * *is* a priority question is flushing, and that lives in core.v with the
 * redirect chain.
 *
 * @port load_use_i [Input]  hdu says the next instruction reads a value that
 *                           is not ready yet.
 * @port im_wait_i  [Input]  The fetched instruction has not arrived.
 * @port dm_wait_i  [Input]  A load or store in MEM has not completed.
 * @port stall_o    [Output] Freeze IF, ID and the ID/EX register.
 */

module stall_ctrl (
    input  load_use_i,
    input  im_wait_i,
    input  dm_wait_i,
    output stall_o
);

  assign stall_o = load_use_i | im_wait_i | dm_wait_i;

endmodule
