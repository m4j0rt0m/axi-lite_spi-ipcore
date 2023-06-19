# AXI4-Lite SPI (Single Clock)

![lint-verilator](https://github.com/m4j0rt0m/axi-lite_spi-ipcore/workflows/lint-verilator/badge.svg)
![synth-quartus](https://github.com/m4j0rt0m/axi-lite_spi-ipcore/workflows/synth-quartus/badge.svg)
![synth-yosys](https://github.com/m4j0rt0m/axi-lite_spi-ipcore/workflows/synth-yosys/badge.svg)

[TOC]

## Introduction

The IP core implements a simplified and lightweight subset of the **Xilinx AXI SPI v3.0 LogiCORE IP** with some modifications and additions.

## Features

* Registers accessible through 32bit AXI transactions.
* Master mode only.
* Clock frequency ratio set by a special RCLK register accessible through AXI interface (i.e. 1/2, 1/4, 1/8...).

## Overview

![](https://raw.githubusercontent.com/m4j0rt0m/axi-lite_spi-ipcore/documentation/documentation/axi-spi-single-clk.png)

## Register Space

### Register Address Map

#### Interrupt Controller Grouping (*not implemented, temporarily ignored*)

| Address Offset | Register Name | Access Type | Default Value (hex) | Description               |
|:--------------:|:-------------:|:-----------:|:-------------------:|:------------------------- |
|      0x1C      |     GIER      |     RW      |     0x00000000      | Global interrupt register |
|      0x20      |      ISR      |     RW      |     0x00000000      | Interrupt status register |
|      0x28      |      IER      |     RW      |     0x00000000      | Interrupt enable register |

#### Core Grouping

| Address Offset | Register Name | Access Type | Default Value (hex) | Description                      |
|:--------------:|:-------------:|:-----------:|:-------------------:|:-------------------------------- |
|      0x40      |      SRR      |     WO      |         N/A         | Software reset register          |
|      0x60      |      CR       |     RW      |     0x00000180      | SPI control register             |
|      0x64      |      SR       |     RO      |     0x000000a5      | SPI status register              |
|      0x68      |      DTR      |     RW      |     0x00000000      | SPI data transmit register       |
|      0x6C      |      DRR      |     RO      |         N/A         | SPI data receive register        |
|      0x70      |      SSR      |     RW      |     0xffffffff      | SPI slave select register        |
|      0x74      |     TFOR      |     RO      |     0x00000000      | Transmit FIFO occupancy register |
|      0x78      |     RFOR      |     RO      |     0x00000000      | Receive FIFO occupancy register  |

#### Custom Grouping

| Address Offset | Register Name | Access Type | Default Value (hex) | Description                    |
|:--------------:|:-------------:|:-----------:|:-------------------:|:------------------------------ |
|      0x30      |     RCLK      |     RW      |     0x00000004      | Clock frequency ratio register |

### Software Reset Register

### SPI Control Register

### SPI Status Register

### SPI Data Transmit Register

### SPI Data Receive Register

### SPI Slave Select Register

### Transmit FIFO Occupancy Register

### Receive FIFO Occupancy Register

### Clock Frequency Ratio Register