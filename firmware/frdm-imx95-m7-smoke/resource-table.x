/*
 * Preserve the zero-vdev remoteproc resource table in ITCM.
 * The table advertises no RPMsg devices or carveouts in this first slice.
 */
SECTIONS
{
  .resource_table : ALIGN(4)
  {
    KEEP(*(.resource_table));
  } > FLASH
}
INSERT AFTER .rodata;
