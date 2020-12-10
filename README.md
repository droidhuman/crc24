# CRC24

This program is intended to calculate and check the CRC-24 checksum used in
secondary surveillance radar system (ADS-B, aircraft transponders in MODE-S)

## Table Of Content:

* [Getting Started](#getting-started)
    * [Prerequisites](#prerequisites)
    * [Installing](#installing)
    * [Running the tests](#running-the-tests)
    * [Documentation](#documentation)
* [About ADS-B CRC-24](#about-ads-b-crc-24)
* [Using](#using)
    * [Options](#options)
    * [Examples](#examples)
* [License](#license)

## Getting Started

### Prerequisites

To get the source code on your system, you may want to clone this repository:

```console
$ git clone https://github.com/RomeoGolf/crc24
```

To build this project you need to have haskell stack installed.

Install the latest version of
[Stack](https://github.com/commercialhaskell/stack); use

```console
stack upgrade
```

to confirm you are on the latest version.

### Installing

Make sure your Stack project builds without errors.
Use

```console
stack build
```

After your project is built successfully, you can install:

```console
stack install
```

to install executable `crc24` to the user `/bin` directory
(e. g. `C:\Users\<username>\AppData\Roaming\local\bin` on Windows), or

```console
stack install --local-bin-path ./bin/
```

to install `crc24` to the `./bin` directory in the current directory.

Also you can run it without installing by
`stack exec crc24 [ -- <arguments>]`, e. g.:

```console
stack exec crc24 -- -v
```

### Running the tests

Use `stack test` to test the project.

Use `stack test --coverage` instead to test the project
and get the textual coverage reports.

### Documentation

use `stack --haddock --no-haddock-hyperlink-source --haddock-arguments -odoc`
to get the project documentation in the `/doc` directory in the current
directory.

## About ADS-B CRC-24

CRC-24 description:
```console
   Name : CRC-24/ADS-B
  Width : 24
   Poly : FFF409 (hex)
   Init : 000000
  RefIn : false
 RefOut : false
 XorOut : address(*)
  Check : A05E66 (**)
```

(*) address:

- modified address from `AA` field for mode-S uplink or address for downlink
- modified address `0xFFFFFF` for All-Call in mode-S (uplink),
- interrogator identifier from II field for respondes (the 24 bits, where the
  last 4 bits is the identifier and the 20 bits have zero value),
- 0 for autogenerated squitters

(**)
Check = CRC-24 for the `«123456789»` string or `{ 0x31, 0x32, 0x33, 0x34,
0x35, 0x36, 0x37, 0x38, 0x39 }`

From the "MINIMUM OPERATIONAL PERFORMANCE SPECIFICATION FOR
SECONDARY SURVEILLANCE RADAR MODE S TRANSPONDERS" document:

```console
 The following combinations of texts and interrogation
 addresses AA will result in AP as shown:

 UF=4,  all fields = 0, AA = CO 51 F6 {HEX} : AP = all ZEROs.
 UF=4,  all fields = 0, AA = 3F AB F2 {HEX} : AP = AA AA AA {HEX}.
 UF=20, all fields = 0, AA = AC C5 55 {HEX} : AP = all ZEROs.
 UF=20, all fields = 0, AA = 53 3F 51 {HEX} : AP = AA AA AA {HEX}.

 DF=5,  all fields = 0, AA = 20 78 CE {HEX} : AP = all ZEROs.
 DF=5,  all fields = 0, AA = 75 2D 9B {HEX} : AP = 55 55 55 {HEX}.
 DF=21, all fields = 0, AA = 0B 15 4F {HEX} : AP = all ZEROs.
 DF=2l, all fields = 0, AA = 5E 40 1A {HEX} : AP = 55 55 55 {HEX}.
```

To encode AP field in the MODE-S uplink:

1. Calculate CRC-24 for the message with zero values in the 3 low bytes.
2. Encode the interrogator MODE-S address. Use the `0xFFFFFF` address for
the all-call (UF11).
3. Calculate AP field: `<CRC-24>` XOR `<modified address>`.

Don`t need the address encoding for the АР field in the MODE-S downlink.
Use the address as is. Interrogator identifier may be as addres
(if it was in the interrogation)

The address must be encoded for the AP field in the MODE-S uplink.
The address  must be multiplied om polynom CRC-24, then most significant
24 bits is used.

For example:

```console
 For AA = 0xC051F6 encoded address is: 0x80665F
 For AA = 0x3FABF2 encoded address is: 0x2ACCF5
 For AA = 0xACC555 encoded address is: 0xC88294
 For AA = 0x533F51 encoded address is: 0x62283E
```

CRC-24 for transmitted data:

```console
 UF/DF 4:    0x20 00 00 00 00 00 00,                       CRC-24 = 0x80665F
 UF/DF 5:    0x28 00 00 00 00 00 00,                       CRC-24 = 0x2078CE
 UF/DF 20:   0xA0 00 00 00 00 00 00 00 00 00 00 00 00 00,  CRC-24 = 0xC88294
 UF/DF 21:   0xA8 00 00 00 00 00 00 00 00 00 00 00 00 00,  CRC-24 = 0x0B154F
```

The encoded all-call address `(0xFFFFFF)` = `0xAAAC07`

UF11 with zero fields = `0x58000000`, CRC-24 = `0xE0EF0D`, AP = `0x4A430A`

Example DF11 squitter:

```console
 0x 5F 11 22 31 3F 07 8D
 0x5F: DF field = 11 (5 bits) and CA field = 3 (3 bits)
 0x112231 – MODE-S address
 0x3F078D – CRC-24
```

And so `crc24 [0x8d, 0x07, 0x3f, 0x31, 0x22, 0x11, 0x5f]` result in 0

## Using

```console
> crc24 [options] [input data as HEX bytes, low bytes first]
```

Input data example:

```console
31 32 33 34 35 36 37 38 39
```

It corresponds to the "123456789" ASCII string

### Options

```console
 --check-crc             Check CRC-24 for an input data (without XorOut)
 --check-crc-uplink      Check CRC-24 for an uplink input data
 --check-crc-downlink    Check CRC-24 for an downlink input data
 --calc-crc              Calculate CRC-24 for an input data (without XorOut)
 --calc-crc-uplink       Calculate CRC-24 for an uplink input data
 --calc-crc-downlink     Calculate CRC-24 for an downlink input data
 -e, --encode-addr       Encode MODE-S uplink address
 --calc-ap               Calculate MODE-S uplink AP field
 -s, --show-input        Show input data
 -fFILE, --file=FILE     Input HEX-file FILE (the data for CRC-24 processing)
 -aADDR, --address=ADDR  MODE-S aircraft address ADDR (default 0x00FFFFFF)
 --arg-file FILE         The text FILE contained commandline arguments
 -v, --version           Show the version information
 -h, -?, --help          Print help message (options list)
```

`--check-crc`, `--check-crc-uplink`, `--check-crc-downlink` options need for
data with a CRC-24 checksum in 3 low bytes; the data length should be at least
3 bytes. E. g. `00 00 00 31 32 33 34 35 36 37 38 39` is a correct data with
the wrong zero checksum.

`--calc-crc`, `--calc-crc-uplink`, `--calc-crc-downlink` options need for data
only without a checksum. E. g. `31 32 33 34 35 36 37 38 39` is a correct data.

`--check-crc-uplink`, `--check-crc-downlink`, `--calc-crc-uplink`,
`--calc-crc-downlink`, `--encode-addr`, `--calc-ap` options need for
`--address` option. If `--address` option is not present, `0x00FFFFFF` default
all-call address will be used.

If `--file` options is present, commandline input data will be ignored.


### Examples

```console
> crc24 -v
Version: 0.1
```

```console
> crc24 --check-crc 66 5E A0 31 32 33 34 35 36 37 38 39
CRC-24 is OK
```

```console
> crc24 --check-crc 00 00 00 31 32 33 34 35 36 37 38 39
CRC-24 is wrong: 0xA05E66
```

```console
> crc24 --calc-crc 31 32 33 34 35 36 37 38 39
CRC-24: 0xA05E66
```

```console
> crc24 -sv -a0x3fabf2 --check-crc-uplink --calc-ap --encode-addr aa aa aa 00 00 00 20
Version: 0.1
Address: 0x3FABF2
No data file name
Input message (hex): aa aa aa 00 00 00 20
Uplink CRC-24 is OK
Encoded Address: 0x2ACCF5
Uplink AP field: 0xAAAAAA
```

```console
> crc24 --arg-file=args.txt
Address: 0x112231
Input message (hex): 8d 07 3f 31 22 11 5f
CRC-24 is OK
Encoded Address: 0x1E3c94
```

```console
args.txt:
>>>>>
-s -a0x112231 --check-crc --encode-addr -finput.txt
<<<<<

input.txt:
>>>>>
8d 07 3f 31 22 11 5f
<<<<<
```

## License

This project is licensed under the MIT License - see
the [LICENSE](LICENSE) file for details
