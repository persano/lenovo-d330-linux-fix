// SPDX-License-Identifier: GPL-2.0-only
/*
 * lenovo_d330_fix.c - Display Power & Resume Stabilization Driver for Lenovo D330-10IGL
 *
 * Copyright (C) 2026 Antigravity Autonomous Systems
 *
 * Problem:
 * On Lenovo IdeaPad D330-10IGL (Type 82H0, Intel Gemini Lake Refresh UHD 600),
 * resuming from S3/S0ix sleep can leave the MIPI-DSI panel dark. The fixed part
 * is a DRM driver issue (i915 rejects a render-compressed framebuffer combined
 * with 90/270 rotation); the still-open part is a DSI panel power/sequencing
 * issue on resume. See docs/research/DISPLAY_RESUME_CCS_MODIFIER.md. Hardware
 * PSR also hangs the GLK pipe, which the shipped modprobe parameters disable.
 *
 * This module:
 * 1. Verifies DMI platform match (Lenovo IdeaPad D330-10IGL / 82H0).
 * 2. Hooks kernel power management notifications via register_pm_notifier().
 * 3. Prints honest suspend/resume breadcrumbs so `dmesg | grep lenovo_d330_fix`
 *    confirms the DMI-matched module is loaded.
 *
 * NOTE: this out-of-tree module cannot fix the display. The DRM fix (stop
 * advertising CCS on 82H0) lives in
 * drivers/gpu/drm/i915/display/skl_universal_plane.c and is delivered only by
 * patches/d330_display_resume_fix.patch, applied to a kernel source tree via
 * `scripts/install_dkms.sh --kernel-src` (Option 2). This module only prints
 * breadcrumbs.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/pci.h>
#include <linux/dmi.h>
#include <linux/suspend.h>
#include <linux/delay.h>
#include <linux/ktime.h>

#define DRV_NAME    "lenovo_d330_fix"
#define DRV_VERSION "1.0.0"

/*
 * No-op retained for backward compatibility with existing modprobe.d snippets
 * and packaging references. This module does not change panel timing; it only
 * prints breadcrumbs. The display fix is the Option 2 kernel patch (see the
 * module NOTE above).
 */
static int power_cycle_delay_ms = 600;
module_param(power_cycle_delay_ms, int, 0644);
MODULE_PARM_DESC(power_cycle_delay_ms, "No-op retained for compatibility; this module only prints breadcrumbs (default: 600)");

static bool force_load = false;
module_param(force_load, bool, 0644);
MODULE_PARM_DESC(force_load, "Force driver load even if DMI check does not match");

static bool debug = true;
module_param(debug, bool, 0644);
MODULE_PARM_DESC(debug, "Enable verbose driver debugging messages");

#define d330_info(fmt, ...) \
	pr_info("[" DRV_NAME "] " fmt, ##__VA_ARGS__)

#define d330_dbg(fmt, ...) \
	do { if (debug) pr_info("[" DRV_NAME "][DEBUG] " fmt, ##__VA_ARGS__); } while (0)

static ktime_t last_suspend_time;
static struct notifier_block d330_pm_notifier;

/*
 * DMI Platform Identification Table
 */
static const struct dmi_system_id d330_dmi_table[] = {
	{
		.ident = "Lenovo IdeaPad D330-10IGL",
		.matches = {
			DMI_EXACT_MATCH(DMI_SYS_VENDOR, "LENOVO"),
			DMI_MATCH(DMI_PRODUCT_VERSION, "Lenovo ideapad D330-10IGL"),
		},
	},
	{
		.ident = "Lenovo IdeaPad D330-10IGL (82H0)",
		.matches = {
			DMI_EXACT_MATCH(DMI_SYS_VENDOR, "LENOVO"),
			DMI_MATCH(DMI_PRODUCT_NAME, "82H0"),
		},
	},
	{
		.ident = "Lenovo IdeaPad D330-10IGM (81H3/81MD)",
		.matches = {
			DMI_EXACT_MATCH(DMI_SYS_VENDOR, "LENOVO"),
			DMI_MATCH(DMI_PRODUCT_VERSION, "Lenovo ideapad D330-10IGM"),
		},
	},
	{ }
};
MODULE_DEVICE_TABLE(dmi, d330_dmi_table);

/*
 * Power Management Notification Callback
 */
static int d330_pm_callback(struct notifier_block *nb, unsigned long action, void *ptr)
{
	switch (action) {
	case PM_SUSPEND_PREPARE:
	case PM_HIBERNATION_PREPARE:
		last_suspend_time = ktime_get();
		d330_dbg("System preparing for sleep. Recorded suspend timestamp.\n");
		break;

	case PM_POST_SUSPEND:
	case PM_POST_HIBERNATION: {
		ktime_t now = ktime_get();
		s64 elapsed_ms = ktime_to_ms(ktime_sub(now, last_suspend_time));

		/*
		 * Honest breadcrumb only. This module does not touch the panel
		 * or the display pipeline; the display fix is the kernel patch
		 * patches/d330_display_resume_fix.patch (Option 2), not this
		 * module.
		 */
		d330_info("System resumed after %lld ms; this module only logs, it does not fix the display (see Option 2 kernel patch).\n",
			  elapsed_ms);
		break;
	}

	default:
		break;
	}

	return NOTIFY_OK;
}

static int __init lenovo_d330_fix_init(void)
{
	const struct dmi_system_id *matched;

	matched = dmi_first_match(d330_dmi_table);
	if (!matched && !force_load) {
		pr_warn("[" DRV_NAME "] Platform not matched in DMI table. Use force_load=1 to override.\n");
		return -ENODEV;
	}

	if (matched)
		d330_info("Matched platform: %s\n", matched->ident);
	else
		d330_info("Forced load on unmatched platform.\n");

	d330_info("Initializing DMI banner module; the display fix is delivered by the Option 2 kernel patch, not this module.\n");

	d330_pm_notifier.notifier_call = d330_pm_callback;
	d330_pm_notifier.priority = 100; /* High priority to run early in wake sequence */

	if (register_pm_notifier(&d330_pm_notifier)) {
		pr_err("[" DRV_NAME "] Failed to register PM notifier callback!\n");
		return -EFAULT;
	}

	d330_info("Driver loaded successfully (v%s).\n", DRV_VERSION);
	return 0;
}

static void __exit lenovo_d330_fix_exit(void)
{
	unregister_pm_notifier(&d330_pm_notifier);
	d330_info("Driver unloaded cleanly.\n");
}

module_init(lenovo_d330_fix_init);
module_exit(lenovo_d330_fix_exit);

MODULE_AUTHOR("Antigravity Autonomous Agent <engineering@lenovo-d330-fix.local>");
MODULE_DESCRIPTION("Lenovo IdeaPad D330-10IGL Display Power & Resume Stabilization Quirk Driver");
MODULE_LICENSE("GPL");
MODULE_VERSION(DRV_VERSION);
