/*
 * @SAMPLE@ -- zfpga hello-world scaffold for @BOARD@.
 * Confirms Zephyr boots on the PS with the PL bitstream loaded. Add your
 * datapath bring-up (SPI/JESD204/DMA) from here.
 */
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(@SAMPLE@, LOG_LEVEL_INF);

int main(void)
{
	LOG_INF("@SAMPLE@ up on @BOARD@");
	return 0;
}
