#pragma once

// Bridge to PowerUI.framework's PowerUISmartChargeClient, the client System Settings
// uses for Battery › Charge Limit. It talks to PowerUIAgent (root, system domain) over
// the `com.apple.powerui.smartChargeManager` mach service. The framework is private, so
// it is loaded at runtime and called through the ObjC runtime rather than linked.
//
// Every call returns 0 on success and -1 on failure.

/// 1 when this Mac offers the manual charge limit, 0 otherwise (including no PowerUI).
int ewiz_powerui_supported(void);

/// The limits PowerUIAgent accepts (80, 85, … 100 at the time of writing), in the order
/// it reports them. Writes at most `max` of them and the count to `*count`.
int ewiz_powerui_available_limits(int *limits, int max, int *count);

/// The configured limit and whether it is being enforced. A disabled limit reads 100.
int ewiz_powerui_get_limit(int *limit, int *enabled);

/// Enable the limit at `limit`, which must be one of the available limits.
int ewiz_powerui_set_limit(int limit);

/// Turn the limit off. PowerUIAgent remembers the last value for System Settings.
int ewiz_powerui_disable(void);
