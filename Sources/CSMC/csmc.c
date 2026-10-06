#include "csmc.h"

#include <IOKit/IOKitLib.h>
#include <string.h>

// SMC user-client command selectors and operations (well-known, from Apple's
// PowerManagement smc.c and smcFanControl).
#define KERNEL_INDEX_SMC      2
#define SMC_CMD_READ_BYTES    5
#define SMC_CMD_WRITE_BYTES   6
#define SMC_CMD_READ_KEYINFO  9
#define SMC_CMD_READ_INDEX    8

typedef struct {
    char major;
    char minor;
    char build;
    char reserved[1];
    uint16_t release;
} SMCKeyData_vers_t;

typedef struct {
    uint16_t version;
    uint16_t length;
    uint32_t cpuPLimit;
    uint32_t gpuPLimit;
    uint32_t memPLimit;
} SMCKeyData_pLimitData_t;

typedef struct {
    uint32_t dataSize;
    uint32_t dataType;
    char dataAttributes;
} SMCKeyData_keyInfo_t;

typedef char SMCBytes_t[32];

typedef struct {
    uint32_t key;
    SMCKeyData_vers_t vers;
    SMCKeyData_pLimitData_t pLimitData;
    SMCKeyData_keyInfo_t keyInfo;
    char result;
    char status;
    char data8;
    uint32_t data32;
    SMCBytes_t bytes;
} SMCKeyData_t;

static io_connect_t g_conn = 0;

// Pack a 4-character key string into a big-endian uint32.
static uint32_t key_to_u32(const char *str) {
    uint32_t total = 0;
    for (int i = 0; i < 4; i++) {
        total += ((uint32_t)(uint8_t)str[i]) << (8 * (3 - i));
    }
    return total;
}

// Unpack a uint32 type code into a 4-char string.
static void u32_to_str(char *str, uint32_t val) {
    str[0] = (char)((val >> 24) & 0xff);
    str[1] = (char)((val >> 16) & 0xff);
    str[2] = (char)((val >> 8) & 0xff);
    str[3] = (char)(val & 0xff);
    str[4] = 0;
}

int csmc_open(void) {
    io_service_t service =
        IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == 0) return 1;

    kern_return_t r = IOServiceOpen(service, mach_task_self(), 0, &g_conn);
    IOObjectRelease(service);
    return (r == kIOReturnSuccess) ? 0 : 2;
}

void csmc_close(void) {
    if (g_conn) {
        IOServiceClose(g_conn);
        g_conn = 0;
    }
}

static kern_return_t smc_call(SMCKeyData_t *in, SMCKeyData_t *out) {
    size_t in_size = sizeof(SMCKeyData_t);
    size_t out_size = sizeof(SMCKeyData_t);
    return IOConnectCallStructMethod(g_conn, KERNEL_INDEX_SMC,
                                     in, in_size, out, &out_size);
}

static int read_key_info(uint32_t key, SMCKeyData_keyInfo_t *info) {
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = key;
    in.data8 = SMC_CMD_READ_KEYINFO;

    kern_return_t r = smc_call(&in, &out);
    if (r != kIOReturnSuccess || out.result != 0) return 1;
    *info = out.keyInfo;
    return 0;
}

// The SMC exposes its key table by index: "#KEY" holds the count, and command 8 maps an
// index to a key name. That's the only way to discover the sensors a machine actually has —
// they differ by model, and a hardcoded list is wrong on every Mac it wasn't written for.
uint32_t csmc_key_count(void) {
    CSMCVal v;
    if (csmc_read("#KEY", &v) != 0 || v.dataSize < 4) return 0;
    return ((uint32_t)v.bytes[0] << 24) | ((uint32_t)v.bytes[1] << 16) |
           ((uint32_t)v.bytes[2] << 8) | (uint32_t)v.bytes[3];
}

int csmc_key_at_index(uint32_t index, char *out_key) {
    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.data8 = SMC_CMD_READ_INDEX;
    in.data32 = index;

    kern_return_t r = smc_call(&in, &out);
    if (r != kIOReturnSuccess || out.result != 0) return 1;
    u32_to_str(out_key, out.key);
    return 0;
}

bool csmc_key_exists(const char *key) {
    SMCKeyData_keyInfo_t info;
    return read_key_info(key_to_u32(key), &info) == 0;
}

int csmc_read(const char *key, CSMCVal *val) {
    memset(val, 0, sizeof(*val));
    uint32_t k = key_to_u32(key);

    SMCKeyData_keyInfo_t info;
    if (read_key_info(k, &info) != 0) return 1;

    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = k;
    in.keyInfo.dataSize = info.dataSize;
    in.data8 = SMC_CMD_READ_BYTES;

    kern_return_t r = smc_call(&in, &out);
    if (r != kIOReturnSuccess || out.result != 0) return 2;

    uint32_t n = info.dataSize > 32 ? 32 : info.dataSize;
    val->dataSize = info.dataSize;
    u32_to_str(val->dataType, info.dataType);
    strncpy(val->key, key, 4);
    val->key[4] = 0;
    memcpy(val->bytes, out.bytes, n);
    return 0;
}

int csmc_write(const char *key, const uint8_t *bytes, uint32_t size) {
    uint32_t k = key_to_u32(key);

    SMCKeyData_keyInfo_t info;
    if (read_key_info(k, &info) != 0) return 1;

    SMCKeyData_t in, out;
    memset(&in, 0, sizeof(in));
    memset(&out, 0, sizeof(out));
    in.key = k;
    in.data8 = SMC_CMD_WRITE_BYTES;
    in.keyInfo.dataSize = info.dataSize;

    uint32_t n = size < info.dataSize ? size : info.dataSize;
    if (n > 32) n = 32;
    memcpy(in.bytes, bytes, n);

    kern_return_t r = smc_call(&in, &out);
    if (r != kIOReturnSuccess || out.result != 0) return 2;
    return 0;
}
