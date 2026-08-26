#ifndef AXIL_CHECKER_H
#define AXIL_CHECKER_H

#include <cstdint>
#include <cstdio>
#include <string>

/*
 * A per-cycle AXI4-Lite protocol checker.
 *
 * The point of this file is that a design can produce correct data while
 * violating the protocol, and the violation will not show up until it meets a
 * slave that behaves differently. Waveforms look fine. Tests pass. Then the
 * real IP arrives and the bus hangs.
 *
 * Three rules, checked on every channel, every cycle:
 *
 *   1. Once VALID is asserted it stays asserted until READY is seen. Pulling
 *      it back because the requester changed its mind is the classic deadlock.
 *   2. While VALID is high and READY has not been seen, the payload must not
 *      change. A slave is allowed to sample it on any of those cycles.
 *   3. A response may not appear before the request it answers.
 *
 * Plus a liveness check: VALID high for a long time with no READY means
 * somebody is waiting for somebody who is waiting for them.
 */

struct AxiChannel {
    const char *name;
    bool prev_valid = false;
    uint64_t prev_payload = 0;
    int stuck = 0;

    // Call once per cycle, after eval() and before the clock edge.
    void check(bool valid, bool ready, uint64_t payload, int &errors)
    {
        if (prev_valid && !valid) {
            // VALID went away. That is only legal if a handshake happened,
            // which the caller records by clearing prev_valid.
            printf("  [AXI] %s: VALID dropped before READY\n", name);
            errors++;
        }
        if (prev_valid && valid && payload != prev_payload) {
            printf("  [AXI] %s: payload changed while VALID was held\n", name);
            errors++;
        }

        if (valid && !ready) {
            if (++stuck > 200) {
                printf("  [AXI] %s: VALID held for %d cycles with no READY "
                       "(deadlock?)\n",
                       name, stuck);
                errors++;
                stuck = 0;
            }
        } else {
            stuck = 0;
        }

        // A completed handshake ends this beat; anything after is a new one.
        prev_valid = valid && !ready;
        prev_payload = payload;
    }
};

struct AxiLiteChecker {
    AxiChannel aw{"AW"}, w{"W"}, b{"B"}, ar{"AR"}, r{"R"};
    int errors = 0;

    // Requests outstanding, so a response arriving unbidden is caught.
    int writes_issued = 0;   // AW handshakes
    int wdata_issued = 0;    // W handshakes
    int reads_issued = 0;    // AR handshakes

    void cycle(bool awvalid, bool awready, uint32_t awaddr,
               bool wvalid, bool wready, uint32_t wdata, uint8_t wstrb,
               bool bvalid, bool bready,
               bool arvalid, bool arready, uint32_t araddr,
               bool rvalid, bool rready, uint32_t rdata)
    {
        aw.check(awvalid, awready, awaddr, errors);
        w.check(wvalid, wready, ((uint64_t) wdata << 4) | wstrb, errors);
        ar.check(arvalid, arready, araddr, errors);
        b.check(bvalid, bready, 0, errors);
        r.check(rvalid, rready, rdata, errors);

        if (awvalid && awready) writes_issued++;
        if (wvalid && wready) wdata_issued++;
        if (arvalid && arready) reads_issued++;

        // A write response needs both halves of the write to have gone.
        if (bvalid && (writes_issued == 0 || wdata_issued == 0)) {
            printf("  [AXI] B: response before the write was issued\n");
            errors++;
        }
        if (rvalid && reads_issued == 0) {
            printf("  [AXI] R: data before any read address was accepted\n");
            errors++;
        }
        if (bvalid && bready) {
            writes_issued--;
            wdata_issued--;
        }
        if (rvalid && rready) reads_issued--;
    }

    void report(const char *label)
    {
        if (errors == 0) {
            printf("\033[32m[SUCCESS] \033[0m%s (AXI4-Lite protocol clean)\n", label);
        } else {
            printf("\033[31m[ERROR]   \033[0m%s (%d AXI protocol violations)\n",
                   label, errors);
        }
    }
};

#endif  // AXIL_CHECKER_H
