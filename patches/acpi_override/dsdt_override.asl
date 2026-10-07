/*
 * ACPI DSDT Override for Lenovo IdeaPad D330-10IGL
 * Eliminates duplicate \_SB.PCI0.RP04 namespace collision (AE_ALREADY_EXISTS error)
 */

DefinitionBlock ("dsdt_override.aml", "DSDT", 2, "LENOVO", "CB-01   ", 0x00000002)
{
    Scope (\_SB)
    {
        Scope (PCI0)
        {
            /*
             * Original OEM DSDT and secondary OEM SSDT both define RP04 (Root Port 4).
             * When the Linux ACPI table loader iterates tables, RP04 triggers:
             * "ACPI Error: [RP04] Namespace lookup failure, AE_ALREADY_EXISTS"
             * This override provides the authoritative single RP04 definition with correct _ADR (0x00130000).
             */
            Device (RP04)
            {
                Name (_ADR, 0x00130000)
                Name (_UID, 0x04)

                Method (_STA, 0, NotSerialized)
                {
                    Return (0x0F)
                }
            }
        }
    }
}
