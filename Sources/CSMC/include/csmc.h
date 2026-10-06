#ifndef CSMC_H
#define CSMC_H

#include <stdint.h>
#include <stdbool.h>

/// A value read from the SMC.
typedef struct {
    char key[5];          // null-terminated 4-char key
    uint32_t dataSize;    // number of valid bytes
    char dataType[5];     // null-terminated 4-char type (e.g. "ui8 ", "flt ")
    uint8_t bytes[32];    // raw value bytes
} CSMCVal;

/// Open a connection to the AppleSMC service. Returns 0 on success.
int csmc_open(void);

/// Close the SMC connection.
void csmc_close(void);

/// Read a key's value. Returns 0 on success, non-zero on failure.
int csmc_read(const char *key, CSMCVal *out);

/// Write raw bytes to a key. Requires root. Returns 0 on success.
/// The number of bytes written is clamped to the key's declared size.
int csmc_write(const char *key, const uint8_t *bytes, uint32_t size);

/// Whether the given key exists on this machine.
bool csmc_key_exists(const char *key);

/// Number of keys the SMC publishes (the "#KEY" value). 0 if it can't be read.
uint32_t csmc_key_count(void);

/// Name of the key at `index` in the SMC's table. `out_key` must hold 5 bytes.
/// Returns 0 on success. Enumerating is the only way to find a model's real sensors.
int csmc_key_at_index(uint32_t index, char *out_key);

#endif /* CSMC_H */
